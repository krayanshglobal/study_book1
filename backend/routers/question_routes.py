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
async def list_topics(class_level: Optional[str] = None, user=Depends(get_current_user)):
    from server import db
    if user["role"] == "student":
        class_level = user.get("class_level")
    match = {"class_level": class_level} if class_level else {}
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
    search: Optional[str] = None,
    limit: int = Query(50, le=500),
    skip: int = Query(0, ge=0),
    user=Depends(get_current_user),
):
    from server import db
    if user["role"] == "student":
        class_level = user.get("class_level")
    q: dict = {}
    if class_level:
        q["class_level"] = class_level
    if topic:
        q["topic"] = topic
    if subject:
        q["subject"] = subject
    if difficulty and difficulty in ("easy", "medium", "hard"):
        q["difficulty"] = difficulty
    if search:
        q["question_text"] = {"$regex": search, "$options": "i"}

    cursor = db.questions.find(q).sort("_id", -1).skip(skip).limit(limit)
    items = [_ser(x) async for x in cursor]
    total = await db.questions.count_documents(q)

    # For non-admin students, hide correct answer in list view
    if user["role"] == "student":
        for it in items:
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
    """Student practice mode - reveals answer after attempt."""
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
    correct = False
    if q.get("q_type") == "mcq":
        correct = int(body.get("selected_index", -1)) == int(q.get("correct_index", -2))
    else:
        answer_text = str(body.get("typed_answer", "")).strip().lower()
        correct = answer_text == str(q.get("correct_answer_text", "")).strip().lower()
    return {
        "correct": correct,
        "correct_index": q.get("correct_index"),
        "correct_answer_text": q.get("correct_answer_text"),
        "explanation": q.get("explanation"),
    }


# ---------- Admin ----------
@router.post("")
async def create_question(body: QuestionCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()
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
    await db.questions.update_one({"_id": oid}, {"$set": upd})
    q = await db.questions.find_one({"_id": oid})
    if not q:
        raise HTTPException(status_code=404, detail="Question not found")
    return _ser(q)


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
