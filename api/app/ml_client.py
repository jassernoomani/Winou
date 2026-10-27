"""Client for the ML service (detect → crop → embed)."""
import base64
from dataclasses import dataclass
from typing import Protocol

import httpx


class NoAnimalDetected(Exception):
    pass


@dataclass
class Embedding:
    species: str          # what the detector saw: "cat" | "dog"
    confidence: float
    vector: list[float]
    crop_jpeg: bytes


class MLClient(Protocol):
    def embed(self, image: bytes) -> Embedding: ...


class HttpMLClient:
    def __init__(self, base_url: str, timeout: float = 120):
        self.client = httpx.Client(base_url=base_url, timeout=timeout)

    def embed(self, image: bytes) -> Embedding:
        response = self.client.post("/embed", params={"return_crop": "true"},
                                    files={"file": ("photo.jpg", image, "image/jpeg")})
        if response.status_code == 422 and _error_code(response) == "no_animal_detected":
            raise NoAnimalDetected()
        response.raise_for_status()
        body = response.json()
        return Embedding(species=body["detection"]["species"], confidence=body["detection"]["confidence"],
                         vector=body["vector"], crop_jpeg=base64.b64decode(body["crop_jpeg_base64"]))


def _error_code(response: httpx.Response) -> str | None:
    try:
        return response.json()["detail"]["code"]
    except (ValueError, KeyError, TypeError):
        return None
