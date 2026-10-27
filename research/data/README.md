# Research data

Everything under `raw/` is git-ignored. Expected layout:

```
raw/
├── oxford-iiit-pet/images/*.jpg          # https://www.robots.ox.ac.uk/~vgg/data/pets/
├── dogfacenet/<dog_id>/*.jpg             # https://zenodo.org/records/12578449 (CC-BY-4.0), 224px set
├── petfinder/{train,test}.csv, {train,test}_images/   # https://www.kaggle.com/competitions/petfinder-adoption-prediction (research use, no redistribution)
└── petface/{cat,dog}/<animal_id>/*.png   # https://dahlian00.github.io/PetFacePage/ (request via form, research use only)
own/<species>_<name>/*.jpg                # your own same-animal photos, see own/README.md
```

| Dataset | Labels | Role in Phase 0 |
|---|---|---|
| Oxford-IIIT Pet | breed only | distractors, breed-clustering check |
| DogFaceNet | individual dogs (face crops) | top-1/top-5, thresholds |
| PetFinder.my | individual cats + dogs (real phone photos, single-animal listings only) | top-1/top-5, thresholds, closest to app conditions |
| PetFace | individual cats + dogs (face crops) | top-1/top-5, thresholds |
| Own photos | individual animals, real phone photos | realistic sanity check |
