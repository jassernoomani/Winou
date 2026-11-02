package tn.winou;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import tn.winou.places.PlaceSource.Place;
import tn.winou.places.Places;
import tn.winou.web.ApiModels.PlaceKind;
import tools.jackson.databind.JsonNode;

/** Vets and shelters from OpenStreetMap: refreshed weekly, served by map area. */
class PlacesTest extends ApiTestBase {

    @Autowired
    FakePlaces source;
    @Autowired
    Places places;

    private static final Place VET = new Place("node/1", PlaceKind.VET, "Clinique Vétérinaire du Lac",
            "+216 71 000 000", "Mo-Sa 09:00-19:00", 36.83, 10.23);
    private static final Place SHELTER = new Place("way/2", PlaceKind.SHELTER, "SPA Tunis", null, null, 36.78, 10.15);
    private static final Place FAR_VET = new Place("node/3", PlaceKind.VET, "Vet Sfax", null, null, 34.74, 10.76);

    private static final Map<String, Object> TUNIS_AREA = Map.of("bbox", "10.0,36.6,10.4,37.0");

    @BeforeEach
    void empty() {
        jdbc.sql("DELETE FROM places").update();
        source.calls.set(0);
        source.places = List.of(VET, SHELTER, FAR_VET);
    }

    @Test
    void fetchedOnceThenServedByArea() {
        places.refreshIfStale();
        places.refreshIfStale(); // fresh: OpenStreetMap is not asked again
        assertThat(source.calls.get()).isEqualTo(1);

        JsonNode tunis = getJson("/places", register("user"), TUNIS_AREA).json();
        assertThat(tunis).hasSize(2);
        assertThat(tunis.get(0).path("name").asString()).isEqualTo("Clinique Vétérinaire du Lac");
        assertThat(tunis.get(0).path("kind").asString()).isEqualTo("VET");
        assertThat(tunis.get(0).path("phone").asString()).isEqualTo("+216 71 000 000");
        assertThat(tunis.get(0).path("opening_hours").asString()).isEqualTo("Mo-Sa 09:00-19:00");
        assertThat(tunis.get(0).path("location").path("lat").asDouble()).isEqualTo(36.83);

        JsonNode shelters = getJson("/places", register("other"),
                Map.of("bbox", "10.0,36.6,10.4,37.0", "kinds", "SHELTER")).json();
        assertThat(shelters).hasSize(1);
        assertThat(shelters.get(0).path("name").asString()).isEqualTo("SPA Tunis");
    }

    @Test
    void aStaleCopyIsReplacedAndClosedPlacesGo() {
        places.refreshIfStale();
        jdbc.sql("UPDATE places SET fetched_at = now() - interval '8 days'").update();
        source.places = List.of(VET); // the shelter closed
        places.refreshIfStale();
        assertThat(source.calls.get()).isEqualTo(2);
        assertThat(getJson("/places", register("user"), TUNIS_AREA).json()).hasSize(1);
    }

    @Test
    void anEmptyAnswerKeepsTheOldCopy() {
        places.refreshIfStale();
        jdbc.sql("UPDATE places SET fetched_at = now() - interval '8 days'").update();
        source.places = List.of(); // Overpass busy
        places.refreshIfStale();
        assertThat(getJson("/places", register("user"), TUNIS_AREA).json()).hasSize(2);
    }

    @Test
    void theAreaIsChecked() {
        String user = register("user");
        assertThat(getJson("/places", user, Map.of("bbox", "nonsense")).status()).isEqualTo(422);
        assertThat(getJson("/places", user, Map.of("bbox", "10.4,36.6,10.0,37.0")).status()).isEqualTo(422);
        assertThat(getJson("/places", null, TUNIS_AREA).status()).isEqualTo(401);
    }
}
