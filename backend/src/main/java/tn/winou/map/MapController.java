package tn.winou.map;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import tn.winou.common.ApiException;
import tn.winou.config.WinouProperties;
import tn.winou.domain.Condition;
import tn.winou.domain.GeoPoint;
import tn.winou.domain.Species;
import tn.winou.domain.SpeciesConverter;
import tn.winou.web.ApiModels.Location;
import tn.winou.web.ApiModels.MapItem;
import tn.winou.web.ApiModels.MapOut;
import tn.winou.web.ApiModels.MapType;
import tn.winou.web.Views;

@RestController
@Tag(name = "map")
public class MapController {

    private static final SpeciesConverter SPECIES = new SpeciesConverter();

    private final JdbcClient jdbc;
    private final Views views;
    private final int maxResults;

    public MapController(JdbcClient jdbc, Views views, WinouProperties properties) {
        this.jdbc = jdbc;
        this.views = views;
        this.maxResults = properties.map().maxResults();
    }

    @GetMapping("/map")
    @Operation(summary = "Open lost reports, sightings and strays inside the box, newest first",
            description = "Public: no login needed. Lost-report positions are approximate (moved up to LOCATION_FUZZ_M).")
    public MapOut map(
            @Parameter(description = "min_lon,min_lat,max_lon,max_lat", example = "10.05,36.75,10.30,36.90")
            @RequestParam String bbox,
            @RequestParam(name = "type", defaultValue = "lost,sighting,stray") List<MapType> types,
            @RequestParam(required = false) List<Species> species,
            @Parameter(description = "sightings and strays only")
            @RequestParam(name = "condition", required = false) List<Condition> conditions,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime since,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime until) {
        Filters filters = new Filters(parseBbox(bbox), species, conditions, since, until);
        List<MapItem> items = new ArrayList<>();
        if (types.contains(MapType.LOST) && filters.conditions().isEmpty()) {
            items.addAll(lostReports(filters));
        }
        boolean sightings = types.contains(MapType.SIGHTING);
        boolean strays = types.contains(MapType.STRAY);
        if (sightings || strays) {
            items.addAll(sightings(filters, sightings && strays ? null : strays));
        }
        items.sort(Comparator.comparing(MapItem::date).reversed());
        return new MapOut(items.subList(0, Math.min(maxResults, items.size())), items.size() > maxResults);
    }

    private record Filters(double[] bbox, List<Species> species, List<Condition> conditions, OffsetDateTime since,
            OffsetDateTime until) {

        Filters {
            species = species == null ? List.of() : species;
            conditions = conditions == null ? List.of() : conditions;
        }
    }

    private List<MapItem> lostReports(Filters f) {
        var sql = new StringBuilder("""
                SELECT r.id, r.species, r.name, r.last_seen_at AS date,
                       ST_Y(r.last_seen_point::geometry) AS lat, ST_X(r.last_seen_point::geometry) AS lon,
                       (SELECT p.id FROM photos p WHERE p.lost_report_id = r.id ORDER BY p.created_at LIMIT 1) AS photo_id
                FROM lost_reports r
                WHERE r.status = 'OPEN'""");
        Map<String, Object> params = where(sql, "r", "last_seen_point", "last_seen_at", f);
        return jdbc.sql(sql.toString()).params(params).query((rs, i) -> {
            UUID id = rs.getObject("id", UUID.class);
            GeoPoint shown = views.publicPosition(id, new GeoPoint(rs.getDouble("lat"), rs.getDouble("lon")));
            return new MapItem(MapType.LOST, id, SPECIES.convertToEntityAttribute(rs.getString("species")),
                    Location.of(shown), rs.getObject("date", OffsetDateTime.class), rs.getString("name"), null,
                    Views.imageUrl(rs.getObject("photo_id", UUID.class)));
        }).list();
    }

    /** stray: null for both kinds, true for strays only, false for loose animals only. */
    private List<MapItem> sightings(Filters f, Boolean stray) {
        var sql = new StringBuilder("""
                SELECT s.id, s.species, s.condition, s.is_stray, s.seen_at AS date,
                       ST_Y(s.point::geometry) AS lat, ST_X(s.point::geometry) AS lon,
                       (SELECT p.id FROM photos p WHERE p.sighting_id = s.id ORDER BY p.created_at LIMIT 1) AS photo_id
                FROM sightings s
                WHERE TRUE""");
        if (stray != null) {
            sql.append(stray ? " AND s.is_stray" : " AND NOT s.is_stray");
        }
        Map<String, Object> params = where(sql, "s", "point", "seen_at", f);
        return jdbc.sql(sql.toString()).params(params).query((rs, i) -> new MapItem(
                rs.getBoolean("is_stray") ? MapType.STRAY : MapType.SIGHTING,
                rs.getObject("id", UUID.class),
                SPECIES.convertToEntityAttribute(rs.getString("species")),
                new Location(rs.getDouble("lat"), rs.getDouble("lon")),
                rs.getObject("date", OffsetDateTime.class),
                null,
                Condition.valueOf(rs.getString("condition")),
                Views.imageUrl(rs.getObject("photo_id", UUID.class)))).list();
    }

    /** Appends the shared filters, the ordering and the limit; returns the parameters. */
    private Map<String, Object> where(StringBuilder sql, String t, String point, String date, Filters f) {
        double[] b = f.bbox();
        Map<String, Object> params = new HashMap<>(Map.of(
                "minLon", b[0], "minLat", b[1], "maxLon", b[2], "maxLat", b[3], "limit", maxResults + 1));
        sql.append(" AND ST_Intersects(%s.%s, ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)::geography)"
                .formatted(t, point));
        if (!f.species().isEmpty()) {
            sql.append(" AND %s.species IN (:species)".formatted(t));
            params.put("species", f.species().stream().map(Species::api).toList());
        }
        if (!f.conditions().isEmpty()) {
            sql.append(" AND %s.condition IN (:conditions)".formatted(t));
            params.put("conditions", f.conditions().stream().map(Enum::name).toList());
        }
        if (f.since() != null) {
            sql.append(" AND %s.%s >= :since".formatted(t, date));
            params.put("since", f.since());
        }
        if (f.until() != null) {
            sql.append(" AND %s.%s <= :until".formatted(t, date));
            params.put("until", f.until());
        }
        sql.append(" ORDER BY %s.%s DESC LIMIT :limit".formatted(t, date));
        return params;
    }

    private static double[] parseBbox(String bbox) {
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
        return v;
    }
}
