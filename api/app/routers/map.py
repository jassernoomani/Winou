from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.config import settings
from app.geo import fuzz
from app.models import Condition, LostReport, ReportStatus, Sighting, Species
from app.schemas import Location, MapItem, MapOut, MapType
from app.security import DB

router = APIRouter(tags=["map"])


def parse_bbox(bbox: str) -> tuple[float, float, float, float]:
    try:
        min_lon, min_lat, max_lon, max_lat = (float(v) for v in bbox.split(","))
    except ValueError:
        raise HTTPException(422, "bbox must be min_lon,min_lat,max_lon,max_lat")
    if not (-180 <= min_lon < max_lon <= 180 and -90 <= min_lat < max_lat <= 90):
        raise HTTPException(422, "bbox is out of range or inverted")
    return min_lon, min_lat, max_lon, max_lat


def _first_photo_url(record) -> str | None:
    return f"/photos/{record.photos[0].id}/image" if record.photos else None


@router.get("/map", response_model=MapOut)
def map_items(
    bbox: Annotated[str, Query(description="min_lon,min_lat,max_lon,max_lat", examples=["10.05,36.75,10.30,36.90"])],
    db: DB,
    types: Annotated[list[MapType], Query(alias="type")] = ["lost", "sighting", "stray"],
    species: Annotated[list[Species] | None, Query()] = None,
    condition: Annotated[list[Condition] | None, Query(description="sightings and strays only")] = None,
    since: datetime | None = None,
    until: datetime | None = None,
):
    """Open lost reports, sightings and strays inside the box, newest first.

    Public: no login needed. Lost-report positions are approximate (moved up to LOCATION_FUZZ_M).
    """
    envelope = func.ST_MakeEnvelope(*parse_bbox(bbox), 4326)
    limit = settings.map_max_results
    items: list[MapItem] = []

    if "lost" in types and not condition:
        query = (select(LostReport).options(selectinload(LostReport.photos))
                 .where(LostReport.status == ReportStatus.OPEN,
                        func.ST_Intersects(LostReport.last_seen_point, func.geography(envelope)))
                 .order_by(LostReport.last_seen_at.desc()).limit(limit + 1))
        if species:
            query = query.where(LostReport.species.in_(species))
        if since:
            query = query.where(LostReport.last_seen_at >= since)
        if until:
            query = query.where(LostReport.last_seen_at <= until)
        for r in db.scalars(query):
            lat, lon = fuzz(r.id, r.lat, r.lon, settings.location_fuzz_m, settings.location_fuzz_secret)
            items.append(MapItem(type="lost", id=r.id, species=r.species, location=Location(lat=lat, lon=lon),
                                 date=r.last_seen_at, name=r.name, photo_url=_first_photo_url(r)))

    sighting_types = {"sighting", "stray"} & set(types)
    if sighting_types:
        query = (select(Sighting).options(selectinload(Sighting.photos))
                 .where(func.ST_Intersects(Sighting.point, func.geography(envelope)))
                 .order_by(Sighting.seen_at.desc()).limit(limit + 1))
        if len(sighting_types) == 1:
            query = query.where(Sighting.is_stray.is_("stray" in sighting_types))
        if species:
            query = query.where(Sighting.species.in_(species))
        if condition:
            query = query.where(Sighting.condition.in_(condition))
        if since:
            query = query.where(Sighting.seen_at >= since)
        if until:
            query = query.where(Sighting.seen_at <= until)
        for s in db.scalars(query):
            items.append(MapItem(type="stray" if s.is_stray else "sighting", id=s.id, species=s.species,
                                 location=Location(lat=s.lat, lon=s.lon), date=s.seen_at, condition=s.condition,
                                 photo_url=_first_photo_url(s)))

    items.sort(key=lambda i: i.date, reverse=True)
    return MapOut(items=items[:limit], truncated=len(items) > limit)
