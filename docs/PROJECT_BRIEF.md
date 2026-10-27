# Project Brief — Lost Pet Matcher + Stray Map

> This file is the starting brief for building the project. Read it fully before writing code.
> Work phase by phase, starting with Phase 0. Ask me before making any decision listed under **Open decisions**.

---

## 1. Vision

A mobile app (with a supporting backend) that does two connected things:

1. **Lost & Found matcher** — Owners report a lost pet with photos, last-seen location and time. Anyone who spots a loose animal posts a photo sighting. The system automatically compares every new sighting against nearby open lost reports using image embeddings and notifies the owner of likely matches.
2. **Stray Map** — Community map of street animals: people log strays they see or feed, flag injured animals, and local animal associations coordinate help.

**The key link:** every stray logged on the map also goes through the matcher, because a "stray" may actually be someone's lost pet.

Initial target region: Tunisia (Tunis first). UI languages: French and English (Arabic later).

---

## 2. MVP scope

### In scope (v1)
- Authentication (email/password + JWT). Roles: `USER`, `ASSOCIATION`, `ADMIN`.
- Create a **Lost Report**: 1–5 photos, species (cat/dog/other), name, description, last-seen point, date/time, status (`OPEN`, `FOUND`, `CLOSED`).
- Create a **Sighting / Stray entry**: 1–3 photos, species, GPS point, timestamp, condition (`HEALTHY`, `INJURED`, `NEEDS_HELP`), optional note.
- **Map screen** showing lost reports, sightings and strays, with filters (type, species, date range, condition).
- **Automatic matching** on every new photo upload → creates `Match` records above a similarity threshold → push notification to the lost-report owner.
- Owner can answer a match: "This is my pet" / "Not my pet". Confirmed match → report status `FOUND`.
- In-app messaging between the owner and the finder (no phone numbers exposed).

### Out of scope (later)
- Association dashboards, feeding rotations, sterilization campaign tracking
- Web admin panel, moderation queue UI
- Rewards / bounties, adoption features
- Fine-tuning the vision model

---

## 3. Architecture

```
Flutter app ──► API service ──► PostgreSQL + PostGIS
                    │
                    ├──► Object storage (MinIO) — original images + crops
                    │
                    ├──► ML service (Python/FastAPI)
                    │        detect animal → crop → embed
                    │
                    ├──► Qdrant — image vectors + payload (species, geo, time, ref ids)
                    │
                    └──► Firebase Cloud Messaging — push notifications
```

- **ML service is separate** from the API so it can be scaled, swapped or run on a GPU independently.
- Matching runs **asynchronously** after upload (background job / queue), not inside the HTTP request.
- Everything runs locally with **Docker Compose**.

---

## 4. Tech stack

| Layer | Choice |
|---|---|
| Mobile | Flutter (Dart), `flutter_map` + OpenStreetMap tiles, `image_picker`/`camera`, `geolocator` |
| State management | Riverpod (unless I say otherwise) |
| API service | **Open decision** — FastAPI (Python) by default |
| ML service | Python, FastAPI, PyTorch, Ultralytics YOLO (detection), CLIP or DINOv2 (embeddings) |
| Relational DB | PostgreSQL + PostGIS |
| Vector DB | Qdrant |
| Image storage | MinIO (S3-compatible) |
| Notifications | Firebase Cloud Messaging |
| Infra | Docker Compose, `.env` files for config |

---

## 5. Data model (initial)

- **User** — id, email, password_hash, display_name, role, fcm_token, created_at
- **Pet / LostReport** — id, owner_id, name, species, description, last_seen_point (geography), last_seen_at, status, created_at
- **Sighting** — id, reporter_id, species, point (geography), seen_at, condition, note, is_stray (bool), created_at
- **Photo** — id, owner_type (`LOST_REPORT` | `SIGHTING`), owner_ref_id, storage_key, crop_key, qdrant_point_id, created_at
- **Match** — id, lost_report_id, sighting_id, score, status (`PENDING`, `CONFIRMED`, `REJECTED`), created_at
- **Conversation / Message** — linked to a Match; sender_id, body, created_at

---

## 6. Matching pipeline

1. **Upload** → image saved to MinIO → `Photo` row created → background job queued.
2. **Detect & crop** (ML service): run YOLO, keep the highest-confidence cat/dog box, crop with a small margin. If no animal is detected, mark the photo as unusable and tell the user.
3. **Embed**: run the crop through the embedding model, L2-normalize the vector.
4. **Store** in Qdrant with payload: `species`, `kind` (`lost` | `sighting`), `ref_id`, `location` (geo point), `timestamp`.
5. **Search**:
   - New **sighting** → search `kind=lost`, same species, geo radius (default 10 km), lost within the last 60 days.
   - New **lost report** → search `kind=sighting`, same species, geo radius, sighted after (lost date − 2 days).
   - Use Qdrant payload + geo filters in a single query.
6. **Score**: take the best photo-to-photo cosine similarity per (report, sighting) pair. Above `MATCH_THRESHOLD` (configurable, tune in Phase 0) → create `Match` → notify the owner.
7. **Feedback**: confirmed/rejected matches are kept as labeled data for future threshold tuning or fine-tuning.

All thresholds, radii and time windows go in config, not hard-coded.

---

## 7. Repository structure

```
pet-app/
├── README.md
├── docker-compose.yml
├── .env.example
├── research/              # Phase 0 notebooks + results
├── ml-service/            # FastAPI: /detect, /embed, /health
├── api/                   # main backend
├── mobile/                # Flutter app
└── docs/                  # architecture notes, API spec
```

---

## 8. Development phases

### Phase 0 — Validate matching (do this first)
Goal: prove that embeddings can tell **individual** animals apart, not just breeds.
- Notebook in `research/` using the Oxford-IIIT Pet dataset plus a small set of same-animal photos from different angles (I'll provide some).
- Compare CLIP vs DINOv2, with and without YOLO cropping.
- Metrics: top-1 / top-5 retrieval accuracy for same-individual queries; similarity distribution for same vs different animals → suggest an initial threshold.
- Write a short `research/RESULTS.md` with the recommended model + threshold.

### Phase 1 — ML service
- FastAPI service: `POST /embed` (image → crop + vector), `GET /health`.
- Dockerfile, model loaded once at startup, CPU-friendly by default.
- Qdrant collection setup script with geo + payload indexes.

### Phase 2 — Backend core
- Docker Compose with Postgres/PostGIS, Qdrant, MinIO, ML service, API.
- Auth, Lost Report CRUD, Sighting CRUD, photo upload, map query endpoint (bbox + filters).
- Background matching job + `Match` creation.
- OpenAPI docs, basic tests.

### Phase 3 — Flutter app
- Screens: login/register, map (main), create lost report, create sighting (camera-first with a "get close, show the face" hint), my reports, match detail, chat.
- FCM integration.

### Phase 4 — Close the loop
- Match confirm/reject flow, report status updates, messaging.

### Phase 5 — Stray map layer
- Stray statuses, injured flag highlighting, association accounts, simple moderation (report button + rate limits).

---

## 9. Non-functional rules

- **Location privacy:** never return an owner's exact location publicly. Lost report points are fuzzed to ~300 m on the public map; exact point is stored but only used server-side for matching.
- **No phone numbers or emails** exposed between users.
- **Rate limiting** on report/sighting creation.
- Strip EXIF metadata from images before storing public copies.
- Config via environment variables; never commit secrets.
- Write tests for the matching logic and core endpoints.
- Keep the README updated with how to run everything locally.

---

## 10. Open decisions (ask me before choosing)

1. API service framework: FastAPI vs Spring Boot vs NestJS.
2. Background jobs: simple in-process queue vs Redis + worker (Celery/RQ).
3. Embedding model — decided by Phase 0 results.
4. Hosting target for a demo deployment.

---

## 11. Working style

- Start with **Phase 0** only. Show me the results before moving on.
- Before each phase, give me a short plan; after each phase, summarize what was built and how to run it.
- Prefer simple, readable code over clever abstractions. This is also a portfolio project, so clean structure and a good README matter.
