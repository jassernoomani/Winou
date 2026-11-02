#!/usr/bin/env bash
# The Jenkinsfile's Deploy stage. Brings the laptop's copy of the repo (the one with .env and
# secrets/, mounted at $WINOU_HOST_REPO) to the commit Jenkins just tested, then rebuilds and
# restarts what changed. Exit code 2 = skipped on purpose (the build is marked unstable).
set -euo pipefail

repo="${WINOU_HOST_REPO:?WINOU_HOST_REPO is not set}"
commit="${GIT_COMMIT:?GIT_COMMIT is not set}"
cd "$repo"

# The copy was checked out by Git for Windows (CRLF line endings)
g() { git -c core.autocrlf=true "$@"; }
compose() { docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml "$@"; }

if [ -n "$(g status --porcelain --untracked-files=no)" ]; then
    echo "The laptop copy has uncommitted changes, so it was left alone. Commit them, then run the job again." >&2
    exit 2
fi

g fetch -q origin
head=$(g rev-parse HEAD)
if [ "$head" != "$commit" ]; then
    if g merge-base --is-ancestor "$head" "$commit"; then
        echo "Updating the laptop copy ${head:0:7} -> ${commit:0:7}"
        g merge -q --ff-only "$commit"
    else
        echo "The laptop copy (${head:0:7}) has commits that are not in ${commit:0:7}. Push them; that push deploys." >&2
        exit 2
    fi
fi

compose up -d --build --remove-orphans
# Caddy does not notice Caddyfile edits by itself
compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile
docker image prune -f >/dev/null

echo "Waiting for the API to report healthy..."
for _ in $(seq 1 60); do
    status=$(docker inspect --format '{{.State.Health.Status}}' "$(compose ps -q api)")
    if [ "$status" = healthy ]; then
        echo "Deployed ${commit:0:7}: https://${WINOU_DOMAIN}/docs"
        exit 0
    fi
    sleep 5
done
echo "The API is not healthy after 5 minutes (status: $status)." >&2
compose logs --tail 80 api >&2
exit 1
