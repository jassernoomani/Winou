"""Database tables. Points are PostGIS geography(Point, 4326): lon/lat in WGS84, distances in metres."""
import enum
import uuid
from datetime import datetime

from geoalchemy2 import Geography
from sqlalchemy import (CheckConstraint, DateTime, Enum, Float, ForeignKey, Integer, String, Text,
                        UniqueConstraint, func)
from sqlalchemy.orm import DeclarativeBase, Mapped, column_property, mapped_column, relationship


class Role(enum.StrEnum):
    USER = "USER"
    ASSOCIATION = "ASSOCIATION"
    ADMIN = "ADMIN"


class Species(enum.StrEnum):
    CAT = "cat"
    DOG = "dog"
    OTHER = "other"


class ReportStatus(enum.StrEnum):
    OPEN = "OPEN"
    FOUND = "FOUND"
    CLOSED = "CLOSED"


class Condition(enum.StrEnum):
    HEALTHY = "HEALTHY"
    INJURED = "INJURED"
    NEEDS_HELP = "NEEDS_HELP"


class PhotoStatus(enum.StrEnum):
    PENDING = "PENDING"        # stored, waiting for the worker
    PROCESSING = "PROCESSING"
    READY = "READY"            # embedded, indexed in Qdrant and matched
    NO_ANIMAL = "NO_ANIMAL"    # no cat/dog found: the user should retake the photo
    SKIPPED = "SKIPPED"        # species "other": stored but not matched
    FAILED = "FAILED"          # gave up after WORKER_MAX_ATTEMPTS


class PhotoSource(enum.StrEnum):
    """Where the app got the photo. Internal only: kept for moderation and match weighting."""
    CAMERA = "CAMERA"
    GALLERY = "GALLERY"


class MatchStatus(enum.StrEnum):
    PENDING = "PENDING"
    CONFIRMED = "CONFIRMED"
    REJECTED = "REJECTED"


def _enum(cls):
    # Stored as VARCHAR + CHECK rather than native Postgres enums, which are awkward to migrate
    return Enum(cls, native_enum=False, create_constraint=True, length=16,
                values_callable=lambda e: [m.value for m in e])


def _lat_lon(point):
    # geography -> geometry for ST_X/ST_Y; loaded with the row
    return (column_property(func.ST_Y(func.geometry(point), type_=Float)),
            column_property(func.ST_X(func.geometry(point), type_=Float)))


def _uuid_pk():
    return mapped_column(primary_key=True, default=uuid.uuid4)


def _created_at():
    return mapped_column(DateTime(timezone=True), server_default=func.now())


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = _uuid_pk()
    email: Mapped[str] = mapped_column(String(320), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(80))
    role: Mapped[Role] = mapped_column(_enum(Role), default=Role.USER)
    fcm_token: Mapped[str | None] = mapped_column(String(4096))
    created_at: Mapped[datetime] = _created_at()


class LostReport(Base):
    __tablename__ = "lost_reports"

    id: Mapped[uuid.UUID] = _uuid_pk()
    owner_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(80))
    species: Mapped[Species] = mapped_column(_enum(Species))
    description: Mapped[str | None] = mapped_column(Text)
    last_seen_point = mapped_column(Geography("POINT", srid=4326, spatial_index=True), nullable=False)
    lat, lon = _lat_lon(last_seen_point)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[ReportStatus] = mapped_column(_enum(ReportStatus), default=ReportStatus.OPEN, index=True)
    created_at: Mapped[datetime] = _created_at()

    photos: Mapped[list["Photo"]] = relationship(back_populates="lost_report", order_by="Photo.created_at",
                                                 cascade="all, delete-orphan", passive_deletes=True)


class Sighting(Base):
    __tablename__ = "sightings"

    id: Mapped[uuid.UUID] = _uuid_pk()
    reporter_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    species: Mapped[Species] = mapped_column(_enum(Species))
    point = mapped_column(Geography("POINT", srid=4326, spatial_index=True), nullable=False)
    lat, lon = _lat_lon(point)
    seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    condition: Mapped[Condition] = mapped_column(_enum(Condition), default=Condition.HEALTHY)
    note: Mapped[str | None] = mapped_column(Text)
    is_stray: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = _created_at()

    photos: Mapped[list["Photo"]] = relationship(back_populates="sighting", order_by="Photo.created_at",
                                                 cascade="all, delete-orphan", passive_deletes=True)


class Photo(Base):
    """A photo of a lost report or a sighting (exactly one). Its id is also its Qdrant point id."""
    __tablename__ = "photos"
    __table_args__ = (
        CheckConstraint("(lost_report_id IS NULL) <> (sighting_id IS NULL)", name="one_owner"),
    )

    id: Mapped[uuid.UUID] = _uuid_pk()
    uploader_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lost_report_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("lost_reports.id", ondelete="CASCADE"), index=True)
    sighting_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("sightings.id", ondelete="CASCADE"), index=True)
    original_key: Mapped[str] = mapped_column(String(255))   # as uploaded, may hold GPS EXIF: never served
    public_key: Mapped[str] = mapped_column(String(255))     # re-encoded JPEG without EXIF
    crop_key: Mapped[str | None] = mapped_column(String(255))
    source: Mapped[PhotoSource | None] = mapped_column(_enum(PhotoSource))  # null: client didn't say
    status: Mapped[PhotoStatus] = mapped_column(_enum(PhotoStatus), default=PhotoStatus.PENDING, index=True)
    detected_species: Mapped[str | None] = mapped_column(String(16))
    detection_confidence: Mapped[float | None] = mapped_column(Float)
    error: Mapped[str | None] = mapped_column(Text)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    next_attempt_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _created_at()

    lost_report: Mapped[LostReport | None] = relationship(back_populates="photos")
    sighting: Mapped[Sighting | None] = relationship(back_populates="photos")

    @property
    def owner_type(self) -> str:
        return "LOST_REPORT" if self.lost_report_id else "SIGHTING"


class Match(Base):
    __tablename__ = "matches"
    __table_args__ = (UniqueConstraint("lost_report_id", "sighting_id"),)

    id: Mapped[uuid.UUID] = _uuid_pk()
    lost_report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("lost_reports.id", ondelete="CASCADE"), index=True)
    sighting_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("sightings.id", ondelete="CASCADE"), index=True)
    score: Mapped[float] = mapped_column(Float)  # best photo-to-photo cosine similarity of the pair
    lost_photo_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("photos.id", ondelete="SET NULL"))
    sighting_photo_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("photos.id", ondelete="SET NULL"))
    status: Mapped[MatchStatus] = mapped_column(_enum(MatchStatus), default=MatchStatus.PENDING)
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _created_at()

    lost_report: Mapped[LostReport] = relationship()
    sighting: Mapped[Sighting] = relationship()
