"""Real service clients, built once per process (API and worker)."""
from qdrant_client import QdrantClient

from app.config import Settings, settings
from app.matching import Services
from app.ml_client import HttpMLClient
from app.notifications import LogNotifier
from app.storage import S3Storage
from app.vectors import VectorIndex


def build_services(cfg: Settings = settings) -> Services:
    storage = S3Storage(cfg)
    storage.ensure_bucket()
    index = VectorIndex(QdrantClient(url=cfg.qdrant_url, api_key=cfg.qdrant_api_key),
                        cfg.qdrant_collection, cfg.embed_dim)
    index.ensure_collection()
    return Services(storage=storage, index=index, ml=HttpMLClient(cfg.ml_service_url), notifier=LogNotifier())
