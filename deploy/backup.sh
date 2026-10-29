#!/usr/bin/env bash
# Dumps the database to ~/backups (gzip), keeping the last 7. Run from the repo root; cron runs it
# nightly (see setup-server.sh). Photos stay in the MinIO volume: back it up separately if needed.
#
# Restore:  gunzip -c ~/backups/winou-<date>.sql.gz | docker compose exec -T postgres psql -U winou -d winou
set -euo pipefail

mkdir -p ~/backups
file=~/backups/winou-$(date +%F).sql.gz
docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml exec -T postgres \
  pg_dump -U winou -d winou --no-owner | gzip > "$file"
ls -1t ~/backups/winou-*.sql.gz | tail -n +8 | xargs -r rm --
echo "$(date -Is) backed up to $file ($(du -h "$file" | cut -f1))"
