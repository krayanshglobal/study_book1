<div align="center">
  <img src="https://customer-assets-eiarnc6j.emergentagent.net/job_leaderbook-study/artifacts/8fbe1ch1_image.png" alt="StudyBook" width="140" />

  # StudyBook — Premium Learning Platform

  **Learn • Focus • Achieve**

  A production-ready, full-stack, multi-tenant learning platform built with **FastAPI + MongoDB + React**. Beautifully designed. Made to scale.

  ![Python](https://img.shields.io/badge/python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)
  ![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?style=for-the-badge&logo=fastapi&logoColor=white)
  ![MongoDB](https://img.shields.io/badge/MongoDB-Motor-47A248?style=for-the-badge&logo=mongodb&logoColor=white)
  ![React](https://img.shields.io/badge/React-19-61DAFB?style=for-the-badge&logo=react&logoColor=black)
  ![Tailwind](https://img.shields.io/badge/Tailwind-3.4-06B6D4?style=for-the-badge&logo=tailwindcss&logoColor=white)
  ![Shadcn UI](https://img.shields.io/badge/Shadcn-UI-0F1B4C?style=for-the-badge)
  ![Stripe](https://img.shields.io/badge/Stripe-Payments-635BFF?style=for-the-badge&logo=stripe&logoColor=white)
  ![KaTeX](https://img.shields.io/badge/KaTeX-Math-329F00?style=for-the-badge)
  ![PWA](https://img.shields.io/badge/PWA-Installable-5A0FC8?style=for-the-badge&logo=pwa&logoColor=white)
  ![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
</div>

---

## Table of contents

1. [What is StudyBook?](#what-is-studybook)
2. [Feature highlights](#feature-highlights)
3. [Screenshots](#screenshots)
4. [Architecture](#architecture)
5. [Tech stack & why](#tech-stack--why)
6. [Project structure](#project-structure)
7. [Quick start](#quick-start)
8. [Environment variables](#environment-variables)
9. [Seeded accounts](#seeded-accounts)
10. [API reference](#api-reference)
11. [CSV bulk-upload format](#csv-bulk-upload-format)
12. [LaTeX support](#latex-support)
13. [Deployment](#deployment)
14. [Roadmap](#roadmap)
15. [License](#license)

---

## What is StudyBook?

**StudyBook** is a premium, multi-role learning platform where an admin can build an entire course experience — question banks, scheduled live tests, video lessons, subscription plans, announcements — while students learn, practice, take tests inside a live window and see their progress in a beautifully designed UI.

It ships with three roles out of the box:

| Role | Powers |
| --- | --- |
| **Student** | Practice from the question bank, take scheduled mock/final tests during their live window, watch videos, subscribe to premium, invite friends via referral code |
| **Admin** | Upload questions (single or bulk CSV), schedule tests, gate final tests behind a minimum score on a prerequisite, publish video URLs, create/edit subscription plans in ₹, broadcast announcements, see platform-wide stats |
| **SuperAdmin** | Everything admins can do + create/delete admin accounts |

---

## Feature highlights

### Learning & assessment
- **Question bank** — MCQ *and* typed-answer questions, per-question positive/negative marks, difficulty, image URLs, class + topic taxonomy
- **Bulk CSV upload** — admins upload hundreds of questions in one click using a downloadable template
- **LaTeX math rendering** — write `$ax^2+bx+c$` or `$$\int_0^1 f(x)dx$$` anywhere in questions/options/explanations; rendered with **KaTeX**
- **Live scheduled tests** — start & end time enforced server-side; if a student joins late their submission deadline is still capped at the test end time
- **Auto-grading with negative marking** — instant score with correct/incorrect/unanswered breakdown
- **Class Switch Requests & Admin Approval** — students select their class (8, 9, or 10) during registration; subsequent changes require admin approval through a dedicated requests dashboard.
- **Unlockable finals** — set `unlock_score_required` on a final test and pick a prerequisite mock; students below the threshold see a locked card
- **Test reminders** — a banner appears on the student dashboard for tests within the next 24 h, plus a browser Notification 15 min before start
- **Question navigator** — click any question to jump, colour-coded (answered / current / blank)

### Content & monetisation
- **Video lessons** — admin adds YouTube URLs, tagged by class/topic, with optional "premium only" flag
- **Subscription plans in ₹** — admin creates any tier (name, price in INR, duration in days, feature bullets), toggles active/hidden
- **Stripe Checkout** — one-click payment, webhook + polling status verification, subscription expiry tracking
- **Free vs paid content** — every test and every video has a `premium_only` switch decided by the admin

### Community
- **Class-wise leaderboard** — points accrue automatically as students score on tests
- **Referral codes** — every student gets a unique code + shareable link; friends who register with it get tracked
- **Announcements** — admin broadcasts to *all* / *students* / *admins*

### Platform
- **JWT auth with httpOnly cookies** — 7-day access + 30-day refresh, brute-force lockout, password reset tokens
- **Role-based access control** — decorator dependencies for `student`, `admin`, `superadmin`
- **Password security** — bcrypt hashing
- **PWA-ready** — installable on Android / iOS home screen with the StudyBook icon
- **Premium UI** — Fraunces serif + Manrope sans, brand-locked navy → royal-blue → violet palette, glassmorphism, entrance staggers, custom cursor feedback

---

## Screenshots

<div align="center">

| Landing | Student Dashboard |
| :---: | :---: |
| Premium hero with animated 3D visual, generic messaging that scales to any subject | Live test reminder, upcoming tests, leaderboard peek, announcements |

| Question Bank (Student) | Admin — Manage Questions |
| :---: | :---: |
| Instant feedback, LaTeX rendering, explanation reveal | CSV template + bulk upload + individual editor |

| Pricing | Admin Dashboard |
| :---: | :---: |
| Plans priced in ₹, admin-managed | Real-time counters, quick actions, platform pulse |

</div>

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                             Client (React 19)                        │
│  Landing • Login • Register • Dashboard • QuestionBank • LiveTest    │
│  Tests • Videos • Leaderboard • Referrals • Pricing • Admin • …      │
│                                                                      │
│    React Router · Axios (withCredentials) · Framer Motion · Tailwind │
│    Shadcn UI · KaTeX · Sonner (toast) · Papa Parse                   │
└────────────────────────────┬─────────────────────────────────────────┘
                             │  HTTPS · httpOnly cookies (access + refresh)
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Ingress                           │
│               /api/* → backend:8001   |   /* → frontend:3000         │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       FastAPI backend (Uvicorn)                      │
│                                                                      │
│  server.py  ──►  routers/                                            │
│                  ├── auth_routes.py     (JWT / bcrypt / reset)       │
│                  ├── question_routes.py (CRUD + bulk-csv)            │
│                  ├── test_routes.py     (start / submit / result)    │
│                  └── misc_routes.py     (videos / plans / stripe …)  │
│                                                                      │
│  auth.py    ──►  hash_password · JWT tokens · get_current_user ·     │
│                  require_role("admin", "superadmin")                 │
│  models.py  ──►  Pydantic (RegisterInput, QuestionCreate, …)         │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                    ┌────────┴─────────┐
                    ▼                  ▼
        ┌───────────────────┐  ┌─────────────────────┐
        │    MongoDB        │  │   Stripe API        │
        │  (Motor async)    │  │   Checkout sessions │
        │                   │  │   + webhook events  │
        │  users            │  └─────────────────────┘
        │  questions        │
        │  tests            │
        │  test_attempts    │
        │  videos           │
        │  plans            │
        │  payment_transactions │
        │  referrals        │
        │  announcements    │
        │  login_attempts   │  ← brute-force lockout
        │  password_reset_tokens │  ← TTL index (1h)
        └───────────────────┘
```

### Request lifecycle (example: student submits a test)

1. Student clicks **Submit** on `/tests/{id}/live` → `axios.post("/api/tests/{id}/submit", { answers })` with httpOnly cookies
2. Kubernetes ingress routes `/api/*` to the FastAPI pod on port 8001
3. `auth.get_current_user()` extracts the JWT from the `access_token` cookie, verifies it, loads the user from Mongo
4. `test_routes.submit_test()`:
    - fetches the test + all its questions
    - iterates answers, applies +/− marks, records `is_correct` per question
    - updates `test_attempts` (uniquely keyed by `user_id + test_id`)
    - increments the user's `total_points` (fuels the leaderboard)
5. Response goes back with `{score, percent, correct, incorrect, unanswered}`
6. Client redirects to `/tests/{id}/result` and calls both `/result` and `/leaderboard` in parallel

---

## Tech stack & why

| Layer | Choice | Why |
| :--- | :--- | :--- |
| **Backend framework** | **FastAPI** | Async, type-safe, automatic OpenAPI docs, minimal boilerplate — ideal for a REST API that must scale to hundreds of thousands of users |
| **ASGI server** | **Uvicorn** | Fast, production-ready, first-class FastAPI companion |
| **Database** | **MongoDB (Motor)** | Flexible schema for evolving question/test shapes; async driver plays well with FastAPI; horizontally scalable |
| **Auth** | **PyJWT + bcrypt + httpOnly cookies** | Industry standard, secure against XSS (httpOnly), refresh-token rotation, brute-force lockout |
| **Payments** | **Stripe (via `emergentintegrations`)** | Best-in-class checkout, INR support, webhook-driven subscription activation |
| **Frontend framework** | **React 19** | Massive ecosystem, concurrent features, familiar to any web engineer |
| **Build tool** | **CRA + Craco** | Simple config, path aliases (`@/*`), zero fuss |
| **Routing** | **React Router 7** | Declarative, code-splitting-ready |
| **Styling** | **Tailwind CSS 3** + **Shadcn UI** | Utility-first + accessible headless components you fully control; no design-system lock-in |
| **Motion** | **Framer Motion** | Buttery entrance staggers, hover choreography, scroll-triggered reveals |
| **Math rendering** | **KaTeX + react-katex** | Faster than MathJax, tiny bundle, supports 95 % of LaTeX symbols students actually use |
| **CSV parsing** | **Papa Parse** (client) + **`csv` stdlib** (server) | Battle-tested, streams-friendly |
| **Icons** | **lucide-react** | 1000+ crisp SVG icons, tree-shakeable |
| **Toasts** | **Sonner** | Beautiful, minimal, keyboard accessible |
| **HTTP** | **Axios** (`withCredentials: true`) | Interceptors, form-data, request cancellation |
| **Fonts** | **Fraunces** (serif headings) + **Manrope** (body) + **JetBrains Mono** (code) | Unique premium pairing that avoids the generic Inter/Roboto AI-slop look |
| **PWA** | **manifest.json** + brand icon | Installable on Android home screen (Play Store distribution via TWA) |

---

## Project structure

```
studybook/
├── backend/
│   ├── server.py                 # FastAPI entrypoint, startup seeding, indexes
│   ├── auth.py                   # JWT, bcrypt, cookie helpers, role deps
│   ├── models.py                 # Pydantic request/response models
│   ├── routers/
│   │   ├── auth_routes.py        # /api/auth/*
│   │   ├── question_routes.py    # /api/questions/* + bulk-csv
│   │   ├── test_routes.py        # /api/tests/*
│   │   └── misc_routes.py        # videos / plans / payments / admin / superadmin / announcements
│   ├── requirements.txt
│   └── .env.example
│
├── frontend/
│   ├── public/
│   │   ├── index.html
│   │   └── manifest.json
│   └── src/
│       ├── App.js                # Route registry
│       ├── index.js
│       ├── index.css             # Design tokens, custom scrollbar, animations
│       ├── App.css
│       ├── lib/
│       │   ├── api.js            # Axios instance (withCredentials)
│       │   └── format.js         # inr() helper
│       ├── contexts/
│       │   └── AuthContext.js    # login / register / me / logout / refresh
│       ├── components/
│       │   ├── Logo.js
│       │   ├── Navbar.js
│       │   ├── Layout.js
│       │   ├── ProtectedRoute.js
│       │   ├── MathText.js       # KaTeX renderer
│       │   └── ui/               # Shadcn UI primitives
│       └── pages/
│           ├── Landing.js
│           ├── Login.js  Register.js  ForgotPassword.js
│           ├── StudentDashboard.js
│           ├── QuestionBank.js
│           ├── Tests.js  LiveTest.js  TestResult.js
│           ├── Videos.js  Leaderboard.js  Referrals.js  Profile.js
│           ├── Pricing.js  PaymentSuccess.js
│           └── admin/
│               ├── AdminDashboard.js
│               ├── ManageQuestions.js
│               ├── ManageTests.js
│               ├── ManageVideos.js
│               ├── ManageUsers.js
│               ├── ManagePlans.js
│               ├── ManageAnnouncements.js
│               └── SuperAdmin.js
│
├── memory/
│   ├── PRD.md
│   └── test_credentials.md
├── test_reports/                 # JSON test reports from CI
└── README.md
```

---

## Quick start

### Prerequisites
- Python 3.11+
- Node.js 20+ and Yarn
- MongoDB running locally (or a connection string)

### 1) Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env         # then edit .env
uvicorn server:app --host 0.0.0.0 --port 8001 --reload
```

The backend auto-seeds an admin, a superadmin, three subscription plans (in ₹) and a handful of sample questions on first run.

### 2) Frontend

```bash
cd frontend
yarn install
echo 'REACT_APP_BACKEND_URL=http://localhost:8001' > .env
yarn start
```

App is now live at **http://localhost:3000** with the API at **http://localhost:8001**.

---

## Environment variables

**`backend/.env`**

| Name | Purpose | Example |
| :--- | :--- | :--- |
| `MONGO_URL` | Mongo connection string | `mongodb://localhost:27017` |
| `DB_NAME` | Database name | `studybook` |
| `CORS_ORIGINS` | Comma-separated allowed origins | `*` |
| `JWT_SECRET` | 32+ byte secret for signing tokens | *(hex-64 recommended)* |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Seeded admin credentials | `admin@studybook.com` / `Admin@123` |
| `SUPERADMIN_EMAIL` / `SUPERADMIN_PASSWORD` | Seeded superadmin credentials | `superadmin@studybook.com` / `Super@123` |
| `STRIPE_API_KEY` | Stripe secret key | `sk_test_...` |
| `FRONTEND_URL` | Public URL of the frontend | `https://studybook.example.com` |

**`frontend/.env`**

| Name | Purpose |
| :--- | :--- |
| `REACT_APP_BACKEND_URL` | Full origin of the FastAPI backend |

---

## Seeded accounts

On first startup, `server.py` upserts two accounts:

| Role | Email | Password |
| :--- | :--- | :--- |
| **Admin** | `admin@studybook.com` | `Admin@123` |
| **SuperAdmin** | `superadmin@studybook.com` | `Super@123` |

> **Change these immediately after deploying to production** by editing `ADMIN_PASSWORD` / `SUPERADMIN_PASSWORD` in `backend/.env` and restarting — the startup routine will re-hash the new password.

Students self-register at `/register`.

---

## API reference

All endpoints are prefixed with `/api`. Auth uses **httpOnly cookies**; browser clients need `withCredentials: true`. For headless tests you can also send `Authorization: Bearer <access_token>` (returned in the login body).

<details>
<summary><strong>Auth · /api/auth</strong></summary>

| Method | Path | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| POST | `/register` | none | Create a student account |
| POST | `/login` | none | Log in, sets cookies |
| POST | `/logout` | any | Clear cookies |
| GET  | `/me` | any | Current user object |
| POST | `/refresh` | refresh cookie | Rotate access token |
| POST | `/forgot-password` | none | Email a reset link (logged to server in dev) |
| POST | `/reset-password` | none | Set new password with token |

</details>

<details>
<summary><strong>Questions · /api/questions</strong></summary>

| Method | Path | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| GET  | `/questions?class_level=&topic=&subject=&limit=&skip=` | any | Paginated question list (correct answers hidden for students) |
| GET  | `/questions/topics?class_level=` | any | Aggregated topic counts |
| GET  | `/questions/{id}` | any | Single question |
| POST | `/questions/{id}/check` | student | Reveal answer after attempt |
| POST | `/questions` | admin | Create |
| PUT  | `/questions/{id}` | admin | Update |
| DELETE | `/questions/{id}` | admin | Delete |
| POST | `/questions/bulk-csv` | admin | Multipart CSV upload, returns `{inserted, errors:[{row, error}]}` |

</details>

<details>
<summary><strong>Tests · /api/tests</strong></summary>

| Method | Path | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| GET  | `/tests` | any | List (students see only published + class-matching + lock status) |
| GET  | `/tests/upcoming` | any | Next 10 upcoming |
| GET  | `/tests/{id}` | any | Detail |
| POST | `/tests/{id}/start` | student | Begin attempt (enforces live window, subscription, prerequisite) |
| POST | `/tests/{id}/submit` | student | Auto-grade with negative marking |
| GET  | `/tests/{id}/result` | student | Detailed review with correct answers + explanations |
| GET  | `/tests/{id}/leaderboard` | any | Ranked scores for one test |
| GET  | `/tests/{id}/attempts` | admin | All attempts + user info |
| POST/PUT/DELETE | `/tests` `/tests/{id}` | admin | CRUD |

</details>

<details>
<summary><strong>Videos, plans, payments, leaderboard, referrals</strong></summary>

| Method | Path | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| GET / POST / DELETE | `/videos` | any / admin | List / create / delete video lessons |
| GET | `/leaderboard?class_level=&limit=` | any | Overall points leaderboard |
| GET | `/referrals/me` | student | Own code + list of referred users |
| GET | `/plans` | any | Active plans (students see) |
| GET / POST / PUT / DELETE | `/admin/plans` `…/{id}` | admin | Plan management |
| POST | `/payments/checkout` | student | Stripe Checkout session |
| GET  | `/payments/status/{session_id}` | student | Poll payment status (activates subscription on paid) |
| POST | `/webhook/stripe` | Stripe signature | Server-to-server payment finalisation |
| POST / DELETE | `/superadmin/admins` `…/{id}` | superadmin | Create / remove admins |
| GET / POST / DELETE | `/announcements` `…/{id}` | any / admin | Broadcasts |
| GET | `/admin/users?role=` | admin | User list |
| GET | `/admin/stats` | admin | Platform-wide counters |

</details>

Interactive OpenAPI docs are available at **`http://localhost:8001/docs`** during development.

---

## CSV bulk-upload format

Download the template from **Admin → Question bank → CSV template**, then upload with **Bulk upload**.

```csv
subject,class_level,topic,question_text,q_type,option_a,option_b,option_c,option_d,correct_index,correct_answer_text,explanation,positive_marks,negative_marks,difficulty,image_url
maths,10,Algebra,"Solve for x: 2x+3=11",mcq,3,4,5,6,1,4,"2x=8 so x=4",1,0.25,easy,
maths,10,Quadratic,"Discriminant of $ax^2+bx+c$?",typed,,,,,,b^2-4ac,"D = b^2 - 4ac",2,0.5,medium,
```

- `q_type = mcq` → fill `option_a…d` + `correct_index` (0-based)
- `q_type = typed` → fill `correct_answer_text`
- `difficulty ∈ { easy, medium, hard }`
- LaTeX allowed everywhere: wrap with `$...$` (inline) or `$$...$$` (block)

The endpoint returns per-row errors so a single bad row never blocks the rest.

---

## LaTeX support

Anywhere StudyBook renders question text, options or explanations, we run the value through the **`<MathText>`** component. Inline math is delimited with `$...$`, block math with `$$...$$`.

```jsx
<MathText text="If $x^2 + 2x - 3 = 0$, then $x = ?$" />
```

Under the hood: `react-katex` → `KaTeX` — one of the fastest math renderers on the web.

---

## Deployment

The app is deploy-ready for any container platform. Two common paths:

1. **Kubernetes** — ship the backend as a Uvicorn container on port `8001`, the frontend as an Nginx serving the CRA build; route `/api/*` to the backend via ingress. This is exactly how the reference cluster is configured.
2. **Managed platforms** — the backend runs on any FastAPI-friendly host (Render / Fly / Railway); the frontend as a static site (Vercel / Netlify / Cloudflare Pages). Point `REACT_APP_BACKEND_URL` at the backend origin.

Post-deploy checklist:
- [ ] Set strong `JWT_SECRET`, `ADMIN_PASSWORD`, `SUPERADMIN_PASSWORD`
- [ ] Set the Stripe **live** key in `STRIPE_API_KEY`
- [ ] Point `FRONTEND_URL` to the real public URL
- [ ] Register the Stripe webhook at `POST {backend}/api/webhook/stripe`
- [ ] Enable TLS everywhere (auth cookies require `Secure`)

---

## Roadmap

- [x] Multi-role auth (student / admin / superadmin)
- [x] Question bank + CSV bulk upload
- [x] Scheduled live tests with negative marking and unlockable finals
- [x] Video lessons (YouTube embed)
- [x] Stripe subscriptions in INR (admin-set pricing)
- [x] Referral codes
- [x] Announcements
- [x] LaTeX math rendering
- [x] Test reminders (dashboard banner + browser notification)
- [x] PWA installable
- [ ] Rich WYSIWYG editor for questions (paste from Word)
- [ ] More subjects: Science, English, Social Studies (schema already supports)
- [ ] Advanced analytics dashboards (Recharts)
- [ ] Email delivery for reset links and test reminders (Resend / SendGrid)
- [ ] Native mobile app via Trusted Web Activity (Play Store)

---

## License

MIT — do whatever you want, just don't remove the copyright.

<div align="center">

Built with focus by the StudyBook team.

Made possible by ❤ **FastAPI · MongoDB · React · Tailwind · Shadcn UI · KaTeX · Stripe**

</div>
