"""Pydantic models for C Maths."""
from datetime import datetime, timezone
from typing import List, Optional, Literal, Any
from pydantic import BaseModel, EmailStr, Field, ConfigDict


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


# ---------- Auth / Users ----------
class RegisterInput(BaseModel):
    name: str
    email: EmailStr
    phone: str
    password: str = Field(min_length=6)
    class_level: Optional[Literal["8", "9", "10"]] = None
    referral_code: Optional[str] = None
    avatar_url: Optional[str] = None
    verification_token: Optional[str] = None


class LoginInput(BaseModel):
    email: EmailStr
    password: str


class GoogleLoginInput(BaseModel):
    id_token: str
    class_level: Optional[Literal["8", "9", "10"]] = None
    referral_code: Optional[str] = None


class MobileSendOtpInput(BaseModel):
    phone: str


class MobileVerifyOtpInput(BaseModel):
    phone: str
    otp: str
    name: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    referral_code: Optional[str] = None
    verification_only: bool = False


class FirebasePhoneAuthInput(BaseModel):
    id_token: str
    name: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    referral_code: Optional[str] = None
    verification_only: bool = False


class ForgotPasswordInput(BaseModel):
    email: EmailStr


class ResetPasswordInput(BaseModel):
    token: str
    password: str = Field(min_length=6)


class ChangePasswordInput(BaseModel):
    current_password: str
    new_password: str = Field(min_length=6)
    confirm_password: str


class UserUpdateAdmin(BaseModel):
    """Admin-only user update: name, phone, class_level, role."""
    name: Optional[str] = None
    phone: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    role: Optional[Literal["student", "admin"]] = None


class SubscriptionPatch(BaseModel):
    """Admin-only subscription toggle."""
    subscription_active: bool
    duration_days: Optional[int] = None      # grant N days from now
    expires_at: Optional[str] = None         # or set explicit ISO expiry


class UserBulkSubscriptionInput(BaseModel):
    user_ids: List[str] = Field(min_length=1, max_length=500)
    premium_only: bool
    duration_days: int = Field(default=30, ge=1, le=1825)


# ---------- Question ----------
class QuestionOption(BaseModel):
    label: str
    text: str


class QuestionCreate(BaseModel):
    subject: str = "maths"
    class_level: Literal["8", "9", "10"]
    topic: str
    question_text: str
    q_type: Literal["mcq", "typed", "file_upload"] = "mcq"
    options: Optional[List[QuestionOption]] = None
    correct_index: Optional[int] = None
    correct_answer_text: Optional[str] = None
    explanation: Optional[str] = None
    positive_marks: float = 1.0
    negative_marks: float = 0.25
    difficulty: Literal["easy", "medium", "hard"] = "medium"
    image_url: Optional[str] = None
    allow_file_upload: Optional[bool] = False
    is_published: Optional[bool] = True
    publish_date: Optional[str] = None
    category: Optional[Literal["question_bank", "daily_24h", "draft"]] = "question_bank"
    premium_only: bool = False


class QuestionUpdate(BaseModel):
    subject: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    topic: Optional[str] = None
    question_text: Optional[str] = None
    q_type: Optional[Literal["mcq", "typed", "file_upload"]] = None
    options: Optional[List[QuestionOption]] = None
    correct_index: Optional[int] = None
    correct_answer_text: Optional[str] = None
    explanation: Optional[str] = None
    positive_marks: Optional[float] = None
    negative_marks: Optional[float] = None
    difficulty: Optional[Literal["easy", "medium", "hard"]] = None
    image_url: Optional[str] = None
    allow_file_upload: Optional[bool] = None
    is_published: Optional[bool] = None
    publish_date: Optional[str] = None
    category: Optional[Literal["question_bank", "daily_24h", "draft"]] = None
    premium_only: Optional[bool] = None


class QuestionBulkAction(BaseModel):
    question_ids: List[str] = Field(min_length=1, max_length=500)
    action: Literal[
        "delete", "move_question_bank", "move_draft", "publish_daily",
        "mark_free", "mark_premium"
    ]


# ---------- Test ----------
class TestCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    test_type: Literal["mock", "final"] = "mock"
    class_level: Literal["8", "9", "10"]
    subject: str = "maths"
    scheduled_date: Optional[str] = None  # legacy alias for start_date
    start_date: Optional[str] = None
    start_time: str = "20:00"  # HH:MM 24h
    end_date: Optional[str] = None
    end_time: Optional[str] = None
    duration_minutes: int = 60
    negative_marking: bool = True
    question_ids: List[str] = []
    is_published: bool = False
    unlock_score_required: Optional[float] = None
    prerequisite_test_id: Optional[str] = None
    premium_only: bool = False


class TestUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    scheduled_date: Optional[str] = None
    start_date: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    end_date: Optional[str] = None
    test_type: Optional[Literal["mock", "final"]] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    subject: Optional[str] = None
    duration_minutes: Optional[int] = None
    negative_marking: Optional[bool] = None
    question_ids: Optional[List[str]] = None
    is_published: Optional[bool] = None
    unlock_score_required: Optional[float] = None
    prerequisite_test_id: Optional[str] = None
    premium_only: Optional[bool] = None


class AnswerInput(BaseModel):
    question_id: str
    selected_index: Optional[int] = None
    typed_answer: Optional[str] = None


class SubmitTestInput(BaseModel):
    answers: List[AnswerInput]


# ---------- Video ----------
class VideoCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    url: str
    thumbnail_url: Optional[str] = None
    subject: str = "maths"
    class_level: Literal["8", "9", "10"]
    topic: Optional[str] = ""
    premium_only: bool = False


class VideoUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    subject: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    topic: Optional[str] = None
    premium_only: Optional[bool] = None


# ---------- Plan ----------
class PlanCreate(BaseModel):
    name: str
    description: Optional[str] = ""
    price: float
    currency: str = "inr"
    duration_days: int = 30
    features: List[str] = []
    is_active: bool = True


class PlanUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    duration_days: Optional[int] = None
    features: Optional[List[str]] = None
    is_active: Optional[bool] = None


# ---------- Payment ----------
class CheckoutInput(BaseModel):
    plan_id: str
    origin_url: Optional[str] = None


class RazorpayVerifyInput(BaseModel):
    razorpay_order_id: str = Field(min_length=1, max_length=100)
    razorpay_payment_id: str = Field(min_length=1, max_length=100)
    razorpay_signature: str = Field(min_length=1, max_length=256)


# ---------- Announcement ----------
class AnnouncementCreate(BaseModel):
    title: str
    body: str
    audience: Literal["all", "students", "admins"] = "all"
    class_level: Optional[str] = None  # None means all classes
    active: bool = True


# ---------- Study Notes ----------
class NoteCreate(BaseModel):
    title: str
    content: str
    class_level: Literal["8", "9", "10"]
    subject: str
    topic: str
    premium_only: bool = False


class NoteUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    subject: Optional[str] = None
    topic: Optional[str] = None
    premium_only: Optional[bool] = None


# ---------- Doubt Discussions ----------
class DiscussionThreadCreate(BaseModel):
    title: str
    body: str
    class_level: Literal["8", "9", "10"]
    subject: str
    topic: str


class DiscussionReplyCreate(BaseModel):
    body: str


# ---------- Flashcards ----------
class FlashcardCreate(BaseModel):
    subject: str = "maths"
    class_level: Literal["8", "9", "10"]
    topic: str
    front: str
    back: str
    premium_only: bool = False


class FlashcardUpdate(BaseModel):
    subject: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    topic: Optional[str] = None
    front: Optional[str] = None
    back: Optional[str] = None
    premium_only: Optional[bool] = None


# ---------- Promo Banners ----------
class PromoBannerCreate(BaseModel):
    title: str
    subtitle: str
    code: Optional[str] = ""
    link_url: Optional[str] = ""
    image_url: Optional[str] = ""
    countdown_hours: int = 24
    is_active: bool = True
    class_level: Optional[str] = "all"
    premium_only: bool = False


class PromoBannerUpdate(BaseModel):
    title: Optional[str] = None
    subtitle: Optional[str] = None
    code: Optional[str] = None
    link_url: Optional[str] = None
    image_url: Optional[str] = None
    countdown_hours: Optional[int] = None
    is_active: Optional[bool] = None
    class_level: Optional[str] = None
    premium_only: Optional[bool] = None


class ContentBulkPremiumInput(BaseModel):
    content_type: Literal["questions", "tests", "videos", "notes", "flashcards", "promos"]
    ids: List[str] = Field(min_length=1, max_length=500)
    premium_only: bool


class LeaderboardAttemptUpdate(BaseModel):
    score: Optional[float] = None
    total_marks: Optional[float] = None
    percent: Optional[float] = Field(default=None, ge=0, le=100)
    total_points: Optional[float] = None
    submitted: Optional[bool] = None
