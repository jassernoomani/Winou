"""Auth, CRUD, photos, map, privacy and rate limits."""
import dataclasses
import io
import math

from PIL import Image

from app.geo import fuzz
from conftest import (BLUE, RED, TUNIS, image_bytes, lost_report, offset, register, sighting, upload)


def distance_m(a, b):
    dlat = math.radians(b["lat"] - a["lat"])
    dlon = math.radians(b["lon"] - a["lon"]) * math.cos(math.radians(a["lat"]))
    return 6_371_000 * math.hypot(dlat, dlon)


# --- auth ---

def test_register_login_me(client):
    response = client.post("/auth/register", json={"email": "Sami@Example.com", "password": "password123",
                                                   "display_name": "Sami"})
    assert response.status_code == 201
    login = client.post("/auth/login", data={"username": "sami@example.com", "password": "password123"})
    assert login.status_code == 200
    me = client.get("/me", headers={"Authorization": f"Bearer {login.json()['access_token']}"}).json()
    assert me["email"] == "sami@example.com" and me["role"] == "USER"
    assert "password_hash" not in me


def test_duplicate_email_and_wrong_password(client):
    body = {"email": "a@example.com", "password": "password123", "display_name": "A"}
    assert client.post("/auth/register", json=body).status_code == 201
    assert client.post("/auth/register", json=body).status_code == 409
    assert client.post("/auth/login", data={"username": "a@example.com", "password": "wrong-pass"}).status_code == 401
    assert client.post("/auth/login", data={"username": "nobody@example.com",
                                            "password": "password123"}).status_code == 401


def test_requires_token(client):
    assert client.get("/me").status_code == 401
    assert client.get("/me", headers={"Authorization": "Bearer garbage"}).status_code == 401


def test_update_me(client):
    auth = register(client)
    me = client.patch("/me", headers=auth, json={"display_name": "New", "fcm_token": "tok"}).json()
    assert me["display_name"] == "New"
    assert client.patch("/me", headers=auth, json={"display_name": None, "fcm_token": None}).status_code == 200


# --- lost reports ---

def test_lost_report_location_is_exact_only_for_owner(client):
    owner, other = register(client, "owner"), register(client, "other")
    report = lost_report(client, owner, color=None)
    assert report["last_seen"] == TUNIS and report["location_is_approximate"] is False

    public = client.get(f"/lost-reports/{report['id']}", headers=other).json()
    assert public["location_is_approximate"] is True
    assert 0 < distance_m(TUNIS, public["last_seen"]) <= 300 + 2  # rounding to 5 decimals ≈ 1 m
    # Same position every time, so it can't be averaged out
    assert client.get(f"/lost-reports/{report['id']}", headers=other).json()["last_seen"] == public["last_seen"]


def test_fuzz_stays_within_radius():
    import uuid
    for _ in range(500):
        lat, lon = fuzz(uuid.uuid4(), TUNIS["lat"], TUNIS["lon"], 300, "s")
        assert distance_m(TUNIS, {"lat": lat, "lon": lon}) <= 302


def test_lost_report_validation(client):
    auth = register(client)
    base = {"name": "Rex", "species": "dog", "last_seen": TUNIS}
    assert client.post("/lost-reports", headers=auth, json={
        **base, "last_seen_at": "2099-01-01T00:00:00+00:00"}).status_code == 422   # future
    assert client.post("/lost-reports", headers=auth, json={
        **base, "last_seen_at": "2026-10-20T10:00:00"}).status_code == 422          # no timezone
    assert client.post("/lost-reports", headers=auth, json={
        **base, "last_seen": {"lat": 91, "lon": 0}, "last_seen_at": "2026-10-20T10:00:00Z"}).status_code == 422


def test_list_open_reports_newest_first(client):
    owner, viewer = register(client, "owner"), register(client, "viewer")
    older = lost_report(client, owner, color=None, last_seen_at="2026-10-20T10:00:00Z")
    newer = lost_report(client, owner, species="dog", color=None, last_seen_at="2026-10-22T10:00:00Z")
    found = lost_report(client, owner, color=None)
    client.patch(f"/lost-reports/{found['id']}", headers=owner, json={"status": "FOUND"})
    lost_report(client, owner, location={"lat": 34.74, "lon": 10.76}, color=None,  # Sfax, ~230 km away
                last_seen_at="2026-10-21T10:00:00Z")

    def ids(**params):
        return [r["id"] for r in client.get("/lost-reports", headers=viewer, params=params).json()]

    assert len(ids()) == 3 and ids()[0] == newer["id"]  # found ones are not listed
    assert ids(lat=TUNIS["lat"], lon=TUNIS["lon"]) == [newer["id"], older["id"]]
    assert ids(species="cat", lat=TUNIS["lat"], lon=TUNIS["lon"]) == [older["id"]]
    assert ids(limit=1, offset=1, lat=TUNIS["lat"], lon=TUNIS["lon"]) == [older["id"]]
    listed = client.get("/lost-reports", headers=viewer, params={"limit": 1}).json()[0]
    assert listed["location_is_approximate"] is True and listed["last_seen"] != TUNIS
    assert client.get("/lost-reports", headers=viewer, params={"lat": 36.8}).status_code == 422


def test_list_radius_uses_the_shown_position(client):
    owner, viewer = register(client, "owner"), register(client, "viewer")
    report = lost_report(client, owner, color=None)
    shown = client.get(f"/lost-reports/{report['id']}", headers=viewer).json()["last_seen"]
    # A tiny circle around the real point misses it unless the fuzz happens to land inside
    near_shown = client.get("/lost-reports", headers=viewer,
                            params={**shown, "radius_km": 0.01}).json()
    assert [r["id"] for r in near_shown] == [report["id"]]
    near_real = client.get("/lost-reports", headers=viewer, params={**TUNIS, "radius_km": 0.01}).json()
    assert near_real == [] or distance_m(TUNIS, shown) <= 10
    near_real_owner = client.get("/lost-reports", headers=owner, params={**TUNIS, "radius_km": 0.01}).json()
    assert [r["id"] for r in near_real_owner] == [report["id"]]


def test_only_owner_can_edit_or_delete(client):
    owner, other = register(client, "owner"), register(client, "other")
    report = lost_report(client, owner, color=None)
    assert client.patch(f"/lost-reports/{report['id']}", headers=other, json={"name": "X"}).status_code == 403
    assert client.delete(f"/lost-reports/{report['id']}", headers=other).status_code == 403
    assert client.patch(f"/lost-reports/{report['id']}", headers=owner,
                        json={"name": "Minou", "status": "FOUND"}).json()["status"] == "FOUND"
    assert client.delete(f"/lost-reports/{report['id']}", headers=owner).status_code == 204
    assert client.get(f"/lost-reports/{report['id']}", headers=owner).status_code == 404


# --- photos ---

def test_upload_strips_exif_but_keeps_original(client, services):
    auth = register(client)
    exif = Image.Exif()
    exif[0x8825] = {2: (36.0, 48.0, 23.4)}  # GPSInfo: latitude
    exif[0x010F] = "PhoneMaker"
    report = lost_report(client, auth, color=None)
    photo = client.post(f"/lost-reports/{report['id']}/photos", headers=auth,
                        files={"file": ("p.jpg", image_bytes(RED, exif=exif.tobytes()), "image/jpeg")}).json()
    assert photo["status"] == "PENDING"

    served = client.get(photo["url"])
    assert served.status_code == 200 and served.headers["content-type"] == "image/jpeg"
    assert not Image.open(io.BytesIO(served.content)).getexif()
    original = services.storage.get(f"originals/{photo['id']}.jpg")
    assert Image.open(io.BytesIO(original)).getexif()  # kept privately, never served


def test_upload_rejects_bad_files_and_limits_count(client):
    auth = register(client)
    report = lost_report(client, auth, color=None)
    path = f"/lost-reports/{report['id']}/photos"
    bad = client.post(path, headers=auth, files={"file": ("p.jpg", b"not an image", "image/jpeg")})
    assert bad.status_code == 415 and bad.json()["detail"]["code"] == "invalid_image"
    for _ in range(5):
        upload(client, auth, path)
    too_many = client.post(path, headers=auth, files={"file": ("p.jpg", image_bytes(), "image/jpeg")})
    assert too_many.status_code == 409


def test_cannot_upload_to_someone_elses_report(client):
    owner, other = register(client, "owner"), register(client, "other")
    report = lost_report(client, owner, color=None)
    response = client.post(f"/lost-reports/{report['id']}/photos", headers=other,
                           files={"file": ("p.jpg", image_bytes(), "image/jpeg")})
    assert response.status_code == 403


def test_delete_report_removes_files_and_vectors(client, services, work):
    auth = register(client)
    report = lost_report(client, auth)
    work()
    assert services.index.client.count("pet_photos").count == 1
    assert services.storage.objects
    client.delete(f"/lost-reports/{report['id']}", headers=auth)
    assert services.index.client.count("pet_photos").count == 0
    assert services.storage.objects == {}


# --- map ---

def test_map_filters(client):
    auth = register(client)
    lost_report(client, auth, color=None)
    sighting(client, auth, color=None, condition="INJURED")
    sighting(client, auth, species="dog", color=None, is_stray=True)
    sighting(client, auth, location={"lat": 34.74, "lon": 10.76}, color=None)  # Sfax, outside the box
    closed = lost_report(client, auth, color=None)
    client.patch(f"/lost-reports/{closed['id']}", headers=auth, json={"status": "CLOSED"})

    bbox = "10.05,36.75,10.30,36.90"
    everything = client.get("/map", params={"bbox": bbox}).json()  # public: no token
    assert sorted(i["type"] for i in everything["items"]) == ["lost", "sighting", "stray"]
    lost = next(i for i in everything["items"] if i["type"] == "lost")
    assert lost["location"] != TUNIS  # fuzzed

    def types(**params):
        return sorted(i["type"] for i in client.get("/map", params={"bbox": bbox, **params}).json()["items"])

    assert types(type="stray") == ["stray"]
    assert types(species="dog") == ["stray"]
    assert types(condition="INJURED") == ["sighting"]
    assert types(since="2026-10-24T00:00:00Z") == ["sighting", "stray"]
    assert client.get("/map", params={"bbox": "10.3,36.9,10.0,36.7"}).status_code == 422


def test_map_truncates(client, monkeypatch):
    import app.routers.map as map_router
    monkeypatch.setattr(map_router, "settings", dataclasses.replace(map_router.settings, map_max_results=2))
    auth = register(client)
    for _ in range(3):
        sighting(client, auth, color=None)
    body = client.get("/map", params={"bbox": "10.05,36.75,10.30,36.90"}).json()
    assert len(body["items"]) == 2 and body["truncated"] is True


# --- rate limits ---

def test_sighting_rate_limit(client, monkeypatch):
    import app.routers.sightings as sightings_router
    monkeypatch.setattr(sightings_router, "settings",
                        dataclasses.replace(sightings_router.settings, rate_limit_sightings_per_hour=2))
    auth = register(client)
    sighting(client, auth, color=None)
    sighting(client, auth, color=None)
    response = client.post("/sightings", headers=auth, json={
        "species": "cat", "location": offset(TUNIS, 1), "seen_at": "2026-10-25T10:00:00Z"})
    assert response.status_code == 429
    assert sighting(client, register(client, "someone-else"), color=None)  # per user


def test_sighting_is_public_but_reporter_is_hidden(client):
    reporter, viewer = register(client, "reporter"), register(client, "viewer")
    item = sighting(client, reporter, color=BLUE)
    seen = client.get(f"/sightings/{item['id']}", headers=viewer).json()
    assert seen["location"] == TUNIS and seen["mine"] is False
    assert "reporter_id" not in seen
    assert client.get("/me/sightings", headers=reporter).json()[0]["mine"] is True


def test_photo_status_is_private(client):
    owner, other = register(client, "owner"), register(client, "other")
    report = lost_report(client, owner, color=None)
    photo = upload(client, owner, f"/lost-reports/{report['id']}/photos", RED)
    assert client.get(f"/photos/{photo['id']}", headers=owner).status_code == 200
    assert client.get(f"/photos/{photo['id']}", headers=other).status_code == 403


def test_photo_source_is_stored_but_not_exposed(client):
    from sqlalchemy import text
    from app.db import engine

    auth = register(client)
    item = sighting(client, auth, color=None)
    response = client.post(f"/sightings/{item['id']}/photos", headers=auth, data={"source": "GALLERY"},
                           files={"file": ("p.jpg", image_bytes(), "image/jpeg")})
    assert response.status_code == 201 and "source" not in response.json()
    upload(client, auth, f"/sightings/{item['id']}/photos")  # older clients: no source
    with engine.connect() as conn:
        assert sorted(conn.scalars(text("SELECT coalesce(source, '-') FROM photos")).all()) == ["-", "GALLERY"]
    bad = client.post(f"/sightings/{item['id']}/photos", headers=auth, data={"source": "INTERNET"},
                      files={"file": ("p.jpg", image_bytes(), "image/jpeg")})
    assert bad.status_code == 422
