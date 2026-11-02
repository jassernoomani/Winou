"""Prometheus metrics: request durations per endpoint and time per pipeline stage.

Served at /metrics, inside the compose network only (the port is not published in production).
"""
from time import perf_counter

from fastapi import FastAPI, Request
from fastapi.responses import Response
from prometheus_client import CONTENT_TYPE_LATEST, Histogram, generate_latest

# Model calls take from tens of milliseconds (GPU) to several seconds (CPU, big photos)
BUCKETS = (0.05, 0.1, 0.25, 0.5, 1, 2, 4, 8, 16, 32)

REQUEST_SECONDS = Histogram("winou_ml_request_seconds", "Requests by endpoint and HTTP status",
                            ["endpoint", "status"], buckets=BUCKETS)
STAGE_SECONDS = Histogram("winou_ml_stage_seconds", "Time per pipeline stage", ["stage"], buckets=BUCKETS)


def install(app: FastAPI) -> None:
    @app.middleware("http")
    async def time_requests(request: Request, call_next):
        start = perf_counter()
        response = await call_next(request)
        route = request.scope.get("route")
        endpoint = getattr(route, "path", "other")  # the route template, never raw URLs
        if endpoint not in ("/metrics", "/health"):
            REQUEST_SECONDS.labels(endpoint, str(response.status_code)).observe(perf_counter() - start)
        return response

    @app.get("/metrics", include_in_schema=False)
    def metrics():
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
