package tn.winou.search;

import org.springframework.http.MediaType;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import tn.winou.common.ApiException;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.Species;
import tn.winou.domain.User;
import tn.winou.search.PhotoSearchService.CheckOut;
import tn.winou.search.PhotoSearchService.SearchOut;
import tn.winou.security.CurrentUser;

@RestController
@Validated
@Tag(name = "photo search")
public class PhotoSearchController {

    private final PhotoSearchService search;

    public PhotoSearchController(PhotoSearchService search) {
        this.search = search;
    }

    @PostMapping(value = "/photos/check", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Is there a cat or dog in this photo? Checked before posting; nothing is stored. "
            + "422 no_animal_detected if not.")
    public CheckOut check(@RequestPart MultipartFile file, @CurrentUser User user) {
        return search.check(user, file);
    }

    @PostMapping(value = "/search/by-photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Open lost reports nearby that look like this photo, best first. Nothing is stored.",
            description = "`likely` results pass the matching threshold; the others are weaker look-alikes. "
                    + "The species is detected unless given.")
    public SearchOut byPhoto(@RequestPart MultipartFile file,
            @RequestParam @DecimalMin("-90") @DecimalMax("90") double lat,
            @RequestParam @DecimalMin("-180") @DecimalMax("180") double lon,
            @RequestParam(name = "radius_km", defaultValue = "10") @DecimalMin(value = "0", inclusive = false)
                    @DecimalMax("50") double radiusKm,
            @RequestParam(required = false) Species species,
            @CurrentUser User user) {
        if (species == Species.OTHER) {
            throw ApiException.invalid("search works for cats and dogs");
        }
        return search.search(user, file, new GeoPoint(lat, lon), radiusKm, species);
    }
}
