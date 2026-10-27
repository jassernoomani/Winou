"""Service configuration, read from environment variables (prefix ML_)."""
import os
from dataclasses import dataclass


def _env(name: str, default: str) -> str:
    return os.getenv(f"ML_{name}", default)


@dataclass(frozen=True)
class Settings:
    embed_model: str = _env("EMBED_MODEL", "facebook/dinov2-base")
    yolo_weights: str = _env("YOLO_WEIGHTS", "yolo11s.pt")
    device: str = _env("DEVICE", "auto")  # "auto", "cpu", "cuda"
    min_detection_confidence: float = float(_env("MIN_DETECTION_CONFIDENCE", "0.25"))
    crop_margin: float = float(_env("CROP_MARGIN", "0.10"))
    max_upload_mb: float = float(_env("MAX_UPLOAD_MB", "10"))
    max_image_pixels: int = int(_env("MAX_IMAGE_PIXELS", "40000000"))
    crop_max_side: int = int(_env("CROP_MAX_SIDE", "1024"))  # returned crop only; embedding uses full res


settings = Settings()
