"""Test scheduling, attempts, submissions, results."""
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, HTTPException, Depends, Query
from bson import ObjectId
from typing import Optional
from models import TestCreate, TestUpdate, SubmitTestInput, now_iso
from auth import get_current_user, require_role
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/tests", tags=["tests"])


def _ser(x):
    if not x:
        return x
    x = dict(x)
    x["_id"] = str(x["_id"])
    return x


def _safe_oid(val: str, field: str = "ID") -> ObjectId:
    try:
        return ObjectId(val)
    except Exception:
        raise HTTPException(status_code=400, detail=f"Invalid {field} format")


def _parse_scheduled(test: dict) -> tuple:
    """Return (start_dt, end_dt) timezone-aware IST datetimes for a test."""
    date_str = test["scheduled_date"]
    start_dt = datetime.fromisoformat(f"{date_str}T{test.get('start_time', '20:00')}:00+05:30")
    end_dt = datetime.fromisoformat(f"{date_str}T{test.get('end_time', '21:00')}:00+05:30")
    if end_dt <= start_dt:
        end_dt = end_dt + timedelta(days=1)
    return start_dt, end_dt


@router.get("")
async def list_tests(
    class_level: Optional[str] = None,
    test_type: Optional[str] = None,
    limit: int = Query(50, le=200),
    skip: int = Query(0, ge=0),
    user=Depends(get_current_user),
):
    from server import db
    q: dict = {}
    if user["role"] == "student":
        q["is_published"] = True
        if user.get("class_level"):
            q["class_level"] = user["class_level"]
    else:
        if class_level:
            q["class_level"] = class_level
    if test_type and test_type in ("mock", "final"):
        q["test_type"] = test_type

    cursor = db.tests.find(q).sort("scheduled_date", -1).skip(skip).limit(limit)
    items = [_ser(t) async for t in cursor]
    total = await db.tests.count_documents(q)

    # Attach attempt info + lock status for student
    if user["role"] == "student":
        for t in items:
            attempt = await db.test_attempts.find_one({
                "user_id": user["_id"], "test_id": t["_id"], "submitted_at": {"$ne": None}
            })
            t["my_score"] = attempt.get("score") if attempt else None
            t["my_attempt_id"] = str(attempt["_id"]) if attempt else None
            t["locked"] = False
            if t.get("unlock_score_required") is not None and t.get("prerequisite_test_id"):
                prereq_attempt = await db.test_attempts.find_one({
                    "user_id": user["_id"], "test_id": t["prerequisite_test_id"], "submitted_at": {"$ne": None}
                })
                if not prereq_attempt or (prereq_attempt.get("percent", 0) < t["unlock_score_required"]):
                    t["locked"] = True
            if t.get("premium_only") and not user.get("subscription_active"):
                t["locked"] = True
                t["premium_locked"] = True
    return {"items": items, "total": total}


@router.get("/upcoming")
async def upcoming(user=Depends(get_current_user)):
    from server import db
    today = datetime.now(timezone.utc).date().isoformat()
    q: dict = {"is_published": True, "scheduled_date": {"$gte": today}}
    if user.get("class_level"):
        q["class_level"] = user["class_level"]
    cursor = db.tests.find(q).sort("scheduled_date", 1).limit(10)
    return {"items": [_ser(t) async for t in cursor]}


@router.get("/my-results")
async def my_results(
    limit: int = Query(20, le=100),
    skip: int = Query(0, ge=0),
    user=Depends(get_current_user),
):
    """All submitted test attempts for the current user, with test titles."""
    from server import db
    q = {"user_id": user["_id"], "submitted_at": {"$ne": None}}
    cursor = db.test_attempts.find(q).sort("submitted_at", -1).skip(skip).limit(limit)
    total = await db.test_attempts.count_documents(q)
    items = []
    async for att in cursor:
        att = _ser(att)
        if ObjectId.is_valid(att.get("test_id", "")):
            t = await db.tests.find_one({"_id": ObjectId(att["test_id"])}, {"title": 1, "class_level": 1})
            att["test_title"] = t["title"] if t else "Unknown Test"
            att["test_class"] = t.get("class_level") if t else None
        else:
            att["test_title"] = "Unknown Test"
            att["test_class"] = None
        items.append(att)
    return {"items": items, "total": total}


@router.get("/{tid}")
async def get_test(tid: str, user=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(tid, "test ID")
    t = await db.tests.find_one({"_id": oid})
    if not t:
        raise HTTPException(status_code=404, detail="Not found")
    if user["role"] == "student" and not t.get("is_published"):
        raise HTTPException(status_code=404, detail="Not found")
    return _ser(t)


@router.post("/{tid}/start")
async def start_test(tid: str, user=Depends(get_current_user)):
    """Start / resume a test attempt. Returns questions (without correct answers) and remaining time."""
    from server import db
    oid = _safe_oid(tid, "test ID")
    t = await db.tests.find_one({"_id": oid})
    if not t:
        raise HTTPException(status_code=404, detail="Test not found")
    if not t.get("is_published"):
        raise HTTPException(status_code=403, detail="Test not published")

    # Premium + lock checks
    if t.get("premium_only") and not user.get("subscription_active"):
        raise HTTPException(status_code=402, detail="Premium subscription required")
    if t.get("unlock_score_required") is not None and t.get("prerequisite_test_id"):
        prereq = await db.test_attempts.find_one({
            "user_id": user["_id"],
            "test_id": t["prerequisite_test_id"],
            "submitted_at": {"$ne": None},
        })
        if not prereq or (prereq.get("percent", 0) < t["unlock_score_required"]):
            raise HTTPException(status_code=403, detail="Prerequisite not met")

    # Time window check
    start_dt, end_dt = _parse_scheduled(t)
    now = datetime.now(timezone.utc)
    if now < start_dt:
        raise HTTPException(status_code=403, detail=f"Test starts at {t['start_time']} IST on {t['scheduled_date']}")
    if now > end_dt:
        raise HTTPException(status_code=403, detail="Test window has ended")

    # Load or create attempt
    attempt = await db.test_attempts.find_one({"user_id": user["_id"], "test_id": tid})
    if attempt and attempt.get("submitted_at"):
        raise HTTPException(status_code=400, detail="Already submitted")
    if not attempt:
        dur_end = now + timedelta(minutes=t.get("duration_minutes", 60))
        deadline = min(dur_end, end_dt)
        attempt_doc = {
            "user_id": user["_id"],
            "test_id": tid,
            "started_at": now_iso(),
            "deadline_at": deadline.isoformat(),
            "submitted_at": None,
            "answers": [],
            "score": 0.0,
            "percent": 0.0,
        }
        result = await db.test_attempts.insert_one(attempt_doc)
        attempt = await db.test_attempts.find_one({"_id": result.inserted_id})

    # Load questions (strip correct answers for students)
    qids = [ObjectId(q) for q in t.get("question_ids", [])]
    questions = []
    async for q in db.questions.find({"_id": {"$in": qids}}):
        q = _ser(q)
        q.pop("correct_index", None)
        q.pop("correct_answer_text", None)
        q.pop("explanation", None)
        questions.append(q)

    return {
        "attempt_id": str(attempt["_id"]),
        "test": _ser(t),
        "questions": questions,
        "deadline_at": attempt["deadline_at"],
        "started_at": attempt["started_at"],
    }


@router.post("/{tid}/submit")
async def submit_test(tid: str, body: SubmitTestInput, user=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(tid, "test ID")
    t = await db.tests.find_one({"_id": oid})
    if not t:
        raise HTTPException(status_code=404, detail="Test not found")
    attempt = await db.test_attempts.find_one({"user_id": user["_id"], "test_id": tid})
    if not attempt:
        raise HTTPException(status_code=404, detail="Attempt not found. Start the test first.")
    if attempt.get("submitted_at"):
        raise HTTPException(status_code=400, detail="Already submitted")

    qids = [ObjectId(q) for q in t.get("question_ids", [])]
    questions: dict = {}
    async for q in db.questions.find({"_id": {"$in": qids}}):
        questions[str(q["_id"])] = q

    score = 0.0
    total = 0.0
    correct_count = 0
    incorrect_count = 0
    unanswered = 0
    detailed = []

    for ans in body.answers:
        q = questions.get(ans.question_id)
        if not q:
            continue
        pos = float(q.get("positive_marks", 1.0))
        neg = float(q.get("negative_marks", 0.25)) if t.get("negative_marking", True) else 0.0
        total += pos
        is_correct = False
        answered = False
        if q.get("q_type") == "mcq":
            if ans.selected_index is not None:
                answered = True
                is_correct = int(ans.selected_index) == int(q.get("correct_index", -2))
        else:
            if ans.typed_answer is not None and str(ans.typed_answer).strip():
                answered = True
                is_correct = str(ans.typed_answer).strip().lower() == str(q.get("correct_answer_text", "")).strip().lower()

        if not answered:
            unanswered += 1
        elif is_correct:
            score += pos
            correct_count += 1
        else:
            score -= neg
            incorrect_count += 1

        detailed.append({
            "question_id": ans.question_id,
            "selected_index": ans.selected_index,
            "typed_answer": ans.typed_answer,
            "is_correct": is_correct,
            "answered": answered,
        })

    # Account for questions not included in the submission
    submitted_qids = {a.question_id for a in body.answers}
    for qid, q in questions.items():
        if qid not in submitted_qids:
            total += float(q.get("positive_marks", 1.0))
            unanswered += 1

    percent = round((score / total) * 100, 2) if total > 0 else 0.0

    await db.test_attempts.update_one(
        {"_id": attempt["_id"]},
        {"$set": {
            "submitted_at": now_iso(),
            "answers": detailed,
            "score": round(score, 2),
            "total_marks": round(total, 2),
            "percent": percent,
            "correct_count": correct_count,
            "incorrect_count": incorrect_count,
            "unanswered": unanswered,
        }},
    )

    # Update user's total points
    try:
        uid_oid = ObjectId(user["_id"])
        await db.users.update_one({"_id": uid_oid}, {"$inc": {"total_points": max(int(score), 0)}})
    except Exception as e:
        logger.error(f"Failed to update total_points for user {user['_id']}: {e}")

    return {
        "score": round(score, 2),
        "total_marks": round(total, 2),
        "percent": percent,
        "correct": correct_count,
        "incorrect": incorrect_count,
        "unanswered": unanswered,
        "attempt_id": str(attempt["_id"]),
    }


@router.get("/{tid}/result")
async def my_result(tid: str, user=Depends(get_current_user)):
    from server import db
    attempt = await db.test_attempts.find_one({"user_id": user["_id"], "test_id": tid, "submitted_at": {"$ne": None}})
    if not attempt:
        raise HTTPException(status_code=404, detail="No result found")
    oid = _safe_oid(tid, "test ID")
    t = await db.tests.find_one({"_id": oid})
    qids = [ObjectId(q) for q in t.get("question_ids", [])] if t else []
    questions = []
    async for q in db.questions.find({"_id": {"$in": qids}}):
        questions.append(_ser(q))
    return {
        "attempt": _ser(attempt),
        "test": _ser(t) if t else None,
        "questions": questions,
    }


# ---------- Admin ----------
@router.post("")
async def create_test(body: TestCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()
    result = await db.tests.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.put("/{tid}")
async def update_test(tid: str, body: TestUpdate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(tid, "test ID")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    await db.tests.update_one({"_id": oid}, {"$set": upd})
    t = await db.tests.find_one({"_id": oid})
    if not t:
        raise HTTPException(status_code=404, detail="Test not found")
    return _ser(t)


@router.delete("/{tid}")
async def delete_test(tid: str, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(tid, "test ID")
    result = await db.tests.delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Test not found")
    return {"ok": True}


@router.get("/{tid}/leaderboard")
async def test_leaderboard(tid: str, _=Depends(get_current_user)):
    from server import db
    cursor = db.test_attempts.find({"test_id": tid, "submitted_at": {"$ne": None}}).sort("score", -1).limit(100)
    out = []
    rank = 1
    async for a in cursor:
        u = None
        try:
            u = await db.users.find_one({"_id": ObjectId(a["user_id"])})
        except Exception:
            pass
        out.append({
            "rank": rank,
            "user_id": a["user_id"],
            "name": u["name"] if u else "Student",
            "class_level": u.get("class_level") if u else None,
            "score": a.get("score", 0),
            "percent": a.get("percent", 0),
            "submitted_at": a.get("submitted_at"),
        })
        rank += 1
    return {"items": out}


@router.get("/{tid}/attempts")
async def all_attempts(tid: str, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    cursor = db.test_attempts.find({"test_id": tid}).sort("submitted_at", -1)
    items = []
    async for a in cursor:
        u = None
        try:
            u = await db.users.find_one({"_id": ObjectId(a["user_id"])})
        except Exception:
            pass
        it = _ser(a)
        it["user_name"] = u["name"] if u else None
        it["user_email"] = u["email"] if u else None
        items.append(it)
    return {"items": items}
