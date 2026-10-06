"""Videos, leaderboard, referrals, plans, admin management, announcements, payments."""
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, Depends, Request, Query
from bson import ObjectId
from typing import Optional
from models import (
    VideoCreate, VideoUpdate, PlanCreate, PlanUpdate, CheckoutInput, RazorpayVerifyInput,
    AnnouncementCreate, UserUpdateAdmin, SubscriptionPatch, now_iso,
)
from auth import get_current_user, require_role, hash_password
import logging
from decimal import Decimal, ROUND_HALF_UP
from pymongo import ReturnDocument
from starlette.concurrency import run_in_threadpool

from razorpay_gateway import (
    RazorpayGateway,
    RazorpayGatewayError,
    decode_webhook,
    verify_webhook_signature,
)

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
    user=Depends(get_current_user),
):
    from server import db
    from bson import ObjectId

    # ── Release-gate: students only see leaderboard if admin released it ──
    is_admin = user["role"] in ("admin", "superadmin")

    if not is_admin:
        if test_id:
            # Check per-test release status (supports both test_lb_ and legacy final_lb_ keys)
            rel = await db.settings.find_one({"_id": {"$in": [f"test_lb_{test_id}", f"final_lb_{test_id}"]}})
            if not rel or not rel.get("released"):
                raise HTTPException(
                    status_code=403,
                    detail="Leaderboard will be displayed shortly by the admin...",
                )
        else:
            # Check global overall leaderboard release status
            setting = await db.settings.find_one({"_id": "leaderboard_release"})
            if not setting or not setting.get("released"):
                raise HTTPException(
                    status_code=403,
                    detail="Leaderboard will be displayed shortly by the admin...",
                )

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
                    "student_id": u.get("student_id", ""),
                    "avatar_url": u.get("avatar_url", ""),
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
        # Class rank based on test scores
        q: dict = {"role": "student"}
        if class_level:
            q["class_level"] = class_level
        users = await db.users.find(q).to_list(1000)
        user_map = {str(u["_id"]): u for u in users}

        # Calculate total test score for each student
        user_scores = {}
        for uid in user_map:
            user_scores[uid] = 0.0

        attempts_cursor = db.test_attempts.find({"submitted_at": {"$ne": None}})
        async for a in attempts_cursor:
            uid = a.get("user_id")
            if uid in user_scores:
                user_scores[uid] += float(a.get("score", 0.0))

        # Sort users by total_test_score desc, then total_points desc
        sorted_uids = sorted(
            user_map.keys(),
            key=lambda uid: (user_scores[uid], user_map[uid].get("total_points", 0)),
            reverse=True
        )

        out = []
        for rank, uid in enumerate(sorted_uids[:limit], start=1):
            u = user_map[uid]
            out.append({
                "rank": rank,
                "user_id": uid,
                "name": u["name"],
                "class_level": u.get("class_level"),
                "student_id": u.get("student_id", ""),
                "avatar_url": u.get("avatar_url", ""),
                "score": round(user_scores[uid], 2),
                "total_points": u.get("total_points", 0),
            })
        return {"items": out}


# =============== LEADERBOARD RELEASE CONTROLS ===============
@router.get("/api/admin/leaderboard/release-status")
async def get_leaderboard_release_status(_=Depends(require_role("admin", "superadmin"))):
    from server import db
    setting = await db.settings.find_one({"_id": "leaderboard_release"})
    released = setting.get("released", False) if setting else False
    return {"released": released}


@router.post("/api/admin/leaderboard/release")
async def set_leaderboard_release(body: dict, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    released = bool(body.get("released", True))
    await db.settings.update_one(
        {"_id": "leaderboard_release"},
        {"$set": {"released": released, "updated_by": admin["_id"], "updated_at": now_iso()}},
        upsert=True,
    )
    return {"released": released}


@router.get("/api/admin/leaderboard/test/{test_id}/release-status")
@router.get("/api/admin/leaderboard/final/{test_id}/release-status")
async def get_test_lb_release_status(test_id: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    rel = await db.settings.find_one({"_id": {"$in": [f"test_lb_{test_id}", f"final_lb_{test_id}"]}})
    return {"released": rel.get("released", False) if rel else False}


@router.post("/api/admin/leaderboard/test/{test_id}/release")
@router.post("/api/admin/leaderboard/final/{test_id}/release")
async def set_test_lb_release(test_id: str, body: dict, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    released = bool(body.get("released", True))
    # Update both keys for compatibility
    for key in [f"test_lb_{test_id}", f"final_lb_{test_id}"]:
        await db.settings.update_one(
            {"_id": key},
            {"$set": {"released": released, "updated_by": admin["_id"], "updated_at": now_iso()}},
            upsert=True,
        )
    return {"released": released}



# =============== ADMIN REFERRALS ANALYTICS ===============
@router.get("/api/admin/referrals")
async def admin_referrals(
    class_level: Optional[str] = None,
    _=Depends(require_role("admin", "superadmin"))
):
    from server import db

    # Aggregate referrals by referrer_id
    pipeline = [
        {"$group": {
            "_id": "$referrer_id",
            "total_referred": {"$sum": 1},
        }},
        {"$sort": {"total_referred": -1}},
        {"$limit": 100},
    ]
    agg = await db.referrals.aggregate(pipeline).to_list(100)

    result = []
    for row in agg:
        referrer_id = row["_id"]
        total = row["total_referred"]
        try:
            referrer = await db.users.find_one({"_id": ObjectId(referrer_id)}, {"name": 1, "email": 1, "referral_code": 1, "class_level": 1, "student_id": 1})
        except Exception:
            referrer = None
        if not referrer:
            continue

        c_level = referrer.get("class_level", "8")
        if class_level and class_level != "all" and str(c_level) != str(class_level):
            continue

        # Count converted (referred user has registered account or active subscription)
        referred_docs = await db.referrals.find({"referrer_id": referrer_id}).to_list(500)
        converted = 0
        for r in referred_docs:
            try:
                u = await db.users.find_one({"_id": ObjectId(r["referred_user_id"])})
                if u:
                    # Count converted if referred user exists / has registered account or active subscription
                    if u.get("subscription_active") or r.get("converted") or r.get("reward_credited") or u.get("role") == "student":
                        converted += 1
            except Exception:
                pass

        result.append({
            "referrer_id": referrer_id,
            "name": referrer["name"],
            "email": referrer["email"],
            "class_level": c_level,
            "student_id": referrer.get("student_id", ""),
            "referral_code": referrer.get("referral_code", ""),
            "total_referred": total,
            "converted": converted,
            "conversion_pct": round(converted / total * 100, 1) if total else 0,
        })

    return {"items": result}


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


# =============== PAYMENTS (RAZORPAY) ===============
def _gateway_or_http_error() -> RazorpayGateway:
    try:
        return RazorpayGateway()
    except RazorpayGatewayError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc


async def _activate_paid_subscription(tx: dict, payment: dict) -> None:
    """Activate a plan exactly once, even if callback and webhook race."""
    from server import db

    claimed = await db.payment_transactions.find_one_and_update(
        {
            "_id": tx["_id"],
            "payment_status": {"$nin": ["paid", "processing"]},
        },
        {"$set": {"payment_status": "processing", "status": payment.get("status")}},
        return_document=ReturnDocument.AFTER,
    )
    if not claimed:
        return

    try:
        duration = int(tx.get("metadata", {}).get("duration_days", 30))
        expires = datetime.now(timezone.utc) + timedelta(days=duration)
        await db.users.update_one(
            {"_id": _safe_oid(tx["user_id"], "user ID")},
            {"$set": {
                "subscription_active": True,
                "subscription_expires_at": expires.isoformat(),
            }},
        )
        await db.payment_transactions.update_one(
            {"_id": tx["_id"]},
            {"$set": {
                "payment_status": "paid",
                "status": payment.get("status", "captured"),
                "payment_id": payment.get("id"),
                "payment_method": payment.get("method"),
                "processed_at": now_iso(),
            }},
        )
    except Exception:
        await db.payment_transactions.update_one(
            {"_id": tx["_id"]},
            {"$set": {"payment_status": "activation_failed"}},
        )
        raise


def _validate_payment_for_transaction(payment: dict, tx: dict) -> None:
    if payment.get("order_id") != tx.get("order_id"):
        raise HTTPException(status_code=400, detail="Payment order does not match")
    if int(payment.get("amount", -1)) != int(tx.get("amount_subunits", -2)):
        raise HTTPException(status_code=400, detail="Payment amount does not match")
    if str(payment.get("currency", "")).upper() != str(tx.get("currency", "")).upper():
        raise HTTPException(status_code=400, detail="Payment currency does not match")


@router.post("/api/payments/checkout")
async def create_checkout(body: CheckoutInput, user=Depends(get_current_user)):
    from server import db

    oid = _safe_oid(body.plan_id, "plan ID")
    plan = await db.plans.find_one({"_id": oid, "is_active": True})
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")

    amount = Decimal(str(plan["price"]))
    amount_subunits = int((amount * 100).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    if amount_subunits < 100:
        raise HTTPException(status_code=400, detail="Plan price must be at least INR 1")
    currency = str(plan.get("currency", "INR")).upper()
    if currency != "INR":
        raise HTTPException(status_code=400, detail="Only INR plans are currently supported")

    gateway = _gateway_or_http_error()
    receipt = f"cm_{str(plan['_id'])[-8:]}_{int(datetime.now().timestamp())}"
    try:
        order = await run_in_threadpool(
            gateway.create_order,
            amount=amount_subunits,
            currency=currency,
            receipt=receipt,
            notes={
                "user_id": user["_id"],
                "plan_id": str(plan["_id"]),
                "plan_name": str(plan["name"])[:250],
            },
        )
    except RazorpayGatewayError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc

    if not order.get("id"):
        raise HTTPException(status_code=502, detail="Razorpay returned an invalid order")

    transaction = {
        "user_id": user["_id"],
        "plan_id": str(plan["_id"]),
        "provider": "razorpay",
        "session_id": order["id"],
        "order_id": order["id"],
        "amount": float(amount),
        "amount_subunits": amount_subunits,
        "currency": currency,
        "payment_status": "initiated",
        "status": order.get("status", "created"),
        "metadata": {"plan_name": plan["name"], "duration_days": plan["duration_days"]},
        "created_at": now_iso(),
    }
    await db.payment_transactions.insert_one(transaction)

    return {
        "provider": "razorpay",
        "key_id": gateway.key_id,
        "order_id": order["id"],
        "session_id": order["id"],
        "amount": amount_subunits,
        "currency": currency,
        "name": "C Maths",
        "description": plan["name"],
        "prefill": {
            "name": user.get("name", ""),
            "email": user.get("email", ""),
            "contact": user.get("phone", ""),
        },
    }


@router.post("/api/payments/verify")
async def verify_payment(body: RazorpayVerifyInput, user=Depends(get_current_user)):
    from server import db

    tx = await db.payment_transactions.find_one({
        "order_id": body.razorpay_order_id,
        "user_id": user["_id"],
        "provider": "razorpay",
    })
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")

    gateway = _gateway_or_http_error()
    if not gateway.verify_payment_signature(
        order_id=tx["order_id"],
        payment_id=body.razorpay_payment_id,
        signature=body.razorpay_signature,
    ):
        raise HTTPException(status_code=400, detail="Invalid Razorpay payment signature")

    try:
        payment = await run_in_threadpool(
            gateway.fetch_payment, body.razorpay_payment_id
        )
        _validate_payment_for_transaction(payment, tx)
        if payment.get("status") == "authorized":
            payment = await run_in_threadpool(
                gateway.capture_payment,
                body.razorpay_payment_id,
                amount=tx["amount_subunits"],
                currency=tx["currency"],
            )
            _validate_payment_for_transaction(payment, tx)
        if payment.get("status") != "captured":
            raise HTTPException(status_code=409, detail="Payment has not been captured")
        await _activate_paid_subscription(tx, payment)
    except RazorpayGatewayError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc

    return {
        "ok": True,
        "payment_status": "paid",
        "status": payment.get("status"),
        "session_id": tx["order_id"],
    }


@router.get("/api/payments/status/{session_id}")
async def payment_status(session_id: str, user=Depends(get_current_user)):
    from server import db

    tx = await db.payment_transactions.find_one({"session_id": session_id, "user_id": user["_id"]})
    if not tx:
        raise HTTPException(status_code=404, detail="Transaction not found")

    if tx.get("payment_status") == "paid":
        return {
            "payment_status": "paid",
            "status": tx.get("status"),
            "amount_total": tx.get("amount_subunits", int(tx["amount"] * 100)),
            "currency": tx["currency"],
        }

    return {
        "payment_status": tx.get("payment_status", "initiated"),
        "status": tx.get("status", "created"),
        "amount_total": tx.get("amount_subunits", int(tx.get("amount", 0) * 100)),
        "currency": tx.get("currency", "INR"),
    }


@router.post("/api/webhook/razorpay")
async def razorpay_webhook(request: Request):
    from server import db

    body = await request.body()
    signature = request.headers.get("X-Razorpay-Signature", "")
    try:
        if not signature or not verify_webhook_signature(body, signature):
            raise HTTPException(status_code=400, detail="Invalid webhook signature")
        event = decode_webhook(body)
    except RazorpayGatewayError as exc:
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc

    if event.get("event") in {"payment.captured", "order.paid"}:
        payment = (
            event.get("payload", {}).get("payment", {}).get("entity", {})
        )
        order_id = payment.get("order_id")
        if order_id:
            tx = await db.payment_transactions.find_one({"order_id": order_id})
            if tx:
                _validate_payment_for_transaction(payment, tx)
                if payment.get("status") == "captured":
                    await _activate_paid_subscription(tx, payment)
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
    if class_level and class_level != "all" and not search:
        q["class_level"] = class_level
    if search:
        q["$or"] = [
            {"name": {"$regex": search, "$options": "i"}},
            {"email": {"$regex": search, "$options": "i"}},
            {"student_id": {"$regex": search, "$options": "i"}},
        ]
    cursor = db.users.find(q, {"password_hash": 0}).sort([("total_points", -1), ("_id", -1)]).skip(skip).limit(limit)
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
    if class_level and class_level != "all":
        q["class_level"] = class_level
    students = await db.users.count_documents({"role": "student", **q})
    questions = await db.questions.count_documents(q)
    tests = await db.tests.count_documents(q)
    videos = await db.videos.count_documents(q)
    active_subs = await db.users.count_documents({"role": "student", "subscription_active": True, **q})
    doubts = await db.discussion_threads.count_documents({"resolved": {"$ne": True}, **q})

    # Calculate highest student referral count for selected class
    highest_referrals = 0
    top_referrer_name = ""
    student_cursor = db.users.find({"role": "student", **q}, {"_id": 1, "name": 1})
    student_map = {str(s["_id"]): s.get("name", "Student") async for s in student_cursor}

    if student_map:
        pipeline = [
            {"$match": {"referrer_id": {"$in": list(student_map.keys())}}},
            {"$group": {"_id": "$referrer_id", "count": {"$sum": 1}}},
            {"$sort": {"count": -1}},
            {"$limit": 1}
        ]
        async for r in db.referrals.aggregate(pipeline):
            highest_referrals = r["count"]
            top_referrer_name = student_map.get(r["_id"], "")

    if class_level and class_level != "all":
        announcements = await db.announcements.count_documents({
            "$or": [
                {"class_level": class_level},
                {"class_level": None},
                {"class_level": {"$exists": False}},
                {"class_level": "all"}
            ]
        })
        test_ids = [str(x["_id"]) async for x in db.tests.find({"class_level": class_level}, {"_id": 1})]
        attempts = await db.test_attempts.count_documents({"test_id": {"$in": test_ids}, "submitted_at": {"$ne": None}})
        class_requests = await db.class_change_requests.count_documents({"status": "pending", "requested_class": class_level})
    else:
        announcements = await db.announcements.count_documents({})
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
        "doubts": doubts,
        "highest_referrals": highest_referrals,
        "top_referrer_name": top_referrer_name,
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
    status: str = "pending",
    class_level: Optional[str] = None,
    _=Depends(require_role("admin", "superadmin")),
):
    from server import db
    q: dict = {}
    if status != "all":
        q["status"] = status
    if class_level and class_level != "all":
        q["requested_class"] = class_level
    cursor = db.class_change_requests.find(q).sort("_id", -1)
    items = []
    async for d in cursor:
        d["_id"] = str(d["_id"])
        if not d.get("student_id") and d.get("user_id"):
            try:
                u = await db.users.find_one({"_id": ObjectId(d["user_id"])}, {"student_id": 1})
                if u and u.get("student_id"):
                    d["student_id"] = u["student_id"]
            except Exception:
                pass
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
