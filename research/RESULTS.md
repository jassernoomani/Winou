# Phase 0 results: can embeddings tell individual animals apart?

**Short answer: yes, well enough to build on, with DINOv2. Dogs work well, cats are harder.**
In a realistic setting (a new photo compared with ~200 nearby lost reports) the right
animal is ranked first for 87% of dogs and 73% of cats, and is in the top 3 for 93% / 83%.

## Recommendation

| Decision | Choice |
|---|---|
| Embedding model | **DINOv2 ViT-B/14** (`facebook/dinov2-base`), CLS token + mean patch token, 1536-d, L2-normalized |
| Cropping | **YOLO crop** (`yolo11s`, highest-confidence cat/dog box, 10% margin); reject photos with no detection |
| Threshold | **per species**: `MATCH_THRESHOLD_DOG=0.60`, `MATCH_THRESHOLD_CAT=0.70` (≈1% false-positive rate per photo pair) |
| Notifications | at most the top 3 matches per new photo, ranked by score |

CLIP ViT-B/16 was clearly worse on every dataset and is not recommended.

## Data

| Dataset | Images | Individuals | Notes |
|---|---|---|---|
| Oxford-IIIT Pet | 7,390 | none (breed labels) | used as same-species distractors in every search |
| DogFaceNet | 8,363 | 1,393 dogs | tight face crops, easy conditions |
| PetFinder.my | 48,542 | 4,894 cats, 5,961 dogs | real phone photos of shelter animals, single-animal listings only |
| Own photos | 5 | 1 cat | white cat, different rooms, lighting and image quality |
| PetFace | – | – | access requested, not yet received |

## Results

### Model comparison (each query ranked against its dataset + all same-species Oxford images)

| Dataset | Model | Crop | Top-1 | Top-5 | AUC |
|---|---|---|---|---|---|
| DogFaceNet | CLIP B/16 | full | 0.614 | 0.760 | 0.917 |
| DogFaceNet | DINOv2 B/14 | crop | **0.911** | **0.967** | **0.995** |
| PetFinder | CLIP B/16 | full | 0.493 | 0.622 | 0.847 |
| PetFinder | DINOv2 B/14 | full | **0.627** | **0.750** | **0.935** |
| PetFinder | DINOv2 B/14 | crop | 0.583 | 0.709 | 0.923 |
| Own cat | DINOv2 B/14 | crop | 1.000 | 1.000 | 0.999 |

Full tables: `outputs/retrieval_results.csv`, `outputs/thresholds.csv`.

CLIP puts same-animal and different-animal pairs in an overlapping 0.7–1.0 band; DINOv2
separates them (different animals ≈ 0.1–0.3, same animal ≈ 0.6–0.9). See
`outputs/similarity_dogfacenet.png`.

### PetFinder by species (DINOv2, 1,000s of distractors)

| Species | Crop | Top-1 | Top-5 | AUC | Threshold @ 1% FPR | Recall @ threshold |
|---|---|---|---|---|---|---|
| Cat | crop | 0.498 | 0.628 | 0.895 | 0.709 | 0.40 |
| Dog | crop | 0.660 | 0.782 | 0.944 | 0.593 | 0.60 |

### Realistic candidate pools (DINOv2, crop)

The app only compares a sighting with lost reports inside the geo radius and time window.
Simulated with pools of 50 and 200 animals, each report scored by its best photo:

| Species | Pool 50: #1 | Pool 50: top 3 | Pool 200: #1 | Pool 200: top 3 |
|---|---|---|---|---|
| Cat | 82.7% | 92.2% | 72.9% | 82.8% |
| Dog | 92.1% | 96.4% | 86.7% | 93.4% |

This is the number that matters for the product: the geo/time filter turns a hard
search into a manageable one.

## Findings

1. **DINOv2 beats CLIP everywhere.** CLIP is trained to match images to captions, so it
   encodes "an orange kitten on a bed" rather than *this* kitten.
2. **Cats are harder than dogs** and need a stricter threshold (0.70 vs 0.60). Failures
   are mostly genuine look-alikes (orange kittens, black kittens, tuxedo cats) or big pose
   changes (lying on its back vs face close-up). Many of them are hard for a human too.
3. **Full images score higher than crops on PetFinder, but we still recommend cropping.**
   Shelter photos of one animal are usually taken in the same room, so the full-image
   score partly rewards matching backgrounds. In the app, the owner's photos (home) and the
   sighting (street) never share a background, so the crop numbers are the honest estimate.
   Cropping also gives a free quality gate: no detection → ask for another photo.
4. **The model groups strongly by breed** (95% of Oxford nearest neighbours share the
   breed) yet still separates individuals; same-breed look-alikes are the main risk.
5. **Photo quality matters.** Extreme close-ups (own cat, nose and one eye only) score
   0.46–0.72 against normal photos. The camera hint should ask for the whole head, from
   about one metre, not "as close as possible".
6. **YOLO detection is reliable:** an animal was found in 97–98% of real photos, with the
   right species ~93% of the time. Species from the detector can pre-fill the form.

## Limitations

- **Thresholds are per photo pair.** The app scores a report by its best photo, which
  raises both true and false match scores; tune with real confirm/reject feedback
  (pipeline step 7).
- **PetFinder is Malaysian shelter animals,** but they are mostly domestic short-haired
  mixes, much like street animals in Tunis.
- **Own photos: one cat.** Encouraging (it handles a lighting/location change at 0.85), but
  not statistically meaningful. More animals, especially local strays, would help.
- **Near-duplicate photos** (taken seconds apart) inflate scores slightly; only ~1% of
  same-animal DINOv2 pairs score above 0.95, so the effect is small.
- **No ageing:** a kitten lost for months changes appearance; not tested.

## Possible next experiments (not needed for Phase 1)

- DINOv2 ViT-L/14: likely better, but slower and ~4× more memory (the RTX 4060 desktop helps).
- A face/head detector instead of a whole-body box, especially for cats.
- Fine-tuning on PetFinder identities (out of scope for v1 per the brief; the confirm/reject
  feedback the app collects is exactly the data this would need).
- Re-run on PetFace once access is granted.

## Reproduce

```bash
cd research
python -m src.embed_all                       # ~1.5 h on an RTX 3050 Ti for all datasets
python notebooks/build_notebook.py
jupyter nbconvert --to notebook --execute --inplace notebooks/phase0_matching.ipynb
```
