"""Small server-side Razorpay client used by the payment routes.

Only the publishable key id may leave this module. The key secret is read from
the backend environment and is used exclusively for authenticated API calls and
signature verification.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
from typing import Any

import requests


class RazorpayGatewayError(RuntimeError):
    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.status_code = status_code


class RazorpayGateway:
    api_base = "https://api.razorpay.com/v1"

    def __init__(self) -> None:
        self.key_id = os.getenv("RAZORPAY_KEY_ID", "").strip()
        self.key_secret = os.getenv("RAZORPAY_KEY_SECRET", "").strip()
        if not self.key_id or not self.key_secret:
            raise RazorpayGatewayError(
                "Razorpay is not configured on the server", status_code=503
            )

    def _request(
        self, method: str, path: str, payload: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        try:
            response = requests.request(
                method,
                f"{self.api_base}{path}",
                auth=(self.key_id, self.key_secret),
                json=payload,
                timeout=20,
            )
        except requests.RequestException as exc:
            raise RazorpayGatewayError("Could not connect to Razorpay") from exc

        if response.ok:
            return response.json()

        message = "Razorpay rejected the payment request"
        try:
            data = response.json()
            message = data.get("error", {}).get("description") or message
        except (ValueError, TypeError):
            pass
        raise RazorpayGatewayError(message, status_code=502)

    def create_order(
        self,
        *,
        amount: int,
        currency: str,
        receipt: str,
        notes: dict[str, str],
    ) -> dict[str, Any]:
        return self._request(
            "POST",
            "/orders",
            {
                "amount": amount,
                "currency": currency.upper(),
                "receipt": receipt[:40],
                "notes": notes,
            },
        )

    def fetch_payment(self, payment_id: str) -> dict[str, Any]:
        return self._request("GET", f"/payments/{payment_id}")

    def capture_payment(
        self, payment_id: str, *, amount: int, currency: str
    ) -> dict[str, Any]:
        return self._request(
            "POST",
            f"/payments/{payment_id}/capture",
            {"amount": amount, "currency": currency.upper()},
        )

    def verify_payment_signature(
        self, *, order_id: str, payment_id: str, signature: str
    ) -> bool:
        expected = hmac.new(
            self.key_secret.encode("utf-8"),
            f"{order_id}|{payment_id}".encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        return hmac.compare_digest(expected, signature)


def verify_webhook_signature(body: bytes, signature: str) -> bool:
    secret = os.getenv("RAZORPAY_WEBHOOK_SECRET", "").strip()
    if not secret:
        raise RazorpayGatewayError(
            "Razorpay webhook secret is not configured", status_code=503
        )
    expected = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def decode_webhook(body: bytes) -> dict[str, Any]:
    try:
        return json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RazorpayGatewayError("Invalid webhook payload", status_code=400) from exc
