import uuid
from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, File, HTTPException, Query, Request, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.config import settings
from app.deps import check_rate_limit, not_found
from app.geo import distance_m, fuzz, point
from app.models import LostReport, PhotoSource, ReportStatus, Species, User
from app.records import after_update, delete_record
from app.routers.photos import SourceField, add_photo
from app.schemas import LostReportIn, LostReportOut, LostReportUpdate, Location, PhotoOut, photo_out
from app.security import DB, CurrentUser, require_owner_or_admin

router = APIRouter(tags=["lost reports"])


def _shown_position(report_id, owner_id, lat, lon, viewer: User | None) -> tuple[float, float]:
    """Exact for the owner, approximate for everyone else."""
    if viewer is not None and viewer.id == owner_id:
        return lat, lon
    return fuzz(report_id, lat, lon, settings.location_fuzz_m, settings.location_fuzz_secret)


def report_out(report: LostReport, viewer: User | None) -> LostReportOut:
    exact = viewer is not None and viewer.id == report.owner_id
    lat, lon = _shown_position(report.id, report.owner_id, report.lat, report.lon, viewer)
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


@router.get("/lost-reports", response_model=list[LostReportOut])
def list_reports(
    user: CurrentUser,
    db: DB,
    lat: Annotated[float | None, Query(ge=-90, le=90)] = None,
    lon: Annotated[float | None, Query(ge=-180, le=180)] = None,
    radius_km: Annotated[float, Query(gt=0, le=200)] = 25,
    species: Annotated[list[Species] | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=50)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
):
    """Open lost reports, the most recently seen first. Fewer than `limit` items means the last page.

    With lat/lon, only reports within radius_km. The distance is measured to the position shown
    (approximate unless it's yours), so moving the search point can't reveal the exact one.
    """
    if (lat is None) != (lon is None):
        raise HTTPException(422, "give both lat and lon, or neither")
    query = (select(LostReport.id, LostReport.owner_id, LostReport.lat.label("lat"), LostReport.lon.label("lon"))
             .where(LostReport.status == ReportStatus.OPEN)
             .order_by(LostReport.last_seen_at.desc(), LostReport.id))
    if species:
        query = query.where(LostReport.species.in_(species))
    if lat is None:
        ids = list(db.scalars(query.with_only_columns(LostReport.id).offset(offset).limit(limit)))
    else:
        # Coarse filter on the exact point (with a margin for the fuzz), then the real one on the shown point
        radius_m = radius_km * 1000
        query = query.where(func.ST_DWithin(LostReport.last_seen_point, func.geography(func.ST_SetSRID(func.ST_MakePoint(lon, lat), 4326)),
                                            radius_m + settings.location_fuzz_m))
        ids = [row.id for row in db.execute(query)
               if distance_m(lat, lon, *_shown_position(row.id, row.owner_id, row.lat, row.lon, user)) <= radius_m]
        ids = ids[offset:offset + limit]
    reports = {r.id: r for r in db.scalars(select(LostReport).where(LostReport.id.in_(ids))
                                           .options(selectinload(LostReport.photos)))}
    return [report_out(reports[i], user) for i in ids]


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
                 file: UploadFile = File(...), source: PhotoSource | None = SourceField):
    """Upload one photo (JPEG, PNG, WebP or HEIC). Matching runs in the background: poll GET /photos/{id}."""
    report = _get(db, report_id)
    require_owner_or_admin(user, report.owner_id)
    return add_photo(request, db, user, report, file, source)
