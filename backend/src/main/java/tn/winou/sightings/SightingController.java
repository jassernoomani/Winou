package tn.winou.sightings;

import java.util.List;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import tn.winou.domain.PhotoSource;
import tn.winou.domain.Sighting;
import tn.winou.domain.User;
import tn.winou.photos.PhotoService;
import tn.winou.security.CurrentUser;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.PhotoOut;
import tn.winou.web.ApiModels.SightingIn;
import tn.winou.web.ApiModels.SightingOut;
import tn.winou.web.ApiModels.SightingUpdate;
import tn.winou.web.Views;

@RestController
@Tag(name = "sightings")
public class SightingController {

    private final SightingService sightings;
    private final PhotoService photos;
    private final Views views;

    public SightingController(SightingService sightings, PhotoService photos, Views views) {
        this.sightings = sightings;
        this.photos = photos;
        this.views = views;
    }

    @PostMapping("/sightings")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Log a loose animal or a stray, then add 1–3 photos with POST /sightings/{id}/photos")
    public SightingOut create(@Valid @RequestBody SightingIn body, @CurrentUser User user) {
        return sightings.create(body, user);
    }

    @GetMapping("/me/sightings")
    public List<SightingOut> mine(@CurrentUser User user) {
        return sightings.mine(user);
    }

    @GetMapping("/sightings/{sightingId}")
    public SightingOut get(@PathVariable UUID sightingId, @CurrentUser User user) {
        return views.sighting(sightings.get(sightingId), user);
    }

    @PatchMapping("/sightings/{sightingId}")
    public SightingOut update(@PathVariable UUID sightingId, @Valid @RequestBody SightingUpdate body,
            @CurrentUser User user) {
        return sightings.update(sightingId, body, user);
    }

    @DeleteMapping("/sightings/{sightingId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID sightingId, @CurrentUser User user) {
        sightings.delete(sightingId, user);
    }

    @PostMapping(value = "/sightings/{sightingId}/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Upload one photo (JPEG, PNG, WebP or HEIC). Matching runs in the background: poll GET /photos/{id}")
    public PhotoOut uploadPhoto(@PathVariable UUID sightingId, @RequestPart MultipartFile file,
            @Parameter(description = "CAMERA or GALLERY, as picked in the app. Not shown to other users.")
            @RequestParam(required = false) PhotoSource source,
            @CurrentUser User user) {
        Sighting sighting = sightings.get(sightingId);
        CurrentUserResolver.requireOwnerOrAdmin(user, sighting.getReporterId());
        return photos.add(user, PhotoService.Owner.SIGHTING, sighting.getId(), file, source);
    }
}
