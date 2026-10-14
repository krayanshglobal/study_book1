"""Tests for optional email support on Firebase phone registration."""
import unittest

from bson import ObjectId
from pydantic import ValidationError

import server
from models import FirebasePhoneAuthInput, MobileVerifyOtpInput
from routers.auth_routes import (
    _is_placeholder_email,
    _placeholder_email,
    update_profile,
)


class TestOptionalPhoneEmail(unittest.TestCase):
    def test_firebase_phone_email_can_be_omitted(self):
        body = FirebasePhoneAuthInput(id_token="verified-token")
        self.assertIsNone(body.email)

    def test_legacy_phone_email_can_be_omitted(self):
        body = MobileVerifyOtpInput(phone="9876543210", otp="123456")
        self.assertIsNone(body.email)

    def test_invalid_optional_email_is_rejected(self):
        with self.assertRaises(ValidationError):
            FirebasePhoneAuthInput(
                id_token="verified-token",
                email="not-an-email",
            )

    def test_placeholder_is_unique_to_normalized_phone(self):
        placeholder = _placeholder_email("+91 98765 43210")
        self.assertEqual(placeholder, "user_9876543210@studybook.com")
        self.assertTrue(_is_placeholder_email(placeholder))
        self.assertFalse(_is_placeholder_email("student@example.com"))


class _FakeUsers:
    def __init__(self, user):
        self.user = user

    async def find_one(self, query):
        if "email" in query:
            return None
        return dict(self.user)

    async def update_one(self, query, update):
        self.user.update(update["$set"])


class TestProfileEmailUpdate(unittest.IsolatedAsyncioTestCase):
    async def test_profile_response_contains_the_new_email(self):
        original_db = server.db
        oid = ObjectId()
        users = _FakeUsers({
            "_id": oid,
            "name": "Student",
            "email": "old@example.com",
            "phone": "9876543210",
            "firebase_uid": "firebase-user",
            "password_hash": "",
            "role": "student",
        })
        server.db = type("FakeDb", (), {"users": users})()
        try:
            result = await update_profile(
                {"email": "new@example.com"},
                {"_id": str(oid), "phone": "9876543210"},
            )
        finally:
            server.db = original_db

        self.assertEqual(result["email"], "new@example.com")


if __name__ == "__main__":
    unittest.main()
