"""Videos, leaderboard, referrals, plans, admin management, announcements, payments."""
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, Depends, Request, Query
from bson import ObjectId
from typing import Optional
from models import (
    VideoCreate, VideoUpdate, PlanCreate, PlanUpdate, CheckoutInput,
    AnnouncementCreate, UserUpdateAdmin, SubscriptionPatch, now_iso,
)
from auth import get_current_user, require_role, hash_password
import logging

logger = logging.getLogger(__name__)

router = APIRouter(tags=["misc"])


def _ser(x):
    if not x:
        return x
    x = dict(x)
    x["_id"] = str(x["_id"])
    return x


def _safe_oid(val: str, field: str = "ID") -> ObjectId:
    """Convert string to ObjectId, raising 400 on failure."""
    try:
        return ObjectId(val)
    except Exception:
        raise HTTPException(status_code=400, detail=f"Invalid {field} format")


# =============== VIDEOS ===============
@router.get("/api/videos")
async def list_videos(
    class_level: Optional[str] = None,
    subject: Optional[str] = None,
    topic: Optional[str] = None,
    limit: int = Query(50, le=200),
    skip: int = Query(0, ge=0),
    user=Depends(get_current_user),
):
    from server import db
    q: dict = {}
    if class_level:
        q["class_level"] = class_level
    if subject:
        q["subject"] = subject
    if topic:
        q["topic"] = topic
    if user["role"] == "student" and not user.get("subscription_active"):
        q["premium_only"] = False

    cursor = db.videos.find(q).sort("_id", -1).skip(skip).limit(limit)
    items = [_ser(v) async for v in cursor]
    total = await db.videos.count_documents(q)
    return {"items": items, "total": total}


@router.post("/api/videos")
async def create_video(body: VideoCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()
    result = await db.videos.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.put("/api/videos/{vid}")
async def update_video(vid: str, body: VideoUpdate, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(vid, "video ID")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    if not upd:
        raise HTTPException(status_code=400, detail="No fields to update")
    result = await db.videos.update_one({"_id": oid}, {"$set": upd})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Video not found")
    video = await db.videos.find_one({"_id": oid})
    return _ser(video)


@router.delete("/api/videos/{vid}")
async def delete_video(vid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(vid, "video ID")
    result = await db.videos.delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Video not found")
    return {"ok": True}


# =============== LEADERBOARD ===============
@router.get("/api/leaderboard")
async def leaderboard(
    class_level: Optional[str] = None,
    test_id: Optional[str] = None,
    limit: int = Query(50, le=200),
    _=Depends(get_current_user),
):
    from server import db
    from bson import ObjectId

    if test_id:
        # Fetch all submitted attempts for this test
        attempts_cursor = db.test_attempts.find(
            {"test_id": test_id, "submitted_at": {"$ne": None}}
        )
        attempts = await attempts_cursor.to_list(1000)

        # Get user details for these attempts
        uids = []
        for a in attempts:
            try:
                uids.append(ObjectId(a["user_id"]))
            except Exception:
                pass

        user_filter = {"_id": {"$in": uids}, "role": "student"}
        if class_level:
            user_filter["class_level"] = class_level

        users = await db.users.find(user_filter).to_list(1000)
        user_map = {str(u["_id"]): u for u in users}

        # Combine
        items = []
        for a in attempts:
            uid = a["user_id"]
            u = user_map.get(uid)
            if u:
                items.append({
                    "user_id": uid,
                    "name": u["name"],
                    "class_level": u.get("class_level"),
                    "score": a.get("score", 0.0),
                    "total_marks": a.get("total_marks", 0.0),
                })

        # Sort by score desc, then by total_marks desc
        items.sort(key=lambda x: (x["score"], x["total_marks"]), reverse=True)

        # Apply pagination/limit and add ranks
        out = []
        for rank, item in enumerate(items[:limit], start=1):
            item["rank"] = rank
            item["total_points"] = item["score"]
            out.append(item)

        return {"items": out}

    else:
        q: dict = {"role": "student"}
        if class_level:
            q["class_level"] = class_level
        cursor = db.users.find(q).sort("total_points", -1).limit(limit)
        out = []
        rank = 1
        async for u in cursor:
            out.append({
                "rank": rank,
                "user_id": str(u["_id"]),
                "name": u["name"],
                "class_level": u.get("class_level"),
                "total_points": u.get("total_points", 0),
            })
            rank += 1
        return {"items": out}


# =============== REFERRALS ===============
@router.get("/api/referrals/me")
async def my_referrals(user=Depends(get_current_user)):
    from server import db
    from auth import generate_referral_code

    # Auto-generate referral code if the user doesn't have one yet
    referral_code = user.get("referral_code")
    if not referral_code:
        referral_code = generate_referral_code()
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"referral_code": referral_code}}
        )

    referrals = []
    async for r in db.referrals.find({"referrer_id": user["_id"]}):
        try:
            u = await db.users.find_one({"_id": ObjectId(r["referred_user_id"])})
        except Exception:
            u = None
        if u:
            referrals.append({
                "name": u["name"],
                "email": u["email"],
                "joined_at": u.get("created_at"),
            })
    return {
        "referral_code": referral_code,
        "count": len(referrals),
        "referrals": referrals,
    }


# =============== PLANS ===============
@router.get("/api/plans")
async def list_plans(_=Depends(get_current_user)):
    from server import db
    cursor = db.plans.find({"is_active": True}).sort("price", 1)
    return {"items": [_ser(p) async for p in cursor]}


@router.get("/api/admin/plans")
async def list_all_plans(_=Depends(require_role("admin", "superadmin"))):
    from server import db
    cursor = db.plans.find({}).sort("_id", -1)
    return {"items": [_ser(p) async for p in cursor]}


@router.post("/api/admin/plans")
async def create_plan(body: PlanCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()
    r = await db.plans.insert_one(doc)
    doc["_id"] = str(r.inserted_id)
    return doc


@router.put("/api/admin/plans/{pid}")
async def update_plan(pid: str, body: PlanUpdate, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(pid, "plan ID")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    await db.plans.update_one({"_id": oid}, {"$set": upd})
    p = await db.plans.find_one({"_id": oid})
    if not p:
        raise HTTPException(status_code=404, detail="Plan not found")
    return _ser(p)


@router.delete("/api/admin/plans/{pid}")
async def delete_plan(pid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(pid, "plan ID")
    await db.plans.delete_one({"_id": oid})
    return {"ok": True}


# =============== PAYMENTS (STRIPE) ===============
@router.post("/api/payments/checkout")
async def create_checkout(body: CheckoutInput, request: Request, user=Depends(get_current_user)):
    from server import db
    from emergentintegrations.payments.stripe.checkout import (
        StripeCheckout, CheckoutSessionRequest,
    )
    import os

    oid = _safe_oid(body.plan_id, "plan ID")
    plan = await db.plans.find_one({"_id": oid, "is_active": True})
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    host_url = str(request.base_url)
    webhook_url = f"{host_url.rstrip('/')}/api/webhook/stripe"
    checkout = StripeCheckout(api_key=os.environ["STRIPE_API_KEY"], webhook_url=webhook_url)

    amount = float(plan["price"])
    currency = plan.get("currency", "inr")
    origin = body.origin_url.rstrip("/")
    success_url = f"{origin}/payment/success?session_id={{CHECKOUT_SESSION_ID}}"
    cancel_url = f"{origin}/pricing"

    req = CheckoutSessionRequest(
        amount=amount,
        currency=currency,
        success_url=success_url,
        cancel_url=cancel_url,
        metadata={
            "user_id": user["_id"],
            "plan_id": str(plan["_id"]),
            "plan_name": plan["name"],
        },
    )
    session = await checkout.create_checkout_session(req)

    await db.payment_transactions.insert_one({
        "user_id": user["_id"],
        "plan_id": str(plan["_id"]),
        "session_id": session.session_id,
        "amount": amount,
        "currency": currency,
        "payment_status": "initiated",
        "status": "pending",
        "metadata": {"plan_name": plan["name"], "duration_days": plan["duration_days"]},
        "created_at": now_iso(),
    })

    return {"url": session.url, "session_id": session.session_id}


@router.get("/api/payments/status/{session_id}")
async def payment_status(session_id: str, user=Depends(get_current_user)):
    from server import db
    from emergentintegrations.payments.stripe.checkout import StripeCheckout
    import os

    tx = await db.payment_transactions.find_one({"session_id": session_id, "user_id": user["_id"]})
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")

    if tx.get("payment_status") == "paid":
        return {
            "payment_status": "paid",
            "status": tx.get("status"),
            "amount_total": int(tx["amount"] * 100),
            "currency": tx["currency"],
        }

    checkout = StripeCheckout(api_key=os.environ["STRIPE_API_KEY"], webhook_url="")
    status = await checkout.get_checkout_status(session_id)

    if status.payment_status == "paid" and tx.get("payment_status") != "paid":
        duration = int(tx["metadata"].get("duration_days", 30))
        expires = datetime.now(timezone.utc) + timedelta(days=duration)
        uid_oid = _safe_oid(user["_id"], "user ID")
        await db.users.update_one(
            {"_id": uid_oid},
            {"$set": {"subscription_active": True, "subscription_expires_at": expires.isoformat()}},
        )
        await db.payment_transactions.update_one(
            {"session_id": session_id},
            {"$set": {
                "payment_status": "paid",
                "status": status.status,
                "processed_at": now_iso(),
            }},
        )
    else:
        await db.payment_transactions.update_one(
            {"session_id": session_id},
            {"$set": {"payment_status": status.payment_status, "status": status.status}},
        )

    return {
        "payment_status": status.payment_status,
        "status": status.status,
        "amount_total": status.amount_total,
        "currency": status.currency,
    }


@router.post("/api/webhook/stripe")
async def stripe_webhook(request: Request):
    from server import db
    from emergentintegrations.payments.stripe.checkout import StripeCheckout
    import os

    body = await request.body()
    signature = request.headers.get("Stripe-Signature", "")
    checkout = StripeCheckout(api_key=os.environ["STRIPE_API_KEY"], webhook_url="")
    try:
        evt = await checkout.handle_webhook(body, signature)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Webhook error: {e}")

    if evt.payment_status == "paid":
        tx = await db.payment_transactions.find_one({"session_id": evt.session_id})
        if tx and tx.get("payment_status") != "paid":
            duration = int(tx["metadata"].get("duration_days", 30))
            expires = datetime.now(timezone.utc) + timedelta(days=duration)
            try:
                uid_oid = ObjectId(tx["user_id"])
                await db.users.update_one(
                    {"_id": uid_oid},
                    {"$set": {"subscription_active": True, "subscription_expires_at": expires.isoformat()}},
                )
            except Exception as e:
                logger.error(f"Stripe webhook: failed to activate subscription for user {tx['user_id']}: {e}")
            await db.payment_transactions.update_one(
                {"session_id": evt.session_id},
                {"$set": {"payment_status": "paid", "processed_at": now_iso()}},
            )
    return {"ok": True}


# =============== ADMIN: PAYMENTS LISTING ===============
@router.get("/api/admin/payments")
async def admin_list_payments(
    limit: int = Query(50, le=200),
    skip: int = Query(0, ge=0),
    payment_status: Optional[str] = None,
    _=Depends(require_role("admin", "superadmin")),
):
    from server import db
    q: dict = {}
    if payment_status:
        q["payment_status"] = payment_status
    cursor = db.payment_transactions.find(q).sort("created_at", -1).skip(skip).limit(limit)
    items = []
    async for tx in cursor:
        tx["_id"] = str(tx["_id"])
        # Enrich with user info
        try:
            u = await db.users.find_one({"_id": ObjectId(tx["user_id"])}, {"name": 1, "email": 1})
            tx["user_name"] = u["name"] if u else None
            tx["user_email"] = u["email"] if u else None
        except Exception:
            tx["user_name"] = None
            tx["user_email"] = None
        items.append(tx)
    total = await db.payment_transactions.count_documents(q)
    return {"items": items, "total": total}


# =============== ADMIN: USERS ===============
@router.get("/api/admin/users")
async def admin_list_users(
    role: Optional[str] = None,
    class_level: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = Query(50, le=200),
    skip: int = Query(0, ge=0),
    _=Depends(require_role("admin", "superadmin")),
):
    from server import db
    q: dict = {}
    if role:
        q["role"] = role
    if class_level:
        q["class_level"] = class_level
    if search:
        q["$or"] = [
            {"name": {"$regex": search, "$options": "i"}},
            {"email": {"$regex": search, "$options": "i"}},
        ]
    cursor = db.users.find(q, {"password_hash": 0}).sort("_id", -1).skip(skip).limit(limit)
    items = [_ser(u) async for u in cursor]
    total = await db.users.count_documents(q)
    return {"items": items, "total": total}


@router.get("/api/admin/users/{uid}")
async def admin_get_user(uid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(uid, "user ID")
    user = await db.users.find_one({"_id": oid}, {"password_hash": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _ser(user)


@router.put("/api/admin/users/{uid}")
async def admin_update_user(uid: str, body: UserUpdateAdmin, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(uid, "user ID")
    user = await db.users.find_one({"_id": oid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    upd = {k: v for k, v in body.model_dump().items() if v is not None}

    # Prevent demoting/promoting superadmin via this endpoint
    if user.get("role") == "superadmin" and "role" in upd:
        raise HTTPException(status_code=403, detail="Cannot modify superadmin role")

    if upd:
        await db.users.update_one({"_id": oid}, {"$set": upd})
    updated = await db.users.find_one({"_id": oid}, {"password_hash": 0})
    return _ser(updated)


@router.patch("/api/admin/users/{uid}/subscription")
async def admin_patch_subscription(uid: str, body: SubscriptionPatch, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(uid, "user ID")
    user = await db.users.find_one({"_id": oid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    upd: dict = {"subscription_active": body.subscription_active}
    if body.subscription_active and body.expires_at:
        upd["subscription_expires_at"] = body.expires_at
    elif body.subscription_active and body.duration_days:
        expires = datetime.now(timezone.utc) + timedelta(days=body.duration_days)
        upd["subscription_expires_at"] = expires.isoformat()
    elif not body.subscription_active:
        upd["subscription_expires_at"] = None

    await db.users.update_one({"_id": oid}, {"$set": upd})
    updated = await db.users.find_one({"_id": oid}, {"password_hash": 0})
    logger.info(f"Admin updated subscription for user {uid}: active={body.subscription_active}")
    return _ser(updated)


@router.delete("/api/admin/users/{uid}")
async def admin_delete_user(uid: str, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(uid, "user ID")
    user = await db.users.find_one({"_id": oid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    # Safety: prevent deleting admins/superadmins via this endpoint
    if user.get("role") in ("admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Cannot delete admin or superadmin users via this endpoint")
    await db.users.delete_one({"_id": oid})
    logger.info(f"Admin {admin['_id']} deleted user {uid}")
    return {"ok": True}


@router.get("/api/admin/stats")
async def admin_stats(class_level: Optional[str] = None, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    q: dict = {}
    if class_level:
        q["class_level"] = class_level
    students = await db.users.count_documents({"role": "student", **q})
    questions = await db.questions.count_documents(q)
    tests = await db.tests.count_documents(q)
    videos = await db.videos.count_documents(q)
    active_subs = await db.users.count_documents({"subscription_active": True, **q})
    announcements = await db.announcements.count_documents({})
    if class_level:
        test_ids = [str(x["_id"]) async for x in db.tests.find({"class_level": class_level}, {"_id": 1})]
        attempts = await db.test_attempts.count_documents({"test_id": {"$in": test_ids}, "submitted_at": {"$ne": None}})
        class_requests = await db.class_change_requests.count_documents({"status": "pending", "requested_class": class_level})
    else:
        attempts = await db.test_attempts.count_documents({"submitted_at": {"$ne": None}})
        class_requests = await db.class_change_requests.count_documents({"status": "pending"})
    return {
        "students": students,
        "questions": questions,
        "tests": tests,
        "videos": videos,
        "active_subs": active_subs,
        "attempts": attempts,
        "class_requests": class_requests,
        "announcements": announcements,
    }


# =============== SUPERADMIN: MANAGE ADMINS ===============
@router.post("/api/superadmin/admins")
async def create_admin(body: dict, _=Depends(require_role("superadmin"))):
    from server import db
    from auth import generate_referral_code
    email = str(body.get("email", "")).lower().strip()
    if not email or not body.get("password") or not body.get("name"):
        raise HTTPException(status_code=400, detail="name, email, password required")
    existing = await db.users.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Email taken")
    doc = {
        "name": body["name"],
        "email": email,
        "phone": body.get("phone", ""),
        "password_hash": hash_password(body["password"]),
        "role": "admin",
        "class_level": None,
        "referral_code": generate_referral_code(),
        "subscription_active": True,
        "created_at": now_iso(),
        "total_points": 0,
    }
    r = await db.users.insert_one(doc)
    doc["_id"] = str(r.inserted_id)
    doc.pop("password_hash", None)
    return doc


@router.delete("/api/superadmin/admins/{uid}")
async def delete_admin(uid: str, _=Depends(require_role("superadmin"))):
    from server import db
    oid = _safe_oid(uid, "user ID")
    await db.users.delete_one({"_id": oid, "role": "admin"})
    return {"ok": True}


# =============== ANNOUNCEMENTS ===============
@router.get("/api/announcements")
async def list_announcements(user=Depends(get_current_user), admin_view: bool = False):
    from server import db
    role = user["role"]

    # Admin management view: return ALL announcements regardless of audience
    if admin_view and role in ("admin", "superadmin"):
        cursor = db.announcements.find({}).sort("_id", -1).limit(100)
        return {"items": [_ser(a) async for a in cursor]}

    if role == "student":
        audience_filter = {"$in": ["all", "students"]}
    elif role in ("admin", "superadmin"):
        audience_filter = {"$in": ["all", "admins"]}
    else:
        audience_filter = {"$in": ["all"]}

    q = {"active": True, "audience": audience_filter}

    # Students only see announcements for their class OR global ones (no class_level set)
    if role == "student":
        student_class = user.get("class_level")
        q["$or"] = [
            {"class_level": None},
            {"class_level": {"$exists": False}},
            {"class_level": student_class},
        ]

    cursor = db.announcements.find(q).sort("_id", -1).limit(20)
    return {"items": [_ser(a) async for a in cursor]}


@router.post("/api/announcements")
async def create_announcement(body: AnnouncementCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()
    r = await db.announcements.insert_one(doc)
    doc["_id"] = str(r.inserted_id)
    return doc


@router.delete("/api/announcements/{aid}")
async def delete_announcement(aid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(aid, "announcement ID")
    await db.announcements.delete_one({"_id": oid})
    return {"ok": True}


# =============== ADMIN: CLASS CHANGE REQUESTS ===============
@router.get("/api/admin/class-change-requests")
async def list_class_change_requests(
    status: Optional[str] = "pending",
    _=Depends(require_role("admin", "superadmin")),
):
    from server import db
    q: dict = {}
    if status != "all":
        q["status"] = status
    cursor = db.class_change_requests.find(q).sort("_id", -1)
    items = []
    async for d in cursor:
        d["_id"] = str(d["_id"])
        items.append(d)
    return {"items": items}


@router.post("/api/admin/class-change-requests/{req_id}/approve")
async def approve_class_change_request(req_id: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(req_id, "request ID")
    req = await db.class_change_requests.find_one({"_id": oid})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    if req["status"] != "pending":
        raise HTTPException(status_code=400, detail="Request already processed")

    try:
        uid_oid = ObjectId(req["user_id"])
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user_id in request")

    await db.users.update_one(
        {"_id": uid_oid},
        {"$set": {"class_level": req["requested_class"]}}
    )
    await db.class_change_requests.update_one(
        {"_id": oid},
        {"$set": {"status": "approved", "processed_at": now_iso()}}
    )
    return {"ok": True}


@router.post("/api/admin/class-change-requests/{req_id}/reject")
async def reject_class_change_request(req_id: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(req_id, "request ID")
    req = await db.class_change_requests.find_one({"_id": oid})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    if req["status"] != "pending":
        raise HTTPException(status_code=400, detail="Request already processed")

    await db.class_change_requests.update_one(
        {"_id": oid},
        {"$set": {"status": "rejected", "processed_at": now_iso()}}
    )
    return {"ok": True}
