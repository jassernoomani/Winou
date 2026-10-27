"""API configuration, read from environment variables (see .env.example)."""
import os
from dataclasses import dataclass, field


def _env(name: str, default: str) -> str:
    return os.getenv(name) or default


@dataclass(frozen=True)
class Settings:
    database_url: str = _env("DATABASE_URL", "postgresql+psycopg://winou:winou@localhost:5432/winou")
    jwt_secret: str = _env("JWT_SECRET", "dev-only-insecure-secret")
    jwt_expire_minutes: int = int(_env("JWT_EXPIRE_MINUTES", "10080"))

    ml_service_url: str = _env("ML_SERVICE_URL", "http://localhost:8000")
    qdrant_url: str = _env("QDRANT_URL", "http://localhost:6333")
    qdrant_api_key: str | None = os.getenv("QDRANT_API_KEY") or None
    qdrant_collection: str = _env("QDRANT_COLLECTION", "pet_photos")
    embed_dim: int = int(_env("EMBED_DIM", "1536"))

    s3_endpoint: str = _env("S3_ENDPOINT", "localhost:9000")
    s3_access_key: str = _env("S3_ACCESS_KEY", "winou")
    s3_secret_key: str = _env("S3_SECRET_KEY", "winou-dev-secret")
    s3_bucket: str = _env("S3_BUCKET", "winou-photos")
    s3_secure: bool = _env("S3_SECURE", "false").lower() == "true"

    max_upload_mb: float = float(_env("MAX_UPLOAD_MB", "10"))
    max_image_pixels: int = int(_env("MAX_IMAGE_PIXELS", "40000000"))
    public_image_max_side: int = int(_env("PUBLIC_IMAGE_MAX_SIDE", "2048"))
    location_fuzz_m: float = float(_env("LOCATION_FUZZ_M", "300"))
    # Separate from JWT_SECRET and never rotated: a new value moves every public position,
    # and comparing old and new positions narrows down the real one.
    location_fuzz_secret: str = _env("LOCATION_FUZZ_SECRET", "dev-only-insecure-fuzz-secret")
    map_max_results: int = int(_env("MAP_MAX_RESULTS", "500"))

    rate_limit_lost_reports_per_day: int = int(_env("RATE_LIMIT_LOST_REPORTS_PER_DAY", "5"))
    rate_limit_sightings_per_hour: int = int(_env("RATE_LIMIT_SIGHTINGS_PER_HOUR", "20"))
    rate_limit_photos_per_hour: int = int(_env("RATE_LIMIT_PHOTOS_PER_HOUR", "60"))

    match_thresholds: dict[str, float] = field(default_factory=lambda: {
        "dog": float(_env("MATCH_THRESHOLD_DOG", "0.60")),
        "cat": float(_env("MATCH_THRESHOLD_CAT", "0.70")),
    })
    match_radius_km: float = float(_env("MATCH_RADIUS_KM", "10"))
    match_lost_window_days: int = int(_env("MATCH_LOST_WINDOW_DAYS", "60"))
    match_sighting_grace_days: int = int(_env("MATCH_SIGHTING_GRACE_DAYS", "2"))
    match_max_notifications: int = int(_env("MATCH_MAX_NOTIFICATIONS", "3"))

    worker_poll_seconds: float = float(_env("WORKER_POLL_SECONDS", "2"))
    worker_max_attempts: int = int(_env("WORKER_MAX_ATTEMPTS", "5"))


settings = Settings()

PHOTO_LIMITS = {"LOST_REPORT": 5, "SIGHTING": 3}
