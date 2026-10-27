from fastapi import APIRouter
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models import LostReport, Match, Sighting
from app.routers.sightings import sighting_out
from app.schemas import MatchOut
from app.security import DB, CurrentUser

router = APIRouter(tags=["matches"])


def _photo_url(photo_id) -> str | None:
    return f"/photos/{photo_id}/image" if photo_id else None


@router.get("/me/matches", response_model=list[MatchOut])
def my_matches(user: CurrentUser, db: DB):
    """Possible sightings of your lost pets, best score first. Answering them comes in Phase 4."""
    matches = db.scalars(
        select(Match).join(LostReport).where(LostReport.owner_id == user.id)
        .options(selectinload(Match.lost_report), selectinload(Match.sighting).selectinload(Sighting.photos))
        .order_by(Match.score.desc()))
    return [MatchOut(id=m.id, lost_report_id=m.lost_report_id, lost_report_name=m.lost_report.name, score=m.score,
                     status=m.status, sighting=sighting_out(m.sighting, user),
                     lost_photo_url=_photo_url(m.lost_photo_id), sighting_photo_url=_photo_url(m.sighting_photo_id),
                     created_at=m.created_at)
            for m in matches]
