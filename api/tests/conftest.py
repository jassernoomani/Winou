"""Tests run against a real PostGIS database (winou_test, created on demand) and an
in-memory Qdrant. Storage and the ML service are faked.

    docker compose up -d postgres
    pytest

Fake embeddings come from the image colour, so tests control similarity: two
near-identical reds score ~1.0, red vs blue scores 0. A black image has "no animal".
"""
import io
import os
import uuid

# Must be set before app modules read their settings
BASE_URL = os.getenv("TEST_DATABASE_URL", "postgresql+psycopg://winou:winou@localhost:5432/winou_test")
os.environ["DATABASE_URL"] = BASE_URL
os.environ["EMBED_DIM"] = "8"
os.environ["JWT_SECRET"] = "test-secret-at-least-32-bytes-long!!"
os.environ["LOCATION_FUZZ_SECRET"] = "test-fuzz-secret"

import numpy as np  # noqa: E402
import pytest  # noqa: E402
from alembic import command  # noqa: E402
from alembic.config import Config  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402
from qdrant_client import QdrantClient  # noqa: E402
from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.engine import make_url  # noqa: E402

from app.config import settings  # noqa: E402
from app.db import engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.matching import Services  # noqa: E402
from app.ml_client import Embedding, NoAnimalDetected  # noqa: E402
from app.vectors import VectorIndex  # noqa: E402
from app.worker import run_once  # noqa: E402

TUNIS = {"lat": 36.8065, "lon": 10.1815}
RED, NEAR_RED, BLUE, BLACK = (220, 30, 30), (215, 35, 30), (30, 30, 220), (0, 0, 0)


class FakeStorage:
    def __init__(self):
        self.objects: dict[str, bytes] = {}

    def put(self, key, data, content_type):
        self.objects[key] = data

    def get(self, key):
        return self.objects[key]

    def delete(self, keys):
        for key in keys:
            self.objects.pop(key, None)


class FakeML:
    def __init__(self):
        self.calls = 0

    def embed(self, image: bytes) -> Embedding:
        self.calls += 1
        rgb = np.asarray(Image.open(io.BytesIO(image)).convert("RGB"), dtype=np.float64).mean(axis=(0, 1))
        if rgb.sum() < 10:
            raise NoAnimalDetected()
        vector = np.zeros(settings.embed_dim)
        vector[:3] = rgb
        vector /= np.linalg.norm(vector)
        return Embedding(species="cat", confidence=0.9, vector=vector.tolist(), crop_jpeg=b"crop")


def _create_database():
    url = make_url(BASE_URL)
    admin = create_engine(url.set(database="postgres"), isolation_level="AUTOCOMMIT")
    with admin.connect() as conn:
        if not conn.scalar(text("SELECT 1 FROM pg_database WHERE datname = :n"), {"n": url.database}):
            conn.execute(text(f'CREATE DATABASE "{url.database}"'))
    admin.dispose()


@pytest.fixture(scope="session", autouse=True)
def database():
    try:
        _create_database()
    except Exception as exc:  # noqa: BLE001
        pytest.exit(f"Postgres not reachable at {BASE_URL} ({exc}). Run: docker compose up -d postgres", 2)
    config = Config(os.path.join(os.path.dirname(__file__), "..", "alembic.ini"))
    config.set_main_option("script_location", os.path.join(os.path.dirname(__file__), "..", "alembic"))
    command.upgrade(config, "head")


@pytest.fixture(autouse=True)
def clean_tables():
    yield
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE users, lost_reports, sightings, photos, matches CASCADE"))


@pytest.fixture
def services():
    index = VectorIndex(QdrantClient(":memory:"), "pet_photos", settings.embed_dim)
    index.ensure_collection()
    return Services(storage=FakeStorage(), index=index, ml=FakeML(), notifier=RecordingNotifier())


class RecordingNotifier:
    def __init__(self):
        self.matches = []

    def match_found(self, db, match):
        self.matches.append(str(match.id))


@pytest.fixture
def client(services):
    with TestClient(create_app(load_services=lambda: services)) as c:
        yield c


@pytest.fixture
def work(services):
    """Run the worker until the photo queue is empty."""
    def run():
        while run_once(services):
            pass
    return run


# --- helpers ---

def register(client, name="user") -> dict:
    email = f"{name}-{uuid.uuid4().hex[:8]}@example.com"
    token = client.post("/auth/register", json={"email": email, "password": "password123",
                                                "display_name": name}).json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def image_bytes(color=RED, fmt="JPEG", exif=None) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (64, 48), color).save(buffer, format=fmt, **({"exif": exif} if exif else {}))
    return buffer.getvalue()


def upload(client, auth, path, color=RED) -> dict:
    response = client.post(path, headers=auth, files={"file": ("p.jpg", image_bytes(color), "image/jpeg")})
    assert response.status_code == 201, response.text
    return response.json()


def offset(location, km_north=0.0, km_east=0.0) -> dict:
    return {"lat": location["lat"] + km_north / 111.0,
            "lon": location["lon"] + km_east / (111.0 * np.cos(np.radians(location["lat"])))}


def lost_report(client, auth, location=TUNIS, species="cat", last_seen_at="2026-10-20T10:00:00+01:00",
                color=RED) -> dict:
    report = client.post("/lost-reports", headers=auth, json={
        "name": "Mimi", "species": species, "last_seen": location, "last_seen_at": last_seen_at}).json()
    if color:
        upload(client, auth, f"/lost-reports/{report['id']}/photos", color)
    return report


def sighting(client, auth, location=TUNIS, species="cat", seen_at="2026-10-25T10:00:00+01:00",
             color=RED, **extra) -> dict:
    response = client.post("/sightings", headers=auth, json={
        "species": species, "location": location, "seen_at": seen_at, **extra})
    assert response.status_code == 201, response.text
    item = response.json()
    if color:
        upload(client, auth, f"/sightings/{item['id']}/photos", color)
    return item
