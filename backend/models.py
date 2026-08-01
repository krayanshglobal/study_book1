"""Pydantic models for StudyBook."""
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


class LoginInput(BaseModel):
    email: EmailStr
    password: str


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


# ---------- Question ----------
class QuestionOption(BaseModel):
    label: str
    text: str


class QuestionCreate(BaseModel):
    subject: str = "maths"
    class_level: Literal["8", "9", "10"]
    topic: str
    question_text: str
    q_type: Literal["mcq", "typed"] = "mcq"
    options: Optional[List[QuestionOption]] = None
    correct_index: Optional[int] = None
    correct_answer_text: Optional[str] = None
    explanation: Optional[str] = None
    positive_marks: float = 1.0
    negative_marks: float = 0.25
    difficulty: Literal["easy", "medium", "hard"] = "medium"
    image_url: Optional[str] = None


class QuestionUpdate(BaseModel):
    subject: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    topic: Optional[str] = None
    question_text: Optional[str] = None
    q_type: Optional[Literal["mcq", "typed"]] = None
    options: Optional[List[QuestionOption]] = None
    correct_index: Optional[int] = None
    correct_answer_text: Optional[str] = None
    explanation: Optional[str] = None
    positive_marks: Optional[float] = None
    negative_marks: Optional[float] = None
    difficulty: Optional[Literal["easy", "medium", "hard"]] = None
    image_url: Optional[str] = None


# ---------- Test ----------
class TestCreate(BaseModel):
    title: str
    description: Optional[str] = ""
    test_type: Literal["mock", "final"] = "mock"
    class_level: Literal["8", "9", "10"]
    subject: str = "maths"
    scheduled_date: str  # ISO date "2026-02-15"
    start_time: str = "20:00"  # HH:MM 24h
    end_time: str = "21:00"
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
    start_time: Optional[str] = None
    end_time: Optional[str] = None
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
    origin_url: str


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


class FlashcardUpdate(BaseModel):
    subject: Optional[str] = None
    class_level: Optional[Literal["8", "9", "10"]] = None
    topic: Optional[str] = None
    front: Optional[str] = None
    back: Optional[str] = None


# ---------- Promo Banners ----------
class PromoBannerCreate(BaseModel):
    title: str
    subtitle: str
    code: Optional[str] = ""
    link_url: Optional[str] = ""
    countdown_hours: int = 24
    is_active: bool = True

