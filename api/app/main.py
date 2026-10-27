"""Winou API. Endpoints are plain `def`: FastAPI runs them in its thread pool (sync SQLAlchemy)."""
from collections.abc import Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text

from app.db import SessionLocal
from app.matching import Services
from app.routers import auth, lost_reports, map, matches, photos, sightings
from app.services import build_services


def create_app(load_services: Callable[[], Services] | None = None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.services = (load_services or build_services)()
        yield

    app = FastAPI(title="Winou API", version="0.2.0", lifespan=lifespan)
    for module in (auth, lost_reports, sightings, photos, map, matches):
        app.include_router(module.router)

    @app.get("/health", tags=["health"])
    def health():
        with SessionLocal() as db:
            db.execute(text("SELECT 1"))
        return {"status": "ok"}

    return app


app = create_app()
