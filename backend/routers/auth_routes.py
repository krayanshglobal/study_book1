"""Auth endpoints."""
import os
import secrets
from datetime import datetime, timezone, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Request, Response, Depends
from bson import ObjectId
from models import (
    RegisterInput,
    LoginInput,
    ForgotPasswordInput,
    ResetPasswordInput,
    now_iso,
)
from auth import (
    hash_password,
    verify_password,
    validate_password,
    create_access_token,
    create_refresh_token,
    set_auth_cookies,
    clear_auth_cookies,
    generate_referral_code,
    get_current_user,
    require_role,
)
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _serialize_user(u: dict) -> dict:
    """Safely serialize a user document from MongoDB.
    Handles _id whether it is an ObjectId or already a string.
    """
    u = dict(u)
    if "_id" in u:
        u["_id"] = str(u["_id"])
    u.pop("password_hash", None)
    return u


def _get_uid_str(user: dict) -> str:
    """Return the user's _id as a string (already serialized by get_current_user)."""
    return str(user["_id"])


def _get_uid_oid(user: dict) -> ObjectId:
    """Return the user's _id as ObjectId (for MongoDB queries)."""
    return ObjectId(user["_id"])


@router.post("/register")
async def register(body: RegisterInput, response: Response):
    from server import db

    # Password validation
    err = validate_password(body.password)
    if err:
        raise HTTPException(status_code=400, detail=err)

    email = body.email.lower().strip()
    existing = await db.users.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    referred_by_id = None
    if body.referral_code:
        ref_user = await db.users.find_one({"referral_code": body.referral_code.strip().upper()})
        if ref_user:
            referred_by_id = str(ref_user["_id"])

    doc = {
        "name": body.name.strip(),
        "email": email,
        "phone": body.phone.strip(),
        "password_hash": hash_password(body.password),
        "role": "student",
        "class_level": body.class_level,
        "referral_code": generate_referral_code(),
        "referred_by": referred_by_id,
        "subscription_active": False,
        "subscription_expires_at": None,
        "total_points": 0,
        "created_at": now_iso(),
    }
    result = await db.users.insert_one(doc)
    uid = str(result.inserted_id)

    if referred_by_id:
        await db.referrals.insert_one({
            "referrer_id": referred_by_id,
            "referred_user_id": uid,
            "created_at": now_iso(),
            "reward_credited": False,
        })

    access = create_access_token(uid, email, "student")
    refresh = create_refresh_token(uid)
    set_auth_cookies(response, access, refresh)

    doc["_id"] = uid
    doc.pop("password_hash", None)
    return doc


@router.post("/login")
async def login(body: LoginInput, request: Request, response: Response):
    from server import db

    email = body.email.lower().strip()
    ip = request.client.host if request.client else "unknown"
    identifier = f"{ip}:{email}"

    lockout = await db.login_attempts.find_one({"identifier": identifier})
    if lockout and lockout.get("count", 0) >= 5:
        last = lockout.get("last_attempt")
        if last:
            # BUG FIX: Safely parse last_attempt whether it is a str or datetime
            if isinstance(last, str):
                last_dt = datetime.fromisoformat(last).replace(tzinfo=timezone.utc) if last.endswith("Z") else datetime.fromisoformat(last)
                if last_dt.tzinfo is None:
                    last_dt = last_dt.replace(tzinfo=timezone.utc)
            elif isinstance(last, datetime):
                last_dt = last if last.tzinfo else last.replace(tzinfo=timezone.utc)
            else:
                last_dt = datetime.now(timezone.utc)

            if datetime.now(timezone.utc) - last_dt < timedelta(minutes=15):
                raise HTTPException(status_code=429, detail="Too many attempts. Try again in 15 minutes.")

    user = await db.users.find_one({"email": email})
    if not user or not verify_password(body.password, user["password_hash"]):
        await db.login_attempts.update_one(
            {"identifier": identifier},
            {"$inc": {"count": 1}, "$set": {"last_attempt": now_iso()}},
            upsert=True,
        )
        raise HTTPException(status_code=401, detail="Invalid email or password")

    await db.login_attempts.delete_one({"identifier": identifier})

    uid = str(user["_id"])
    access = create_access_token(uid, email, user["role"])
    refresh = create_refresh_token(uid)
    set_auth_cookies(response, access, refresh)
    return _serialize_user(user)


@router.post("/logout")
async def logout(response: Response, _=Depends(get_current_user)):
    clear_auth_cookies(response)
    return {"ok": True}


@router.get("/me")
async def me(user=Depends(get_current_user)):
    return user


@router.post("/refresh")
async def refresh_token(request: Request, response: Response):
    import jwt as pyjwt
    from auth import get_jwt_secret, JWT_ALGORITHM
    from server import db

    token = request.cookies.get("refresh_token")
    if not token:
        raise HTTPException(status_code=401, detail="No refresh token")
    try:
        payload = pyjwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Wrong token type")

    # BUG FIX: Wrap ObjectId conversion in try/except
    try:
        oid = ObjectId(payload["sub"])
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    user = await db.users.find_one({"_id": oid})
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    uid = str(user["_id"])
    access = create_access_token(uid, user["email"], user["role"])
    refresh = create_refresh_token(uid)
    set_auth_cookies(response, access, refresh)
    return {"ok": True}


@router.post("/forgot-password")
async def forgot_password(body: ForgotPasswordInput):
    from server import db

    email = body.email.lower().strip()
    user = await db.users.find_one({"email": email})
    if not user:
        return {"ok": True}  # don't reveal if email exists

    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=1)
    await db.password_reset_tokens.insert_one({
        "token": token,
        "user_id": str(user["_id"]),
        "expires_at": expires_at,   # stored as BSON date (datetime object)
        "used": False,
        "created_at": now_iso(),
    })
    frontend = os.environ.get("FRONTEND_URL", "")
    logger.info(f"[password-reset] {email} -> {frontend}/reset-password?token={token}")
    print(f"[password-reset] {email} -> {frontend}/reset-password?token={token}")
    return {"ok": True}


@router.post("/reset-password")
async def reset_password(body: ResetPasswordInput):
    from server import db

    # Password validation
    err = validate_password(body.password)
    if err:
        raise HTTPException(status_code=400, detail=err)

    doc = await db.password_reset_tokens.find_one({"token": body.token})
    if not doc or doc.get("used"):
        raise HTTPException(status_code=400, detail="Invalid or used token")

    # BUG FIX: Handle expires_at as both datetime (BSON) and str (ISO)
    expires_at = doc["expires_at"]
    if isinstance(expires_at, str):
        expires_at = datetime.fromisoformat(expires_at)
    # Make timezone-aware if naive
    if isinstance(expires_at, datetime) and expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=400, detail="Token expired")

    # BUG FIX: user_id is stored as a string; use ObjectId() for the query
    try:
        uid_oid = ObjectId(doc["user_id"])
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid token data")

    await db.users.update_one(
        {"_id": uid_oid},
        {"$set": {"password_hash": hash_password(body.password)}},
    )
    await db.password_reset_tokens.update_one({"token": body.token}, {"$set": {"used": True}})
    return {"ok": True}


@router.post("/profile")
async def update_profile(body: dict, user=Depends(get_current_user)):
    from server import db

    # BUG FIX: user["_id"] is already a string; use ObjectId() only for queries
    uid_oid = _get_uid_oid(user)

    up = {}
    if "class_level" in body:
        val = str(body["class_level"]).strip()
        if val in ["8", "9", "10"]:
            db_user = await db.users.find_one({"_id": uid_oid})
            if not db_user:
                raise HTTPException(status_code=404, detail="User not found")
            if not db_user.get("class_level"):
                up["class_level"] = val
            elif db_user.get("class_level") != val:
                raise HTTPException(
                    status_code=400,
                    detail="Class change requires admin approval. Please submit a request.",
                )
    if "name" in body:
        name = body["name"].strip()
        if name:
            up["name"] = name
    if "phone" in body:
        up["phone"] = body["phone"].strip()

    if up:
        await db.users.update_one({"_id": uid_oid}, {"$set": up})

    updated = await db.users.find_one({"_id": uid_oid})
    return _serialize_user(updated)


@router.post("/profile/request-class-change")
async def request_class_change(body: dict, user=Depends(get_current_user)):
    from server import db

    req_class = str(body.get("requested_class", "")).strip()
    if req_class not in ["8", "9", "10"]:
        raise HTTPException(status_code=400, detail="Invalid requested class")

    uid_oid = _get_uid_oid(user)
    db_user = await db.users.find_one({"_id": uid_oid})
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")
    if db_user.get("class_level") == req_class:
        raise HTTPException(status_code=400, detail="You are already in this class")

    # Delete any existing pending requests for this user
    await db.class_change_requests.delete_many({"user_id": user["_id"], "status": "pending"})

    doc = {
        "user_id": user["_id"],
        "user_name": user["name"],
        "user_email": user["email"],
        "current_class": db_user.get("class_level"),
        "requested_class": req_class,
        "status": "pending",
        "created_at": now_iso(),
    }
    result = await db.class_change_requests.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.get("/profile/class-change-request")
async def get_class_change_request(user=Depends(get_current_user)):
    from server import db
    req = await db.class_change_requests.find_one({"user_id": user["_id"], "status": "pending"})
    if req:
        req["_id"] = str(req["_id"])
        return req
    return {"status": "none"}
