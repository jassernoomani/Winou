#!/usr/bin/env bash
# Starts or updates the demo server: pulls the latest code from GitHub, rebuilds what changed and
# restarts it. Database migrations run when the API starts. Run from the repo root on the server.
set -euo pipefail

compose() { docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml "$@"; }

git pull --ff-only
compose up -d --build --remove-orphans
docker image prune -f >/dev/null

domain=$(grep -E '^WINOU_DOMAIN=' .env | cut -d= -f2)
echo "Waiting for https://$domain/health ..."
for _ in $(seq 1 60); do
  if curl -fsS "https://$domain/health" >/dev/null 2>&1; then
    echo "Up: https://$domain/docs"
    exit 0
  fi
  sleep 5
done
echo "Not answering yet. Check: docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml logs caddy api" >&2
exit 1
