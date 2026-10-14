"""Regression tests for actionable email/password login status messages."""
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock

from fastapi import HTTPException, Response
from starlette.requests import Request

import server
from auth import hash_password
from models import LoginInput
from routers.auth_routes import login


def _request() -> Request:
    return Request({
        "type": "http",
        "method": "POST",
        "path": "/api/auth/login",
        "headers": [],
        "client": ("127.0.0.1", 12345),
    })


class TestLoginStatusMessages(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.original_db = server.db
        self.users = SimpleNamespace(find_one=AsyncMock())
        self.attempts = SimpleNamespace(
            find_one=AsyncMock(return_value=None),
            update_one=AsyncMock(),
        )
        server.db = SimpleNamespace(
            users=self.users,
            login_attempts=self.attempts,
        )

    async def asyncTearDown(self):
        server.db = self.original_db

    async def test_wrong_password_has_clear_status(self):
        self.users.find_one.return_value = {
            "email": "student@example.com",
            "password_hash": hash_password("Correct@123"),
        }
        with self.assertRaises(HTTPException) as raised:
            await login(
                LoginInput(email="student@example.com", password="Wrong@123"),
                _request(),
                Response(),
            )
        self.assertEqual(raised.exception.status_code, 401)
        self.assertEqual(raised.exception.detail, "Wrong password entered")

    async def test_phone_only_account_points_to_mobile_otp(self):
        self.users.find_one.return_value = {
            "email": "user_9876543210@studybook.com",
            "password_hash": "",
        }
        with self.assertRaises(HTTPException) as raised:
            await login(
                LoginInput(
                    email="user_9876543210@studybook.com",
                    password="Anything@123",
                ),
                _request(),
                Response(),
            )
        self.assertIn("Mobile OTP", raised.exception.detail)


if __name__ == "__main__":
    unittest.main()
