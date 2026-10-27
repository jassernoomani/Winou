import uuid
from datetime import datetime, timezone
from typing import Annotated, Literal

from pydantic import AfterValidator, BaseModel, ConfigDict, EmailStr, Field

from app.models import Condition, MatchStatus, PhotoStatus, ReportStatus, Role, Species


def _aware_not_future(value: datetime) -> datetime:
    if value.tzinfo is None:
        raise ValueError("include a timezone, e.g. 2026-10-27T14:00:00+01:00")
    if value > datetime.now(timezone.utc):
        raise ValueError("cannot be in the future")
    return value


PastTime = Annotated[datetime, AfterValidator(_aware_not_future)]


class Location(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# --- auth ---

class RegisterIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    display_name: str = Field(min_length=1, max_length=80)


class TokenOut(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"


class UserOut(ORM):
    id: uuid.UUID
    email: str
    display_name: str
    role: Role
    created_at: datetime


class UserUpdate(BaseModel):
    display_name: str | None = Field(None, min_length=1, max_length=80)
    fcm_token: str | None = Field(None, max_length=4096)


# --- photos ---

class PhotoOut(ORM):
    id: uuid.UUID
    status: PhotoStatus
    detected_species: str | None
    url: str
    crop_url: str | None
    created_at: datetime


def photo_out(photo) -> PhotoOut:
    return PhotoOut(id=photo.id, status=photo.status, detected_species=photo.detected_species,
                    url=f"/photos/{photo.id}/image",
                    crop_url=f"/photos/{photo.id}/crop" if photo.crop_key else None,
                    created_at=photo.created_at)


# --- lost reports ---

class LostReportIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    species: Species
    description: str | None = Field(None, max_length=2000)
    last_seen: Location
    last_seen_at: PastTime


class LostReportUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=80)
    species: Species | None = None
    description: str | None = Field(None, max_length=2000)
    last_seen: Location | None = None
    last_seen_at: PastTime | None = None
    status: ReportStatus | None = None


class LostReportOut(BaseModel):
    id: uuid.UUID
    name: str
    species: Species
    description: str | None
    last_seen: Location
    location_is_approximate: bool  # true unless you own the report
    last_seen_at: datetime
    status: ReportStatus
    photos: list[PhotoOut]
    created_at: datetime


# --- sightings ---

class SightingIn(BaseModel):
    species: Species
    location: Location
    seen_at: PastTime
    condition: Condition = Condition.HEALTHY
    note: str | None = Field(None, max_length=1000)
    is_stray: bool = False


class SightingUpdate(BaseModel):
    species: Species | None = None
    location: Location | None = None
    seen_at: PastTime | None = None
    condition: Condition | None = None
    note: str | None = Field(None, max_length=1000)
    is_stray: bool | None = None


class SightingOut(BaseModel):
    id: uuid.UUID
    species: Species
    location: Location
    seen_at: datetime
    condition: Condition
    note: str | None
    is_stray: bool
    mine: bool
    photos: list[PhotoOut]
    created_at: datetime


# --- map ---

MapType = Literal["lost", "sighting", "stray"]


class MapItem(BaseModel):
    type: MapType
    id: uuid.UUID
    species: Species
    location: Location
    date: datetime  # last seen (lost) or seen (sighting/stray)
    name: str | None = None
    condition: Condition | None = None
    photo_url: str | None = None


class MapOut(BaseModel):
    items: list[MapItem]
    truncated: bool  # more results than MAP_MAX_RESULTS: zoom in


# --- matches ---

class MatchOut(BaseModel):
    id: uuid.UUID
    lost_report_id: uuid.UUID
    lost_report_name: str
    score: float
    status: MatchStatus
    sighting: SightingOut
    lost_photo_url: str | None
    sighting_photo_url: str | None
    created_at: datetime
