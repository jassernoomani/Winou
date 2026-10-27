# Pet App: Lost Pet Matcher + Stray Map

A mobile app and backend that match photos of loose animals against nearby lost-pet
reports using image embeddings, plus a community map of street animals.
Target region: Tunis. See [docs/PROJECT_BRIEF.md](docs/PROJECT_BRIEF.md) for the full brief.

## Status

| Phase | What | Status |
|---|---|---|
| 0 | Validate matching (research) | done, see [RESULTS](research/RESULTS.md) |
| 1 | ML service | – |
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
docs/         brief, architecture notes, API spec
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
