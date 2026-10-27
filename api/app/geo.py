import hashlib
import hmac
import math
import uuid

from geoalchemy2 import WKTElement

EARTH_RADIUS_M = 6_371_000


def point(lat: float, lon: float) -> WKTElement:
    return WKTElement(f"POINT({lon} {lat})", srid=4326)


def fuzz(ref_id: uuid.UUID, lat: float, lon: float, radius_m: float, secret: str) -> tuple[float, float]:
    """Move a point up to radius_m away, uniformly over the disc.

    The offset is fixed per report (keyed hash of its id), so reloading the map
    never shows a different position that could be averaged back to the real one.
    """
    digest = hmac.new(secret.encode(), ref_id.bytes, hashlib.sha256).digest()
    u1 = int.from_bytes(digest[:8]) / 2**64
    u2 = int.from_bytes(digest[8:16]) / 2**64
    distance = radius_m * math.sqrt(u1)
    angle = 2 * math.pi * u2
    dlat = distance * math.cos(angle) / EARTH_RADIUS_M
    dlon = distance * math.sin(angle) / (EARTH_RADIUS_M * math.cos(math.radians(lat)))
    return round(lat + math.degrees(dlat), 5), round(lon + math.degrees(dlon), 5)
