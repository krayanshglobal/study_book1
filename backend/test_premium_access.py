"""Focused tests for the global premium-content access gate."""
from datetime import datetime, timedelta, timezone
import unittest

from fastapi import HTTPException

from auth import has_active_premium, require_premium


class TestPremiumAccess(unittest.IsolatedAsyncioTestCase):
    async def test_free_student_is_rejected(self):
        user = {"role": "student", "subscription_active": False}
        with self.assertRaises(HTTPException) as raised:
            await require_premium(user)
        self.assertEqual(raised.exception.status_code, 402)

    async def test_active_premium_student_is_allowed(self):
        user = {
            "role": "student",
            "subscription_active": True,
            "subscription_expires_at": (
                datetime.now(timezone.utc) + timedelta(days=1)
            ).isoformat(),
        }
        self.assertIs(await require_premium(user), user)

    async def test_expired_premium_student_is_rejected(self):
        user = {
            "role": "student",
            "subscription_active": True,
            "subscription_expires_at": (
                datetime.now(timezone.utc) - timedelta(seconds=1)
            ).isoformat(),
        }
        self.assertFalse(has_active_premium(user))
        with self.assertRaises(HTTPException) as raised:
            await require_premium(user)
        self.assertEqual(raised.exception.status_code, 402)

    async def test_admin_is_allowed_without_subscription(self):
        user = {"role": "admin", "subscription_active": False}
        self.assertIs(await require_premium(user), user)


if __name__ == "__main__":
    unittest.main()
