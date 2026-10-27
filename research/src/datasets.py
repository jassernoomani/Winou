"""Dataset loaders.

Every loader returns a DataFrame with one row per image:
    path      absolute image path
    source    dataset name
    species   "cat" | "dog"
    breed     breed name, or None when unknown
    identity  id of the individual animal, or None when unknown (distractor)
"""
from pathlib import Path

import pandas as pd

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
COLUMNS = ["path", "source", "species", "breed", "identity"]


def _images_in(folder: Path) -> list[Path]:
    return sorted(p for p in folder.iterdir() if p.suffix.lower() in IMAGE_EXTS)


def load_oxford_pets(root: Path) -> pd.DataFrame:
    """Oxford-IIIT Pet: breed labels only, so every image is a distractor.

    Breed is encoded in the filename ("Bengal_12.jpg"); cat breeds start
    with an uppercase letter, dog breeds with a lowercase one.
    """
    rows = []
    for path in _images_in(root / "images"):
        breed = path.stem.rsplit("_", 1)[0]
        species = "cat" if breed[0].isupper() else "dog"
        rows.append((str(path), "oxford", species, breed.lower(), None))
    return pd.DataFrame(rows, columns=COLUMNS)


def load_identity_folders(root: Path, source: str, species: str | None = None) -> pd.DataFrame:
    """Generic loader for `<root>/<identity>/<image>` layouts.

    Used for DogFaceNet, PetFace and our own photos. When `species` is None
    it is read from an identity prefix like "cat_mimi".
    """
    rows = []
    for folder in sorted(p for p in root.iterdir() if p.is_dir()):
        sp = species or folder.name.split("_", 1)[0].lower()
        if sp not in ("cat", "dog"):
            continue
        for path in _images_in(folder):
            rows.append((str(path), source, sp, None, f"{source}/{folder.name}"))
    return pd.DataFrame(rows, columns=COLUMNS)


def load_petfinder(root: Path) -> pd.DataFrame:
    """PetFinder.my adoption listings: photos are named `<PetID>-<n>.jpg`.

    Only single-animal listings (Quantity == 1) are kept; litters would mix
    several individuals under one PetID.
    """
    rows = []
    for split in ("train", "test"):
        csv = root / f"{split}.csv"
        if not csv.exists():
            csv = root / split / f"{split}.csv"
        if not csv.exists():
            continue
        listings = pd.read_csv(csv, usecols=["PetID", "Type", "Quantity"])
        single = listings[listings["Quantity"] == 1].set_index("PetID")["Type"]
        for path in _images_in(root / f"{split}_images"):
            pet_id = path.stem.rsplit("-", 1)[0]
            if pet_id in single.index:
                species = "dog" if single[pet_id] == 1 else "cat"
                rows.append((str(path), "petfinder", species, None, f"petfinder/{pet_id}"))
    return pd.DataFrame(rows, columns=COLUMNS)


def keep_identities_with_min_images(df: pd.DataFrame, n: int = 2) -> pd.DataFrame:
    """Drop identities that have fewer than `n` images (they can't be queried)."""
    counts = df.groupby("identity")["path"].transform("count")
    return df[df["identity"].isna() | (counts >= n)].reset_index(drop=True)
