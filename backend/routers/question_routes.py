"""Question bank endpoints."""
import csv
import io
from fastapi import APIRouter, HTTPException, Depends, Query, UploadFile, File
from bson import ObjectId
from typing import Optional
from models import QuestionCreate, QuestionUpdate, now_iso
from auth import get_current_user, require_role
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/questions", tags=["questions"])


def _ser(q):
    q = dict(q)
    q["_id"] = str(q["_id"])
    return q


# ============================================================
# IMPORTANT: Static sub-routes MUST come before /{qid} routes
# to prevent FastAPI from matching "bulk-csv" as a qid.
# ============================================================

@router.get("/topics")
async def list_topics(class_level: Optional[str] = None, category: Optional[str] = None, user=Depends(get_current_user)):
    from server import db
    if user["role"] == "student":
        class_level = user.get("class_level")
    match = {}
    if class_level:
        match["class_level"] = str(class_level)

    if category == "question_bank":
        match["$or"] = [
            {"category": "question_bank"},
            {"category": None},
            {"category": {"$exists": False}},
        ]
    elif category:
        match["category"] = category

    pipeline = [
        {"$match": match},
        {"$group": {"_id": {"class_level": "$class_level", "topic": "$topic"}, "count": {"$sum": 1}}},
        {"$sort": {"count": -1}},
    ]
    out = []
    async for doc in db.questions.aggregate(pipeline):
        out.append({
            "class_level": doc["_id"]["class_level"],
            "topic": doc["_id"]["topic"],
            "count": doc["count"],
        })
    return {"topics": out}


# BUG FIX: bulk-csv must be before /{qid} — otherwise FastAPI routes "bulk-csv" to get_question
@router.post("/bulk-csv")
async def bulk_upload_csv(
    file: UploadFile = File(...),
    admin=Depends(require_role("admin", "superadmin")),
):
    """CSV columns (header row required):
    subject, class_level, topic, question_text, q_type, option_a, option_b, option_c, option_d, correct_index,
    correct_answer_text, explanation, positive_marks, negative_marks, difficulty, image_url

    q_type = 'mcq' or 'typed'. For MCQ, correct_index is 0-3. For typed, use correct_answer_text.
    """
    from server import db
    raw = (await file.read()).decode("utf-8-sig", errors="replace")
    reader = csv.DictReader(io.StringIO(raw))
    inserted, errors = 0, []
    for i, row in enumerate(reader, start=2):
        try:
            q_type = (row.get("q_type") or "mcq").strip().lower()
            doc = {
                "subject": (row.get("subject") or "maths").strip(),
                "class_level": (row.get("class_level") or "10").strip(),
                "topic": (row.get("topic") or "").strip(),
                "question_text": (row.get("question_text") or "").strip(),
                "q_type": q_type,
                "options": None,
                "correct_index": None,
                "correct_answer_text": (row.get("correct_answer_text") or "").strip() or None,
                "explanation": (row.get("explanation") or "").strip(),
                "positive_marks": float(row.get("positive_marks") or 1.0),
                "negative_marks": float(row.get("negative_marks") or 0.25),
                "difficulty": (row.get("difficulty") or "medium").strip().lower(),
                "image_url": (row.get("image_url") or "").strip() or None,
                "category": (row.get("category") or "question_bank").strip().lower(),
                "is_published": True if (row.get("category") or "").strip().lower() != "draft" else False,
                "created_by": admin["_id"],
                "created_at": now_iso(),
            }
            if q_type == "mcq":
                labels = ["A", "B", "C", "D"]
                keys = ["option_a", "option_b", "option_c", "option_d"]
                opts = []
                for lbl, k in zip(labels, keys):
                    txt = (row.get(k) or "").strip()
                    if txt:
                        opts.append({"label": lbl, "text": txt})
                doc["options"] = opts
                ci = row.get("correct_index")
                doc["correct_index"] = int(ci) if ci not in (None, "") else 0
                if not doc["correct_answer_text"] and opts and doc["correct_index"] < len(opts):
                    doc["correct_answer_text"] = opts[doc["correct_index"]]["text"]
            if not doc["question_text"]:
                raise ValueError("question_text is empty")
            await db.questions.insert_one(doc)
            inserted += 1
        except Exception as e:
            errors.append({"row": i, "error": str(e)})
    logger.info(f"Bulk CSV upload: {inserted} inserted, {len(errors)} errors by admin {admin['_id']}")
    return {"inserted": inserted, "errors": errors}


@router.get("")
async def list_questions(
    class_level: Optional[str] = None,
    topic: Optional[str] = None,
    subject: Optional[str] = None,
    difficulty: Optional[str] = None,
    status: Optional[str] = None,
    category: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = Query(50, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(get_current_user),
):
    from server import db
    from datetime import datetime, timezone, timedelta

    conditions = []
    if user["role"] == "student":
        class_level = user.get("class_level")
        # Students ONLY see published questions (True or missing)
        conditions.append({"$or": [{"is_published": True}, {"is_published": {"$exists": False}}]})
    else:
        if status == "draft":
            conditions.append({"is_published": False})
        elif status == "published":
            conditions.append({"$or": [{"is_published": True}, {"is_published": {"$exists": False}}]})

    if category == "daily_24h":
        conditions.append({"category": "daily_24h"})
        if user["role"] == "student":
            cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).isoformat()
            conditions.append({
                "$or": [
                    {"created_at": {"$gte": cutoff}},
                    {"published_at": {"$gte": cutoff}},
                    {"updated_at": {"$gte": cutoff}},
                ]
            })
    elif category == "question_bank":
        conditions.append({"$or": [
            {"category": "question_bank"},
            {"category": None},
            {"category": {"$exists": False}},
        ]})
    elif category == "draft":
        conditions.append({"$or": [{"category": "draft"}, {"is_published": False}]})
    elif category:
        conditions.append({"category": category})

    if class_level:
        conditions.append({"class_level": str(class_level)})
    if topic:
        conditions.append({"topic": topic})
    if subject:
        conditions.append({"subject": subject})
    if difficulty and difficulty in ("easy", "medium", "hard"):
        conditions.append({"difficulty": difficulty})
    if search:
        conditions.append({"question_text": {"$regex": search, "$options": "i"}})

    q = {"$and": conditions} if conditions else {}

    cursor = db.questions.find(q).sort("_id", -1).skip(skip).limit(limit)
    items = [_ser(x) async for x in cursor]
    total = await db.questions.count_documents(q)

    # Attach 24h countdown only for daily_24h category; hide correct answer for non-admin students
    now_utc = datetime.now(timezone.utc)
    for it in items:
        cat = it.get("category") or "question_bank"
        it["category"] = cat
        if cat == "daily_24h":
            try:
                c_str = it.get("created_at") or ""
                dt = datetime.fromisoformat(c_str.replace("Z", "+00:00"))
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
                elapsed = (now_utc - dt).total_seconds()
                rem = max(0, int(86400 - elapsed))
                it["time_remaining_seconds"] = rem
                it["is_expired"] = rem <= 0
            except Exception:
                it["time_remaining_seconds"] = 0
                it["is_expired"] = True
        else:
            it["time_remaining_seconds"] = None
            it["is_expired"] = False

        if user["role"] == "student":
            it.pop("correct_answer_text", None)

    return {"items": items, "total": total, "skip": skip, "limit": limit}


@router.get("/{qid}")
async def get_question(qid: str, user=Depends(get_current_user)):
    from server import db
    try:
        oid = ObjectId(qid)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid question ID")
    q = await db.questions.find_one({"_id": oid})
    if not q:
        raise HTTPException(status_code=404, detail="Not found")
    if user["role"] == "student" and q.get("class_level") != user.get("class_level"):
        raise HTTPException(status_code=403, detail="Access denied to this question's class level")
    return _ser(q)


@router.post("/{qid}/check")
async def check_answer(qid: str, body: dict, user=Depends(get_current_user)):
    """Student practice mode - reveals answer after attempt and calculates daily bonus points."""
    from server import db
    from datetime import datetime, timezone
    try:
        oid = ObjectId(qid)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid question ID")
    q = await db.questions.find_one({"_id": oid})
    if not q:
        raise HTTPException(status_code=404, detail="Not found")
    if user["role"] == "student" and q.get("class_level") != user.get("class_level"):
        raise HTTPException(status_code=403, detail="Access denied to this question's class level")
    correct = False
    if q.get("q_type") == "mcq":
        correct = int(body.get("selected_index", -1)) == int(q.get("correct_index", -2))
    elif q.get("q_type") == "typed":
        answer_text = str(body.get("typed_answer", "")).strip().lower()
        correct = answer_text == str(q.get("correct_answer_text", "")).strip().lower()
    else:
        # File upload question — marked as attempted
        correct = True

    pos = float(q.get("positive_marks", 1.0))
    neg = float(q.get("negative_marks", 0.25))
    earned_pts = pos if correct else -neg

    daily_bonus_earned = False
    today_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Check question created_at date vs today_str
    q_created = str(q.get("created_at", ""))
    q_date = q_created[:10] if len(q_created) >= 10 else ""
    is_posted_today = (q_date == today_str)

    if user["role"] == "student":
        try:
            user_oid = ObjectId(user["_id"])

            # Check previous points earned on this question to compute net delta
            existing_attempt = await db.question_attempts.find_one({
                "user_id": str(user["_id"]),
                "question_id": str(q["_id"])
            })
            prev_earned = float(existing_attempt.get("points_earned", 0.0)) if existing_attempt else 0.0
            delta = earned_pts - prev_earned

            # Record student's attempt
            await db.question_attempts.update_one(
                {"user_id": str(user["_id"]), "question_id": str(q["_id"])},
                {"$set": {
                    "is_correct": correct,
                    "points_earned": earned_pts,
                    "date": today_str,
                    "q_posted_date": q_date,
                    "is_posted_today": is_posted_today,
                    "solved_at": now_iso()
                }},
                upsert=True
            )

            # Add/update net question marks in total_points
            if delta != 0:
                await db.users.update_one(
                    {"_id": user_oid},
                    {"$inc": {"total_points": round(delta, 2)}}
                )

            # Same-day completion bonus (+1.0 point) ONLY if questions were posted TODAY
            # and the student solves ALL questions posted today on the day itself!
            if is_posted_today:
                today_q_ids = [
                    str(x["_id"]) async for x in db.questions.find({
                        "class_level": user.get("class_level"),
                        "created_at": {"$regex": f"^{today_str}"}
                    })
                ]

                if today_q_ids:
                    solved_count = await db.question_attempts.count_documents({
                        "user_id": str(user["_id"]),
                        "question_id": {"$in": today_q_ids},
                        "date": today_str
                    })
                    bonus_dates = user.get("daily_bonus_dates", [])
                    if solved_count >= len(today_q_ids) and today_str not in bonus_dates:
                        await db.users.update_one(
                            {"_id": user_oid},
                            {
                                "$inc": {"total_points": 1.0},
                                "$push": {"daily_bonus_dates": today_str}
                            }
                        )
                        daily_bonus_earned = True
        except Exception as e:
            logger.error(f"Error checking daily points for user {user['_id']}: {e}")

    return {
        "correct": correct,
        "correct_index": q.get("correct_index"),
        "correct_answer_text": q.get("correct_answer_text"),
        "explanation": q.get("explanation"),
        "daily_bonus_earned": daily_bonus_earned,
    }


@router.post("")
async def create_question(body: QuestionCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()

    if not doc.get("category"):
        doc["category"] = "question_bank"

    if doc.get("category") == "draft":
        doc["is_published"] = False
    elif doc.get("is_published") is None:
        doc["is_published"] = True

    if doc.get("is_published"):
        doc["published_at"] = doc.get("publish_date") or now_iso()
    else:
        doc["published_at"] = None

    if doc.get("options"):
        doc["options"] = [o if isinstance(o, dict) else o.model_dump() for o in doc["options"]]
    result = await db.questions.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.put("/{qid}")
async def update_question(qid: str, body: QuestionUpdate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    try:
        oid = ObjectId(qid)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid question ID")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    if "options" in upd and upd["options"] is not None:
        upd["options"] = [o if isinstance(o, dict) else o.model_dump() for o in upd["options"]]

    if upd.get("category") == "daily_24h":
        upd["created_at"] = now_iso()
        upd["published_at"] = now_iso()
        upd["updated_at"] = now_iso()
        upd["is_published"] = True
        # Clear previous attempts so students must solve fresh!
        await db.question_attempts.delete_many({"question_id": str(oid)})
    elif upd.get("category") == "draft":
        upd["is_published"] = False
    elif upd.get("is_published") is True:
        upd["published_at"] = upd.get("publish_date") or now_iso()

    await db.questions.update_one({"_id": oid}, {"$set": upd})
    q = await db.questions.find_one({"_id": oid})
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")
    return _ser(q)


@router.post("/{qid}/publish")
async def publish_question(qid: str, body: Optional[dict] = None, admin=Depends(require_role("admin", "superadmin"))):
    """Toggle or set question published status and record published date."""
    from server import db
    try:
        oid = ObjectId(qid)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid question ID")
    q = await db.questions.find_one({"_id": oid})
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")
    
    current_pub = q.get("is_published", True)
    target_pub = body.get("is_published") if body and "is_published" in body else not current_pub
    
    upd = {
        "is_published": target_pub,
        "published_at": now_iso() if target_pub else None
    }
    if body and body.get("publish_date"):
        upd["publish_date"] = body["publish_date"]

    await db.questions.update_one({"_id": oid}, {"$set": upd})
    updated = await db.questions.find_one({"_id": oid})
    return _ser(updated)


@router.delete("/{qid}")
async def delete_question(qid: str, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    try:
        oid = ObjectId(qid)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid question ID")
    result = await db.questions.delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Question not found")
    return {"ok": True}
