import uuid
from datetime import timedelta

from fastapi import APIRouter, File, Request, UploadFile, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.config import settings
from app.deps import check_rate_limit, not_found
from app.geo import fuzz, point
from app.models import LostReport, User
from app.records import after_update, delete_record
from app.routers.photos import add_photo
from app.schemas import LostReportIn, LostReportOut, LostReportUpdate, Location, PhotoOut, photo_out
from app.security import DB, CurrentUser, require_owner_or_admin

router = APIRouter(tags=["lost reports"])


def report_out(report: LostReport, viewer: User | None) -> LostReportOut:
    exact = viewer is not None and viewer.id == report.owner_id
    lat, lon = ((report.lat, report.lon) if exact else
                fuzz(report.id, report.lat, report.lon, settings.location_fuzz_m, settings.location_fuzz_secret))
    return LostReportOut(id=report.id, name=report.name, species=report.species, description=report.description,
                         last_seen=Location(lat=lat, lon=lon), location_is_approximate=not exact,
                         last_seen_at=report.last_seen_at, status=report.status,
                         photos=[photo_out(p) for p in report.photos], created_at=report.created_at)


def _get(db, report_id: uuid.UUID) -> LostReport:
    report = db.scalar(select(LostReport).where(LostReport.id == report_id)
                       .options(selectinload(LostReport.photos)))
    if report is None:
        raise not_found("Lost report")
    return report


@router.post("/lost-reports", response_model=LostReportOut, status_code=status.HTTP_201_CREATED)
def create_report(body: LostReportIn, user: CurrentUser, db: DB):
    """Create the report, then add 1–5 photos with POST /lost-reports/{id}/photos."""
    check_rate_limit(db, LostReport.owner_id, user.id, LostReport.created_at,
                     settings.rate_limit_lost_reports_per_day, timedelta(days=1), "lost reports")
    report = LostReport(owner_id=user.id, name=body.name.strip(), species=body.species,
                        description=body.description, last_seen_point=point(body.last_seen.lat, body.last_seen.lon),
                        last_seen_at=body.last_seen_at)
    db.add(report)
    db.commit()
    return report_out(_get(db, report.id), user)


@router.get("/me/lost-reports", response_model=list[LostReportOut])
def my_reports(user: CurrentUser, db: DB):
    reports = db.scalars(select(LostReport).where(LostReport.owner_id == user.id)
                         .options(selectinload(LostReport.photos)).order_by(LostReport.created_at.desc()))
    return [report_out(r, user) for r in reports]


@router.get("/lost-reports/{report_id}", response_model=LostReportOut)
def get_report(report_id: uuid.UUID, user: CurrentUser, db: DB):
    """The location is exact for the owner and moved up to LOCATION_FUZZ_M for everyone else."""
    return report_out(_get(db, report_id), user)


@router.patch("/lost-reports/{report_id}", response_model=LostReportOut)
def update_report(report_id: uuid.UUID, body: LostReportUpdate, request: Request, user: CurrentUser, db: DB):
    report = _get(db, report_id)
    require_owner_or_admin(user, report.owner_id)
    changes = body.model_dump(exclude_unset=True, exclude_none=True)
    for field, value in changes.items():
        if field == "last_seen":
            report.last_seen_point = point(value["lat"], value["lon"])
        else:
            setattr(report, field, value.strip() if field == "name" else value)
    db.commit()
    after_update(request, db, report, set(changes))
    return report_out(_get(db, report_id), user)


@router.delete("/lost-reports/{report_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_report(report_id: uuid.UUID, request: Request, user: CurrentUser, db: DB):
    report = _get(db, report_id)
    require_owner_or_admin(user, report.owner_id)
    delete_record(request, db, report)


@router.post("/lost-reports/{report_id}/photos", response_model=PhotoOut, status_code=status.HTTP_201_CREATED)
def upload_photo(report_id: uuid.UUID, request: Request, user: CurrentUser, db: DB,
                 file: UploadFile = File(...)):
    """Upload one photo (JPEG, PNG, WebP or HEIC). Matching runs in the background: poll GET /photos/{id}."""
    report = _get(db, report_id)
    require_owner_or_admin(user, report.owner_id)
    return add_photo(request, db, user, report, file)
