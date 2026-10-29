"""Upload validation and decoding."""
import base64
import io

from PIL import Image, ImageOps, UnidentifiedImageError
from pi_heif import register_heif_opener

# HEIC is the default photo format on iPhones. Registering it here also stops
# ultralytics from trying to pip-install pi-heif at runtime on unknown files.
register_heif_opener()

ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP", "HEIF"}


class ImageError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status, self.code, self.message = status, code, message


def decode_upload(data: bytes, max_bytes: int, max_pixels: int) -> Image.Image:
    """Validate and decode an uploaded image into an upright RGB image.

    The format is checked from the file content, not its name. Phone
    rotation (EXIF orientation) is applied; the returned image carries no
    EXIF data.
    """
    if len(data) > max_bytes:
        raise ImageError(413, "file_too_large", f"Image is larger than {max_bytes // 1_000_000} MB.")
    try:
        image = Image.open(io.BytesIO(data))
        if image.format not in ALLOWED_FORMATS:
            raise ImageError(415, "unsupported_format", "Use a JPEG, PNG, WebP or HEIC image.")
        if image.width * image.height > max_pixels:
            raise ImageError(413, "image_too_large", "Image resolution is too high.")
        image = ImageOps.exif_transpose(image)
        return image.convert("RGB")
    except Image.DecompressionBombError:
        raise ImageError(413, "image_too_large", "Image resolution is too high.")
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError):
        # Pillow raises any of these for corrupt or truncated files
        raise ImageError(415, "invalid_image", "The file is not a readable image.")


def to_jpeg(image: Image.Image, max_side: int, quality: int = 90) -> bytes:
    image = image.copy()
    image.thumbnail((max_side, max_side))  # only ever shrinks, keeps aspect ratio
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=quality)  # no EXIF is written
    return buffer.getvalue()


def to_jpeg_base64(image: Image.Image, max_side: int, quality: int = 90) -> str:
    return base64.b64encode(to_jpeg(image, max_side, quality)).decode("ascii")
