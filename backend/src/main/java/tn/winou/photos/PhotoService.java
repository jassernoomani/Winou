package tn.winou.photos;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import java.util.stream.Stream;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import tn.winou.common.AfterCommit;
import tn.winou.common.ApiException;
import tn.winou.common.RateLimits;
import tn.winou.config.WinouProperties;
import tn.winou.domain.Photo;
import tn.winou.domain.PhotoRepository;
import tn.winou.domain.PhotoSource;
import tn.winou.domain.User;
import tn.winou.infra.Storage;
import tn.winou.infra.VectorIndex;
import tn.winou.web.ApiModels.PhotoOut;
import tn.winou.web.Views;

@Service
public class PhotoService {

    public enum Owner {
        LOST_REPORT(5),
        SIGHTING(3);

        final int maxPhotos;

        Owner(int maxPhotos) {
            this.maxPhotos = maxPhotos;
        }
    }

    private static final Map<String, String> ORIGINAL_EXTENSIONS = Map.of(
            "image/jpeg", "jpg", "image/png", "png", "image/webp", "webp", "image/heif", "heic");

    private final PhotoRepository photos;
    private final Images images;
    private final Storage storage;
    private final VectorIndex index;
    private final WinouProperties properties;

    public PhotoService(PhotoRepository photos, Images images, Storage storage, VectorIndex index,
            WinouProperties properties) {
        this.photos = photos;
        this.images = images;
        this.storage = storage;
        this.index = index;
        this.properties = properties;
    }

    /** Validates and stores an upload, then queues it for the worker (embedding + matching). */
    @Transactional
    public PhotoOut add(User user, Owner owner, UUID recordId, MultipartFile file, PhotoSource source) {
        long count = owner == Owner.LOST_REPORT ? photos.countByLostReportId(recordId) : photos.countBySightingId(recordId);
        if (count >= owner.maxPhotos) {
            throw ApiException.coded(HttpStatus.CONFLICT, "too_many_photos", "At most " + owner.maxPhotos + " photos.");
        }
        RateLimits.check(photos.countByUploaderIdAndCreatedAtGreaterThanEqual(user.getId(),
                OffsetDateTime.now().minusHours(1)), properties.rateLimits().photosPerHour(), "photo uploads");

        byte[] data = bytes(file);
        Images.PublicCopy copy = images.publicCopy(data);
        Photo photo = new Photo();
        photo.setUploaderId(user.getId());
        photo.setSource(source);
        photo.setOriginalKey("originals/" + photo.getId() + "." + ORIGINAL_EXTENSIONS.get(copy.originalType()));
        photo.setPublicKey("public/" + photo.getId() + ".jpg");
        if (owner == Owner.LOST_REPORT) {
            photo.setLostReportId(recordId);
        } else {
            photo.setSightingId(recordId);
        }
        storage.put(photo.getOriginalKey(), data, copy.originalType());
        storage.put(photo.getPublicKey(), copy.jpeg(), "image/jpeg");
        return Views.photo(photos.save(photo));
    }

    public Photo get(UUID photoId) {
        return photos.findById(photoId).orElseThrow(() -> ApiException.notFound("Photo"));
    }

    @Transactional
    public void delete(Photo photo) {
        index.deletePhoto(photo.getId());
        photos.delete(photo);
        deleteFilesAfterCommit(List.of(photo));
    }

    /** Files go once the rows are gone, so a failed transaction never leaves a photo without its files. */
    public void deleteFilesAfterCommit(List<Photo> deleted) {
        List<String> keys = deleted.stream()
                .flatMap(p -> Stream.of(p.getOriginalKey(), p.getPublicKey(), p.getCropKey()))
                .filter(Objects::nonNull)
                .toList();
        if (!keys.isEmpty()) {
            AfterCommit.run(() -> storage.delete(keys));
        }
    }

    private byte[] bytes(MultipartFile file) {
        long max = properties.uploads().maxBytes();
        if (file.getSize() > max) {
            throw ApiException.coded(HttpStatus.CONTENT_TOO_LARGE, "file_too_large",
                    "Image is larger than " + max / 1_000_000 + " MB.");
        }
        try {
            return file.getBytes();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
