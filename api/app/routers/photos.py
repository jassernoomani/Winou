import uuid
from datetime import timedelta

from fastapi import APIRouter, Form, HTTPException, Request, Response, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import PHOTO_LIMITS, settings
from app.deps import check_rate_limit, not_found, services
from app.images import make_public_copy, read_upload
from app.models import LostReport, Photo, PhotoSource, Sighting, User
from app.schemas import PhotoOut, photo_out
from app.security import DB, CurrentUser, require_owner_or_admin

router = APIRouter(tags=["photos"])

SourceField = Form(None, description="CAMERA or GALLERY, as picked in the app. Not shown to other users.")

ORIGINAL_EXTENSIONS = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/heif": "heic"}


def add_photo(request: Request, db: Session, user: User, record: LostReport | Sighting,
              file: UploadFile, source: PhotoSource | None) -> PhotoOut:
    """Validate and store an upload, then queue it for the worker (embedding + matching)."""
    owner_type = "LOST_REPORT" if isinstance(record, LostReport) else "SIGHTING"
    owner_column = Photo.lost_report_id if owner_type == "LOST_REPORT" else Photo.sighting_id
    if db.scalar(select(func.count()).where(owner_column == record.id)) >= PHOTO_LIMITS[owner_type]:
        raise HTTPException(status.HTTP_409_CONFLICT, {
            "code": "too_many_photos", "message": f"At most {PHOTO_LIMITS[owner_type]} photos."})
    check_rate_limit(db, Photo.uploader_id, user.id, Photo.created_at, settings.rate_limit_photos_per_hour,
                     timedelta(hours=1), "photo uploads")

    data = read_upload(file, int(settings.max_upload_mb * 1_000_000))
    public_jpeg, original_type = make_public_copy(data, settings.max_image_pixels,
                                                  settings.public_image_max_side)
    photo_id = uuid.uuid4()
    photo = Photo(id=photo_id, uploader_id=user.id, source=source,
                  original_key=f"originals/{photo_id}.{ORIGINAL_EXTENSIONS[original_type]}",
                  public_key=f"public/{photo_id}.jpg",
                  **({"lost_report_id": record.id} if owner_type == "LOST_REPORT" else {"sighting_id": record.id}))
    storage = services(request).storage
    storage.put(photo.original_key, data, original_type)
    storage.put(photo.public_key, public_jpeg, "image/jpeg")
    db.add(photo)
    db.commit()
    db.refresh(photo)
    return photo_out(photo)


def delete_photo_files(request: Request, photos: list[Photo]) -> None:
    keys = [k for p in photos for k in (p.original_key, p.public_key, p.crop_key) if k]
    if keys:
        services(request).storage.delete(keys)


def _get_photo(db: Session, photo_id: uuid.UUID) -> Photo:
    photo = db.get(Photo, photo_id)
    if photo is None:
        raise not_found("Photo")
    return photo


def _image_response(request: Request, key: str) -> Response:
    data = services(request).storage.get(key)
    # Keys are immutable (one per photo id), so clients may cache forever
    return Response(data, media_type="image/jpeg",
                    headers={"Cache-Control": "public, max-age=31536000, immutable"})


@router.get("/photos/{photo_id}/image", response_class=Response,
            responses={200: {"content": {"image/jpeg": {}}}})
def photo_image(photo_id: uuid.UUID, request: Request, db: DB):
    """The photo as an EXIF-free JPEG (no login needed, so the app can load it directly)."""
    return _image_response(request, _get_photo(db, photo_id).public_key)


@router.get("/photos/{photo_id}/crop", response_class=Response,
            responses={200: {"content": {"image/jpeg": {}}}})
def photo_crop(photo_id: uuid.UUID, request: Request, db: DB):
    """The detected animal, cropped (available once the photo is processed)."""
    photo = _get_photo(db, photo_id)
    if not photo.crop_key:
        raise not_found("Crop")
    return _image_response(request, photo.crop_key)


@router.get("/photos/{photo_id}", response_model=PhotoOut)
def photo_status(photo_id: uuid.UUID, user: CurrentUser, db: DB):
    """Poll after upload: status goes PENDING → READY, or NO_ANIMAL if the photo should be retaken."""
    photo = _get_photo(db, photo_id)
    require_owner_or_admin(user, photo.uploader_id)
    return photo_out(photo)


@router.delete("/photos/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_photo(photo_id: uuid.UUID, request: Request, user: CurrentUser, db: DB):
    photo = _get_photo(db, photo_id)
    require_owner_or_admin(user, photo.uploader_id)
    services(request).index.delete_photo(photo.id)
    db.delete(photo)
    db.commit()
    delete_photo_files(request, [photo])
