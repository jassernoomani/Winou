"""Tests with the real models. Run with: pytest -m models

The parity test checks that the service produces the same vectors as the
Phase 0 research code, so the evaluated thresholds still apply. It needs
the cached research embeddings and is skipped when they are absent.
"""
import csv
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

from app.config import Settings
from app.pipeline import Detection, Pipeline

pytestmark = pytest.mark.models

RESEARCH = Path(__file__).resolve().parents[2] / "research"
EMBEDDINGS = RESEARCH / "outputs" / "embeddings"


@pytest.fixture(scope="module")
def pipeline():
    return Pipeline(Settings())


def test_embedding_is_normalized(pipeline):
    vector = pipeline.embed(Image.new("RGB", (224, 224), "white"))
    assert vector.shape == (pipeline.dim,)
    assert np.isclose(np.linalg.norm(vector), 1.0, atol=1e-5)


def test_blank_image_has_no_animal(pipeline):
    assert pipeline.detect(Image.new("RGB", (640, 480), "gray")) is None


@pytest.mark.skipif(not (EMBEDDINGS / "dogfacenet_index.csv").exists(),
                    reason="research embeddings not available")
def test_matches_research_embeddings(pipeline):
    with open(EMBEDDINGS / "dogfacenet_index.csv", newline="") as f:
        rows = list(csv.DictReader(f))
    expected = np.load(EMBEDDINGS / "dogfacenet_dinov2-b14_crop.npy")
    detected = [(i, row) for i, row in enumerate(rows) if row["det_conf"]][:5]
    for i, row in detected:
        image = Image.open(row["path"]).convert("RGB")
        detection = pipeline.detect(image)
        assert detection is not None and detection.species == row["det_species"]
        box = tuple(int(float(row[k])) for k in ("x1", "y1", "x2", "y2"))
        crop = pipeline.crop(image, Detection(row["det_species"], float(row["det_conf"]), box))
        assert float(pipeline.embed(crop) @ expected[i]) > 0.999
