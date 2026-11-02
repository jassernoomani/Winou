#!/usr/bin/env bash
# Nightly backup of what git can't rebuild: the database, the photos (MinIO) and the vector index
# (a Qdrant snapshot). One folder per night in /backups (the laptop's winou-backups folder), the
# last 14 kept. Run by the Jenkins job winou-backup; restoring is in deploy/jenkins/README.md.
set -euo pipefail

out=/backups
keep=14
night="$out/$(date +%F)"
repo="${WINOU_HOST_REPO:?WINOU_HOST_REPO is not set}"
cd "$repo"

compose() { docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml "$@"; }
# Qdrant is only reachable inside the compose network
qdrant() { docker run --rm --network winou_default curlimages/curl:8.21.0 -fsS "$@"; }

mkdir -p "$night"

echo "Database..."
compose exec -T postgres pg_dump -U winou -d winou --no-owner </dev/null | gzip > "$night/postgres.sql.gz"

echo "Photos..."
docker run --rm -v winou_minio_data:/data:ro alpine:3.22 tar -czf - -C /data . > "$night/minio.tar.gz"

echo "Vectors..."
collection=$(sed -n 's/^QDRANT_COLLECTION=//p' .env 2>/dev/null | tr -d '\r ')  # .env is edited on Windows
collection=${collection:-pet_photos}
snapshot=$(qdrant -X POST "http://qdrant:6333/collections/$collection/snapshots" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
[ -n "$snapshot" ] || { echo "Qdrant did not create a snapshot" >&2; exit 1; }
qdrant "http://qdrant:6333/collections/$collection/snapshots/$snapshot" > "$night/qdrant-$collection.snapshot"
qdrant -X DELETE "http://qdrant:6333/collections/$collection/snapshots/$snapshot" >/dev/null

# A backup that can't be read is worse than none: check before pruning older ones
gzip -t "$night/postgres.sql.gz"
tar -tzf "$night/minio.tar.gz" >/dev/null
[ -s "$night/qdrant-$collection.snapshot" ]

ls -1d "$out"/20??-??-?? | sort | head -n -"$keep" | xargs -r rm -rf --
echo "Backed up to $night:"
du -h "$night"/*
