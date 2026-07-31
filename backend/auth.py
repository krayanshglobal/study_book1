"""JWT auth helpers, dependencies, and role-based access."""
import os
import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional
import bcrypt
import jwt
from bson import ObjectId
from fastapi import HTTPException, Request, Depends
import logging

logger = logging.getLogger(__name__)

JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_MINUTES = 60       # 1 hour — refresh token handles long sessions
REFRESH_TOKEN_DAYS = 30


def get_jwt_secret() -> str:
    secret = os.environ.get("JWT_SECRET", "")
    if not secret:
        raise RuntimeError("JWT_SECRET environment variable is not set")
    return secret


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False


def validate_password(password: str) -> Optional[str]:
    """Return an error message if password is invalid, or None if valid."""
    if len(password) < 6:
        return "Password must be at least 6 characters"
    return None


def create_access_token(user_id: str, email: str, role: str) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "role": role,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_MINUTES),
        "type": "access",
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm=JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    payload = {
        "sub": user_id,
        "exp": datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_DAYS),
        "type": "refresh",
    }
    return jwt.encode(payload, get_jwt_secret(), algorithm=JWT_ALGORITHM)


def generate_referral_code() -> str:
    return secrets.token_urlsafe(6).replace("-", "A").replace("_", "B")[:8].upper()


def set_auth_cookies(response, access_token: str, refresh_token: str) -> None:
    frontend_url = os.environ.get("FRONTEND_URL", "http://localhost:3000")
    is_localhost = "localhost" in frontend_url or "127.0.0.1" in frontend_url

    secure_val = not is_localhost
    samesite_val = "lax" if is_localhost else "none"

    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,
        secure=secure_val,
        samesite=samesite_val,
        max_age=ACCESS_TOKEN_MINUTES * 60,
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=secure_val,
        samesite=samesite_val,
        max_age=REFRESH_TOKEN_DAYS * 24 * 60 * 60,
        path="/",
    )


def clear_auth_cookies(response) -> None:
    response.delete_cookie("access_token", path="/")
    response.delete_cookie("refresh_token", path="/")


async def get_current_user(request: Request):
    from server import db  # local import to avoid circulars

    token = request.cookies.get("access_token")
    if not token:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    try:
        payload = jwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
        if payload.get("type") != "access":
            raise HTTPException(status_code=401, detail="Invalid token type")

        # BUG FIX: Wrap ObjectId conversion in try/except to avoid 500 on invalid sub
        sub = payload.get("sub", "")
        try:
            oid = ObjectId(sub)
        except Exception:
            raise HTTPException(status_code=401, detail="Invalid token payload")

        user = await db.users.find_one({"_id": oid})
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        # Serialize _id to string immediately
        user["_id"] = str(user["_id"])
        user.pop("password_hash", None)
        return user
    except HTTPException:
        raise
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as exc:
        logger.error(f"get_current_user unexpected error: {exc}")
        raise HTTPException(status_code=401, detail="Authentication error")


def require_role(*roles: str):
    async def _dep(user=Depends(get_current_user)):
        if user["role"] not in roles:
            raise HTTPException(status_code=403, detail="Forbidden")
        return user

    return _dep
