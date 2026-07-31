# StudyBook — PRD

Premium learning platform. FastAPI + MongoDB + React. See `/app/README.md` for the full public documentation.

## Roles
- **student** — practice, take tests during live window, view personal analytics
- **admin** — question bank (CSV bulk + rich WYSIWYG), tests, videos, plans (₹), announcements, platform analytics
- **superadmin** — everything admins can do + create/delete admins

## What's implemented (Feb 2026 — iteration 3)
- JWT httpOnly cookie auth, bcrypt, brute-force lockout, password reset
- Question bank: MCQ + typed, LaTeX ($...$ / $$...$$), images, CSV bulk upload, Tiptap WYSIWYG with image uploads (base64 in Mongo, served at `/api/uploads/image/{id}`)
- Tests: scheduled live window, auto-submit at deadline, negative marking, unlockable finals
- Videos, referrals, announcements, Stripe subscriptions (INR)
- **Admin analytics** — 14-day attempts/registrations line chart, per-topic pass-rate bar chart, recent tests summary
- **Student analytics** — overall accuracy radial gauge, score-trend line, strengths, weaknesses, per-topic bar chart, motivational card
- Test reminder banner + browser notifications
- Back buttons on every non-dashboard page (3 roles)
- Bigger navbar logo with visible "Study**Book**" wordmark
- Landing rewritten — two premium photos (library + focused student), no subject bias, only 2 CTA sets

## Test creds
- Admin: `admin@studybook.com` / `Admin@123`
- SuperAdmin: `superadmin@studybook.com` / `Super@123`

## Backlog
- Email reminders via Resend (deferred — user said not needed yet)
- AI-powered analytics (deferred — user said no AI for now)
- Rich text/image in options (currently text only)
- CSV export of student results
- Native mobile via TWA
