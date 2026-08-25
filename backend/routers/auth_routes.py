"""Auth endpoints."""
import os
import secrets
import base64
from datetime import datetime, timezone, timedelta
from typing import Optional
from fastapi import APIRouter, HTTPException, Request, Response, Depends, UploadFile, File
from bson import ObjectId
from models import (
    RegisterInput,
    LoginInput,
    GoogleLoginInput,
    MobileSendOtpInput,
    MobileVerifyOtpInput,
    ForgotPasswordInput,
    ResetPasswordInput,
    ChangePasswordInput,
    now_iso,
)
from auth import (
    hash_password,
    verify_password,
    validate_password,
    validate_phone,
    validate_email_str,
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


def _serialize_user(u: dict, access_token: str = None, refresh_token: str = None) -> dict:
    """Safely serialize a user document from MongoDB.
    Handles _id whether it is an ObjectId or already a string.
    """
    u = dict(u)
    if "_id" in u:
        u["_id"] = str(u["_id"])
    u.pop("password_hash", None)
    u["profile_picture"] = u.get("avatar_url", "")
    if access_token:
        u["access_token"] = access_token
    if refresh_token:
        u["refresh_token"] = refresh_token
    return u


def _get_uid_str(user: dict) -> str:
    """Return the user's _id as a string (already serialized by get_current_user)."""
    return str(user["_id"])


def _get_uid_oid(user: dict) -> ObjectId:
    """Return the user's _id as ObjectId (for MongoDB queries)."""
    return ObjectId(user["_id"])


async def _generate_student_id(db, class_level: str) -> str:
    """Generate a unique student ID: SB-YY-CLASS-XXXX using atomic counter."""
    yy = datetime.now(timezone.utc).strftime("%y")
    bucket = f"student_id_{yy}_{class_level}"
    result = await db.counters.find_one_and_update(
        {"_id": bucket},
        {"$inc": {"seq": 1}},
        upsert=True,
        return_document=True,
    )
    seq = result["seq"]
    return f"SB-{yy}-{class_level}-{seq:04d}"


@router.post("/register")
async def register(body: RegisterInput, response: Response):
    from server import db

    # Phone validation
    phone_err = validate_phone(body.phone)
    if phone_err:
        raise HTTPException(status_code=400, detail=phone_err)

    # Email validation
    email_err = validate_email_str(body.email)
    if email_err:
        raise HTTPException(status_code=400, detail=email_err)

    # Password validation
    err = validate_password(body.password)
    if err:
        raise HTTPException(status_code=400, detail=err)

    email = body.email.lower().strip()
    existing_email = await db.users.find_one({"email": email})
    if existing_email:
        raise HTTPException(status_code=400, detail="Email already registered")

    raw_phone = body.phone.strip()
    digits = "".join([c for c in raw_phone if c.isdigit()])
    normalized_phone = digits[-10:] if len(digits) >= 10 else raw_phone

    existing_phone = await db.users.find_one({"$or": [{"phone": normalized_phone}, {"phone": raw_phone}]})
    if existing_phone:
        raise HTTPException(status_code=400, detail="This mobile number is already registered. Please sign in.")

    # Server-Side OTP Verification Check
    ver_rec = None
    if body.verification_token:
        ver_rec = await db.otp_verifications.find_one({
            "verification_token": body.verification_token,
            "used": False,
            "expires_at": {"$gte": now_iso()},
        })
    if not ver_rec:
        ver_rec = await db.otp_verifications.find_one({
            "phone": normalized_phone,
            "used": False,
            "expires_at": {"$gte": now_iso()},
        })

    if not ver_rec:
        raise HTTPException(status_code=400, detail="Mobile number must be OTP verified before account creation.")

    # Mark verification token as consumed (single-use)
    await db.otp_verifications.update_one({"_id": ver_rec["_id"]}, {"$set": {"used": True}})

    referred_by_id = None
    if body.referral_code:
        ref_user = await db.users.find_one({"referral_code": body.referral_code.strip().upper()})
        if ref_user:
            referred_by_id = str(ref_user["_id"])

    # Generate student_id
    student_id = await _generate_student_id(db, body.class_level or "0")

    doc = {
        "name": body.name.strip(),
        "email": email,
        "phone": normalized_phone,
        "password_hash": hash_password(body.password),
        "role": "student",
        "class_level": body.class_level,
        "student_id": student_id,
        "referral_code": generate_referral_code(),
        "referred_by": referred_by_id,
        "subscription_active": False,
        "subscription_expires_at": None,
        "total_points": 0,
        "avatar_url": "",
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
    return _serialize_user(doc, access_token=access, refresh_token=refresh)

    doc["_id"] = uid
    doc.pop("password_hash", None)
    return _serialize_user(doc, access_token=access, refresh_token=refresh)


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
    return _serialize_user(user, access_token=access, refresh_token=refresh)


@router.post("/google")
async def google_login(body: GoogleLoginInput, response: Response):
    from server import db
    import urllib.request
    import json

    token = body.id_token.strip()
    if not token:
        raise HTTPException(status_code=400, detail="Google ID token or Access token required")

    payload = None
    # 1. Verify token server-side via Google TokenInfo API (for ID tokens)
    try:
        url = f"https://oauth2.googleapis.com/tokeninfo?id_token={token}"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 200:
                payload = json.loads(resp.read().decode())
    except Exception as e:
        logger.warning(f"Google token verification failed via id_token endpoint: {e}")

    # 2. Try UserInfo endpoint (for Access Tokens or fallback)
    if not payload or not payload.get("email"):
        try:
            url = "https://www.googleapis.com/oauth2/v3/userinfo"
            req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                if resp.status == 200:
                    payload = json.loads(resp.read().decode())
        except Exception as e:
            logger.warning(f"Google token verification failed via userinfo endpoint: {e}")

    if not payload or not payload.get("email"):
        raise HTTPException(status_code=401, detail="Invalid or expired Google authentication token")

    google_email = payload["email"].lower().strip()
    google_sub = payload.get("sub")
    google_name = payload.get("name") or google_email.split("@")[0]
    google_picture = payload.get("picture") or ""

    # 2. Check if user already exists by email or google_sub
    user = await db.users.find_one({"$or": [{"email": google_email}, {"google_sub": google_sub}]})

    if user:
        uid = str(user["_id"])
        if not user.get("google_sub") and google_sub:
            await db.users.update_one({"_id": user["_id"]}, {"$set": {"google_sub": google_sub}})
            user["google_sub"] = google_sub
        if not user.get("avatar_url") and google_picture:
            await db.users.update_one({"_id": user["_id"]}, {"$set": {"avatar_url": google_picture}})
            user["avatar_url"] = google_picture
    else:
        referred_by_id = None
        if body.referral_code:
            ref_user = await db.users.find_one({"referral_code": body.referral_code.strip().upper()})
            if ref_user:
                referred_by_id = str(ref_user["_id"])

        student_id = await _generate_student_id(db, body.class_level or "10")

        doc = {
            "name": google_name,
            "email": google_email,
            "phone": "",
            "google_sub": google_sub,
            "password_hash": "",
            "role": "student",
            "class_level": body.class_level or "10",
            "student_id": student_id,
            "referral_code": generate_referral_code(),
            "referred_by": referred_by_id,
            "subscription_active": False,
            "subscription_expires_at": None,
            "total_points": 0,
            "avatar_url": google_picture,
            "created_at": now_iso(),
        }
        result = await db.users.insert_one(doc)
        uid = str(result.inserted_id)
        doc["_id"] = uid
        user = doc

        if referred_by_id:
            await db.referrals.insert_one({
                "referrer_id": referred_by_id,
                "referred_user_id": uid,
                "created_at": now_iso(),
                "reward_credited": False,
            })

    access = create_access_token(uid, user["email"], user["role"])
    refresh = create_refresh_token(uid)
    set_auth_cookies(response, access, refresh)
    return _serialize_user(user, access_token=access, refresh_token=refresh)


async def _send_sms_via_provider(phone_10: str, otp_code: str) -> bool:
    """Send SMS via configured provider in environment variables."""
    provider = (os.environ.get("OTP_PROVIDER") or "").lower().strip()
    api_key = os.environ.get("OTP_PROVIDER_API_KEY") or os.environ.get("SMS_API_KEY") or os.environ.get("FAST2SMS_API_KEY") or os.environ.get("MSG91_AUTH_KEY")
    sender_id = os.environ.get("OTP_PROVIDER_SENDER_ID", "STUDYB")
    template_id = os.environ.get("OTP_PROVIDER_TEMPLATE_ID", "")

    if not api_key:
        logger.info(f"[DEV MODE] No SMS API key configured in environment. OTP for +91{phone_10}: {otp_code}")
        return True

    phone_91 = f"91{phone_10}"

    try:
        import urllib.request
        import urllib.parse
        import json

        if provider == "fast2sms" or "fast2sms" in api_key.lower():
            url = "https://www.fast2sms.com/dev/bulkV2"
            headers = {
                "authorization": api_key,
                "Content-Type": "application/json"
            }
            payload = {
                "route": "otp",
                "variables_values": otp_code,
                "numbers": phone_10
            }
            req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers=headers)
            with urllib.request.urlopen(req, timeout=10) as resp:
                resp_body = json.loads(resp.read().decode('utf-8'))
                logger.info(f"[SMS DIAGNOSTICS] Fast2SMS status: {resp.status}, response: {resp_body}")
                return resp_body.get("return") is True

        elif provider == "msg91":
            url = f"https://control.msg91.com/api/v5/otp?template_id={template_id}&mobile={phone_91}&authkey={api_key}"
            payload = {"otp": otp_code}
            req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=10) as resp:
                resp_body = json.loads(resp.read().decode('utf-8'))
                logger.info(f"[SMS DIAGNOSTICS] MSG91 response: {resp_body}")
                return resp_body.get("type") == "success"

        elif provider == "2factor":
            url = f"https://2factor.in/API/V1/{api_key}/SMS/{phone_10}/{otp_code}"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=10) as resp:
                resp_body = json.loads(resp.read().decode('utf-8'))
                logger.info(f"[SMS DIAGNOSTICS] 2Factor response: {resp_body}")
                return resp_body.get("Status") == "Success"

        else:
            logger.info(f"[SMS DIAGNOSTICS] Provider '{provider}' SMS dispatched for +91{phone_10}")
            return True

    except Exception as e:
        logger.error(f"[SMS DIAGNOSTICS ERROR] Failed to send SMS via {provider}: {e}")
        return False


@router.post("/mobile/send-otp")
async def mobile_send_otp(body: MobileSendOtpInput):
    from server import db

    raw_phone = body.phone.strip()
    digits = "".join([c for c in raw_phone if c.isdigit()])
    if len(digits) < 10:
        raise HTTPException(status_code=400, detail="Phone number must be at least 10 digits")

    normalized_phone = digits[-10:]

    cutoff = (datetime.now(timezone.utc) - timedelta(minutes=15)).isoformat()
    recent_count = await db.otp_codes.count_documents({
        "phone": normalized_phone,
        "created_at": {"$gte": cutoff},
    })
    if recent_count >= 5:
        raise HTTPException(status_code=429, detail="Too many OTP requests. Please wait 15 minutes before retrying.")

    existing_user = await db.users.find_one({"$or": [{"phone": normalized_phone}, {"phone": raw_phone}]})
    user_exists = existing_user is not None

    otp_code = f"{secrets.randbelow(900000) + 100000}"
    otp_hash = hash_password(otp_code)
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()

    await db.otp_codes.delete_many({"phone": normalized_phone})
    await db.otp_codes.insert_one({
        "phone": normalized_phone,
        "otp_hash": otp_hash,
        "attempts": 0,
        "created_at": now_iso(),
        "expires_at": expires_at,
    })

    # Dispatch SMS via configured provider
    sms_sent = await _send_sms_via_provider(normalized_phone, otp_code)

    return {
        "ok": True,
        "message": "OTP sent successfully",
        "phone": normalized_phone,
        "exists": user_exists,
    }


@router.post("/mobile/verify-otp")
async def mobile_verify_otp(body: MobileVerifyOtpInput, response: Response):
    from server import db

    raw_phone = body.phone.strip()
    digits = "".join([c for c in raw_phone if c.isdigit()])
    if len(digits) < 10:
        raise HTTPException(status_code=400, detail="Phone number must be at least 10 digits")
    normalized_phone = digits[-10:]

    otp_input = body.otp.strip()
    if not otp_input or len(otp_input) != 6:
        raise HTTPException(status_code=400, detail="OTP must be 6 digits")

    now_str = now_iso()
    otp_record = await db.otp_codes.find_one({"phone": normalized_phone})
    if not otp_record or otp_record.get("expires_at", "") < now_str:
        raise HTTPException(status_code=400, detail="OTP has expired or was not requested. Please request a new OTP.")

    if otp_record.get("attempts", 0) >= 3:
        await db.otp_codes.delete_one({"_id": otp_record["_id"]})
        raise HTTPException(status_code=400, detail="Too many invalid attempts. Please request a new OTP.")

    if not verify_password(otp_input, otp_record["otp_hash"]):
        await db.otp_codes.update_one({"_id": otp_record["_id"]}, {"$inc": {"attempts": 1}})
        raise HTTPException(status_code=400, detail="Invalid OTP code")

    await db.otp_codes.delete_one({"_id": otp_record["_id"]})

    # Generate and store verification_token for account creation proof
    verification_token = secrets.token_hex(16)
    await db.otp_verifications.delete_many({"phone": normalized_phone})
    await db.otp_verifications.insert_one({
        "phone": normalized_phone,
        "verification_token": verification_token,
        "created_at": now_iso(),
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=20)).isoformat(),
        "used": False,
    })

    user = await db.users.find_one({"$or": [{"phone": normalized_phone}, {"phone": raw_phone}]})

    if user:
        uid = str(user["_id"])
    else:
        referred_by_id = None
        if body.referral_code:
            ref_user = await db.users.find_one({"referral_code": body.referral_code.strip().upper()})
            if ref_user:
                referred_by_id = str(ref_user["_id"])

        student_id = await _generate_student_id(db, body.class_level or "10")
        name = body.name.strip() if (body.name and body.name.strip()) else f"Student {normalized_phone[-4:]}"
        email = f"user_{normalized_phone}@studybook.com"

        doc = {
            "name": name,
            "email": email,
            "phone": normalized_phone,
            "password_hash": "",
            "role": "student",
            "class_level": body.class_level or "10",
            "student_id": student_id,
            "referral_code": generate_referral_code(),
            "referred_by": referred_by_id,
            "subscription_active": False,
            "subscription_expires_at": None,
            "total_points": 0,
            "avatar_url": "",
            "created_at": now_iso(),
        }
        result = await db.users.insert_one(doc)
        uid = str(result.inserted_id)
        doc["_id"] = uid
        user = doc

        if referred_by_id:
            await db.referrals.insert_one({
                "referrer_id": referred_by_id,
                "referred_user_id": uid,
                "created_at": now_iso(),
                "reward_credited": False,
            })

    access = create_access_token(uid, user["email"], user["role"])
    refresh = create_refresh_token(uid)
    set_auth_cookies(response, access, refresh)
    res_data = _serialize_user(user, access_token=access, refresh_token=refresh)
    res_data["verification_token"] = verification_token
    res_data["verified"] = True
    return res_data


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
        try:
            body_data = await request.json()
            token = body_data.get("refresh_token") if isinstance(body_data, dict) else None
        except Exception:
            token = None
    if not token:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]

    if not token:
        raise HTTPException(status_code=401, detail="No refresh token")

    try:
        payload = pyjwt.decode(token, get_jwt_secret(), algorithms=[JWT_ALGORITHM])
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh token")
    if payload.get("type") != "refresh":
        raise HTTPException(status_code=401, detail="Wrong token type")

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
    return {"ok": True, "access_token": access, "refresh_token": refresh}


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
    
    res = {"ok": True}
    if os.environ.get("ENVIRONMENT") != "production":
        res["dev_reset_token"] = token
    return res


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


@router.post("/change-password")
async def change_password(body: ChangePasswordInput, user=Depends(get_current_user)):
    """Allow an authenticated user to change their own password."""
    from server import db

    # Validate new password meets existing password rules
    err = validate_password(body.new_password)
    if err:
        raise HTTPException(status_code=400, detail=err)

    # Confirm the two new-password fields match
    if body.new_password != body.confirm_password:
        raise HTTPException(status_code=400, detail="New passwords do not match")

    # Fetch the full user document (get_current_user strips password_hash)
    uid_oid = _get_uid_oid(user)
    db_user = await db.users.find_one({"_id": uid_oid})
    if not db_user:
        raise HTTPException(status_code=404, detail="User not found")

    # Verify the current password against the stored bcrypt hash
    if not verify_password(body.current_password, db_user["password_hash"]):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    # Prevent setting the same password again
    if body.new_password == body.current_password:
        raise HTTPException(status_code=400, detail="New password must differ from the current password")

    # Update the stored bcrypt hash
    await db.users.update_one(
        {"_id": uid_oid},
        {"$set": {"password_hash": hash_password(body.new_password)}},
    )
    logger.info(f"[change-password] user {user['_id']} changed their password")
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


@router.post("/profile/photo")
@router.put("/users/me/profile-picture")
async def upload_profile_photo(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
):
    """Upload a profile photo (stored as base64 data URI)."""
    from server import db

    if not file.content_type or not (file.content_type.startswith("image/jpeg") or file.content_type.startswith("image/jpg") or file.content_type.startswith("image/png") or file.content_type.startswith("image/")):
        raise HTTPException(
            status_code=400,
            detail="Profile picture must be JPG or PNG and less than 2 MB.",
        )

    MAX_SIZE = 2 * 1024 * 1024  # 2 MB
    data = await file.read()
    if len(data) > MAX_SIZE:
        raise HTTPException(
            status_code=400,
            detail="Profile picture must be JPG or PNG and less than 2 MB.",
        )

    b64 = base64.b64encode(data).decode("utf-8")
    data_uri = f"data:{file.content_type};base64,{b64}"

    uid_oid = _get_uid_oid(user)
    await db.users.update_one({"_id": uid_oid}, {"$set": {"avatar_url": data_uri, "profile_picture": data_uri}})
    updated = await db.users.find_one({"_id": uid_oid})
    return _serialize_user(updated)


@router.delete("/profile/photo")
@router.delete("/users/me/profile-picture")
async def remove_profile_photo(user=Depends(get_current_user)):
    """Remove/clear the user's profile photo."""
    from server import db
    uid_oid = _get_uid_oid(user)
    await db.users.update_one({"_id": uid_oid}, {"$set": {"avatar_url": "", "profile_picture": ""}})
    updated = await db.users.find_one({"_id": uid_oid})
    return _serialize_user(updated)
