"""ML service: detect an animal in a photo, crop it and embed it.

Endpoints are plain `def` (not `async`) so FastAPI runs the model calls in
its thread pool instead of blocking the event loop.
"""
from collections.abc import Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, Query, Request, UploadFile
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

from app.config import Settings, settings
from app.images import ImageError, decode_upload, to_jpeg, to_jpeg_base64
from app.pipeline import Pipeline


class DetectionOut(BaseModel):
    species: str
    confidence: float
    box: tuple[int, int, int, int]


class EmbedOut(BaseModel):
    detection: DetectionOut
    model: str
    dim: int
    vector: list[float]
    crop_jpeg_base64: str | None = None


class HealthOut(BaseModel):
    status: str
    model: str
    device: str
    dim: int


def create_app(load_pipeline: Callable[[Settings], Pipeline] = Pipeline) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.pipeline = load_pipeline(settings)
        yield

    app = FastAPI(title="Winou ML service", version="1.0.0", lifespan=lifespan)

    @app.exception_handler(ImageError)
    def image_error(_: Request, exc: ImageError):
        return JSONResponse(status_code=exc.status,
                            content={"detail": {"code": exc.code, "message": exc.message}})

    def read_image(file: UploadFile):
        # Read one byte past the limit so oversized uploads are rejected without loading them fully.
        max_bytes = int(settings.max_upload_mb * 1_000_000)
        return decode_upload(file.file.read(max_bytes + 1), max_bytes, settings.max_image_pixels)

    def detect_or_fail(pipeline: Pipeline, image):
        detection = pipeline.detect(image)
        if detection is None:
            raise ImageError(422, "no_animal_detected",
                             "No cat or dog found. Try a closer photo showing the animal's head.")
        return detection

    @app.get("/health", response_model=HealthOut)
    def health(request: Request):
        pipeline: Pipeline = request.app.state.pipeline
        return HealthOut(status="ok", model=pipeline.model_name, device=pipeline.device, dim=pipeline.dim)

    @app.post("/detect", response_model=DetectionOut,
              responses={422: {"description": "No cat or dog in the image"}})
    def detect(request: Request, file: UploadFile = File(...)):
        """Find the main cat or dog in a photo (cheap; for instant feedback in the app)."""
        pipeline: Pipeline = request.app.state.pipeline
        detection = detect_or_fail(pipeline, read_image(file))
        return DetectionOut(**detection.__dict__)

    @app.post("/embed", response_model=EmbedOut,
              responses={422: {"description": "No cat or dog in the image"}})
    def embed(request: Request, file: UploadFile = File(...),
              return_crop: bool = Query(False, description="Include the cropped animal as base64 JPEG")):
        """Detect the animal, crop it and return its L2-normalized embedding."""
        pipeline: Pipeline = request.app.state.pipeline
        image = read_image(file)
        detection = detect_or_fail(pipeline, image)
        crop = pipeline.crop(image, detection)
        vector = pipeline.embed(crop)
        return EmbedOut(
            detection=DetectionOut(**detection.__dict__),
            model=pipeline.model_name,
            dim=len(vector),
            vector=vector.tolist(),
            crop_jpeg_base64=to_jpeg_base64(crop, settings.crop_max_side) if return_crop else None,
        )

    @app.post("/convert", response_class=Response, responses={200: {"content": {"image/jpeg": {}}}})
    def convert(file: UploadFile = File(...), max_side: int = Query(2048, ge=64, le=8192)):
        """Any supported image (notably HEIC, which Java cannot decode) as an upright JPEG without metadata."""
        return Response(to_jpeg(read_image(file), max_side, quality=88), media_type="image/jpeg")

    return app


app = create_app()
