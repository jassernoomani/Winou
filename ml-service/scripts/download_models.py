"""Download model weights ahead of time (used at Docker build time).

YOLO weights are saved to $ML_YOLO_WEIGHTS; Hugging Face models go to $HF_HOME.
"""
import shutil
from pathlib import Path

from transformers import AutoImageProcessor, AutoModel
from ultralytics import YOLO

from app.config import settings

target = Path(settings.yolo_weights)
if not target.exists():
    YOLO(target.name)  # downloads into the working directory
    target.parent.mkdir(parents=True, exist_ok=True)
    if Path(target.name).resolve() != target.resolve():
        shutil.move(target.name, target)
print(f"YOLO weights: {target}")

AutoImageProcessor.from_pretrained(settings.embed_model)
AutoModel.from_pretrained(settings.embed_model)
print(f"Embedding model cached: {settings.embed_model}")
