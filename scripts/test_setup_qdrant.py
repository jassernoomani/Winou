"""Runs the setup and smoke test against Qdrant's in-process mode (no server needed)."""
import pytest
from qdrant_client import QdrantClient

from setup_qdrant import setup_collection, smoke_test


@pytest.fixture
def client():
    return QdrantClient(":memory:")


def test_setup_is_idempotent(client):
    setup_collection(client, "photos", dim=16)
    setup_collection(client, "photos", dim=16)
    assert client.get_collection("photos").config.params.vectors.size == 16


def test_dimension_change_is_refused(client):
    setup_collection(client, "photos", dim=16)
    with pytest.raises(SystemExit):
        setup_collection(client, "photos", dim=32)


def test_matching_filters(client):
    setup_collection(client, "photos", dim=16)
    smoke_test(client, "photos", dim=16)
    assert client.count("photos").count == 0  # smoke points are cleaned up
