"""Qdrant photo index. One point per photo, id = Photo.id. Payload layout: see scripts/setup_qdrant.py."""
import uuid
from dataclasses import dataclass
from datetime import datetime

from qdrant_client import QdrantClient
from qdrant_client import models as m

PAYLOAD_INDEXES = {
    "species": m.PayloadSchemaType.KEYWORD,
    "kind": m.PayloadSchemaType.KEYWORD,
    "ref_id": m.PayloadSchemaType.KEYWORD,
    "location": m.PayloadSchemaType.GEO,
    "timestamp": m.PayloadSchemaType.DATETIME,
}


@dataclass
class Hit:
    photo_id: uuid.UUID
    ref_id: uuid.UUID
    score: float


def payload(species: str, kind: str, ref_id: uuid.UUID, lat: float, lon: float, timestamp: datetime) -> dict:
    return {"species": species, "kind": kind, "ref_id": str(ref_id),
            "location": {"lat": lat, "lon": lon}, "timestamp": timestamp.isoformat()}


class VectorIndex:
    def __init__(self, client: QdrantClient, collection: str, dim: int):
        self.client, self.collection, self.dim = client, collection, dim

    def ensure_collection(self) -> None:
        if not self.client.collection_exists(self.collection):
            self.client.create_collection(self.collection, vectors_config=m.VectorParams(
                size=self.dim, distance=m.Distance.COSINE))
        size = self.client.get_collection(self.collection).config.params.vectors.size
        if size != self.dim:
            raise RuntimeError(f"Qdrant collection {self.collection!r} has {size}-d vectors, expected "
                               f"{self.dim}: the embedding model changed, re-create it and re-embed.")
        existing = self.client.get_collection(self.collection).payload_schema
        for name, schema in PAYLOAD_INDEXES.items():
            if name not in existing:
                self.client.create_payload_index(self.collection, field_name=name, field_schema=schema, wait=True)

    def upsert(self, photo_id: uuid.UUID, vector: list[float], point_payload: dict) -> None:
        self.client.upsert(self.collection, wait=True, points=[
            m.PointStruct(id=str(photo_id), vector=vector, payload=point_payload)])

    def get_vector(self, photo_id: uuid.UUID) -> list[float] | None:
        points = self.client.retrieve(self.collection, ids=[str(photo_id)], with_vectors=True)
        return list(points[0].vector) if points else None

    def search(self, vector: list[float], species: str, kind: str, lat: float, lon: float, radius_m: float,
               since: datetime | None = None, until: datetime | None = None, limit: int = 100) -> list[Hit]:
        must = [
            m.FieldCondition(key="species", match=m.MatchValue(value=species)),
            m.FieldCondition(key="kind", match=m.MatchValue(value=kind)),
            m.FieldCondition(key="location", geo_radius=m.GeoRadius(
                center=m.GeoPoint(lat=lat, lon=lon), radius=radius_m)),
        ]
        if since or until:
            must.append(m.FieldCondition(key="timestamp", range=m.DatetimeRange(gte=since, lte=until)))
        points = self.client.query_points(self.collection, query=vector, query_filter=m.Filter(must=must),
                                          limit=limit, with_payload=["ref_id"]).points
        return [Hit(uuid.UUID(str(p.id)), uuid.UUID(p.payload["ref_id"]), p.score) for p in points]

    def update_ref(self, ref_id: uuid.UUID, new_payload: dict) -> None:
        """Change species/location/timestamp on every photo of a report or sighting."""
        self.client.set_payload(self.collection, payload=new_payload, wait=True,
                                points=self._ref_filter(ref_id))

    def delete_photo(self, photo_id: uuid.UUID) -> None:
        self.client.delete(self.collection, points_selector=m.PointIdsList(points=[str(photo_id)]), wait=True)

    def delete_ref(self, ref_id: uuid.UUID) -> None:
        self.client.delete(self.collection, points_selector=m.FilterSelector(filter=self._ref_filter(ref_id)),
                           wait=True)

    @staticmethod
    def _ref_filter(ref_id: uuid.UUID) -> m.Filter:
        return m.Filter(must=[m.FieldCondition(key="ref_id", match=m.MatchValue(value=str(ref_id)))])
