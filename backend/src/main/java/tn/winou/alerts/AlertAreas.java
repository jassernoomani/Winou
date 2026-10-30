package tn.winou.alerts;

import java.util.List;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import tn.winou.domain.GeoPoint;
import tn.winou.domain.User;
import tn.winou.web.ApiModels.AlertAreaIn;
import tn.winou.web.ApiModels.AlertAreaOut;
import tn.winou.web.ApiModels.Location;

/**
 * The area a user watches: a point and a radius, and what they want to hear about there. One per
 * user, kept on the account.
 */
@Service
public class AlertAreas {

    private final JdbcClient jdbc;

    public AlertAreas(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /** null when the user watches nothing. */
    @Transactional(readOnly = true)
    public AlertAreaOut get(User user) {
        return jdbc.sql("""
                        SELECT ST_Y(watch_point::geometry) AS lat, ST_X(watch_point::geometry) AS lon,
                               watch_radius_km, watch_lost, watch_help
                        FROM users WHERE id = :id AND watch_point IS NOT NULL""")
                .param("id", user.getId())
                .query((rs, i) -> new AlertAreaOut(new Location(rs.getDouble("lat"), rs.getDouble("lon")),
                        rs.getDouble("watch_radius_km"), rs.getBoolean("watch_lost"), rs.getBoolean("watch_help")))
                .optional().orElse(null);
    }

    @Transactional
    public AlertAreaOut set(User user, AlertAreaIn body) {
        GeoPoint point = body.location().toPoint();
        jdbc.sql("""
                        UPDATE users SET watch_point = ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                               watch_radius_km = :radius, watch_lost = :lost, watch_help = :help
                        WHERE id = :id""")
                .param("lat", point.lat())
                .param("lon", point.lon())
                .param("radius", body.radiusKm())
                .param("lost", body.lost())
                .param("help", body.help())
                .param("id", user.getId())
                .update();
        return get(user);
    }

    @Transactional
    public void clear(User user) {
        jdbc.sql("""
                        UPDATE users SET watch_point = NULL, watch_radius_km = NULL, watch_lost = false,
                               watch_help = false
                        WHERE id = :id""")
                .param("id", user.getId())
                .update();
    }

    /** Users watching [point] for lost pets, except [except] (who posted it) and banned users. */
    public List<UUID> watchingLost(GeoPoint point, UUID except) {
        return watching(point, except, "watch_lost");
    }

    /** Users watching [point] for animals that need help. */
    public List<UUID> watchingHelp(GeoPoint point, UUID except) {
        return watching(point, except, "watch_help");
    }

    private List<UUID> watching(GeoPoint point, UUID except, String flag) {
        return jdbc.sql("""
                        SELECT id FROM users
                        WHERE %s AND watch_point IS NOT NULL AND id <> :except
                          AND (banned_until IS NULL OR banned_until <= now())
                          AND ST_DWithin(watch_point, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                                         watch_radius_km * 1000)""".formatted(flag))
                .param("lat", point.lat())
                .param("lon", point.lon())
                .param("except", except)
                .query(UUID.class)
                .list();
    }
}
