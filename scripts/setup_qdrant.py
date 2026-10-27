"""Create the Qdrant collection for photo embeddings. Safe to run repeatedly.

    python scripts/setup_qdrant.py            # QDRANT_URL defaults to http://localhost:6333
    python scripts/setup_qdrant.py --smoke    # also run a test matching query

Each point is one photo crop. Payload:
    species    "cat" | "dog"
    kind       "lost" | "sighting"
    ref_id     id of the lost report or sighting in Postgres
    location   {"lat": .., "lon": ..} (exact point, never exposed publicly)
    timestamp  RFC 3339: last-seen time (lost) or seen time (sighting)
"""
import argparse
import os
import sys
import uuid
from datetime import datetime, timedelta, timezone

import numpy as np
from qdrant_client import QdrantClient
from qdrant_client import models as m

COLLECTION = os.getenv("QDRANT_COLLECTION", "pet_photos")
DIM = int(os.getenv("EMBED_DIM", "1536"))

PAYLOAD_INDEXES = {
    "species": m.PayloadSchemaType.KEYWORD,
    "kind": m.PayloadSchemaType.KEYWORD,
    "ref_id": m.PayloadSchemaType.KEYWORD,
    "location": m.PayloadSchemaType.GEO,
    "timestamp": m.PayloadSchemaType.DATETIME,
}


def setup_collection(client: QdrantClient, name: str = COLLECTION, dim: int = DIM) -> None:
    if not client.collection_exists(name):
        client.create_collection(name, vectors_config=m.VectorParams(size=dim, distance=m.Distance.COSINE))
        print(f"created collection {name!r} ({dim}-d, cosine)")
    else:
        size = client.get_collection(name).config.params.vectors.size
        if size != dim:
            sys.exit(f"collection {name!r} has {size}-d vectors, expected {dim}. "
                     "The embedding model changed: re-create the collection and re-embed.")
        print(f"collection {name!r} already exists")

    existing = client.get_collection(name).payload_schema
    for field, schema in PAYLOAD_INDEXES.items():
        if field not in existing:
            client.create_payload_index(name, field_name=field, field_schema=schema, wait=True)
            print(f"  + index {field} ({schema.value})")


def candidate_filter(species: str, kind: str, lat: float, lon: float, radius_m: float,
                     since: datetime | None = None, until: datetime | None = None) -> m.Filter:
    """Payload + geo + time filter for one matching query (pipeline step 5)."""
    must = [
        m.FieldCondition(key="species", match=m.MatchValue(value=species)),
        m.FieldCondition(key="kind", match=m.MatchValue(value=kind)),
        m.FieldCondition(key="location", geo_radius=m.GeoRadius(
            center=m.GeoPoint(lat=lat, lon=lon), radius=radius_m)),
    ]
    if since or until:
        must.append(m.FieldCondition(key="timestamp", range=m.DatetimeRange(gte=since, lte=until)))
    return m.Filter(must=must)


def smoke_test(client: QdrantClient, name: str = COLLECTION, dim: int = DIM) -> None:
    """Insert fake lost reports, run the 'new sighting' query, then clean up.

    Only the nearby, recent, same-species lost cat must come back.
    """
    rng = np.random.default_rng(0)
    cat = rng.normal(size=dim)
    now = datetime.now(timezone.utc)
    tunis, sfax = (36.8065, 10.1815), (34.7406, 10.7603)

    def point(ref_id, species, latlon, age_days, vector):
        return m.PointStruct(id=str(uuid.uuid4()), vector=list(vector), payload={
            "species": species, "kind": "lost", "ref_id": ref_id, "smoke_test": True,
            "location": {"lat": latlon[0], "lon": latlon[1]},
            "timestamp": (now - timedelta(days=age_days)).isoformat(),
        })

    near_noise = lambda: cat + rng.normal(scale=0.3, size=dim)  # noqa: E731
    client.upsert(name, wait=True, points=[
        point("smoke-match", "cat", (36.82, 10.19), 5, near_noise()),
        point("smoke-too-far", "cat", sfax, 5, near_noise()),
        point("smoke-wrong-species", "dog", (36.81, 10.18), 5, near_noise()),
        point("smoke-too-old", "cat", (36.80, 10.17), 90, near_noise()),
    ])
    try:
        hits = client.query_points(
            name, query=list(cat), limit=10, with_payload=True,
            query_filter=candidate_filter("cat", "lost", *tunis, radius_m=10_000,
                                          since=now - timedelta(days=60)),
        ).points
        found = [h.payload["ref_id"] for h in hits]
        assert found == ["smoke-match"], f"unexpected matches: {found}"
        print(f"smoke test passed: {found[0]} (score {hits[0].score:.3f})")
    finally:
        client.delete(name, wait=True, points_selector=m.FilterSelector(filter=m.Filter(
            must=[m.FieldCondition(key="smoke_test", match=m.MatchValue(value=True))])))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--smoke", action="store_true", help="run a test matching query")
    args = parser.parse_args()

    qdrant = QdrantClient(url=os.getenv("QDRANT_URL", "http://localhost:6333"),
                          api_key=os.getenv("QDRANT_API_KEY") or None)
    setup_collection(qdrant)
    if args.smoke:
        smoke_test(qdrant)
