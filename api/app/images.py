"""Upload validation and the EXIF-free public copy."""
import io

from fastapi import HTTPException, UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError
from pi_heif import register_heif_opener

register_heif_opener()  # HEIC is the default photo format on iPhones

ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP", "HEIF"}
CONTENT_TYPES = {"JPEG": "image/jpeg", "PNG": "image/png", "WEBP": "image/webp", "HEIF": "image/heif"}


def _error(status: int, code: str, message: str) -> HTTPException:
    return HTTPException(status, {"code": code, "message": message})


def read_upload(file: UploadFile, max_bytes: int) -> bytes:
    data = file.file.read(max_bytes + 1)  # one byte past the limit: reject without reading it all
    if len(data) > max_bytes:
        raise _error(413, "file_too_large", f"Image is larger than {max_bytes // 1_000_000} MB.")
    return data


def make_public_copy(data: bytes, max_pixels: int, max_side: int) -> tuple[bytes, str]:
    """Validate an upload and return (EXIF-free upright JPEG, original content type).

    The format is checked from the file content, not its name. The copy drops all
    metadata, including the GPS position phones write into photos.
    """
    try:
        image = Image.open(io.BytesIO(data))
        if image.format not in ALLOWED_FORMATS:
            raise _error(415, "unsupported_format", "Use a JPEG, PNG, WebP or HEIC image.")
        if image.width * image.height > max_pixels:
            raise _error(413, "image_too_large", "Image resolution is too high.")
        original_type = CONTENT_TYPES[image.format]
        image = ImageOps.exif_transpose(image).convert("RGB")
    except Image.DecompressionBombError:
        raise _error(413, "image_too_large", "Image resolution is too high.")
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError):
        raise _error(415, "invalid_image", "The file is not a readable image.")

    image.thumbnail((max_side, max_side))
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=88)  # no EXIF is written
    return buffer.getvalue(), original_type
