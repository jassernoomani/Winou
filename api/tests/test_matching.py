"""The background matching job end to end: upload → worker → Match rows."""
from conftest import (BLACK, BLUE, NEAR_RED, RED, TUNIS, lost_report, offset, register, sighting, upload)


def matches(client, auth):
    return client.get("/me/matches", headers=auth).json()


def test_sighting_matches_nearby_lost_report(client, services, work):
    owner, finder = register(client, "owner"), register(client, "finder")
    report = lost_report(client, owner)
    found = sighting(client, finder, location=offset(TUNIS, km_north=2), color=NEAR_RED)
    work()

    [match] = matches(client, owner)
    assert match["lost_report_id"] == report["id"] and match["sighting"]["id"] == found["id"]
    assert match["score"] > 0.99 and match["status"] == "PENDING"
    assert match["lost_photo_url"] and match["sighting_photo_url"]
    assert services.notifier.matches == [match["id"]]
    assert matches(client, finder) == []  # matches belong to the lost report's owner

    photo = client.get(f"/sightings/{found['id']}", headers=finder).json()["photos"][0]
    assert photo["status"] == "READY" and photo["detected_species"] == "cat"
    assert client.get(photo["crop_url"]).content == b"crop"


def test_lost_report_matches_earlier_sighting(client, work):
    owner, finder = register(client, "owner"), register(client, "finder")
    sighting(client, finder, seen_at="2026-10-21T08:00:00Z")
    work()
    lost_report(client, owner, last_seen_at="2026-10-20T10:00:00Z")
    work()
    assert len(matches(client, owner)) == 1


def test_no_match_when_filters_exclude(client, work):
    owner, finder = register(client, "owner"), register(client, "finder")
    lost_report(client, owner, last_seen_at="2026-10-20T10:00:00Z")
    sighting(client, finder, color=BLUE)                                   # different animal
    sighting(client, finder, location=offset(TUNIS, km_east=15))           # outside 10 km
    sighting(client, finder, species="dog")                                # other species
    sighting(client, finder, seen_at="2026-10-10T10:00:00Z")               # 10 days before it was lost
    sighting(client, finder, seen_at="2026-01-01T10:00:00Z")               # > 60 days before
    sighting(client, owner)                                                # the owner's own sighting
    work()
    assert matches(client, owner) == []


def test_closed_reports_are_not_matched(client, work):
    owner, finder = register(client, "owner"), register(client, "finder")
    report = lost_report(client, owner)
    client.patch(f"/lost-reports/{report['id']}", headers=owner, json={"status": "FOUND"})
    sighting(client, finder)
    work()
    assert matches(client, owner) == []


def test_best_photo_pair_is_kept_once(client, work):
    owner, finder = register(client, "owner"), register(client, "finder")
    report = lost_report(client, owner, color=NEAR_RED)
    found = sighting(client, finder, color=RED)
    work()
    first = matches(client, owner)[0]["score"]
    upload(client, owner, f"/lost-reports/{report['id']}/photos", RED)  # exact same colour: better
    upload(client, finder, f"/sightings/{found['id']}/photos", BLUE)
    work()
    [match] = matches(client, owner)
    assert match["score"] > first


def test_no_animal_photo(client, services, work):
    auth = register(client)
    report = lost_report(client, auth, color=BLACK)
    work()
    [photo] = client.get(f"/lost-reports/{report['id']}", headers=auth).json()["photos"]
    assert photo["status"] == "NO_ANIMAL" and photo["crop_url"] is None
    assert services.index.client.count("pet_photos").count == 0


def test_other_species_is_skipped(client, services, work):
    auth = register(client)
    report = lost_report(client, auth, species="other")
    work()
    assert client.get(f"/lost-reports/{report['id']}", headers=auth).json()["photos"][0]["status"] == "SKIPPED"
    assert services.ml.calls == 0


def test_moving_a_sighting_rematches_without_re_embedding(client, services, work):
    owner, finder = register(client, "owner"), register(client, "finder")
    lost_report(client, owner)
    found = sighting(client, finder, location=offset(TUNIS, km_east=30))
    work()
    assert matches(client, owner) == []
    calls = services.ml.calls

    client.patch(f"/sightings/{found['id']}", headers=finder, json={"location": offset(TUNIS, km_east=3)})
    work()
    assert len(matches(client, owner)) == 1
    assert services.ml.calls == calls  # vector reused from Qdrant


def test_transient_ml_failure_is_retried(client, services, work):
    auth = register(client)
    report = lost_report(client, auth)
    embed = services.ml.embed

    def down(_):
        raise ConnectionError("ml-service unreachable")

    services.ml.embed = down
    work()
    [photo] = client.get(f"/lost-reports/{report['id']}", headers=auth).json()["photos"]
    assert photo["status"] == "PENDING"  # back in the queue, with a delay

    from sqlalchemy import text
    from app.db import engine
    with engine.begin() as conn:
        conn.execute(text("UPDATE photos SET next_attempt_at = now()"))
    services.ml.embed = embed
    work()
    [photo] = client.get(f"/lost-reports/{report['id']}", headers=auth).json()["photos"]
    assert photo["status"] == "READY"
