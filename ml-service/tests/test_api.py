"""API tests with a fake pipeline: fast, offline, no model weights needed."""
import base64
import io

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.config import Settings
from app.main import create_app
from app.pipeline import Detection


class FakePipeline:
    model_name = "fake-model"
    device = "cpu"
    dim = 8

    def __init__(self, settings, detection=Detection("cat", 0.9, (10, 10, 60, 40))):
        self.detection = detection
        self.seen_sizes = []

    def detect(self, image):
        self.seen_sizes.append(image.size)
        return self.detection

    def crop(self, image, detection):
        return image.crop(detection.box)

    def embed(self, image):
        v = np.arange(1, self.dim + 1, dtype=np.float32)
        return v / np.linalg.norm(v)


def make_client(pipeline=None):
    pipeline = pipeline or FakePipeline(None)
    return TestClient(create_app(load_pipeline=lambda _: pipeline)), pipeline


def image_bytes(fmt="JPEG", size=(100, 50), exif=None):
    buffer = io.BytesIO()
    image = Image.new("RGB", size, "orange")
    image.save(buffer, format=fmt, **({"exif": exif} if exif else {}))
    return buffer.getvalue()


def upload(data, name="photo.jpg"):
    return {"file": (name, data, "application/octet-stream")}


def test_health():
    client, _ = make_client()
    with client:
        body = client.get("/health").json()
    assert body == {"status": "ok", "model": "fake-model", "device": "cpu", "dim": 8}


def test_embed_returns_normalized_vector():
    client, _ = make_client()
    with client:
        response = client.post("/embed", files=upload(image_bytes()))
    assert response.status_code == 200
    body = response.json()
    assert body["detection"] == {"species": "cat", "confidence": 0.9, "box": [10, 10, 60, 40]}
    assert body["dim"] == 8 and len(body["vector"]) == 8
    assert np.isclose(np.linalg.norm(body["vector"]), 1.0)
    assert body["crop_jpeg_base64"] is None


def test_embed_can_return_crop_without_exif():
    client, _ = make_client()
    exif = Image.Exif()
    exif[0x010F] = "PhoneMaker"  # camera make
    with client:
        body = client.post("/embed?return_crop=true", files=upload(image_bytes(exif=exif))).json()
    crop = Image.open(io.BytesIO(base64.b64decode(body["crop_jpeg_base64"])))
    assert crop.size == (50, 30)
    assert len(crop.getexif()) == 0


def test_returned_crop_is_downscaled(monkeypatch):
    monkeypatch.setattr("app.main.settings", Settings(crop_max_side=25))
    client, _ = make_client()
    with client:
        body = client.post("/embed?return_crop=true", files=upload(image_bytes())).json()
    crop = Image.open(io.BytesIO(base64.b64decode(body["crop_jpeg_base64"])))
    assert crop.size == (25, 15)  # 50x30 crop, longest side capped, aspect kept


def test_exif_rotation_is_applied():
    client, pipeline = make_client()
    exif = Image.Exif()
    exif[0x0112] = 6  # orientation: rotate 90° clockwise
    with client:
        client.post("/detect", files=upload(image_bytes(size=(100, 50), exif=exif)))
    assert pipeline.seen_sizes == [(50, 100)]


def test_heic_decoding_is_registered():
    # pi-heif can only decode, so a HEIC fixture can't be generated here.
    from app.images import ALLOWED_FORMATS
    assert "HEIF" in ALLOWED_FORMATS and "HEIF" in Image.OPEN


def test_no_animal_returns_422():
    client, _ = make_client(FakePipeline(None, detection=None))
    with client:
        response = client.post("/embed", files=upload(image_bytes()))
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "no_animal_detected"


@pytest.mark.parametrize("data, code", [
    (b"definitely not an image", "invalid_image"),
    (b"# A markdown file\n\nNot a photo.", "invalid_image"),
    (image_bytes(fmt="JPEG")[:200], "invalid_image"),  # truncated
    (image_bytes(fmt="GIF"), "unsupported_format"),
])
def test_rejects_bad_files(data, code):
    client, _ = make_client()
    with client:
        response = client.post("/embed", files=upload(data))
    assert response.status_code == 415
    assert response.json()["detail"]["code"] == code


def test_rejects_oversized_upload(monkeypatch):
    monkeypatch.setattr("app.main.settings", Settings(max_upload_mb=0.0001))
    client, _ = make_client()
    with client:
        response = client.post("/embed", files=upload(image_bytes(size=(400, 400))))
    assert response.status_code == 413
    assert response.json()["detail"]["code"] == "file_too_large"


def test_rejects_too_many_pixels(monkeypatch):
    monkeypatch.setattr("app.main.settings", Settings(max_image_pixels=1000))
    client, _ = make_client()
    with client:
        response = client.post("/embed", files=upload(image_bytes(size=(100, 50))))
    assert response.status_code == 413
    assert response.json()["detail"]["code"] == "image_too_large"


def test_convert_returns_upright_jpeg_without_exif():
    exif = Image.Exif()
    exif[0x0112] = 6  # Orientation: rotate 90° clockwise
    exif[0x8825] = {2: (36.0, 48.0, 23.4)}  # GPSInfo
    client, _ = make_client()
    with client:
        response = client.post("/convert", params={"max_side": 64},
                               files=upload(image_bytes(size=(200, 100), exif=exif.tobytes())))
    assert response.status_code == 200 and response.headers["content-type"] == "image/jpeg"
    image = Image.open(io.BytesIO(response.content))
    assert image.format == "JPEG" and image.size == (32, 64)  # rotated, then shrunk
    assert not image.getexif()
