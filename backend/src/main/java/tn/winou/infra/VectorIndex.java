package tn.winou.infra;

import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import jakarta.annotation.PostConstruct;
import tools.jackson.databind.JsonNode;
import tn.winou.config.WinouProperties;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.Species;

/**
 * The Qdrant photo index, over its REST API. One point per photo, id = photo id, with payload
 * {species, kind ("lost" | "sighting"), ref_id, location, timestamp}: see scripts/setup_qdrant.py.
 */
@Component
public class VectorIndex {

    private static final Map<String, String> PAYLOAD_INDEXES = Map.of(
            "species", "keyword",
            "kind", "keyword",
            "ref_id", "keyword",
            "location", "geo",
            "timestamp", "datetime");

    private final RestClient http;
    private final String collection;
    private final int dim;

    public VectorIndex(WinouProperties properties) {
        WinouProperties.Qdrant qdrant = properties.qdrant();
        var builder = RestClient.builder()
                .baseUrl(qdrant.url() + "/collections/" + qdrant.collection())
                .requestFactory(new SimpleClientHttpRequestFactory());
        if (qdrant.apiKey() != null && !qdrant.apiKey().isBlank()) {
            builder.defaultHeader("api-key", qdrant.apiKey());
        }
        this.http = builder.build();
        this.collection = qdrant.collection();
        this.dim = qdrant.embedDim();
    }

    public record Hit(UUID photoId, UUID refId, double score) {}

    /** Creates the collection and payload indexes if missing; refuses a collection of another size. */
    @PostConstruct
    public void ensureCollection() {
        boolean exists = http.get().uri("/exists").retrieve().body(JsonNode.class)
                .path("result").path("exists").asBoolean();
        if (!exists) {
            http.put().body(Map.of("vectors", Map.of("size", dim, "distance", "Cosine"))).retrieve().toBodilessEntity();
        }
        JsonNode info = http.get().retrieve().body(JsonNode.class).path("result");
        int size = info.path("config").path("params").path("vectors").path("size").asInt();
        if (size != dim) {
            throw new IllegalStateException("Qdrant collection '" + collection + "' has " + size
                    + "-d vectors, expected " + dim + ": the embedding model changed, re-create it and re-embed.");
        }
        JsonNode existing = info.path("payload_schema");
        PAYLOAD_INDEXES.forEach((field, schema) -> {
            if (!existing.has(field)) {
                http.put().uri("/index?wait=true").body(Map.of("field_name", field, "field_schema", schema))
                        .retrieve().toBodilessEntity();
            }
        });
    }

    public static Map<String, Object> payload(Species species, String kind, UUID refId, GeoPoint location,
            OffsetDateTime timestamp) {
        return Map.of(
                "species", species.api(),
                "kind", kind,
                "ref_id", refId.toString(),
                "location", Map.of("lat", location.lat(), "lon", location.lon()),
                "timestamp", iso(timestamp));
    }

    public void upsert(UUID photoId, List<Double> vector, Map<String, Object> payload) {
        var point = Map.of("id", photoId.toString(), "vector", vector, "payload", payload);
        http.put().uri("/points?wait=true").body(Map.of("points", List.of(point))).retrieve().toBodilessEntity();
    }

    public Optional<List<Double>> getVector(UUID photoId) {
        JsonNode points = http.post().uri("/points")
                .body(Map.of("ids", List.of(photoId.toString()), "with_vector", true))
                .retrieve().body(JsonNode.class).path("result");
        if (points.isEmpty()) {
            return Optional.empty();
        }
        List<Double> vector = new ArrayList<>();
        points.get(0).path("vector").forEach(v -> vector.add(v.asDouble()));
        return Optional.of(vector);
    }

    /** Nearest photos of the given species and kind within radiusM, optionally within a time window. */
    public List<Hit> search(List<Double> vector, Species species, String kind, GeoPoint center, double radiusM,
            OffsetDateTime since, OffsetDateTime until, int limit) {
        List<Map<String, Object>> must = new ArrayList<>();
        must.add(Map.of("key", "species", "match", Map.of("value", species.api())));
        must.add(Map.of("key", "kind", "match", Map.of("value", kind)));
        must.add(Map.of("key", "location", "geo_radius", Map.of(
                "center", Map.of("lat", center.lat(), "lon", center.lon()), "radius", radiusM)));
        if (since != null || until != null) {
            Map<String, Object> range = new HashMap<>();
            if (since != null) {
                range.put("gte", iso(since));
            }
            if (until != null) {
                range.put("lte", iso(until));
            }
            must.add(Map.of("key", "timestamp", "range", range));
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("query", vector);
        body.put("filter", Map.of("must", must));
        body.put("limit", limit);
        body.put("with_payload", List.of("ref_id"));
        JsonNode points = http.post().uri("/points/query").body(body).retrieve().body(JsonNode.class)
                .path("result").path("points");
        List<Hit> hits = new ArrayList<>();
        for (JsonNode p : points) {
            hits.add(new Hit(UUID.fromString(p.path("id").asString()),
                    UUID.fromString(p.path("payload").path("ref_id").asString()), p.path("score").asDouble()));
        }
        return hits;
    }

    /** Changes species/location/timestamp on every photo of a report or sighting. */
    public void updateRef(UUID refId, Map<String, Object> payload) {
        http.post().uri("/points/payload?wait=true").body(Map.of("payload", payload, "filter", refFilter(refId)))
                .retrieve().toBodilessEntity();
    }

    public void deletePhoto(UUID photoId) {
        http.post().uri("/points/delete?wait=true").body(Map.of("points", List.of(photoId.toString())))
                .retrieve().toBodilessEntity();
    }

    public void deleteRef(UUID refId) {
        http.post().uri("/points/delete?wait=true").body(Map.of("filter", refFilter(refId)))
                .retrieve().toBodilessEntity();
    }

    public long count() {
        return http.post().uri("/points/count").body(Map.of("exact", true)).retrieve().body(JsonNode.class)
                .path("result").path("count").asLong();
    }

    private static Map<String, Object> refFilter(UUID refId) {
        return Map.of("must", List.of(Map.of("key", "ref_id", "match", Map.of("value", refId.toString()))));
    }

    /** Always with seconds and offset ("2026-10-20T09:00:00Z"), which Qdrant's datetime index needs. */
    private static String iso(OffsetDateTime time) {
        return time.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
    }
}
