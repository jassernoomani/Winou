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
| 2 | Backend core | – |
| 3 | Flutter app | – |
| 4 | Close the loop | – |
| 5 | Stray map layer | – |

## Repository layout

```
research/     Phase 0: can embeddings tell individual animals apart?
ml-service/   FastAPI: detect, crop, embed
api/          main backend
mobile/       Flutter app
scripts/      Qdrant collection setup
docs/         brief, architecture notes, API spec
```

## Running locally (Docker)

```bash
cp .env.example .env
docker compose up --build -d                  # first build downloads ~2 GB (PyTorch + model weights)

pip install -r scripts/requirements.txt
python scripts/setup_qdrant.py --smoke        # create the collection + indexes, test a matching query
```

- ML service: http://localhost:8000/docs
- Qdrant dashboard: http://localhost:6333/dashboard

## ML service

| Endpoint | What it does |
|---|---|
| `GET /health` | model name, device, vector size |
| `POST /detect` | finds the main cat/dog: `{species, confidence, box}` |
| `POST /embed` | detect → crop → DINOv2 embedding (1536-d, L2-normalized). `?return_crop=true` adds the crop as base64 JPEG (EXIF-free, max 1024 px) |

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
