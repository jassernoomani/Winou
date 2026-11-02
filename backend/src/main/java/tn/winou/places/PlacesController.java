package tn.winou.places;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import tn.winou.common.ApiException;
import tn.winou.web.ApiModels.PlaceKind;
import tn.winou.web.ApiModels.PlaceOut;

@RestController
@Tag(name = "places")
public class PlacesController {

    private final Places places;

    public PlacesController(Places places) {
        this.places = places;
    }

    @GetMapping("/places")
    @Operation(summary = "Vets and animal shelters in a map area (from OpenStreetMap), at most 300",
            description = "bbox: min_lon,min_lat,max_lon,max_lat. kinds: VET, SHELTER (both by default).")
    public List<PlaceOut> in(@RequestParam String bbox, @RequestParam(required = false) List<PlaceKind> kinds) {
        String[] parts = bbox.split(",");
        double[] v = new double[4];
        try {
            if (parts.length != 4) {
                throw new NumberFormatException();
            }
            for (int i = 0; i < 4; i++) {
                v[i] = Double.parseDouble(parts[i].strip());
            }
        } catch (NumberFormatException e) {
            throw ApiException.invalid("bbox must be min_lon,min_lat,max_lon,max_lat");
        }
        if (!(-180 <= v[0] && v[0] < v[2] && v[2] <= 180 && -90 <= v[1] && v[1] < v[3] && v[3] <= 90)) {
            throw ApiException.invalid("bbox is out of range or inverted");
        }
        return places.in(v[0], v[1], v[2], v[3], kinds == null || kinds.isEmpty() ? List.of(PlaceKind.values()) : kinds);
    }
}
