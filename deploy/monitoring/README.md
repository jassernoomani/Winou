# Monitoring: Prometheus + Grafana

Part of the production stack ([docker-compose.prod.yml](../docker-compose.prod.yml)), so every
deploy keeps it up to date. Grafana is only reachable on the server: **http://localhost:3000**
(user `admin`, password `GRAFANA_ADMIN_PASSWORD` from `.env`). Nothing here is exposed to the
internet: the metrics endpoints are not published and Caddy does not route them.

```
api:9091/actuator/prometheus ─┐
ml-service:8000/metrics ──────┤
postgres-exporter:9187 ───────┼──> Prometheus (15 s, kept 30 days) ──> Grafana: "Winou" dashboard
Jenkins /jenkins/prometheus/ ─┘
```

## What is measured

| Source | Metrics |
|---|---|
| API (Spring Boot Actuator + Micrometer) | requests per endpoint and status, response-time histograms, JVM memory and CPU, connection pool |
| API, app gauges ([AppMetrics](../../backend/src/main/java/tn/winou/infra/AppMetrics.java)) | `winou_photos{status}` (the worker's queue: it has no web server, its work shows here), `winou_matches{status}`, `winou_lost_reports{status}`, `winou_sightings`, `winou_users` |
| ML service ([metrics.py](../../ml-service/app/metrics.py)) | `winou_ml_request_seconds{endpoint,status}`, `winou_ml_stage_seconds{stage=detect\|embed}` |
| Postgres (postgres-exporter) | connections, database size, transactions, cache hits |
| Jenkins (Prometheus plugin) | last build result and duration |

## The dashboard

[grafana/dashboards/winou.json](grafana/dashboards/winou.json), provisioned with the Prometheus data
source; it is Grafana's home page. Rows: health (services up, 5xx in the last hour, failed photos),
API traffic, photos and matching, community numbers, platform, CI/CD.

To change it: edit in Grafana, *Export → Save to file*, replace the JSON here and push. Changes
made only in the UI are not saved.

## Setup

Add to the repo's `.env` before the first deploy that includes monitoring:

```
GRAFANA_ADMIN_PASSWORD=<a password>
```

Grafana stores the admin password on first start; later changes to `.env` do not change it (use
*Profile → Change password*, or delete the `winou_grafana_data` volume to start over).

Prometheus answers on the compose network only. For ad-hoc queries, use Grafana's *Explore* page.
