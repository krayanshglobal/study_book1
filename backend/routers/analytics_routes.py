"""Analytics and image-upload endpoints."""
import base64
import uuid
from datetime import datetime, timezone, timedelta
from collections import defaultdict
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Response
from typing import Optional
from bson import ObjectId
from auth import get_current_user, require_role
from models import now_iso
import logging

logger = logging.getLogger(__name__)

router = APIRouter(tags=["analytics-uploads"])


# =============== IMAGE UPLOADS (base64 in Mongo) ===============
@router.post("/api/uploads/image")
async def upload_image(file: UploadFile = File(...), user=Depends(get_current_user)):
    from server import db
    raw = await file.read()
    if len(raw) > 4 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 4 MB)")
    doc_id = str(uuid.uuid4())
    await db.uploads.insert_one({
        "_id": doc_id,
        "content_type": file.content_type or "image/png",
        "data": base64.b64encode(raw).decode("ascii"),
        "size": len(raw),
        "user_id": user["_id"],
        "created_at": now_iso(),
    })
    return {"url": f"/api/uploads/image/{doc_id}", "id": doc_id, "size": len(raw)}


@router.get("/api/uploads/image/{doc_id}")
async def get_image(doc_id: str):
    from server import db
    doc = await db.uploads.find_one({"_id": doc_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Not found")
    raw = base64.b64decode(doc["data"])
    return Response(
        content=raw,
        media_type=doc.get("content_type", "image/png"),
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )


# =============== ADMIN ANALYTICS ===============
@router.get("/api/admin/analytics/weekly")
async def admin_weekly(class_level: Optional[str] = None, _=Depends(require_role("admin", "superadmin"))):
    """Daily attempts + registrations for the last 14 days."""
    from server import db
    days = 14
    today = datetime.now(timezone.utc).date()
    buckets = {(today - timedelta(days=i)).isoformat(): {"attempts": 0, "registrations": 0} for i in range(days - 1, -1, -1)}

    uq: dict = {}
    if class_level:
        uq["class_level"] = class_level

    aq: dict = {"submitted_at": {"$ne": None}}
    if class_level:
        test_ids = [str(x["_id"]) async for x in db.tests.find({"class_level": class_level}, {"_id": 1})]
        aq["test_id"] = {"$in": test_ids}

    async for a in db.test_attempts.find(aq, {"submitted_at": 1}):
        try:
            d = a["submitted_at"][:10]
            if d in buckets:
                buckets[d]["attempts"] += 1
        except Exception:
            pass
    async for u in db.users.find({"role": "student", **uq}, {"created_at": 1}):
        try:
            d = (u.get("created_at") or "")[:10]
            if d in buckets:
                buckets[d]["registrations"] += 1
        except Exception:
            pass

    return {"items": [{"date": d, **v} for d, v in buckets.items()]}


@router.get("/api/admin/analytics/topics")
async def admin_topics(class_level: Optional[str] = None, _=Depends(require_role("admin", "superadmin"))):
    """Per-topic performance: attempts, average % correct across all submitted answers."""
    from server import db

    # BUG FIX: renamed inner variable from 'q' to 'qfilter' to avoid shadowing the outer 'q' dict
    qfilter: dict = {}
    if class_level:
        qfilter["class_level"] = class_level

    # Build map of question -> topic + class
    qmap: dict = {}
    async for qd in db.questions.find(qfilter, {"topic": 1, "class_level": 1}):
        qmap[str(qd["_id"])] = {"topic": qd.get("topic") or "Untitled", "class_level": qd.get("class_level")}

    stats: dict = defaultdict(lambda: {"correct": 0, "total": 0})
    att_q: dict = {"submitted_at": {"$ne": None}}
    if class_level:
        test_ids = [str(x["_id"]) async for x in db.tests.find({"class_level": class_level}, {"_id": 1})]
        att_q["test_id"] = {"$in": test_ids}

    async for att in db.test_attempts.find(att_q, {"answers": 1}):
        for a in att.get("answers", []):
            info = qmap.get(a.get("question_id"))
            if not info or not a.get("answered"):
                continue
            k = info["topic"]
            stats[k]["total"] += 1
            if a.get("is_correct"):
                stats[k]["correct"] += 1

    out = []
    for topic, s in stats.items():
        pct = round(100 * s["correct"] / s["total"], 1) if s["total"] else 0
        out.append({"topic": topic, "attempts": s["total"], "pass_rate": pct})
    out.sort(key=lambda x: -x["attempts"])
    return {"items": out}


@router.get("/api/admin/analytics/tests")
async def admin_tests_summary(class_level: Optional[str] = None, _=Depends(require_role("admin", "superadmin"))):
    """Recent tests + avg percent."""
    from server import db
    tests = []
    tq: dict = {"is_published": True}
    if class_level:
        tq["class_level"] = class_level
    async for t in db.tests.find(tq).sort("_id", -1).limit(10):
        agg = db.test_attempts.aggregate([
            {"$match": {"test_id": str(t["_id"]), "submitted_at": {"$ne": None}}},
            {"$group": {"_id": None, "avg": {"$avg": "$percent"}, "count": {"$sum": 1}}},
        ])
        avg = 0
        count = 0
        async for row in agg:
            avg = round(row["avg"] or 0, 1)
            count = row["count"]
        tests.append({
            "title": t["title"],
            "class_level": t.get("class_level"),
            "avg_percent": avg,
            "attempts": count,
        })
    return {"items": tests}


# =============== STUDENT ANALYTICS ===============
@router.get("/api/students/me/analytics")
async def student_analytics(user=Depends(get_current_user)):
    """Personal performance: strengths/weaknesses by topic + recent scores."""
    from server import db
    qmap: dict = {}
    async for q in db.questions.find({}, {"topic": 1}):
        qmap[str(q["_id"])] = q.get("topic") or "Untitled"

    topic_stats: dict = defaultdict(lambda: {"correct": 0, "total": 0})
    recent_scores = []
    total_attempts = 0
    async for att in db.test_attempts.find(
        {"user_id": user["_id"], "submitted_at": {"$ne": None}}
    ).sort("submitted_at", -1):
        total_attempts += 1
        if len(recent_scores) < 8:
            t = None
            if ObjectId.is_valid(att.get("test_id", "")):
                t = await db.tests.find_one({"_id": ObjectId(att["test_id"])})
            recent_scores.append({
                "title": t["title"] if t else "Test",
                "percent": att.get("percent", 0),
                "date": (att.get("submitted_at") or "")[:10],
            })
        for a in att.get("answers", []):
            if not a.get("answered"):
                continue
            topic = qmap.get(a.get("question_id"), "General")
            topic_stats[topic]["total"] += 1
            if a.get("is_correct"):
                topic_stats[topic]["correct"] += 1

    topics = []
    for topic, s in topic_stats.items():
        pct = round(100 * s["correct"] / s["total"], 1) if s["total"] else 0
        topics.append({"topic": topic, "accuracy": pct, "questions": s["total"]})
    topics.sort(key=lambda x: -x["accuracy"])
    strengths = [t for t in topics if t["accuracy"] >= 70][:5]
    weaknesses = [t for t in topics if t["accuracy"] < 60][:5]
    total_q = sum(x["questions"] for x in topics)
    overall_pct = (
        round(sum(x["accuracy"] * x["questions"] for x in topics) / total_q, 1)
        if total_q > 0
        else 0
    )

    return {
        "overall_accuracy": overall_pct,
        "total_attempts": total_attempts,
        "total_points": user.get("total_points", 0),
        "topics": topics,
        "strengths": strengths,
        "weaknesses": weaknesses,
        "recent_scores": list(reversed(recent_scores)),
    }
