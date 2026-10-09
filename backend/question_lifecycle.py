"""Question master-copy and Daily 24h lifecycle helpers."""

from datetime import datetime, timedelta, timezone
from bson import ObjectId

from models import now_iso


async def ensure_master_copy(db, question: dict, admin_id: str | None = None) -> str:
    """Create the immutable master snapshot for a question if it has none."""
    existing_master = question.get("master_id")
    if existing_master:
        return str(existing_master)

    operational_id = str(question["_id"])
    existing = await db.question_masters.find_one(
        {"operational_question_id": operational_id}
    )
    if existing:
        master_id = str(existing["_id"])
    else:
        snapshot = {
            k: v for k, v in question.items()
            if k not in {"_id", "master_id", "source_question_id", "updated_at"}
        }
        snapshot.update({
            "operational_question_id": operational_id,
            "snapshot": snapshot.copy(),
            "created_by": admin_id or question.get("created_by"),
            "created_at": question.get("created_at") or now_iso(),
        })
        result = await db.question_masters.insert_one(snapshot)
        master_id = str(result.inserted_id)

    await db.questions.update_one(
        {"_id": question["_id"]}, {"$set": {"master_id": master_id}}
    )
    return master_id


async def create_mastered_question(db, doc: dict, admin_id: str) -> dict:
    """Insert an operational question and its permanent master snapshot."""
    result = await db.questions.insert_one(doc)
    doc["_id"] = result.inserted_id
    master_id = await ensure_master_copy(db, doc, admin_id)
    doc["master_id"] = master_id
    return doc


async def expire_daily_questions(db) -> int:
    """Move expired Daily 24h questions back to the Question Bank."""
    now = datetime.now(timezone.utc)
    now_value = now.isoformat()
    legacy_cutoff = (now - timedelta(hours=24)).isoformat()
    result = await db.questions.update_many(
        {
            "category": "daily_24h",
            "$or": [
                {"daily_expires_at": {"$lte": now_value}},
                {
                    "daily_expires_at": {"$exists": False},
                    "$or": [
                        {"published_at": {"$lte": legacy_cutoff}},
                        {"created_at": {"$lte": legacy_cutoff}},
                    ],
                },
            ],
        },
        {
            "$set": {
                "category": "question_bank",
                "is_published": True,
                "daily_expired_at": now_value,
                "updated_at": now_value,
            },
            "$unset": {"daily_expires_at": ""},
        },
    )
    return result.modified_count


async def delete_questions_and_orphaned_masters(db, object_ids: list[ObjectId]) -> int:
    questions = await db.questions.find({"_id": {"$in": object_ids}}).to_list(None)
    result = await db.questions.delete_many({"_id": {"$in": object_ids}})
    master_ids = {q.get("master_id") for q in questions if q.get("master_id")}
    for master_id in master_ids:
        if not await db.questions.find_one({"master_id": master_id}):
            try:
                await db.question_masters.delete_one({"_id": ObjectId(master_id)})
            except Exception:
                pass
    return result.deleted_count
