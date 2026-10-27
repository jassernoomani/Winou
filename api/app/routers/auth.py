from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models import User
from app.schemas import RegisterIn, TokenOut, UserOut, UserUpdate
from app.security import DB, CurrentUser, create_access_token, hash_password, verify_password

router = APIRouter(tags=["auth"])


@router.post("/auth/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(body: RegisterIn, db: DB):
    user = User(email=body.email.lower(), password_hash=hash_password(body.password),
                display_name=body.display_name.strip())
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        raise HTTPException(status.HTTP_409_CONFLICT, {"code": "email_taken",
                                                       "message": "This email is already registered."})
    return TokenOut(access_token=create_access_token(user.id))


@router.post("/auth/login", response_model=TokenOut)
def login(form: Annotated[OAuth2PasswordRequestForm, Depends()], db: DB):
    """OAuth2 password form: `username` is the email."""
    user = db.scalar(select(User).where(User.email == form.username.lower()))
    if not verify_password(user.password_hash if user else None, form.password):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    return TokenOut(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser):
    return user


@router.patch("/me", response_model=UserOut)
def update_me(body: UserUpdate, user: CurrentUser, db: DB):
    changes = body.model_dump(exclude_unset=True)
    if changes.get("display_name") is None:
        changes.pop("display_name", None)  # fcm_token may be cleared with null; the name may not
    for field, value in changes.items():
        setattr(user, field, value)
    db.commit()
    return user
