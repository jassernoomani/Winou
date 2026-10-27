"""Changes to lost reports and sightings that must reach Qdrant and the matcher."""
from datetime import datetime, timezone

from fastapi import Request
from sqlalchemy import update
from sqlalchemy.orm import Session

from app.deps import services
from app.matching import index_payload
from app.models import LostReport, Photo, PhotoStatus, Sighting, Species
from app.routers.photos import delete_photo_files

MATCH_FIELDS = {"species", "last_seen", "last_seen_at", "location", "seen_at", "status"}


def after_update(request: Request, db: Session, record: LostReport | Sighting, changed: set[str]) -> None:
    """Call after committing an edit. Re-runs matching if what matching depends on changed."""
    if not changed & MATCH_FIELDS:
        return
    db.refresh(record)  # reload lat/lon
    index = services(request).index
    if record.species == Species.OTHER:
        index.delete_ref(record.id)
    else:
        index.update_ref(record.id, index_payload(record))
    # Queue processed photos again: the worker reuses their vectors and searches with the new filters
    owner_column = Photo.lost_report_id if isinstance(record, LostReport) else Photo.sighting_id
    db.execute(update(Photo)
               .where(owner_column == record.id, Photo.status.in_([PhotoStatus.READY, PhotoStatus.SKIPPED]))
               .values(status=PhotoStatus.PENDING, attempts=0, next_attempt_at=datetime.now(timezone.utc)))
    db.commit()


def delete_record(request: Request, db: Session, record: LostReport | Sighting) -> None:
    photos = list(record.photos)
    services(request).index.delete_ref(record.id)
    db.delete(record)  # photos and matches cascade in Postgres
    db.commit()
    delete_photo_files(request, photos)
