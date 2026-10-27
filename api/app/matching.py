"""Photo processing and matching (brief §6, steps 2–6). Run by the worker, one photo at a time."""
import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.config import Settings
from app.ml_client import MLClient, NoAnimalDetected
from app.models import LostReport, Match, Photo, PhotoStatus, ReportStatus, Sighting, Species
from app.notifications import Notifier
from app.storage import Storage
from app.vectors import Hit, VectorIndex, payload

log = logging.getLogger(__name__)


@dataclass
class Services:
    storage: Storage
    index: VectorIndex
    ml: MLClient
    notifier: Notifier


def index_payload(record: LostReport | Sighting) -> dict:
    if isinstance(record, LostReport):
        return payload(record.species, "lost", record.id, record.lat, record.lon, record.last_seen_at)
    return payload(record.species, "sighting", record.id, record.lat, record.lon, record.seen_at)


def process_photo(db: Session, photo: Photo, services: Services, settings: Settings) -> None:
    """Embed one photo, index it and create matches. Sets photo.status; the caller commits.

    Raises on transient failures (ML service or storage down) so the worker can retry.
    """
    record: LostReport | Sighting = photo.lost_report or photo.sighting
    if record.species == Species.OTHER:
        services.index.delete_photo(photo.id)  # in case the species was changed to "other"
        photo.status = PhotoStatus.SKIPPED  # the detector only knows cats and dogs
        return

    # Re-matching after an edit (new location, date or species) reuses the stored vector
    vector = services.index.get_vector(photo.id) if photo.crop_key else None
    if vector is None:
        try:
            result = services.ml.embed(services.storage.get(photo.public_key))
        except NoAnimalDetected:
            photo.status = PhotoStatus.NO_ANIMAL
            return
        vector = result.vector
        photo.crop_key = f"crops/{photo.id}.jpg"
        services.storage.put(photo.crop_key, result.crop_jpeg, "image/jpeg")
        photo.detected_species = result.species
        photo.detection_confidence = result.confidence

    if photo.detected_species != record.species:
        # Matching uses the species the user chose; a mismatch is kept for review, not auto-corrected.
        log.info("photo %s: user said %s, detector saw %s", photo.id, record.species, photo.detected_species)

    services.index.upsert(photo.id, vector, index_payload(record))
    new_matches = find_matches(db, photo, record, vector, services.index, settings)
    photo.status = PhotoStatus.READY
    db.flush()
    for match in new_matches[:settings.match_max_notifications]:
        services.notifier.match_found(db, match)
        match.notified_at = datetime.now(timezone.utc)


def find_matches(db: Session, photo: Photo, record: LostReport | Sighting, vector: list[float],
                 index: VectorIndex, settings: Settings) -> list[Match]:
    """Search the other side, keep the best score per (report, sighting) pair above the threshold.

    Returns the newly created matches, best first. Existing matches only get their score raised.
    """
    threshold = settings.match_thresholds[record.species]
    radius_m = settings.match_radius_km * 1000
    if isinstance(record, LostReport):
        if record.status != ReportStatus.OPEN:
            return []
        since = record.last_seen_at - timedelta(days=settings.match_sighting_grace_days)
        hits = index.search(vector, record.species, "sighting", record.lat, record.lon, radius_m, since=since)
    else:
        hits = index.search(vector, record.species, "lost", record.lat, record.lon, radius_m,
                            since=record.seen_at - timedelta(days=settings.match_lost_window_days),
                            until=record.seen_at + timedelta(days=settings.match_sighting_grace_days))

    best: dict[uuid.UUID, Hit] = {}
    for hit in hits:
        if hit.score >= threshold and hit.photo_id != photo.id and (
                hit.ref_id not in best or hit.score > best[hit.ref_id].score):
            best[hit.ref_id] = hit
    if not best:
        return []

    created = []
    for other in _valid_counterparts(db, record, list(best)):
        hit = best[other.id]
        report, sighting = (record, other) if isinstance(record, LostReport) else (other, record)
        lost_photo, sighting_photo = ((photo.id, hit.photo_id) if isinstance(record, LostReport)
                                      else (hit.photo_id, photo.id))
        values = {"score": hit.score, "lost_photo_id": lost_photo, "sighting_photo_id": sighting_photo}
        # Insert-or-raise-score in SQL: two workers may match the same pair at the same time
        new_id = db.scalar(insert(Match).values(id=uuid.uuid4(), lost_report_id=report.id,
                                                sighting_id=sighting.id, **values)
                           .on_conflict_do_nothing(index_elements=["lost_report_id", "sighting_id"])
                           .returning(Match.id))
        if new_id is not None:
            created.append(db.get(Match, new_id))
        else:
            db.execute(update(Match).where(Match.lost_report_id == report.id, Match.sighting_id == sighting.id,
                                           Match.score < hit.score).values(**values))
    created.sort(key=lambda mt: mt.score, reverse=True)
    return created


def _valid_counterparts(db: Session, record: LostReport | Sighting, ids: list[uuid.UUID]):
    """Drop closed reports and pairs where the owner reported their own animal."""
    if isinstance(record, LostReport):
        return db.scalars(select(Sighting).where(Sighting.id.in_(ids),
                                                 Sighting.reporter_id != record.owner_id)).all()
    return db.scalars(select(LostReport).where(LostReport.id.in_(ids), LostReport.status == ReportStatus.OPEN,
                                               LostReport.owner_id != record.reporter_id)).all()
