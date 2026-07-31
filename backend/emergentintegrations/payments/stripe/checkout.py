class CheckoutSessionRequest:
    def __init__(self, amount, currency, success_url, cancel_url, metadata=None):
        self.amount = amount
        self.currency = currency
        self.success_url = success_url
        self.cancel_url = cancel_url
        self.metadata = metadata or {}

class CheckoutSession:
    def __init__(self, session_id, url):
        self.session_id = session_id
        self.url = url

class CheckoutStatus:
    def __init__(self, payment_status, status, amount_total, currency):
        self.payment_status = payment_status
        self.status = status
        self.amount_total = amount_total
        self.currency = currency

class WebhookEvent:
    def __init__(self, payment_status, session_id):
        self.payment_status = payment_status
        self.session_id = session_id

class StripeCheckout:
    def __init__(self, api_key, webhook_url):
        self.api_key = api_key
        self.webhook_url = webhook_url

    async def create_checkout_session(self, req: CheckoutSessionRequest):
        import uuid
        session_id = f"mock_session_{uuid.uuid4().hex}"
        url = req.success_url.replace("{CHECKOUT_SESSION_ID}", session_id)
        return CheckoutSession(session_id=session_id, url=url)

    async def get_checkout_status(self, session_id: str):
        return CheckoutStatus(
            payment_status="paid",
            status="complete",
            amount_total=100000,
            currency="inr"
        )

    async def handle_webhook(self, body: bytes, signature: str):
        return WebhookEvent(payment_status="paid", session_id="mock_session_123")
