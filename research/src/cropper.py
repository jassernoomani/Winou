"""YOLO-based animal detection and cropping (same logic the ML service will use)."""
from dataclasses import dataclass

from PIL import Image
from ultralytics import YOLO

# COCO class ids
COCO_CAT, COCO_DOG = 15, 16
SPECIES_BY_CLASS = {COCO_CAT: "cat", COCO_DOG: "dog"}


@dataclass
class Detection:
    species: str
    confidence: float
    box: tuple[int, int, int, int]  # x1, y1, x2, y2 in pixels


class AnimalCropper:
    def __init__(self, weights: str = "yolo11s.pt", min_confidence: float = 0.25,
                 margin: float = 0.10, device: str | None = None):
        self.model = YOLO(weights)
        self.min_confidence = min_confidence
        self.margin = margin
        self.device = device

    def detect(self, image: Image.Image) -> Detection | None:
        """Return the highest-confidence cat/dog box, or None."""
        result = self.model.predict(image, classes=list(SPECIES_BY_CLASS),
                                    conf=self.min_confidence, device=self.device,
                                    verbose=False)[0]
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
        """Crop the detection box, padded by `margin` on each side."""
        x1, y1, x2, y2 = detection.box
        pad_x, pad_y = (x2 - x1) * self.margin, (y2 - y1) * self.margin
        return image.crop((
            max(0, int(x1 - pad_x)), max(0, int(y1 - pad_y)),
            min(image.width, int(x2 + pad_x)), min(image.height, int(y2 + pad_y)),
        ))
