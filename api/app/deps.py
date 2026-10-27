"""Helpers shared by the routers."""
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, Request
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.matching import Services


def services(request: Request) -> Services:
    return request.app.state.services


def check_rate_limit(db: Session, column, user_id, created_at_column, limit: int, window: timedelta,
                     what: str) -> None:
    """Reject with 429 if the user created `limit` rows in the last `window`.

    Counted in Postgres so it holds across API replicas.
    """
    since = datetime.now(timezone.utc) - window
    count = db.scalar(select(func.count()).where(column == user_id, created_at_column >= since))
    if count >= limit:
        raise HTTPException(429, {"code": "rate_limited",
                                  "message": f"Too many {what}. Try again later."})


def not_found(what: str) -> HTTPException:
    return HTTPException(404, f"{what} not found")
