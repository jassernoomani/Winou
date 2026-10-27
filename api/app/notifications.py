"""Match notifications. Phase 2 only logs them; Firebase Cloud Messaging is wired in Phase 3."""
import logging
from typing import Protocol

from sqlalchemy.orm import Session

from app.models import Match

log = logging.getLogger(__name__)


class Notifier(Protocol):
    def match_found(self, db: Session, match: Match) -> None: ...


class LogNotifier:
    def match_found(self, db: Session, match: Match) -> None:
        log.info("match %s: lost report %s <-> sighting %s (score %.3f)",
                 match.id, match.lost_report_id, match.sighting_id, match.score)
