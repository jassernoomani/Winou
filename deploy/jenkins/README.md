# CI/CD: Jenkins + SonarCloud

Every push to `main` on GitHub runs the [Jenkinsfile](../../Jenkinsfile) on this laptop:

```
GitHub push ──webhook──> Caddy (/jenkins/github-webhook/) ──> Jenkins
   Tests (parallel):  backend (Maven + Testcontainers + JaCoCo)
                      ML service (pytest + coverage)
                      app (flutter analyze + flutter test)
   SonarCloud:        analysis of all three, waits for the quality gate
   Deploy:            laptop repo -> tested commit, docker compose up -d --build, Caddy reload,
                      waits for the API to be healthy
   APK:               only when mobile/ changed (or FORCE_APK): release APK -> /download/winou.apk
```

Jenkins runs in Docker, next to the Winou stack but as its own compose project (`winou-ci`), and
drives the host's Docker through the mounted socket. Its configuration is code
([casc/jenkins.yaml](casc/jenkins.yaml)): admin account, SonarCloud token and the `winou` job.

The Jenkins UI is only reachable on the laptop: **http://localhost:8081/jenkins**. From the
internet, Caddy forwards GitHub's webhook path and nothing else.

## One-time setup

1. **SonarCloud**: on the project, *Administration → Analysis Method*: turn **off** Automatic
   Analysis. *My Account → Security*: generate a token.
2. **Secrets**: copy `.env.example` to `.env` in this folder, set an admin password and the token.
3. **Start Jenkins** (from this folder; the first build of the image takes a while):
   ```
   docker compose up -d --build
   ```
   Sign in at http://localhost:8081/jenkins as `admin`.
4. **First run**: open the `winou` job and click *Build Now* once. Jenkins learns the repo from
   this run; after it, pushes trigger builds.
5. **GitHub webhook**: repo *Settings → Webhooks → Add webhook*
   - Payload URL: `https://winou.duckdns.org/jenkins/github-webhook/`
   - Content type: `application/json`, event: *Just the push event*.

   GitHub sends a ping; a green tick on the webhook means it reached Jenkins.

## Day to day

- Push to `main`: the build starts within seconds. Follow it at http://localhost:8081/jenkins.
- **Deploy** works on the laptop's copy of the repo (it holds `.env` and `secrets/`). It is left
  alone, and the build marked unstable, if that copy has uncommitted changes or commits not on
  GitHub yet; pushing those commits deploys them.
- *Build with Parameters*: `FORCE_APK` rebuilds the APK, `SKIP_DEPLOY` only tests and analyses.
- Jenkins data (job history, caches, Android SDK) is in the `winou-ci_jenkins_home` volume.
- After editing anything in this folder: `docker compose up -d --build`.

## Nightly backups

The `winou-backup` job runs every night around 3:00 ([backup.sh](backup.sh)) and writes one folder
per night to **`C:\Users\BabaYaga\winou-backups`** (`WINOU_BACKUP_DIR` in `.env` changes it). The
last 14 nights are kept; each backup is checked (readable archives) before older ones are deleted.

| File | What | Rebuildable otherwise? |
|---|---|---|
| `postgres.sql.gz` | the database: accounts, reports, sightings, matches, chats | no |
| `minio.tar.gz` | every photo (originals, public copies, crops, chat photos) | no |
| `qdrant-pet_photos.snapshot` | the photo vectors | slowly: re-embedding every photo |

These sit on the same disk as the server: they protect against mistakes and corruption, not a dead
disk. Copy the folder elsewhere now and then (USB drive, the other PC, cloud storage).

Run one now: *winou-backup → Build Now*.

### Restoring

From the repo root, with the stack running (`compose` = `docker compose -f docker-compose.yml -f deploy/docker-compose.prod.yml`):

```bash
night=/c/Users/BabaYaga/winou-backups/2026-11-03        # the night to restore

# Database: replaces the current one
compose stop api worker
compose exec -T postgres psql -U winou -d postgres -c "DROP DATABASE winou WITH (FORCE)" -c "CREATE DATABASE winou OWNER winou"
gunzip -c "$night/postgres.sql.gz" | compose exec -T postgres psql -U winou -d winou

# Photos: replaces the MinIO volume's content
compose stop minio
docker run --rm -v winou_minio_data:/data -v "$night":/backup alpine:3.22 \
  sh -c 'rm -rf /data/* /data/.[!.]* ; tar -xzf /backup/minio.tar.gz -C /data'

# Vectors: upload the snapshot to Qdrant (replaces the collection)
compose up -d minio qdrant
docker run --rm --network winou_default -v "$night":/backup curlimages/curl:8.21.0 -fsS \
  -X POST "http://qdrant:6333/collections/pet_photos/snapshots/upload?priority=snapshot" \
  -F "snapshot=@/backup/qdrant-pet_photos.snapshot"

compose up -d
```
