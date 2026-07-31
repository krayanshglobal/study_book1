"""Router for study notes and doubt discussion board features."""
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, Depends, Request, Query
from bson import ObjectId
from typing import Optional, List
from models import (
    NoteCreate, NoteUpdate, DiscussionThreadCreate, DiscussionReplyCreate,
    FlashcardCreate, FlashcardUpdate, PromoBannerCreate, now_iso
)
from auth import get_current_user, require_role
import logging

logger = logging.getLogger(__name__)


def _safe_oid(val: str, field: str = "ID") -> ObjectId:
    try:
        return ObjectId(val)
    except Exception:
        raise HTTPException(status_code=400, detail=f"Invalid {field} format")

router = APIRouter(tags=["study_features"])


def _ser(x):
    if not x:
        return x
    x = dict(x)
    x["_id"] = str(x["_id"])
    return x


# =============== STUDY NOTES ===============
@router.get("/api/notes")
async def list_notes(
    class_level: Optional[str] = None,
    subject: Optional[str] = None,
    topic: Optional[str] = None,
    search: Optional[str] = None,
    user=Depends(get_current_user)
):
    from server import db
    q: dict = {}
    if class_level:
        q["class_level"] = class_level
    if subject:
        q["subject"] = subject.lower().strip()
    if topic:
        q["topic"] = topic.strip()
    if search:
        q["$or"] = [
            {"title": {"$regex": search, "$options": "i"}},
            {"content": {"$regex": search, "$options": "i"}},
        ]

    cursor = db.study_notes.find(q).sort("_id", -1)
    notes = []
    is_premium = user["role"] in ("admin", "superadmin") or user.get("subscription_active", False)
    async for doc in cursor:
        n = _ser(doc)
        if n.get("premium_only") and not is_premium:
            # Teaser content + locked flag
            n["locked"] = True
            n["contentTeaser"] = "Upgrade to premium to unlock this note."
            n["content"] = ""
        else:
            n["locked"] = False
        notes.append(n)
    return {"items": notes}


@router.get("/api/notes/{nid}")
async def get_note(nid: str, user=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(nid, "note ID")
    doc = await db.study_notes.find_one({"_id": oid})
    if not doc:
        raise HTTPException(404, "Note not found")
    n = _ser(doc)
    is_premium = user["role"] in ("admin", "superadmin") or user.get("subscription_active", False)
    if n.get("premium_only") and not is_premium:
        raise HTTPException(402, "Premium subscription required")
    n["locked"] = False
    return n


@router.post("/api/notes")
async def create_note(body: NoteCreate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = body.model_dump()
    doc["subject"] = doc["subject"].lower().strip()
    doc["created_by"] = admin["_id"]
    doc["created_at"] = now_iso()
    result = await db.study_notes.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.put("/api/notes/{nid}")
async def update_note(nid: str, body: NoteUpdate, admin=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(nid, "note ID")
    doc = await db.study_notes.find_one({"_id": oid})
    if not doc:
        raise HTTPException(404, "Note not found")
    up = {k: v for k, v in body.model_dump().items() if v is not None}
    if "subject" in up:
        up["subject"] = up["subject"].lower().strip()
    if up:
        await db.study_notes.update_one({"_id": oid}, {"$set": up})
        doc.update(up)
    return _ser(doc)


@router.delete("/api/notes/{nid}")
async def delete_note(nid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(nid, "note ID")
    await db.study_notes.delete_one({"_id": oid})
    return {"ok": True}


# =============== DOUBT DISCUSSION FORUMS ===============
@router.get("/api/discussions")
async def list_discussions(
    class_level: Optional[str] = None,
    subject: Optional[str] = None,
    topic: Optional[str] = None,
    _=Depends(get_current_user)
):
    from server import db
    q = {}
    if class_level:
        q["class_level"] = class_level
    if subject:
        q["subject"] = subject.lower().strip()
    if topic:
        q["topic"] = topic.strip()
        
    cursor = db.discussion_threads.find(q).sort("_id", -1)
    threads = []
    async for doc in cursor:
        t = _ser(doc)
        t["replies_count"] = len(t.get("replies", []))
        t["replies"] = []  # Clear for list view
        threads.append(t)
    return {"items": threads}


@router.get("/api/discussions/{tid}")
async def get_discussion(tid: str, _=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(tid, "thread ID")
    doc = await db.discussion_threads.find_one({"_id": oid})
    if not doc:
        raise HTTPException(404, "Thread not found")
    return _ser(doc)


@router.post("/api/discussions")
async def create_discussion(body: DiscussionThreadCreate, user=Depends(get_current_user)):
    from server import db
    doc = body.model_dump()
    doc["subject"] = doc["subject"].lower().strip()
    doc["user_id"] = user["_id"]
    doc["user_name"] = user["name"]
    doc["user_role"] = user["role"]
    doc["replies"] = []
    doc["created_at"] = now_iso()
    result = await db.discussion_threads.insert_one(doc)
    doc["_id"] = str(result.inserted_id)
    return doc


@router.post("/api/discussions/{tid}/reply")
async def reply_discussion(tid: str, body: DiscussionReplyCreate, user=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(tid, "thread ID")
    thread = await db.discussion_threads.find_one({"_id": oid})
    if not thread:
        raise HTTPException(404, "Thread not found")
    reply = {
        "reply_id": str(ObjectId()),
        "user_id": user["_id"],
        "user_name": user["name"],
        "role": user["role"],
        "body": body.body,
        "created_at": now_iso()
    }
    await db.discussion_threads.update_one(
        {"_id": oid},
        {"$push": {"replies": reply}}
    )
    return reply


@router.delete("/api/discussions/{tid}")
async def delete_discussion(tid: str, user=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(tid, "thread ID")
    thread = await db.discussion_threads.find_one({"_id": oid})
    if not thread:
        raise HTTPException(404, "Thread not found")
    is_owner = str(thread["user_id"]) == str(user["_id"])
    is_admin = user["role"] in ("admin", "superadmin")
    if not (is_owner or is_admin):
        raise HTTPException(403, "Not authorized to delete this thread")
    await db.discussion_threads.delete_one({"_id": oid})
    return {"ok": True}


@router.delete("/api/discussions/{tid}/reply/{rid}")
async def delete_reply(tid: str, rid: str, user=Depends(get_current_user)):
    from server import db
    oid = _safe_oid(tid, "thread ID")
    thread = await db.discussion_threads.find_one({"_id": oid})
    if not thread:
        raise HTTPException(404, "Thread not found")
    
    replies = thread.get("replies", [])
    reply_to_delete = None
    for r in replies:
        if r["reply_id"] == rid:
            reply_to_delete = r
            break
    
    if not reply_to_delete:
        raise HTTPException(404, "Reply not found")
        
    is_reply_owner = str(reply_to_delete["user_id"]) == str(user["_id"])
    is_thread_owner = str(thread["user_id"]) == str(user["_id"])
    is_admin = user["role"] in ("admin", "superadmin")
    
    if not (is_reply_owner or is_thread_owner or is_admin):
        raise HTTPException(403, "Not authorized to delete this reply")
        
    await db.discussion_threads.update_one(
        {"_id": oid},
        {"$pull": {"replies": {"reply_id": rid}}}
    )
    return {"ok": True}


# =============== FLASHCARDS ===============
import re

@router.get("/api/flashcards")
async def list_flashcards(
    class_level: Optional[str] = None,
    subject: Optional[str] = None,
    topic: Optional[str] = None,
    user=Depends(get_current_user)
):
    from server import db
    q = {}
    if class_level and class_level.strip() != "all":
        q["class_level"] = class_level.strip()
    if subject and subject.strip().lower() not in ("all", ""):
        s = subject.strip().lower()
        if "math" in s:
            q["subject"] = {"$regex": "^math", "$options": "i"}
        else:
            q["subject"] = {"$regex": f"^{re.escape(s)}$", "$options": "i"}

    if topic and topic.strip().lower() not in ("all", ""):
        t = topic.strip()
        q["$or"] = [
            {"topic": {"$regex": f"^{re.escape(t)}$", "$options": "i"}},
            {"topic": ""},
            {"topic": None},
            {"topic": {"$exists": False}}
        ]

    cursor = db.flashcards.find(q).sort("created_at", 1)
    items = await cursor.to_list(length=200)

    # Fallback 1: If topic filter returned 0 items, search for all flashcards in this class_level
    if not items and "class_level" in q:
        fallback_q = {"class_level": q["class_level"]}
        cursor = db.flashcards.find(fallback_q).sort("created_at", 1)
        items = await cursor.to_list(length=200)

    # Fallback 2: If still 0 items, return all flashcards available
    if not items:
        cursor = db.flashcards.find({}).sort("created_at", 1)
        items = await cursor.to_list(length=200)

    return {"locked": False, "items": [_ser(x) for x in items]}


@router.post("/api/flashcards")
async def create_flashcard(body: FlashcardCreate, user=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = {
        "subject": body.subject.lower().strip(),
        "class_level": body.class_level,
        "topic": body.topic.strip(),
        "front": body.front.strip(),
        "back": body.back.strip(),
        "created_at": now_iso(),
        "created_by": str(user["_id"])
    }
    res = await db.flashcards.insert_one(doc)
    doc["_id"] = str(res.inserted_id)
    return doc


@router.put("/api/flashcards/{fid}")
async def update_flashcard(fid: str, body: FlashcardUpdate, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(fid, "flashcard ID")
    upd = {k: v for k, v in body.model_dump().items() if v is not None}
    if "subject" in upd:
        upd["subject"] = upd["subject"].lower().strip()
    if not upd:
        raise HTTPException(status_code=400, detail="No fields to update")
    result = await db.flashcards.update_one({"_id": oid}, {"$set": upd})
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    fc = await db.flashcards.find_one({"_id": oid})
    return _ser(fc)


@router.delete("/api/flashcards/{fid}")
async def delete_flashcard(fid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(fid, "flashcard ID")
    await db.flashcards.delete_one({"_id": oid})
    return {"ok": True}


# =============== PROMO BANNERS ===============
@router.get("/api/promos")
async def list_promos():
    from server import db
    cursor = db.promos.find({"is_active": True}).sort("created_at", -1)
    items = await cursor.to_list(length=50)
    return {"items": [_ser(x) for x in items]}


@router.post("/api/promos")
async def create_promo(body: PromoBannerCreate, user=Depends(require_role("admin", "superadmin"))):
    from server import db
    doc = {
        "title": body.title.strip(),
        "subtitle": body.subtitle.strip(),
        "code": (body.code or "").upper().strip(),
        "link_url": (body.link_url or "").strip(),
        "countdown_hours": body.countdown_hours,
        "is_active": body.is_active,
        "created_at": now_iso(),
        "created_by": str(user["_id"])
    }
    res = await db.promos.insert_one(doc)
    doc["_id"] = str(res.inserted_id)
    return doc


@router.delete("/api/promos/{pid}")
async def delete_promo(pid: str, _=Depends(require_role("admin", "superadmin"))):
    from server import db
    oid = _safe_oid(pid, "promo ID")
    await db.promos.delete_one({"_id": oid})
    return {"ok": True}

