"""StudyBook FastAPI server entrypoint."""
from dotenv import load_dotenv
from pathlib import Path

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

import os
import logging
from datetime import datetime, timezone
from fastapi import FastAPI, APIRouter, Request
from fastapi.responses import JSONResponse
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient

from auth import hash_password, verify_password, generate_referral_code
from models import now_iso

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────
# Environment validation
# ─────────────────────────────────────────
_REQUIRED_ENV = ["MONGO_URL", "DB_NAME", "JWT_SECRET"]
_missing = [k for k in _REQUIRED_ENV if not os.environ.get(k)]
if _missing:
    raise EnvironmentError(f"Missing required environment variables: {', '.join(_missing)}")

# ─────────────────────────────────────────
# MongoDB
# ─────────────────────────────────────────
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

app = FastAPI(title="StudyBook API", version="1.0.0")

# ─────────────────────────────────────────
# Global exception handler (no traceback leakage in production)
# ─────────────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception on {request.method} {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again later."},
    )

# ─────────────────────────────────────────
# Import routers AFTER db is available
# ─────────────────────────────────────────
from routers.auth_routes import router as auth_router
from routers.question_routes import router as question_router
from routers.test_routes import router as test_router
from routers.misc_routes import router as misc_router
from routers.analytics_routes import router as analytics_router
from routers.study_features_routes import router as study_features_router

# Root api router
api_router = APIRouter(prefix="/api")


@api_router.get("/")
async def root():
    return {"status": "ok", "app": "StudyBook", "version": "1.0"}


@api_router.get("/health")
async def health():
    """Health-check endpoint — also pings MongoDB."""
    try:
        await client.admin.command("ping")
        return {"ok": True, "db": "connected"}
    except Exception as e:
        logger.error(f"Health check DB ping failed: {e}")
        return JSONResponse(status_code=503, content={"ok": False, "db": "unreachable"})


app.include_router(api_router)
app.include_router(auth_router)
app.include_router(question_router)
app.include_router(test_router)
app.include_router(misc_router)
app.include_router(analytics_router)
app.include_router(study_features_router)

# ─────────────────────────────────────────
# CORS
# ─────────────────────────────────────────
frontend_url = os.environ.get("FRONTEND_URL", "http://localhost:3000")
_origins = list({frontend_url, "http://localhost:3000"})
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────
# Seed helpers
# ─────────────────────────────────────────
async def _seed_user(email_env: str, pass_env: str, name: str, role: str):
    email = os.environ.get(email_env, "").lower().strip()
    password = os.environ.get(pass_env, "")
    if not email or not password:
        logger.warning(f"Seed skipped: {email_env} or {pass_env} not set")
        return None
    existing = await db.users.find_one({"email": email})
    if existing:
        updated = False
        if not verify_password(password, existing["password_hash"]):
            await db.users.update_one({"email": email}, {"$set": {"password_hash": hash_password(password)}})
            updated = True
        if existing.get("role") != role:
            await db.users.update_one({"email": email}, {"$set": {"role": role}})
            updated = True
        if updated:
            logger.info(f"Updated seed user: {email}")
        return existing
    doc = {
        "name": name,
        "email": email,
        "phone": "",
        "password_hash": hash_password(password),
        "role": role,
        "class_level": None,
        "referral_code": generate_referral_code(),
        "referred_by": None,
        "subscription_active": True,
        "subscription_expires_at": None,
        "total_points": 0,
        "created_at": now_iso(),
    }
    await db.users.insert_one(doc)
    logger.info(f"Seeded {role}: {email}")
    return doc


async def _seed_sample_data():
    """Seed a handful of sample questions and a demo mock test if empty."""
    if await db.questions.count_documents({}) > 0:
        return
    admin = await db.users.find_one({"role": "admin"})
    if not admin:
        return
    admin_id = str(admin["_id"])
    samples = [
        {
            "subject": "maths", "class_level": "8", "topic": "Algebra",
            "question_text": "Solve for x: 2x + 3 = 11",
            "q_type": "mcq",
            "options": [{"label": "A", "text": "3"}, {"label": "B", "text": "4"}, {"label": "C", "text": "5"}, {"label": "D", "text": "6"}],
            "correct_index": 1, "correct_answer_text": "4",
            "explanation": "2x = 8, so x = 4.",
            "positive_marks": 1.0, "negative_marks": 0.25, "difficulty": "easy",
            "created_by": admin_id, "created_at": now_iso(),
        },
        {
            "subject": "maths", "class_level": "9", "topic": "Geometry",
            "question_text": "The sum of interior angles of a triangle is:",
            "q_type": "mcq",
            "options": [{"label": "A", "text": "90°"}, {"label": "B", "text": "180°"}, {"label": "C", "text": "270°"}, {"label": "D", "text": "360°"}],
            "correct_index": 1, "correct_answer_text": "180",
            "explanation": "Interior angles of a triangle sum to 180 degrees.",
            "positive_marks": 1.0, "negative_marks": 0.25, "difficulty": "easy",
            "created_by": admin_id, "created_at": now_iso(),
        },
        {
            "subject": "maths", "class_level": "10", "topic": "Trigonometry",
            "question_text": "Value of sin(30°) is:",
            "q_type": "mcq",
            "options": [{"label": "A", "text": "1/2"}, {"label": "B", "text": "√3/2"}, {"label": "C", "text": "1"}, {"label": "D", "text": "0"}],
            "correct_index": 0, "correct_answer_text": "1/2",
            "explanation": "sin(30°) = 1/2.",
            "positive_marks": 1.0, "negative_marks": 0.25, "difficulty": "medium",
            "created_by": admin_id, "created_at": now_iso(),
        },
        {
            "subject": "maths", "class_level": "10", "topic": "Quadratic Equations",
            "question_text": "Discriminant of ax²+bx+c is:",
            "q_type": "typed",
            "options": None, "correct_index": None,
            "correct_answer_text": "b^2-4ac",
            "explanation": "Discriminant D = b² − 4ac.",
            "positive_marks": 2.0, "negative_marks": 0.5, "difficulty": "medium",
            "created_by": admin_id, "created_at": now_iso(),
        },
    ]
    result = await db.questions.insert_many(samples)
    qids = [str(_id) for _id in result.inserted_ids]

    if await db.plans.count_documents({}) == 0:
        await db.plans.insert_many([
            {
                "name": "Basic Monthly", "description": "Access to all question banks and weekly practice tests.",
                "price": 299.0, "currency": "inr", "duration_days": 30,
                "features": ["Unlimited question bank", "Weekly practice tests", "Analytics"],
                "is_active": True, "created_by": admin_id, "created_at": now_iso(),
            },
            {
                "name": "Premium Quarterly", "description": "Includes video lessons and advanced tests.",
                "price": 799.0, "currency": "inr", "duration_days": 90,
                "features": ["Everything in Basic", "Premium video lessons", "Unlocked advanced tests", "Priority support"],
                "is_active": True, "created_by": admin_id, "created_at": now_iso(),
            },
            {
                "name": "Elite Yearly", "description": "Full year of premium access.",
                "price": 2499.0, "currency": "inr", "duration_days": 365,
                "features": ["Everything in Premium", "Doubt sessions (email)", "Exclusive study material"],
                "is_active": True, "created_by": admin_id, "created_at": now_iso(),
            },
        ])

    if await db.videos.count_documents({}) == 0:
        await db.videos.insert_one({
            "title": "Introduction to Algebra — Class 8",
            "description": "Learn the basics of algebraic expressions.",
            "url": "https://www.youtube.com/watch?v=NybHckSEQBI",
            "thumbnail_url": "https://images.unsplash.com/photo-1509228468518-180dd4864904",
            "subject": "maths", "class_level": "8", "topic": "Algebra",
            "premium_only": False,
            "created_by": admin_id, "created_at": now_iso(),
        })

    if await db.study_notes.count_documents({}) == 0:
        await db.study_notes.insert_many([
            {
                "title": "Introduction to Algebraic Expressions",
                "content": "<p>An algebraic expression is formed from variables and constants using arithmetic operations.</p>",
                "subject": "maths",
                "class_level": "8",
                "topic": "Algebra",
                "premium_only": False,
                "created_by": admin_id,
                "created_at": now_iso()
            },
            {
                "title": "Trigonometric Identities Cheat Sheet",
                "content": "<p>Trigonometric identities are equations involving trig functions true for every value of the variables.</p>",
                "subject": "maths",
                "class_level": "10",
                "topic": "Trigonometry",
                "premium_only": True,
                "created_by": admin_id,
                "created_at": now_iso()
            }
        ])

    if await db.flashcards.count_documents({}) == 0:
        await db.flashcards.insert_many([
            {
                "subject": "maths", "class_level": "8", "topic": "Algebra",
                "front": "What is an Algebraic Term?",
                "back": "A term is a product of variables and constants, e.g., $3x$ or $-5y^2$.",
                "created_by": admin_id, "created_at": now_iso()
            },
            {
                "subject": "maths", "class_level": "10", "topic": "Trigonometry",
                "front": "What is $\\sin^2(\\theta) + \\cos^2(\\theta)$ equal to?",
                "back": "It is equal to $1$ for any angle $\\theta$.",
                "created_by": admin_id, "created_at": now_iso()
            }
        ])

    if await db.promos.count_documents({}) == 0:
        await db.promos.insert_many([
            {
                "title": "₹200 off for New Users",
                "subtitle": "Join StudyBook Premium today to unlock all videos, notes, and tests.",
                "code": "FIRST200",
                "countdown_hours": 36,
                "is_active": True,
                "created_by": admin_id,
                "created_at": now_iso()
            },
            {
                "title": "Launch Offer: Get up to 80% Off",
                "subtitle": "Unlock all advanced practice questions and discussion board replies.",
                "code": "LAUNCH80",
                "countdown_hours": 24,
                "is_active": True,
                "created_by": admin_id,
                "created_at": now_iso()
            }
        ])

    logger.info(f"Seeded {len(qids)} sample questions, plans, video, notes, flashcards, promos.")


async def _seed_test_credentials_file():
    """Write admin/test credentials to /app/memory/test_credentials.md."""
    memory_dir = ROOT_DIR.parent / "memory"
    memory_dir.mkdir(parents=True, exist_ok=True)
    content = f"""# StudyBook Test Credentials

## Admin
- Email: `{os.environ.get('ADMIN_EMAIL')}`
- Password: `{os.environ.get('ADMIN_PASSWORD')}`
- Role: admin

## SuperAdmin
- Email: `{os.environ.get('SUPERADMIN_EMAIL')}`
- Password: `{os.environ.get('SUPERADMIN_PASSWORD')}`
- Role: superadmin

## Test Premium Student
- Email: `premium@studybook.com`
- Password: `Premium@123`
- Role: student
- Subscription Status: Active Premium

## Test Student (register via UI)
- You may register a student at `/register`. Use any email + phone + password (min 6 chars).
- Or create programmatically via POST `/api/auth/register`.

## Auth Endpoints
- POST `/api/auth/register`
- POST `/api/auth/login`
- POST `/api/auth/logout`
- GET  `/api/auth/me`
- POST `/api/auth/refresh`
- POST `/api/auth/forgot-password`
- POST `/api/auth/reset-password`
"""
    (memory_dir / "test_credentials.md").write_text(content)


@app.on_event("startup")
async def _startup():
    logger.info("StudyBook API starting up...")
    try:
        # Verify MongoDB connectivity
        await client.admin.command("ping")
        logger.info("MongoDB connection: OK")
    except Exception as e:
        logger.error(f"MongoDB connection FAILED: {e}")
        # Don't raise — let the app start so /health can report the issue

    try:
        # Create indexes
        await db.users.create_index("email", unique=True)
        await db.users.create_index("referral_code")
        await db.users.create_index([("role", 1), ("total_points", -1)])
        await db.questions.create_index([("class_level", 1), ("topic", 1)])
        await db.questions.create_index([("question_text", "text")])   # text search index
        await db.tests.create_index([("scheduled_date", 1)])
        await db.test_attempts.create_index([("user_id", 1), ("test_id", 1)], unique=True)
        await db.test_attempts.create_index([("test_id", 1), ("score", -1)])
        await db.login_attempts.create_index("identifier")
        await db.password_reset_tokens.create_index("expires_at", expireAfterSeconds=0)
        await db.payment_transactions.create_index("session_id", unique=True)
        logger.info("MongoDB indexes: OK")

        # Seed users
        await _seed_user("ADMIN_EMAIL", "ADMIN_PASSWORD", "Admin", "admin")
        await _seed_user("SUPERADMIN_EMAIL", "SUPERADMIN_PASSWORD", "Super Admin", "superadmin")

        # Seed premium student
        existing_premium = await db.users.find_one({"email": "premium@studybook.com"})
        if not existing_premium:
            await db.users.insert_one({
                "name": "Premium Student",
                "email": "premium@studybook.com",
                "phone": "+1234567890",
                "password_hash": hash_password("Premium@123"),
                "role": "student",
                "class_level": "10",
                "referral_code": generate_referral_code(),
                "referred_by": None,
                "subscription_active": True,
                "subscription_expires_at": "2030-12-31T23:59:59Z",
                "total_points": 250,
                "created_at": now_iso(),
            })
            logger.info("Seeded premium student: premium@studybook.com")

        await _seed_sample_data()
        await _seed_test_credentials_file()
        logger.info("StudyBook API startup complete.")
    except Exception as e:
        logger.error(f"Startup error: {e}", exc_info=True)


@app.on_event("shutdown")
async def _shutdown():
    logger.info("StudyBook API shutting down...")
    client.close()
