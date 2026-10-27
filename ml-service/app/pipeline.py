"""Detect -> crop -> embed. Same logic as research/src (validated in Phase 0)."""
import threading
from dataclasses import dataclass

import numpy as np
import torch
from PIL import Image
from transformers import AutoImageProcessor, AutoModel
from ultralytics import YOLO

from app.config import Settings

# COCO class ids
SPECIES_BY_CLASS = {15: "cat", 16: "dog"}


@dataclass
class Detection:
    species: str
    confidence: float
    box: tuple[int, int, int, int]  # x1, y1, x2, y2 in pixels


class Pipeline:
    """Holds the models; loaded once at startup and shared by all requests."""

    def __init__(self, settings: Settings):
        self.settings = settings
        self.device = _resolve_device(settings.device)
        self.detector = YOLO(settings.yolo_weights)
        self.processor = AutoImageProcessor.from_pretrained(settings.embed_model)
        self.embedder = AutoModel.from_pretrained(settings.embed_model).to(self.device).eval()
        # DINOv2: CLS token + mean patch token, see research/src/embedders.py
        self.dim = self.embedder.config.hidden_size * 2
        # One request at a time on the model; keeps memory use predictable.
        self._lock = threading.Lock()

    @property
    def model_name(self) -> str:
        return self.settings.embed_model

    def detect(self, image: Image.Image) -> Detection | None:
        """Return the highest-confidence cat/dog box, or None."""
        with self._lock:
            result = self.detector.predict(image, classes=list(SPECIES_BY_CLASS),
                                           conf=self.settings.min_detection_confidence,
                                           device=self.device, verbose=False)[0]
        if len(result.boxes) == 0:
            return None
        best = int(result.boxes.conf.argmax())
        x1, y1, x2, y2 = result.boxes.xyxy[best].tolist()
        return Detection(
            species=SPECIES_BY_CLASS[int(result.boxes.cls[best])],
            confidence=float(result.boxes.conf[best]),
            box=(int(x1), int(y1), int(x2), int(y2)),
        )

    def crop(self, image: Image.Image, detection: Detection) -> Image.Image:
        """Crop the detection box, padded by `crop_margin` on each side."""
        x1, y1, x2, y2 = detection.box
        margin = self.settings.crop_margin
        pad_x, pad_y = (x2 - x1) * margin, (y2 - y1) * margin
        return image.crop((
            max(0, int(x1 - pad_x)), max(0, int(y1 - pad_y)),
            min(image.width, int(x2 + pad_x)), min(image.height, int(y2 + pad_y)),
        ))

    @torch.inference_mode()
    def embed(self, image: Image.Image) -> np.ndarray:
        """L2-normalized embedding of one image."""
        inputs = self.processor(images=[image], return_tensors="pt").to(self.device)
        with self._lock:
            tokens = self.embedder(**inputs).last_hidden_state
        features = torch.cat([tokens[:, 0], tokens[:, 1:].mean(dim=1)], dim=-1)
        return torch.nn.functional.normalize(features.float(), dim=-1)[0].cpu().numpy()


def _resolve_device(device: str) -> str:
    if device == "auto":
        return "cuda" if torch.cuda.is_available() else "cpu"
    return device
