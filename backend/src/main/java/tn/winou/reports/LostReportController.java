package tn.winou.reports;

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
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import tn.winou.common.ApiException;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.LostReport;
import tn.winou.domain.PhotoSource;
import tn.winou.domain.Species;
import tn.winou.domain.User;
import tn.winou.photos.PhotoService;
import tn.winou.security.CurrentUser;
import tn.winou.security.CurrentUserResolver;
import tn.winou.web.ApiModels.LostReportIn;
import tn.winou.web.ApiModels.LostReportOut;
import tn.winou.web.ApiModels.LostReportUpdate;
import tn.winou.web.ApiModels.PhotoOut;
import tn.winou.web.Views;

@RestController
@Tag(name = "lost reports")
public class LostReportController {

    private final LostReportService reports;
    private final PhotoService photos;
    private final Views views;

    public LostReportController(LostReportService reports, PhotoService photos, Views views) {
        this.reports = reports;
        this.photos = photos;
        this.views = views;
    }

    @PostMapping("/lost-reports")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Create the report, then add 1–5 photos with POST /lost-reports/{id}/photos")
    public LostReportOut create(@Valid @RequestBody LostReportIn body, @CurrentUser User user) {
        return reports.create(body, user);
    }

    @GetMapping("/lost-reports")
    @Operation(summary = "Open lost reports, the most recently seen first. Fewer than `limit` items means the last page.",
            description = "With lat/lon, only reports within radius_km. The distance is measured to the position "
                    + "shown (approximate unless it's yours), so moving the search point can't reveal the exact one.")
    public List<LostReportOut> list(
            @CurrentUser User user,
            @RequestParam(required = false) @DecimalMin("-90") @DecimalMax("90") Double lat,
            @RequestParam(required = false) @DecimalMin("-180") @DecimalMax("180") Double lon,
            @RequestParam(name = "radius_km", defaultValue = "25") @DecimalMin(value = "0", inclusive = false)
                    @DecimalMax("200") double radiusKm,
            @RequestParam(required = false) List<Species> species,
            @RequestParam(defaultValue = "20") @Min(1) @Max(50) int limit,
            @RequestParam(defaultValue = "0") @Min(0) int offset) {
        if ((lat == null) != (lon == null)) {
            throw ApiException.invalid("give both lat and lon, or neither");
        }
        GeoPoint center = lat == null ? null : new GeoPoint(lat, lon);
        return reports.list(user, center, radiusKm, species, limit, offset);
    }

    @GetMapping("/me/lost-reports")
    public List<LostReportOut> mine(@CurrentUser User user) {
        return reports.mine(user);
    }

    @GetMapping("/lost-reports/{reportId}")
    @Operation(summary = "The location is exact for the owner and moved up to LOCATION_FUZZ_M for everyone else")
    public LostReportOut get(@PathVariable UUID reportId, @CurrentUser User user) {
        return views.report(reports.visible(reportId, user), user);
    }

    @PatchMapping("/lost-reports/{reportId}")
    public LostReportOut update(@PathVariable UUID reportId, @Valid @RequestBody LostReportUpdate body,
            @CurrentUser User user) {
        return reports.update(reportId, body, user);
    }

    @DeleteMapping("/lost-reports/{reportId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable UUID reportId, @CurrentUser User user) {
        reports.delete(reportId, user);
    }

    @PostMapping(value = "/lost-reports/{reportId}/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Upload one photo (JPEG, PNG, WebP or HEIC). Matching runs in the background: poll GET /photos/{id}")
    public PhotoOut uploadPhoto(@PathVariable UUID reportId, @RequestPart MultipartFile file,
            @Parameter(description = "CAMERA or GALLERY, as picked in the app. Not shown to other users.")
            @RequestParam(required = false) PhotoSource source,
            @CurrentUser User user) {
        LostReport report = reports.get(reportId);
        CurrentUserResolver.requireOwnerOrAdmin(user, report.getOwnerId());
        return photos.add(user, PhotoService.Owner.LOST_REPORT, report.getId(), file, source);
    }
}
