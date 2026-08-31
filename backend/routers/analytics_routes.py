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


# =============== DAILY PRACTICE ===============
@router.get("/api/students/daily-practice")
async def daily_practice(user=Depends(get_current_user)):
    """
    Returns today's 10 practice questions for the student's class level.
    Same set for the entire day (date-seeded random). Also returns
    which ones are already attempted and the student's current streak.
    """
    from server import db
    import random, hashlib

    class_level = user.get("class_level")
    if not class_level:
        return {"questions": [], "attempted_ids": [], "streak": 0, "completed": False}

    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # ── Collect eligible daily 24h questions (past 24h only) ─────────────
    cutoff_24h = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
    daily_uploaded_ids = [str(q["_id"]) async for q in db.questions.find(
        {
            "class_level": str(class_level),
            "category": "daily_24h",
            "$or": [
                {"created_at": {"$gte": cutoff_24h}},
                {"published_at": {"$gte": cutoff_24h}},
                {"updated_at": {"$gte": cutoff_24h}},
            ]
        },
        {"_id": 1}
    )]

    if not daily_uploaded_ids:
        return {
            "questions": [],
            "attempted_map": {},
            "attempted_ids": [],
            "total": 0,
            "completed": False,
            "streak": 0,
            "date": today_str,
        }

    daily_ids = daily_uploaded_ids[:10]

    # ── Fetch full question docs (hide correct answer) ──────────────────
    oid_list = [ObjectId(i) for i in daily_ids]
    questions = []
    async for q in db.questions.find({"_id": {"$in": oid_list}}):
        doc = {
            "_id": str(q["_id"]),
            "question_text": q.get("question_text", ""),
            "q_type": q.get("q_type", "mcq"),
            "options": q.get("options"),
            "positive_marks": q.get("positive_marks", 1.0),
            "negative_marks": q.get("negative_marks", 0.25),
            "difficulty": q.get("difficulty", "medium"),
            "topic": q.get("topic", ""),
            "image_url": q.get("image_url"),
        }
        questions.append(doc)

    # Preserve the seeded order
    order = {qid: i for i, qid in enumerate(daily_ids)}
    questions.sort(key=lambda x: order.get(x["_id"], 99))

    # ── Which ones has this student already attempted today? ────────────
    attempted = await db.question_attempts.find(
        {"user_id": str(user["_id"]), "question_id": {"$in": daily_ids}, "date": today_str},
        {"question_id": 1, "is_correct": 1}
    ).to_list(length=10)
    attempted_map = {a["question_id"]: a.get("is_correct") for a in attempted}
    attempted_ids = list(attempted_map.keys())
    completed = len(attempted_ids) >= len(daily_ids)

    # ── Streak calculation ─────────────────────────────────────────────
    streak = 0
    check_date = datetime.now(timezone.utc).date()
    # If today is not yet practiced, start checking from yesterday for streak
    has_today = await db.question_attempts.find_one(
        {"user_id": str(user["_id"]), "date": today_str}
    )
    if not has_today:
        check_date -= timedelta(days=1)

    for _ in range(365):
        date_str = check_date.isoformat()
        count = await db.question_attempts.count_documents(
            {"user_id": str(user["_id"]), "date": date_str}
        )
        if count > 0:
            streak += 1
            check_date -= timedelta(days=1)
        else:
            break
    if has_today:
        streak = max(streak, 1)

    return {
        "questions": questions,
        "attempted_map": attempted_map,
        "attempted_ids": attempted_ids,
        "total": len(daily_ids),
        "completed": completed,
        "streak": streak,
        "date": today_str,
    }


# =============== 1-MONTH ANALYSIS ===============
@router.get("/api/students/me/monthly-analysis")
async def student_monthly_analysis(user=Depends(get_current_user)):
    """
    30-day practice analysis: daily activity heatmap, topic breakdown,
    monthly totals and streak.
    """
    from server import db

    today = datetime.now(timezone.utc).date()
    thirty_days_ago = today - timedelta(days=29)

    # Build 30-day date buckets
    buckets: dict = {}
    for i in range(30):
        d = (thirty_days_ago + timedelta(days=i)).isoformat()
        buckets[d] = {"date": d, "questions": 0, "correct": 0, "accuracy": 0}

    # ── Map daily_24h question IDs to topics ──────────────────────────
    topic_stats: dict = defaultdict(lambda: {"correct": 0, "total": 0})
    daily_q_ids = set()
    qmap: dict = {}
    async for q in db.questions.find({"category": "daily_24h"}, {"topic": 1}):
        qid = str(q["_id"])
        daily_q_ids.add(qid)
        qmap[qid] = q.get("topic") or "General"

    total_q = 0
    total_correct = 0

    async for att in db.question_attempts.find(
        {"user_id": str(user["_id"]), "date": {"$gte": thirty_days_ago.isoformat()}}
    ):
        qid = att.get("question_id", "")
        if qid not in daily_q_ids:
            continue

        d = att.get("date", "")[:10]
        if d in buckets:
            buckets[d]["questions"] += 1
            total_q += 1
            if att.get("is_correct"):
                buckets[d]["correct"] += 1
                total_correct += 1
        topic = qmap.get(qid, "General")
        topic_stats[topic]["total"] += 1
        if att.get("is_correct"):
            topic_stats[topic]["correct"] += 1

    # Compute daily accuracy
    for d, b in buckets.items():
        if b["questions"] > 0:
            b["accuracy"] = round(100 * b["correct"] / b["questions"], 1)

    # ── Test attempts in last 30 days ──────────────────────────────────
    test_scores = []
    async for ta in db.test_attempts.find(
        {"user_id": str(user["_id"]), "submitted_at": {"$ne": None}}
    ).sort("submitted_at", -1).limit(30):
        d = (ta.get("submitted_at") or "")[:10]
        if d >= thirty_days_ago.isoformat():
            tid = ta.get("test_id", "")
            t = None
            if ObjectId.is_valid(tid):
                t = await db.tests.find_one({"_id": ObjectId(tid)}, {"title": 1})
            test_scores.append({
                "date": d,
                "title": t["title"] if t else "Test",
                "percent": ta.get("percent", 0),
            })

    # ── Topics for the month ──────────────────────────────────────────
    topics_month = []
    for topic, s in topic_stats.items():
        pct = round(100 * s["correct"] / s["total"], 1) if s["total"] else 0
        topics_month.append({"topic": topic, "questions": s["total"], "accuracy": pct})
    topics_month.sort(key=lambda x: -x["questions"])

    # ── Streak ────────────────────────────────────────────────────────
    streak = 0
    check = today
    today_str = today.isoformat()
    has_today = buckets.get(today_str, {}).get("questions", 0) > 0
    if not has_today:
        check -= timedelta(days=1)
    for _ in range(60):
        if buckets.get(check.isoformat(), {}).get("questions", 0) > 0:
            streak += 1
            check -= timedelta(days=1)
        else:
            # Check outside 30-day window
            ds = check.isoformat()
            cnt = await db.question_attempts.count_documents(
                {"user_id": str(user["_id"]), "date": ds}
            )
            if cnt > 0:
                streak += 1
                check -= timedelta(days=1)
            else:
                break

    best_day = max(buckets.values(), key=lambda x: x["questions"]) if buckets else {}
    overall_acc = round(100 * total_correct / total_q, 1) if total_q else 0

    return {
        "daily": list(buckets.values()),
        "total_questions": total_q,
        "total_correct": total_correct,
        "overall_accuracy": overall_acc,
        "streak": streak,
        "best_day": best_day,
        "topics": topics_month,
        "test_scores": test_scores,
    }

