"""Background worker: processes uploaded photos (python -m app.worker).

The queue is the photos table itself. A photo is claimed with FOR UPDATE SKIP LOCKED,
so several workers can run side by side. Claiming sets a lease (next_attempt_at in
the future): if a worker dies mid-photo, the lease runs out and another one retries it.
"""
import logging
import signal
import time
from datetime import datetime, timedelta, timezone

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.config import Settings, settings
from app.db import SessionLocal
from app.matching import Services, process_photo
from app.models import Photo, PhotoStatus
from app.services import build_services

log = logging.getLogger("winou.worker")
LEASE = timedelta(minutes=10)


def claim_photo(db: Session) -> Photo | None:
    now = datetime.now(timezone.utc)
    photo = db.scalar(
        select(Photo)
        .where(or_(Photo.status == PhotoStatus.PENDING, Photo.status == PhotoStatus.PROCESSING),
               Photo.next_attempt_at <= now)
        .order_by(Photo.next_attempt_at)
        .limit(1)
        .with_for_update(skip_locked=True))
    if photo is None:
        return None
    photo.status = PhotoStatus.PROCESSING
    photo.attempts += 1
    photo.next_attempt_at = now + LEASE
    db.commit()
    return photo


def run_once(services: Services, cfg: Settings = settings) -> bool:
    """Process one photo if any is waiting. Returns False when the queue is empty."""
    with SessionLocal() as db:
        photo = claim_photo(db)
        if photo is None:
            return False
        try:
            process_photo(db, photo, services, cfg)
            photo.error = None
            photo.processed_at = datetime.now(timezone.utc)
            db.commit()
            log.info("photo %s: %s", photo.id, photo.status)
        except Exception as exc:
            db.rollback()
            failed = photo.attempts >= cfg.worker_max_attempts
            photo.status = PhotoStatus.FAILED if failed else PhotoStatus.PENDING
            photo.error = f"{type(exc).__name__}: {exc}"[:2000]
            photo.next_attempt_at = datetime.now(timezone.utc) + timedelta(seconds=30 * 2 ** photo.attempts)
            db.commit()
            log.warning("photo %s attempt %d failed: %s", photo.id, photo.attempts, photo.error,
                        exc_info=failed)
        return True


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    logging.getLogger("httpx").setLevel(logging.WARNING)  # one line per Qdrant/ML request otherwise
    stopping = False

    def stop(*_):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    services = build_services()
    log.info("worker started")
    while not stopping:
        try:
            busy = run_once(services)
        except Exception:
            log.exception("worker loop error")  # e.g. database briefly unavailable
            busy = False
        if not busy:
            time.sleep(settings.worker_poll_seconds)


if __name__ == "__main__":
    main()
