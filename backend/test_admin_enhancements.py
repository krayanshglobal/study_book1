"""Focused regression tests for admin scheduling and question lifecycle rules."""

from datetime import datetime, timedelta, timezone
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import AsyncMock, patch

from bson import ObjectId

from fastapi import HTTPException

from question_lifecycle import expire_daily_questions
from models import ContentBulkPremiumInput
from routers.misc_routes import _rank_test_leaderboard, bulk_content_premium
from routers.question_routes import get_question, list_questions
from routers.test_routes import _normalise_and_validate_schedule, _parse_scheduled


class TestScheduleValidation(TestCase):
    def future_date(self, days=2):
        return (datetime.now(timezone.utc) + timedelta(days=days)).date().isoformat()

    def test_final_end_must_follow_start(self):
        day = self.future_date()
        with self.assertRaises(HTTPException) as error:
            _normalise_and_validate_schedule({
                "test_type": "final", "start_date": day, "start_time": "10:00",
                "end_date": day, "end_time": "09:59", "duration_minutes": 60,
            })
        self.assertEqual(error.exception.status_code, 422)

    def test_mock_uses_duration_and_removes_end_time(self):
        start = self.future_date()
        end = self.future_date(7)
        result = _normalise_and_validate_schedule({
            "test_type": "mock", "start_date": start, "start_time": "10:00",
            "end_date": end, "end_time": "18:00", "duration_minutes": 45,
        })
        self.assertIsNone(result["end_time"])
        start_dt, end_dt = _parse_scheduled(result)
        self.assertGreater(end_dt, start_dt)

    def test_mock_end_date_cannot_precede_start(self):
        with self.assertRaises(HTTPException):
            _normalise_and_validate_schedule({
                "test_type": "mock", "start_date": self.future_date(5),
                "start_time": "10:00", "end_date": self.future_date(2),
                "duration_minutes": 45,
            })


class _UpdateResult:
    modified_count = 3


class _Questions:
    def __init__(self):
        self.query = None
        self.update = None

    async def update_many(self, query, update):
        self.query = query
        self.update = update
        return _UpdateResult()


class _FakeDb:
    def __init__(self):
        self.questions = _Questions()


class TestDailyQuestionLifecycle(IsolatedAsyncioTestCase):
    async def test_expired_daily_questions_move_to_bank_without_deletion(self):
        db = _FakeDb()
        changed = await expire_daily_questions(db)
        self.assertEqual(changed, 3)
        self.assertEqual(db.questions.query["category"], "daily_24h")
        self.assertEqual(db.questions.update["$set"]["category"], "question_bank")
        self.assertTrue(db.questions.update["$set"]["is_published"])
        self.assertNotIn("$delete", db.questions.update)


class TestLeaderboardRecalculation(TestCase):
    def test_score_correction_recalculates_order_and_ranks(self):
        rows = [
            {"name": "A", "score": 10, "total_marks": 20},
            {"name": "B", "score": 18, "total_marks": 20},
            {"name": "C", "score": 15, "total_marks": 20},
        ]
        ranked = _rank_test_leaderboard(rows, 10)
        self.assertEqual([row["name"] for row in ranked], ["B", "C", "A"])
        self.assertEqual([row["rank"] for row in ranked], [1, 2, 3])


class _Cursor:
    def sort(self, *_args): return self
    def skip(self, *_args): return self
    def limit(self, *_args): return self
    def __aiter__(self): return self
    async def __anext__(self): raise StopAsyncIteration


class _Result:
    modified_count = 2


class _Collection:
    def __init__(self, document=None):
        self.document = document
        self.query = None
        self.update = None
        self.inserted = None

    def find(self, query):
        self.query = query
        return _Cursor()

    async def find_one(self, _query): return self.document
    async def count_documents(self, _query): return 0
    async def update_many(self, query, update):
        self.query, self.update = query, update
        return _Result()
    async def insert_one(self, document): self.inserted = document


class _ApiDb:
    def __init__(self, question=None):
        self.questions = _Collection(question)
        self.admin_audit_logs = _Collection()
        self.videos = _Collection()

    def __getitem__(self, name): return getattr(self, name)


class TestFilteringBulkAndPremiumAccess(IsolatedAsyncioTestCase):
    async def test_question_filters_reach_database_query(self):
        import server
        db = _ApiDb()
        with patch.object(server, "db", db), patch(
            "routers.question_routes.expire_daily_questions", new=AsyncMock(return_value=0)
        ):
            await list_questions(
                class_level="10", difficulty="hard", premium="premium",
                created_from="2030-01-01", user={"role": "admin"},
            )
        query_text = str(db.questions.query)
        self.assertIn("difficulty", query_text)
        self.assertIn("premium_only", query_text)
        self.assertIn("created_at", query_text)

    async def test_bulk_premium_updates_selected_records_and_audits(self):
        import server
        db = _ApiDb()
        ids = [str(ObjectId()), str(ObjectId())]
        with patch.object(server, "db", db):
            result = await bulk_content_premium(
                ContentBulkPremiumInput(content_type="videos", ids=ids, premium_only=True),
                admin={"_id": "admin-1"},
            )
        self.assertEqual(result["changed"], 2)
        self.assertTrue(db.videos.update["$set"]["premium_only"])
        self.assertEqual(db.admin_audit_logs.inserted["action"], "content.bulk_premium")

    async def test_free_student_cannot_open_premium_question(self):
        import server
        question_id = ObjectId()
        db = _ApiDb({
            "_id": question_id, "class_level": "10", "premium_only": True,
        })
        with patch.object(server, "db", db):
            with self.assertRaises(HTTPException) as error:
                await get_question(
                    str(question_id),
                    user={"role": "student", "class_level": "10", "subscription_active": False},
                )
        self.assertEqual(error.exception.status_code, 402)

