"""Demo data for showing Winou, and a live match on demand. Standard library only.

    python scripts/seed_demo.py seed --me you@example.com --password ...   # once, before demos
    python scripts/seed_demo.py sighting                                    # live: a neighbour sees your cat
    python scripts/seed_demo.py reply                                       # live: the neighbour answers you

seed:      fills Tunis with lost pets, sightings and strays (some injured, one helped by an
           association) from neighbour accounts, and reports *your* cat lost from your account,
           with three photos from research/data/own/cat_*/.
sighting:  a neighbour posts a sighting near your lost cat with another photo of it. The real
           pipeline (YOLO crop, DINOv2, Qdrant) matches it and your phone gets the push.
reply:     the neighbour answers the latest message you sent them.

Photos come from research/data (never committed): your own cat, and the Oxford-IIIT Pet dataset.
Needs the stack running (scripts/demo.ps1) and your account created in the app.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "research" / "data"
OXFORD = DATA / "raw" / "oxford-iiit-pet" / "images"
NEIGHBOUR_PASSWORD = "winou-demo-2026"
LIVE_FINDER = "karim"

# Tunis neighbourhoods (lat, lon)
PLACES = {
    "La Marsa": (36.8782, 10.3247), "Carthage": (36.8528, 10.3233), "Sidi Bou Said": (36.8708, 10.3417),
    "La Goulette": (36.8183, 10.3050), "Lac 2": (36.8467, 10.2700), "El Menzah": (36.8370, 10.1730),
    "Ariana": (36.8665, 10.1647), "Le Bardo": (36.8090, 10.1340), "Centre-ville": (36.8008, 10.1800),
}

NEIGHBOURS = {"amira": "Amira", "sami": "Sami", "leila": "Leila", "youssef": "Youssef", LIVE_FINDER: "Karim",
              "refuge": "Refuge de Tunis"}

# (owner, name, species, breed photo, place, days ago, description)
LOST = [
    ("amira", "Rocky", "dog", "beagle", "Carthage", 2, "Beagle, red collar, very friendly. Answers to Rocky."),
    ("sami", "Félix", "cat", "Bengal", "Lac 2", 1, "Spotted Bengal, shy, chipped. Never goes outside."),
    ("leila", "Neige", "cat", "Persian", "El Menzah", 4, "White Persian, blue eyes, needs her medicine."),
    ("youssef", "Simba", "dog", "shiba_inu", "Ariana", 3, "Shiba Inu, curly tail, scared of motorbikes."),
    ("amira", "Choco", "dog", "pug", "La Goulette", 6, "Small pug, black face, snores a lot."),
]

# (reporter, species, breed photo, place, hours ago, condition, stray, stray status, note)
SIGHTINGS = [
    ("sami", "dog", "basset_hound", "Centre-ville", 5, "HEALTHY", False, None, "Following people near the market"),
    ("leila", "cat", "Egyptian_Mau", "Sidi Bou Said", 20, "HEALTHY", True, None, "Lives near the café, gets fed"),
    ("youssef", "dog", "german_shorthaired", "Le Bardo", 3, "INJURED", True, None, "Limping, front left paw"),
    ("amira", "cat", "Bombay", "La Marsa", 30, "NEEDS_HELP", True, None, "Very thin, hiding under cars"),
    ("sami", "dog", "staffordshire_bull_terrier", "Lac 2", 48, "HEALTHY", True, "HELPED", "Taken in by the refuge"),
    ("leila", "cat", "British_Shorthair", "Carthage", 8, "HEALTHY", False, None, "Wearing a blue collar"),
    ("youssef", "cat", "Siamese", "Ariana", 12, "HEALTHY", True, None, "Friendly, a family of three cats"),
]


# --- HTTP ---

class Api:
    def __init__(self, base: str, token: str | None = None):
        self.base = base.rstrip("/")
        self.token = token

    def call(self, method: str, path: str, body=None, form=None, files=None, ok=(200, 201, 204)):
        headers = {"Authorization": f"Bearer {self.token}"} if self.token else {}
        data = None
        if files:
            boundary = uuid.uuid4().hex
            parts = []
            for name, (filename, content) in files.items():
                parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
                             f"Content-Type: image/jpeg\r\n\r\n".encode() + content + b"\r\n")
            data = b"".join(parts) + f"--{boundary}--\r\n".encode()
            headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        elif form is not None:
            data = urllib.parse.urlencode(form).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                text = response.read().decode()
                status = response.status
        except urllib.error.HTTPError as e:
            text, status = e.read().decode(), e.code
        if status not in ok:
            raise RuntimeError(f"{method} {path} -> {status}: {text[:300]}")
        return json.loads(text) if text else None


def login(base: str, email: str, password: str) -> Api:
    token = Api(base).call("POST", "/auth/login", form={"username": email, "password": password})["access_token"]
    return Api(base, token)


def neighbour(base: str, key: str) -> Api:
    """Signs in a demo neighbour, creating the account the first time."""
    email = f"{key}@demo.winou"
    try:
        return login(base, email, NEIGHBOUR_PASSWORD)
    except RuntimeError:
        token = Api(base).call("POST", "/auth/register", {
            "email": email, "password": NEIGHBOUR_PASSWORD, "display_name": NEIGHBOURS[key]})["access_token"]
        return Api(base, token)


# --- data ---

def ago(**kw) -> str:
    return (datetime.now(timezone.utc) - timedelta(**kw)).isoformat()


def near(place: str, metres_north: float = 0, metres_east: float = 0) -> dict:
    lat, lon = PLACES[place]
    return {"lat": lat + metres_north / 111_000, "lon": lon + metres_east / 89_500}


def oxford(breed: str) -> Path:
    photos = sorted(OXFORD.glob(f"{breed}_*.jpg"), key=lambda p: int(p.stem.rsplit("_", 1)[1]))
    if not photos:
        sys.exit(f"No Oxford-IIIT Pet photos for {breed} in {OXFORD}")
    return photos[min(9, len(photos) - 1)]  # not the first: a varied set


def own_cat() -> list[Path]:
    folders = sorted(p for p in (DATA / "own").glob("cat_*") if p.is_dir())
    if not folders:
        sys.exit(f"Put photos of your cat in {DATA / 'own'}/cat_<name>/ (see its README)")
    photos = sorted(p for p in folders[0].iterdir() if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".heic"))
    if len(photos) < 4:
        sys.exit(f"{folders[0]} needs at least 4 photos: 3 for the report, 1+ for live sightings")
    return photos


def upload(api: Api, owner_path: str, photo: Path) -> dict:
    return api.call("POST", f"{owner_path}/photos?source=CAMERA", files={"file": (photo.name, photo.read_bytes())})


def wait_for(api: Api, photo_ids: list[str], timeout_s: int = 300) -> list[dict]:
    deadline = time.time() + timeout_s
    while True:
        photos = [api.call("GET", f"/photos/{pid}") for pid in photo_ids]
        if all(p["status"] not in ("PENDING", "PROCESSING") for p in photos) or time.time() > deadline:
            return photos
        time.sleep(2)


def sql(statement: str) -> None:
    docker = shutil.which("docker") or str(Path(os.environ.get("LOCALAPPDATA", "")) /
                                          "Programs/DockerDesktop/resources/bin/docker.exe")
    subprocess.run([docker, "compose", "exec", "-T", "postgres", "psql", "-U", "winou", "-d", "winou",
                    "-v", "ON_ERROR_STOP=1", "-q", "-c", statement], cwd=ROOT, check=True)


# --- commands ---

def seed(args) -> None:
    me = login(args.api, args.me, args.password)
    print(f"Signed in as {args.me}")

    already = neighbour(args.api, "amira").call("GET", "/me/lost-reports")
    if already:
        print("Neighbours already have data: skipping them (delete the *@demo.winou accounts to start over)")
    else:
        photos = []
        for owner, name, species, breed, place, days, description in LOST:
            api = neighbour(args.api, owner)
            report = api.call("POST", "/lost-reports", {
                "name": name, "species": species, "description": description,
                "last_seen": near(place), "last_seen_at": ago(days=days, hours=3)})
            photos.append((api, upload(api, f"/lost-reports/{report['id']}", oxford(breed))["id"]))
            print(f"  lost: {name} ({place})")
        helped = []
        for reporter, species, breed, place, hours, condition, stray, status, note in SIGHTINGS:
            api = neighbour(args.api, reporter)
            sighting = api.call("POST", "/sightings", {
                "species": species, "location": near(place, 150, -120), "seen_at": ago(hours=hours),
                "condition": condition, "is_stray": stray, "note": note})
            photos.append((api, upload(api, f"/sightings/{sighting['id']}", oxford(breed))["id"]))
            if status:
                helped.append(sighting["id"])
            print(f"  {'stray' if stray else 'sighting'}: {species} in {place} ({condition.lower()})")

        # The association: request through the API, approved straight in the database (no admin needed)
        refuge = neighbour(args.api, "refuge")
        refuge.call("POST", "/me/association-request", {
            "organisation": "Refuge de Tunis", "city": "Tunis", "contact": "+216 20 000 000",
            "note": "Demo association", "location": near("Lac 2")})
        sql("""UPDATE association_requests SET status = 'APPROVED', decided_at = now() WHERE status = 'PENDING'
                 AND user_id = (SELECT id FROM users WHERE email = 'refuge@demo.winou');
               UPDATE users u SET role = 'ASSOCIATION', association_name = r.organisation, alert_point = r.point
                 FROM association_requests r WHERE r.user_id = u.id AND u.email = 'refuge@demo.winou'""")
        for sighting_id in helped:
            refuge.call("PATCH", f"/sightings/{sighting_id}/stray-status", {"status": "HELPED"})
        print("  association: Refuge de Tunis (verified), credited for a helped stray")

        print("Waiting for the matcher to process the photos...")
        for api, pid in photos:
            wait_for(api, [pid])

    # Your cat, lost from your account
    cat = own_cat()
    mine = [r for r in me.call("GET", "/me/lost-reports") if r["status"] == "OPEN" and r["name"] == args.pet_name]
    if mine:
        print(f"You already have {args.pet_name} reported lost: kept as is")
        return
    report = me.call("POST", "/lost-reports", {
        "name": args.pet_name, "species": "cat", "last_seen": near("La Marsa"), "last_seen_at": ago(days=1),
        "description": "Tabby cat, very shy, answers to her name. Please call if you see her!"})
    ids = [upload(me, f"/lost-reports/{report['id']}", p)["id"] for p in cat[:3]]
    statuses = [p["status"] for p in wait_for(me, ids)]
    print(f"Reported {args.pet_name} lost from your account with 3 photos: {statuses}")
    print("Live demo: python scripts/seed_demo.py sighting")


def live_sighting(args) -> None:
    karim = neighbour(args.api, LIVE_FINDER)
    target = next((r for r in Api(args.api, karim.token).call("GET", "/lost-reports?limit=50")
                   if r["species"] == "cat" and r["name"] == args.pet_name), None)
    if target is None:
        sys.exit(f"No open lost report named {args.pet_name}: run 'seed' first")
    cat = own_cat()
    used = len(karim.call("GET", "/me/sightings"))
    photo = cat[3 + used % (len(cat) - 3)]  # a photo the report doesn't have
    where = target["last_seen"]
    sighting = karim.call("POST", "/sightings", {
        "species": "cat", "seen_at": ago(minutes=10), "condition": "HEALTHY", "is_stray": False,
        "location": {"lat": where["lat"] + 0.004, "lon": where["lon"] + 0.003},
        "note": "Sleeping under a blue car next to the bakery"})
    pid = upload(karim, f"/sightings/{sighting['id']}", photo)["id"]
    print(f"Karim saw a cat 500 m away and posted {photo.name}. Matching...")
    status = wait_for(karim, [pid])[0]["status"]
    print(f"Photo {status}. If it matched, the owner's phone just got 'Possible match'.")


def reply(args) -> None:
    karim = neighbour(args.api, LIVE_FINDER)
    conversations = karim.call("GET", "/conversations")
    if not conversations:
        sys.exit("No conversation yet: on the phone, open the match and tap 'Message the finder'")
    conversation = conversations[0]
    karim.call("POST", f"/conversations/{conversation['id']}/messages",
               {"body": args.text or f"Yes! I think it's {conversation['pet_name']}. She's still under the blue "
                                     "car by the bakery, I'm keeping an eye on her."})
    print(f"Karim answered in the conversation about {conversation['pet_name']}.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--api", default="http://localhost:8080")
    parser.add_argument("--pet-name", default="Luna", help="your lost cat's name (default Luna)")
    sub = parser.add_subparsers(dest="command", required=True)
    s = sub.add_parser("seed", help="demo data and your lost cat")
    s.add_argument("--me", required=True, help="your account's email (create it in the app first)")
    s.add_argument("--password", required=True)
    sub.add_parser("sighting", help="live: a neighbour sees your cat")
    r = sub.add_parser("reply", help="live: the neighbour answers you")
    r.add_argument("--text")
    args = parser.parse_args()
    {"seed": seed, "sighting": live_sighting, "reply": reply}[args.command](args)


if __name__ == "__main__":
    main()
