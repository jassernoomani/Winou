package tn.winou.domain;

import java.math.BigDecimal;

/** A WGS84 position. Stored as PostGIS geography, read and written as WKT text. */
public record GeoPoint(double lat, double lon) {

    /** EWKT for ST_GeogFromText, e.g. "SRID=4326;POINT(10.1815 36.8065)" (longitude first). */
    public String toEwkt() {
        return "SRID=4326;POINT(" + plain(lon) + " " + plain(lat) + ")";
    }

    /** Parses ST_AsText output ("POINT(10.1815 36.8065)") or our own EWKT. */
    public static GeoPoint parse(String wkt) {
        String inner = wkt.substring(wkt.indexOf('(') + 1, wkt.lastIndexOf(')')).trim();
        String[] parts = inner.split("\\s+");
        return new GeoPoint(Double.parseDouble(parts[1]), Double.parseDouble(parts[0]));
    }

    private static String plain(double value) {
        return BigDecimal.valueOf(value).stripTrailingZeros().toPlainString(); // never "1.0E-5", which WKT does not allow
    }
}
