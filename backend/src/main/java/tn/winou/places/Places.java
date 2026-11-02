package tn.winou.places;

import java.time.OffsetDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import tn.winou.config.WinouProperties;
import tn.winou.places.PlaceSource.Place;
import tn.winou.web.ApiModels.Location;
import tn.winou.web.ApiModels.PlaceKind;
import tn.winou.web.ApiModels.PlaceOut;

/** Vets and animal shelters: a copy of OpenStreetMap's, refreshed weekly, served by map area. */
@Service
public class Places {

    private static final Logger log = LoggerFactory.getLogger(Places.class);
    private static final int MAX_RESULTS = 300;

    private final PlaceSource source;
    private final JdbcClient jdbc;
    private final TransactionTemplate tx;
    private final WinouProperties.Places settings;

    public Places(PlaceSource source, JdbcClient jdbc, TransactionTemplate tx, WinouProperties properties) {
        this.source = source;
        this.jdbc = jdbc;
        this.tx = tx;
        this.settings = properties.places();
    }

    /** Fetches the region again if the copy is missing or older than refreshDays. The worker calls it. */
    public void refreshIfStale() {
        if (!settings.enabled()) {
            return;
        }
        OffsetDateTime last = jdbc.sql("SELECT max(fetched_at) FROM places").query(OffsetDateTime.class).optional()
                .orElse(null);
        if (last != null && last.isAfter(OffsetDateTime.now().minusDays(settings.refreshDays()))) {
            return;
        }
        String[] box = settings.region().split(",");
        List<Place> fetched = source.fetch(Double.parseDouble(box[0].strip()), Double.parseDouble(box[1].strip()),
                Double.parseDouble(box[2].strip()), Double.parseDouble(box[3].strip()));
        log.info("places: {} vets and shelters from OpenStreetMap", fetched.size());
        replace(fetched);
    }

    /** The new list replaces the old one; an empty answer (Overpass busy) keeps the old one. */
    void replace(List<Place> fetched) {
        if (fetched.isEmpty()) {
            return;
        }
        tx.executeWithoutResult(status -> {
            OffsetDateTime now = OffsetDateTime.now();
            for (Place p : fetched) {
                jdbc.sql("""
                                INSERT INTO places (osm_id, kind, name, phone, opening_hours, point, fetched_at)
                                VALUES (:id, :kind, :name, :phone, :hours,
                                        ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :now)
                                ON CONFLICT (osm_id) DO UPDATE SET kind = EXCLUDED.kind, name = EXCLUDED.name,
                                    phone = EXCLUDED.phone, opening_hours = EXCLUDED.opening_hours,
                                    point = EXCLUDED.point, fetched_at = EXCLUDED.fetched_at""")
                        .param("id", p.osmId()).param("kind", p.kind().name()).param("name", cut(p.name(), 200))
                        .param("phone", cut(p.phone(), 60)).param("hours", cut(p.openingHours(), 200))
                        .param("lat", p.lat()).param("lon", p.lon()).param("now", now).update();
            }
            jdbc.sql("DELETE FROM places WHERE fetched_at < :now").param("now", now).update(); // closed since
        });
    }

    /** The places in a map area, of the given kinds. */
    public List<PlaceOut> in(double minLon, double minLat, double maxLon, double maxLat, List<PlaceKind> kinds) {
        return jdbc.sql("""
                        SELECT osm_id, kind, name, phone, opening_hours,
                               ST_Y(point::geometry) AS lat, ST_X(point::geometry) AS lon
                        FROM places
                        WHERE kind IN (:kinds)
                          AND ST_Intersects(point, ST_MakeEnvelope(:minLon, :minLat, :maxLon, :maxLat, 4326)::geography)
                        ORDER BY name NULLS LAST LIMIT :limit""")
                .param("kinds", kinds.stream().map(Enum::name).toList())
                .param("minLon", minLon).param("minLat", minLat).param("maxLon", maxLon).param("maxLat", maxLat)
                .param("limit", MAX_RESULTS)
                .query((rs, i) -> new PlaceOut(rs.getString("osm_id"), PlaceKind.valueOf(rs.getString("kind")),
                        rs.getString("name"), rs.getString("phone"), rs.getString("opening_hours"),
                        new Location(rs.getDouble("lat"), rs.getDouble("lon"))))
                .list();
    }

    private static String cut(String text, int max) {
        return text == null || text.length() <= max ? text : text.substring(0, max);
    }
}
