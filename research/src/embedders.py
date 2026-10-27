"""Image embedding models. Each returns L2-normalized float32 vectors."""
import numpy as np
import torch
from PIL import Image
from transformers import AutoImageProcessor, AutoModel, CLIPModel, CLIPProcessor


class Embedder:
    name: str
    dim: int

    def embed(self, images: list[Image.Image]) -> np.ndarray:
        raise NotImplementedError


def _normalize(x: torch.Tensor) -> np.ndarray:
    return torch.nn.functional.normalize(x.float(), dim=-1).cpu().numpy()


class ClipEmbedder(Embedder):
    def __init__(self, model_id: str = "openai/clip-vit-base-patch16", device: str = "cuda"):
        self.name = "clip-b16"
        self.device = device
        self.processor = CLIPProcessor.from_pretrained(model_id)
        self.model = CLIPModel.from_pretrained(model_id).to(device).eval()
        self.dim = self.model.config.projection_dim

    @torch.inference_mode()
    def embed(self, images):
        inputs = self.processor(images=images, return_tensors="pt").to(self.device)
        features = self.model.get_image_features(**inputs)
        # transformers >= 5 wraps the projected embedding in an output object
        if not isinstance(features, torch.Tensor):
            features = features.pooler_output
        return _normalize(features)


class DinoV2Embedder(Embedder):
    """DINOv2: CLS token concatenated with the mean patch token.

    The mean patch token adds local texture (coat pattern, markings), which
    matters for telling individuals apart.
    """

    def __init__(self, model_id: str = "facebook/dinov2-base", device: str = "cuda"):
        self.name = "dinov2-b14"
        self.device = device
        self.processor = AutoImageProcessor.from_pretrained(model_id)
        self.model = AutoModel.from_pretrained(model_id).to(device).eval()
        self.dim = self.model.config.hidden_size * 2

    @torch.inference_mode()
    def embed(self, images):
        inputs = self.processor(images=images, return_tensors="pt").to(self.device)
        tokens = self.model(**inputs).last_hidden_state
        features = torch.cat([tokens[:, 0], tokens[:, 1:].mean(dim=1)], dim=-1)
        return _normalize(features)


EMBEDDERS = {"clip-b16": ClipEmbedder, "dinov2-b14": DinoV2Embedder}
