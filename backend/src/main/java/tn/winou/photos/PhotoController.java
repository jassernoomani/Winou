package tn.winou.photos;

import java.util.UUID;

import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import tn.winou.common.ApiException;
import tn.winou.domain.Photo;
import tn.winou.domain.User;
import tn.winou.infra.Storage;
import tn.winou.security.CurrentUser;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.PhotoOut;
import tn.winou.web.Views;

@RestController
@Tag(name = "photos")
public class PhotoController {

    // Keys are immutable (one per photo id), so clients may cache forever
    private static final CacheControl FOREVER = CacheControl.maxAge(java.time.Duration.ofDays(365))
            .cachePublic().immutable();

    private final PhotoService photos;
    private final Storage storage;

    public PhotoController(PhotoService photos, Storage storage) {
        this.photos = photos;
        this.storage = storage;
    }

    @GetMapping(value = "/photos/{photoId}/image", produces = MediaType.IMAGE_JPEG_VALUE)
    @Operation(summary = "The photo as an EXIF-free JPEG (no login needed, so the app can load it directly)")
    public ResponseEntity<byte[]> image(@PathVariable UUID photoId) {
        return jpeg(photos.get(photoId).getPublicKey());
    }

    @GetMapping(value = "/photos/{photoId}/crop", produces = MediaType.IMAGE_JPEG_VALUE)
    @Operation(summary = "The detected animal, cropped (available once the photo is processed)")
    public ResponseEntity<byte[]> crop(@PathVariable UUID photoId) {
        Photo photo = photos.get(photoId);
        if (photo.getCropKey() == null) {
            throw ApiException.notFound("Crop");
        }
        return jpeg(photo.getCropKey());
    }

    @GetMapping("/photos/{photoId}")
    @Operation(summary = "Poll after upload: PENDING, then READY, or NO_ANIMAL if the photo should be retaken")
    public PhotoOut status(@PathVariable UUID photoId, @CurrentUser User user) {
        Photo photo = photos.get(photoId);
        CurrentUserResolver.requireOwnerOrAdmin(user, photo.getUploaderId());
        return Views.photo(photo);
    }

    @DeleteMapping("/photos/{photoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID photoId, @CurrentUser User user) {
        Photo photo = photos.get(photoId);
        CurrentUserResolver.requireOwnerOrAdmin(user, photo.getUploaderId());
        photos.delete(photo);
    }

    private ResponseEntity<byte[]> jpeg(String key) {
        return ResponseEntity.ok().contentType(MediaType.IMAGE_JPEG).cacheControl(FOREVER).body(storage.get(key));
    }
}
