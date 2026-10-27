"""Object storage (MinIO / any S3-compatible server). The bucket is private; the API serves images."""
import io
from typing import Protocol

from minio import Minio
from minio.deleteobjects import DeleteObject

from app.config import Settings


class Storage(Protocol):
    def put(self, key: str, data: bytes, content_type: str) -> None: ...
    def get(self, key: str) -> bytes: ...
    def delete(self, keys: list[str]) -> None: ...


class S3Storage:
    def __init__(self, settings: Settings):
        self.bucket = settings.s3_bucket
        self.client = Minio(settings.s3_endpoint, access_key=settings.s3_access_key,
                            secret_key=settings.s3_secret_key, secure=settings.s3_secure)

    def ensure_bucket(self) -> None:
        if not self.client.bucket_exists(self.bucket):
            self.client.make_bucket(self.bucket)

    def put(self, key: str, data: bytes, content_type: str) -> None:
        self.client.put_object(self.bucket, key, io.BytesIO(data), len(data), content_type=content_type)

    def get(self, key: str) -> bytes:
        response = self.client.get_object(self.bucket, key)
        try:
            return response.read()
        finally:
            response.close()
            response.release_conn()

    def delete(self, keys: list[str]) -> None:
        errors = self.client.remove_objects(self.bucket, [DeleteObject(k) for k in keys])
        for error in errors:  # lazy: iterating performs the deletion
            raise RuntimeError(f"could not delete {error.name}: {error.message}")
