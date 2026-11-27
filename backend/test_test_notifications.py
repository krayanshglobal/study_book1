"""Regression tests for student notifications emitted when tests are published."""

from copy import deepcopy
from datetime import datetime, timedelta, timezone
from unittest import IsolatedAsyncioTestCase
from unittest.mock import patch

from bson import ObjectId

from models import TestCreate as CreateTestModel
from models import TestUpdate as UpdateTestModel
from routers.test_routes import create_test, test_notifications as get_test_notifications, update_test


class _InsertResult:
    def __init__(self, inserted_id):
        self.inserted_id = inserted_id


class _UpdateResult:
    modified_count = 1


class _Cursor:
    def __init__(self, documents):
        self.documents = list(documents)
        self.position = 0

    def sort(self, fields, direction=None):
        sort_fields = fields if isinstance(fields, list) else [(fields, direction)]
        for field, order in reversed(sort_fields):
            self.documents.sort(
                key=lambda item: item.get(field) or "",
                reverse=order == -1,
            )
        return self

    def skip(self, count):
        self.documents = self.documents[count:]
        return self

    def limit(self, count):
        self.documents = self.documents[:count]
        return self

    def __aiter__(self):
        self.position = 0
        return self

    async def __anext__(self):
        if self.position >= len(self.documents):
            raise StopAsyncIteration
        document = deepcopy(self.documents[self.position])
        self.position += 1
        return document


class _Collection:
    def __init__(self, documents=None):
        self.documents = [deepcopy(item) for item in (documents or [])]

    @staticmethod
    def _matches(document, query):
        return all(document.get(key) == value for key, value in query.items())

    async def count_documents(self, query):
        return sum(self._matches(item, query) for item in self.documents)

    def find(self, query, projection=None):
        matches = [item for item in self.documents if self._matches(item, query)]
        if projection:
            fields = {key for key, included in projection.items() if included}
            matches = [
                {
                    key: value
                    for key, value in item.items()
                    if key == "_id" or key in fields
                }
                for item in matches
            ]
        return _Cursor(matches)

    async def find_one(self, query, projection=None):
        for item in self.documents:
            if self._matches(item, query):
                document = deepcopy(item)
                if projection:
                    fields = {key for key, included in projection.items() if included}
                    document = {
                        key: value
                        for key, value in document.items()
                        if key == "_id" or key in fields
                    }
                return document
        return None

    async def insert_one(self, document):
        inserted_id = ObjectId()
        stored = deepcopy(document)
        stored["_id"] = inserted_id
        self.documents.append(stored)
        return _InsertResult(inserted_id)

    async def update_one(self, query, update):
        for item in self.documents:
            if self._matches(item, query):
                item.update(deepcopy(update.get("$set", {})))
                break
        return _UpdateResult()

    async def update_many(self, _query, _update):
        return _UpdateResult()


class _Database:
    def __init__(self, tests=None):
        self.tests = _Collection(tests)
        self.questions = _Collection()


def _future_date():
    return (datetime.now(timezone.utc) + timedelta(days=2)).date().isoformat()


def _test_body(*, published):
    return CreateTestModel(
        title="Algebra Weekly Test",
        class_level="10",
        subject="maths",
        start_date=_future_date(),
        start_time="20:00",
        duration_minutes=60,
        is_published=published,
    )


class TestPublishedTestNotifications(IsolatedAsyncioTestCase):
    async def test_published_creation_records_first_publish_time(self):
        import server

        db = _Database()
        published_at = "2030-01-02T03:04:05+00:00"
        with patch.object(server, "db", db), patch(
            "routers.test_routes.now_iso", return_value=published_at
        ):
            result = await create_test(
                _test_body(published=True), admin={"_id": "admin-1"}
            )

        self.assertEqual(result["published_at"], published_at)
        self.assertEqual(db.tests.documents[0]["published_at"], published_at)

    async def test_draft_creation_has_no_notification_timestamp(self):
        import server

        db = _Database()
        with patch.object(server, "db", db), patch(
            "routers.test_routes.now_iso",
            return_value="2030-01-02T03:04:05+00:00",
        ):
            result = await create_test(
                _test_body(published=False), admin={"_id": "admin-1"}
            )

        self.assertNotIn("published_at", result)
        self.assertNotIn("published_at", db.tests.documents[0])

    async def test_first_publication_is_idempotent_across_later_edits(self):
        import server

        test_id = ObjectId()
        db = _Database([
            {
                "_id": test_id,
                "title": "Draft Test",
                "class_level": "10",
                "subject": "maths",
                "test_type": "mock",
                "start_date": _future_date(),
                "scheduled_date": _future_date(),
                "start_time": "20:00",
                "duration_minutes": 60,
                "question_ids": [],
                "is_published": False,
                "created_at": "2029-12-01T00:00:00+00:00",
            }
        ])
        first_publish = "2030-01-02T03:04:05+00:00"
        with patch.object(server, "db", db), patch(
            "routers.test_routes.now_iso",
            side_effect=[first_publish, "2030-01-02T03:04:06+00:00"],
        ):
            published = await update_test(
                str(test_id), UpdateTestModel(is_published=True), admin={"_id": "admin-1"}
            )

        self.assertEqual(published["published_at"], first_publish)

        with patch.object(server, "db", db), patch(
            "routers.test_routes.now_iso",
            return_value="2030-01-03T03:04:05+00:00",
        ):
            edited = await update_test(
                str(test_id), UpdateTestModel(title="Edited title"), admin={"_id": "admin-1"}
            )

        self.assertEqual(edited["published_at"], first_publish)

    async def test_feed_reaches_free_students_and_only_their_class(self):
        import server

        class_ten_id = ObjectId()
        legacy_id = ObjectId()
        db = _Database([
            {
                "_id": class_ten_id,
                "title": "New Class 10 Test",
                "class_level": "10",
                "is_published": True,
                "scheduled_date": "2030-02-01",
                "start_time": "18:00",
                "published_at": "2030-01-02T00:00:00+00:00",
                "created_at": "2030-01-01T00:00:00+00:00",
            },
            {
                "_id": legacy_id,
                "title": "Legacy Class 10 Test",
                "class_level": "10",
                "is_published": True,
                "scheduled_date": "2029-12-01",
                "start_time": "18:00",
                "created_at": "2029-11-01T00:00:00+00:00",
            },
            {
                "_id": ObjectId(),
                "title": "Class 9 Test",
                "class_level": "9",
                "is_published": True,
                "created_at": "2030-01-03T00:00:00+00:00",
            },
            {
                "_id": ObjectId(),
                "title": "Class 10 Draft",
                "class_level": "10",
                "is_published": False,
                "created_at": "2030-01-04T00:00:00+00:00",
            },
        ])

        with patch.object(server, "db", db):
            result = await get_test_notifications(
                limit=100,
                skip=0,
                user={
                    "_id": "student-1",
                    "role": "student",
                    "class_level": "10",
                    "subscription_active": False,
                },
            )

        self.assertEqual(result["total"], 2)
        self.assertEqual(
            {item["notification_id"] for item in result["items"]},
            {f"test_{class_ten_id}", f"test_{legacy_id}"},
        )
        newest = next(
            item for item in result["items"] if item["_id"] == str(class_ten_id)
        )
        self.assertEqual(newest["notification_at"], newest["published_at"])

    async def test_non_students_do_not_receive_student_test_notifications(self):
        import server

        db = _Database()
        with patch.object(server, "db", db):
            result = await get_test_notifications(
                limit=100,
                skip=0,
                user={"_id": "admin-1", "role": "admin", "class_level": "10"},
            )

        self.assertEqual(result, {"items": [], "total": 0})
