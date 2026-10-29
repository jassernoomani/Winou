package tn.winou.photos;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Iterator;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.stream.MemoryCacheImageOutputStream;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.drew.imaging.ImageMetadataReader;
import com.drew.metadata.exif.ExifIFD0Directory;

import net.coobird.thumbnailator.Thumbnails;
import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.infra.MlClient;

/** Upload validation and the EXIF-free public copy of each photo. */
@Component
public class Images {

    private static final float JPEG_QUALITY = 0.88f;

    private final WinouProperties.Uploads limits;
    private final MlClient ml;

    public Images(WinouProperties properties, MlClient ml) {
        this.limits = properties.uploads();
        this.ml = ml;
    }

    /** The original's content type, and the copy served to everyone. */
    public record PublicCopy(byte[] jpeg, String originalType) {}

    /**
     * Validates an upload and returns an upright JPEG without metadata, including the GPS position
     * phones write into photos. The format is checked from the file content, not its name.
     */
    public PublicCopy publicCopy(byte[] data) {
        if (data.length > limits.maxBytes()) {
            throw ApiException.coded(HttpStatus.CONTENT_TOO_LARGE, "file_too_large",
                    "Image is larger than " + limits.maxBytes() / 1_000_000 + " MB.");
        }
        if (isHeif(data)) {
            // HEIC is the default photo format on iPhones; Java cannot decode it, the ML service can
            return new PublicCopy(ml.heicToJpeg(data, limits.publicImageMaxSide()), "image/heif");
        }
        try (ImageInputStream in = ImageIO.createImageInputStream(new ByteArrayInputStream(data))) {
            Iterator<ImageReader> readers = ImageIO.getImageReaders(in);
            if (!readers.hasNext()) {
                throw invalidImage();
            }
            ImageReader reader = readers.next();
            try {
                String type = switch (reader.getFormatName().toLowerCase()) {
                    case "jpeg", "jpg" -> "image/jpeg";
                    case "png" -> "image/png";
                    case "webp" -> "image/webp";
                    default -> throw ApiException.coded(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "unsupported_format",
                            "Use a JPEG, PNG, WebP or HEIC image.");
                };
                reader.setInput(in, true, true);
                // Checked before decoding: a small file can declare a huge image
                if ((long) reader.getWidth(0) * reader.getHeight(0) > limits.maxImagePixels()) {
                    throw ApiException.coded(HttpStatus.CONTENT_TOO_LARGE, "image_too_large",
                            "Image resolution is too high.");
                }
                BufferedImage image = upright(reader.read(0), orientation(data));
                return new PublicCopy(jpeg(shrink(image, limits.publicImageMaxSide())), type);
            } finally {
                reader.dispose();
            }
        } catch (ApiException e) {
            throw e;
        } catch (IOException | RuntimeException e) {
            throw invalidImage(); // corrupt or truncated file
        }
    }

    private static ApiException invalidImage() {
        return ApiException.coded(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "invalid_image",
                "The file is not a readable image.");
    }

    /** ISO-BMFF "ftyp" box with a HEIF brand, at bytes 4-12. */
    static boolean isHeif(byte[] data) {
        if (data.length < 12 || !new String(data, 4, 4, java.nio.charset.StandardCharsets.US_ASCII).equals("ftyp")) {
            return false;
        }
        String brand = new String(data, 8, 4, java.nio.charset.StandardCharsets.US_ASCII);
        return switch (brand) {
            case "heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1" -> true;
            default -> false;
        };
    }

    /** EXIF orientation 1-8 (1 = upright); 1 when the file has none. */
    private static int orientation(byte[] data) {
        try {
            var directory = ImageMetadataReader.readMetadata(new ByteArrayInputStream(data))
                    .getFirstDirectoryOfType(ExifIFD0Directory.class);
            if (directory != null && directory.containsTag(ExifIFD0Directory.TAG_ORIENTATION)) {
                return directory.getInt(ExifIFD0Directory.TAG_ORIENTATION);
            }
        } catch (Exception ignored) {
            // no readable metadata: keep the image as stored
        }
        return 1;
    }

    /** Applies the EXIF orientation and drops transparency, on a new RGB image. */
    static BufferedImage upright(BufferedImage source, int orientation) {
        int w = source.getWidth();
        int h = source.getHeight();
        // Maps source pixels to their upright position: x' = m00 x + m01 y + m02, y' = m10 x + m11 y + m12
        AffineTransform t = switch (orientation) {
            case 2 -> new AffineTransform(-1, 0, 0, 1, w, 0);   // mirrored
            case 3 -> new AffineTransform(-1, 0, 0, -1, w, h);  // upside down
            case 4 -> new AffineTransform(1, 0, 0, -1, 0, h);   // mirrored vertically
            case 5 -> new AffineTransform(0, 1, 1, 0, 0, 0);    // transposed
            case 6 -> new AffineTransform(0, 1, -1, 0, h, 0);   // rotate 90° clockwise
            case 7 -> new AffineTransform(0, -1, -1, 0, h, w);  // transversed
            case 8 -> new AffineTransform(0, -1, 1, 0, 0, w);   // rotate 90° counter-clockwise
            default -> new AffineTransform();
        };
        boolean swap = orientation >= 5 && orientation <= 8;
        BufferedImage target = new BufferedImage(swap ? h : w, swap ? w : h, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = target.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
            g.drawImage(source, t, null);
        } finally {
            g.dispose();
        }
        return target;
    }

    /** Only ever shrinks, keeping the aspect ratio. */
    private static BufferedImage shrink(BufferedImage image, int maxSide) throws IOException {
        if (Math.max(image.getWidth(), image.getHeight()) <= maxSide) {
            return image;
        }
        return Thumbnails.of(image).size(maxSide, maxSide).keepAspectRatio(true).asBufferedImage();
    }

    /** Written from pixels only, so no metadata is carried over. */
    private static byte[] jpeg(BufferedImage image) throws IOException {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (MemoryCacheImageOutputStream stream = new MemoryCacheImageOutputStream(out)) {
            writer.setOutput(stream);
            ImageWriteParam param = writer.getDefaultWriteParam();
            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            param.setCompressionQuality(JPEG_QUALITY);
            writer.write(null, new IIOImage(image, null, null), param);
        } finally {
            writer.dispose();
        }
        return out.toByteArray();
    }
}
