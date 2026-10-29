# Winou

**Winou** is a lost-pet matcher and stray map: a mobile app and backend that match
photos of loose animals against nearby lost-pet reports using image embeddings, plus a
community map of street animals.
Target region: Tunis. See [docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md) for the full brief.

## Status

| Phase | What | Status |
|---|---|---|
| 0 | Validate matching (research) | done, see [RESULTS](research/RESULTS.md) |
| 1 | ML service | done |
| 2 | Backend core | done |
| 3 | Flutter app | done |
| 4 | Close the loop | done |
| 5 | Stray map layer | done |

## Repository layout

```
research/     Phase 0: can embeddings tell individual animals apart?
ml-service/   FastAPI: detect, crop, embed
backend/      Spring Boot API + background matching worker (Java 25)
mobile/       Flutter app (see mobile/README.md to run it on a phone)
deploy/       free demo server: Oracle Cloud + DuckDNS + Caddy (see deploy/README.md)
scripts/      Qdrant setup, demo laptop startup (demo.ps1) and demo data (seed_demo.py), see docs/DEMO.md
docs/         brief, architecture notes, API spec
```

## Running locally (Docker)

```bash
cp .env.example .env
docker compose up --build -d                  # first build downloads ~2 GB (PyTorch + model weights)
```

The backend applies database migrations (Flyway) on start and creates the Qdrant collection
and the storage bucket if missing. The `api` and `worker` services run the same Spring Boot
image; the worker has `WINOU_WORKER_ENABLED=true` and no web server. `python scripts/setup_qdrant.py --smoke` still works to test a
matching query directly against Qdrant.

| Service | URL |
|---|---|
| API (OpenAPI docs) | http://localhost:8080/docs |
| ML service | http://localhost:8000/docs |
| Qdrant dashboard | http://localhost:6333/dashboard |
| MinIO console | http://localhost:9001 (`S3_ACCESS_KEY` / `S3_SECRET_KEY`) |
| Postgres + PostGIS | localhost:5432, user/db `winou` |

Set real `JWT_SECRET` and `LOCATION_FUZZ_SECRET` values in `.env` for anything beyond local
development. `JWT_SECRET` can be rotated (it logs everyone out); `LOCATION_FUZZ_SECRET` must
never change once real reports exist, or old and new public positions together reveal the real one.

**Push notifications** (Firebase Cloud Messaging): put the Firebase service account key at
`secrets/firebase-service-account.json` (Firebase console → Project settings → Service accounts →
Generate new private key). Compose mounts `secrets/` read-only into the api and worker. Without the key,
notifications are only logged. `secrets/` is git-ignored.

## API

Auth is email + password; send the token as `Authorization: Bearer <token>`. In the docs
page, use **Authorize** with your email as the username.

| Endpoint | What it does |
|---|---|
| `POST /auth/register`, `POST /auth/login` | returns an access token (JWT) |
| `GET/PATCH /me` | profile, FCM token |
| `POST /lost-reports`, `GET/PATCH/DELETE /lost-reports/{id}`, `GET /me/lost-reports` | lost pets |
| `POST /sightings`, `GET/PATCH/DELETE /sightings/{id}`, `GET /me/sightings` | loose animals and strays (`is_stray`) |
| `POST /lost-reports/{id}/photos`, `POST /sightings/{id}/photos` | upload one photo (max 5 per report, 3 per sighting) |
| `GET /photos/{id}` | processing status: `PENDING` → `READY`, or `NO_ANIMAL` (retake the photo) |
| `GET /photos/{id}/image`, `/crop` | EXIF-free JPEG, cropped animal (public, cacheable) |
| `GET /map?bbox=min_lon,min_lat,max_lon,max_lat` | public map; filters `type`, `species`, `condition`, `since`, `until` |
| `GET /me/matches` | possible sightings of your lost pets, best first |
| `PATCH /matches/{id}` | `CONFIRMED` ("that's my pet", tells the finder), `REJECTED`, or `PENDING` (undo) |
| `POST /matches/{id}/conversation` | owner only: open the conversation with the finder |
| `GET /conversations`, `GET /conversations/{id}` | your conversations, with unread counts |
| `GET/POST /conversations/{id}/messages` | read (oldest first, `before` to scroll back) or send |
| `PATCH /sightings/{id}/stray-status` | anyone: a stray is `AROUND` (seen again), `HELPED` or `GONE` |
| `POST/GET /me/association-request` | ask to be shown as an association; see where it stands |
| `POST /reports` | report a lost report, sighting or message |
| `GET /admin/association-requests`, `POST .../{id}/approve` or `/reject` | admins: decide requests |
| `GET /admin/hidden`, `POST /admin/hidden/{type}/{id}/restore`, `DELETE /admin/hidden/{type}/{id}` | admins: review hidden content |

**Closing a case** takes two steps. Confirming a match ("that's my pet") tells the finder,
and the search goes on: other sightings still help. Marking the lost report `FOUND` ("I got
my pet back") closes it: no more matching, it leaves the map and the list, and the finders of
confirmed matches get a thank-you. Rejected matches are hidden and never suggested again.
Only the owner can start a conversation, from a match; participants see each other's display
name, never an email. Reopening a report brings its pending matches back.

**Strays, associations and moderation.** Anyone can say what became of a stray. The map shows
strays still around and seen or updated within `STRAY_FADE_DAYS` (30); "still around" keeps one
there. Users ask to be an association in the app; an admin (an account listed in `ADMIN_EMAILS`)
checks the contact they gave and approves it. Associations get a badge and a push when an animal
is reported injured or in need of help within `ASSOCIATION_ALERT_RADIUS_KM` (10) of the place in
their request; strays they mark as helped are credited to them. Content reported by
`HIDE_AFTER_REPORTS` (3) different people is hidden from everyone but its author until an admin
restores or deletes it; a message, which only its recipient can see, once they report it. Hidden
content takes no part in matching.

**How matching runs.** An upload stores the original (private, never served) and an
EXIF-free copy in MinIO, then queues the photo. The `worker` service picks it up, calls
the ML service, indexes the vector in Qdrant and searches the other side with species,
10 km radius and time-window filters (see `MATCH_*` in `.env.example`). The best
photo-to-photo score per (lost report, sighting) pair above the species threshold
becomes a `Match`. The queue is the `photos` table (`FOR UPDATE SKIP LOCKED`), so
several workers can run and failed photos are retried with backoff. Editing a report's
location, date or species re-runs matching with the stored vectors.

**Privacy.** Lost-report positions are moved up to 300 m (fixed per report) for
everyone but the owner. Sighting reporters and user emails are never exposed. Creating
reports, sightings and photos is rate-limited per user.

When a match is found, the lost report's owner gets a push notification (at most
`MATCH_MAX_NOTIFICATIONS` per photo). The app registers its Firebase installation ID through
`PATCH /me` while signed in and clears it on logout; a phone belongs to the last account signed in
on it, and IDs Firebase reports as unregistered are removed.

Errors are `{"detail": "message"}`, or `{"detail": {"code", "message"}}` when the app reacts to
them (`rate_limited`, `email_taken`, `too_many_photos`, `invalid_image`...). Invalid input is
422 with `{"detail": [{"loc", "msg"}]}`.

Without Docker (Java 25; the Maven wrapper downloads Maven):

```bash
docker compose up -d postgres minio qdrant ml-service
cd backend
./mvnw spring-boot:run                                   # the API on :8080
WINOU_WORKER_ENABLED=true ./mvnw spring-boot:run -Dspring-boot.run.arguments=--server.port=8081   # the worker

./mvnw test      # needs Docker: starts throwaway PostGIS and Qdrant containers (Testcontainers)
```

In IntelliJ IDEA, open `backend/` as a Maven project and run `WinouApplication`. Set the
project SDK to Java 25 (IntelliJ can download it).

## ML service

| Endpoint | What it does |
|---|---|
| `GET /health` | model name, device, vector size |
| `POST /detect` | finds the main cat/dog: `{species, confidence, box}` |
| `POST /embed` | detect → crop → DINOv2 embedding (1536-d, L2-normalized). `?return_crop=true` adds the crop as base64 JPEG (EXIF-free, max 1024 px) |
| `POST /convert` | any supported image as an upright, EXIF-free JPEG (`?max_side=`). The backend uses it for HEIC, which Java cannot decode |

Accepts JPEG, PNG, WebP and HEIC (iPhone) up to 10 MB; EXIF rotation is applied.
On CPU (Docker default) an `/embed` call takes about 0.5–1.5 s.

Errors use `{"detail": {"code", "message"}}`: `no_animal_detected` (422), `invalid_image` /
`unsupported_format` (415), `file_too_large` / `image_too_large` (413).

Without Docker, with a GPU:

```bash
cd ml-service
python -m venv .venv && .venv/Scripts/activate
pip install torch==2.11.0 torchvision==0.26.0 --index-url https://download.pytorch.org/whl/cu128
pip install -r requirements-dev.txt
uvicorn app.main:app --port 8000

pytest -m "not models"    # fast API tests, no weights needed
pytest -m models          # real models, incl. parity with the Phase 0 embeddings
```

## Phase 0: running the research

Requires Python 3.11+ and, ideally, an NVIDIA GPU.

```bash
cd research
python -m venv .venv
.venv/Scripts/activate            # Windows; use `source .venv/bin/activate` elsewhere
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu128
pip install -r requirements.txt

# datasets go in research/data/raw/ (see research/data/README.md)
python -m src.embed_all           # detect, crop and embed everything (cached)
jupyter notebook notebooks/phase0_matching.ipynb
pytest tests
```

Results: [research/RESULTS.md](research/RESULTS.md).
