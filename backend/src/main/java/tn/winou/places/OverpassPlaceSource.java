package tn.winou.places;

import java.util.ArrayList;
import java.util.List;

import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;

import tn.winou.config.WinouProperties;
import tn.winou.web.ApiModels.PlaceKind;
import tools.jackson.databind.JsonNode;

/**
 * OpenStreetMap's Overpass API: amenity=veterinary and amenity=animal_shelter. Its usage policy
 * asks for few, cached queries: the worker asks once a week for the whole region (see Places).
 */
@Component
public class OverpassPlaceSource implements PlaceSource {

    private final RestClient http;

    public OverpassPlaceSource(WinouProperties properties) {
        var requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(10_000);
        requestFactory.setReadTimeout(120_000); // a whole country takes a while
        this.http = RestClient.builder().baseUrl(properties.places().overpassUrl()).requestFactory(requestFactory)
                .defaultHeader("User-Agent", "Winou (lost pets and street animals; https://github.com/jassernoomani/Winou)")
                .build();
    }

    @Override
    public List<Place> fetch(double south, double west, double north, double east) {
        String box = south + "," + west + "," + north + "," + east;
        String query = "[out:json][timeout:90];(nwr[\"amenity\"=\"veterinary\"](" + box + ");"
                + "nwr[\"amenity\"=\"animal_shelter\"](" + box + "););out center tags;";
        var form = new LinkedMultiValueMap<String, String>();
        form.add("data", query);
        JsonNode body = http.post().contentType(MediaType.APPLICATION_FORM_URLENCODED).body(form)
                .retrieve().body(JsonNode.class);
        return parse(body);
    }

    /** Overpass JSON to places: nodes have lat/lon, ways and relations a "center". */
    static List<Place> parse(JsonNode body) {
        List<Place> places = new ArrayList<>();
        for (JsonNode element : body.path("elements")) {
            JsonNode tags = element.path("tags");
            PlaceKind kind = switch (tags.path("amenity").asString("")) {
                case "veterinary" -> PlaceKind.VET;
                case "animal_shelter" -> PlaceKind.SHELTER;
                default -> null;
            };
            JsonNode point = element.has("lat") ? element : element.path("center");
            if (kind == null || !point.has("lat")) {
                continue;
            }
            places.add(new Place(element.path("type").asString() + "/" + element.path("id").asString(), kind,
                    first(tags, "name", "name:fr", "name:ar", "name:en"),
                    first(tags, "phone", "contact:phone", "contact:mobile"),
                    first(tags, "opening_hours"),
                    point.path("lat").asDouble(), point.path("lon").asDouble()));
        }
        return places;
    }

    private static String first(JsonNode tags, String... keys) {
        for (String key : keys) {
            String value = tags.path(key).asString("").strip();
            if (!value.isEmpty()) {
                return value.length() > 200 ? value.substring(0, 200) : value;
            }
        }
        return null;
    }
}
