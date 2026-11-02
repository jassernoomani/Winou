package tn.winou.places;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import tn.winou.web.ApiModels.PlaceKind;
import tools.jackson.databind.json.JsonMapper;

/** Overpass answers: nodes have a position, ways a "center"; names in any language. */
class OverpassParseTest {

    @Test
    void parsesNodesAndWays() {
        var body = JsonMapper.builder().build().readTree("""
                {"elements": [
                  {"type": "node", "id": 1, "lat": 36.8, "lon": 10.2,
                   "tags": {"amenity": "veterinary", "name:fr": "Cabinet Vétérinaire", "contact:phone": "+216 71 1"}},
                  {"type": "way", "id": 2, "center": {"lat": 36.7, "lon": 10.1},
                   "tags": {"amenity": "animal_shelter", "name": "SPA", "opening_hours": "Mo-Fr 09:00-17:00"}},
                  {"type": "way", "id": 3, "tags": {"amenity": "veterinary"}},
                  {"type": "node", "id": 4, "lat": 1, "lon": 2, "tags": {"amenity": "pharmacy"}}
                ]}""");
        var places = OverpassPlaceSource.parse(body);
        assertThat(places).hasSize(2);
        assertThat(places.get(0).osmId()).isEqualTo("node/1");
        assertThat(places.get(0).kind()).isEqualTo(PlaceKind.VET);
        assertThat(places.get(0).name()).isEqualTo("Cabinet Vétérinaire");
        assertThat(places.get(0).phone()).isEqualTo("+216 71 1");
        assertThat(places.get(1).kind()).isEqualTo(PlaceKind.SHELTER);
        assertThat(places.get(1).lat()).isEqualTo(36.7);
        assertThat(places.get(1).openingHours()).isEqualTo("Mo-Fr 09:00-17:00");
    }
}
