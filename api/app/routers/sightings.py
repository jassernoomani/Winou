import uuid
from datetime import timedelta

from fastapi import APIRouter, File, Request, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.config import settings
from app.deps import check_rate_limit, not_found
from app.geo import point
from app.models import PhotoSource, Sighting, User
from app.records import after_update, delete_record
from app.routers.photos import SourceField, add_photo
from app.schemas import Location, PhotoOut, SightingIn, SightingOut, SightingUpdate, photo_out
from app.security import DB, CurrentUser, require_owner_or_admin

router = APIRouter(tags=["sightings"])


def sighting_out(sighting: Sighting, viewer: User | None) -> SightingOut:
    # Sightings are about the animal, not a home address: the location is shown as reported.
    # The reporter is never exposed.
    return SightingOut(id=sighting.id, species=sighting.species, location=Location(lat=sighting.lat, lon=sighting.lon),
                       seen_at=sighting.seen_at, condition=sighting.condition, note=sighting.note,
                       is_stray=sighting.is_stray, mine=viewer is not None and viewer.id == sighting.reporter_id,
                       photos=[photo_out(p) for p in sighting.photos], created_at=sighting.created_at)


def _get(db, sighting_id: uuid.UUID) -> Sighting:
    sighting = db.scalar(select(Sighting).where(Sighting.id == sighting_id)
                         .options(selectinload(Sighting.photos)))
    if sighting is None:
        raise not_found("Sighting")
    return sighting


@router.post("/sightings", response_model=SightingOut, status_code=status.HTTP_201_CREATED)
def create_sighting(body: SightingIn, user: CurrentUser, db: DB):
    """Log a loose animal or a stray, then add 1–3 photos with POST /sightings/{id}/photos."""
    check_rate_limit(db, Sighting.reporter_id, user.id, Sighting.created_at,
                     settings.rate_limit_sightings_per_hour, timedelta(hours=1), "sightings")
    sighting = Sighting(reporter_id=user.id, species=body.species, point=point(body.location.lat, body.location.lon),
                        seen_at=body.seen_at, condition=body.condition, note=body.note, is_stray=body.is_stray)
    db.add(sighting)
    db.commit()
    return sighting_out(_get(db, sighting.id), user)


@router.get("/me/sightings", response_model=list[SightingOut])
def my_sightings(user: CurrentUser, db: DB):
    sightings = db.scalars(select(Sighting).where(Sighting.reporter_id == user.id)
                           .options(selectinload(Sighting.photos)).order_by(Sighting.created_at.desc()))
    return [sighting_out(s, user) for s in sightings]


@router.get("/sightings/{sighting_id}", response_model=SightingOut)
def get_sighting(sighting_id: uuid.UUID, user: CurrentUser, db: DB):
    return sighting_out(_get(db, sighting_id), user)


@router.patch("/sightings/{sighting_id}", response_model=SightingOut)
def update_sighting(sighting_id: uuid.UUID, body: SightingUpdate, request: Request, user: CurrentUser, db: DB):
    sighting = _get(db, sighting_id)
    require_owner_or_admin(user, sighting.reporter_id)
    changes = body.model_dump(exclude_unset=True, exclude_none=True)
    for field, value in changes.items():
        if field == "location":
            sighting.point = point(value["lat"], value["lon"])
        else:
            setattr(sighting, field, value)
    db.commit()
    after_update(request, db, sighting, set(changes))
    return sighting_out(_get(db, sighting_id), user)


@router.delete("/sightings/{sighting_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_sighting(sighting_id: uuid.UUID, request: Request, user: CurrentUser, db: DB):
    sighting = _get(db, sighting_id)
    require_owner_or_admin(user, sighting.reporter_id)
    delete_record(request, db, sighting)


@router.post("/sightings/{sighting_id}/photos", response_model=PhotoOut, status_code=status.HTTP_201_CREATED)
def upload_photo(sighting_id: uuid.UUID, request: Request, user: CurrentUser, db: DB,
                 file: UploadFile = File(...), source: PhotoSource | None = SourceField):
    """Upload one photo (JPEG, PNG, WebP or HEIC). Matching runs in the background: poll GET /photos/{id}."""
    sighting = _get(db, sighting_id)
    require_owner_or_admin(user, sighting.reporter_id)
    return add_photo(request, db, user, sighting, file, source)
