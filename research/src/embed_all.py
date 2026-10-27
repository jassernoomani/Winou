"""Compute and cache embeddings for every dataset x model x crop setting.

Usage (from research/):
    python -m src.embed_all                    # all available datasets
    python -m src.embed_all --datasets own     # only re-embed own photos

Outputs, under outputs/embeddings/:
    <dataset>_index.csv                image list + YOLO detection per image
    <dataset>_<model>_<crop>.npy       embeddings, rows aligned with the index
"""
import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image, ImageOps
from tqdm import tqdm

from src.cropper import AnimalCropper, Detection
from src.datasets import (keep_identities_with_min_images, load_identity_folders, load_oxford_pets,
                          load_petfinder)
from src.embedders import EMBEDDERS

RESEARCH = Path(__file__).resolve().parents[1]
RAW = RESEARCH / "data" / "raw"
OUT = RESEARCH / "outputs" / "embeddings"

DATASETS = {
    "oxford": lambda: load_oxford_pets(RAW / "oxford-iiit-pet"),
    "dogfacenet": lambda: load_identity_folders(RAW / "dogfacenet", "dogfacenet", species="dog"),
    "petface_cat": lambda: load_identity_folders(RAW / "petface" / "cat", "petface", species="cat"),
    "petface_dog": lambda: load_identity_folders(RAW / "petface" / "dog", "petface", species="dog"),
    "petfinder": lambda: load_petfinder(RAW / "petfinder"),
    "own": lambda: load_identity_folders(RESEARCH / "data" / "own", "own"),
}


def open_image(path: str) -> Image.Image:
    # exif_transpose applies phone rotation metadata so crops line up
    return ImageOps.exif_transpose(Image.open(path)).convert("RGB")


def detect_all(df: pd.DataFrame, cropper: AnimalCropper) -> pd.DataFrame:
    boxes = []
    for path in tqdm(df["path"], desc="detect"):
        det = cropper.detect(open_image(path))
        boxes.append((det.species, det.confidence, *det.box) if det else (None, None, *[None] * 4))
    det = pd.DataFrame(boxes, columns=["det_species", "det_conf", "x1", "y1", "x2", "y2"])
    return pd.concat([df.reset_index(drop=True), det], axis=1)


def load_for_embedding(row, crop: bool, cropper: AnimalCropper) -> Image.Image:
    image = open_image(row.path)
    if crop and pd.notna(row.det_conf):
        box = (int(row.x1), int(row.y1), int(row.x2), int(row.y2))
        image = cropper.crop(image, Detection(row.det_species, row.det_conf, box))
    return image  # no detection -> full image (detection rate is reported separately)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--datasets", nargs="*", default=list(DATASETS))
    parser.add_argument("--batch-size", type=int, default=32)
    args = parser.parse_args()

    device = "cuda" if torch.cuda.is_available() else "cpu"
    OUT.mkdir(parents=True, exist_ok=True)
    cropper = AnimalCropper(device=device)
    embedders = {name: cls(device=device) for name, cls in EMBEDDERS.items()}

    for name in args.datasets:
        try:
            df = DATASETS[name]()
        except FileNotFoundError:
            print(f"[skip] {name}: not downloaded")
            continue
        if name != "oxford":
            df = keep_identities_with_min_images(df, n=2)
        if df.empty:
            print(f"[skip] {name}: no images")
            continue
        print(f"[{name}] {len(df)} images, {df['identity'].nunique()} identities")

        index = detect_all(df, cropper)
        index.to_csv(OUT / f"{name}_index.csv", index=False)

        for model_name, embedder in embedders.items():
            for crop in (False, True):
                tag = "crop" if crop else "full"
                vectors = []
                rows = list(index.itertuples())
                for start in tqdm(range(0, len(rows), args.batch_size), desc=f"{model_name}/{tag}"):
                    batch = [load_for_embedding(r, crop, cropper) for r in rows[start:start + args.batch_size]]
                    vectors.append(embedder.embed(batch))
                np.save(OUT / f"{name}_{model_name}_{tag}.npy", np.concatenate(vectors))


if __name__ == "__main__":
    main()
