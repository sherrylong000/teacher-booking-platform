# Roadmap

## Teacher Booking Platform

**Last Updated:** 2026-04-08

---

## Phase 1 — Foundation

**Goal:** Live site with working authentication and correct role separation.

**Critical Path:**

- Next.js app initialised and deployed to production
- Database schema and initial migrations applied
- Google OAuth + Email Magic Link working end-to-end
- Auto-create user profile on sign-up (role = student)
- Middleware protects `/booking` and `/dashboard`
- Public pages: Home, About, Contact, Courses

**Definition of Done:**

- Custom domain live with HTTPS
- Student can sign in and be redirected correctly
- New sign-in creates a `profiles` row with `role = student`
- Unauthenticated request to `/dashboard` redirects to `/login`
- Teacher and student roles cannot access each other's data (RLS verified)

---

## Phase 2 — Booking Core

**Goal:** Complete request → approval → confirm/cancel flow.

**Critical Path:**

- Full database schema deployed (all tables, triggers, RLS policies)
- Teacher: create, edit, delete time slots
- Student: browse available slots with local timezone display
- Student: submit booking request (status: pending)
- Teacher: approve → confirmed; reject → cancelled
- Student and teacher cancellation (both paths)
- Concurrency protection: row lock prevents double booking

**Definition of Done:**

- Student can request a slot; status transitions correctly through the flow
- Teacher approves → slot locked, student notified
- Two simultaneous requests for same slot → only one succeeds
- Cancellation by either party releases the slot automatically
- Student cannot read another student's bookings (RLS verified)

---

## Phase 3 — Dashboards & Notifications

**Goal:** Usable day-to-day by teacher and students without manual checking.

**Critical Path:**

- Student dashboard: upcoming and past bookings
- Teacher dashboard: slot management + booking list with status filter
- Email notifications: booking submitted, confirmed, cancelled, 24h reminder
- Scheduled job for 24h reminder configured
- Loading states, empty states, error handling, toast feedback

**Definition of Done:**

- Teacher receives email when booking is submitted
- Student receives email on confirmation and cancellation
- Student receives 24h reminder before lesson
- Dashboard reflects current booking state without page refresh
- Empty and error states handled gracefully on all dashboard views

---

## Phase 4 — Polish & Launch (Optional)

- SEO metadata on all public pages
- Lighthouse audit ≥ 90 (Performance, Accessibility)
- Keyboard navigation and screen reader review
- Rate limiting on API routes
- `robots.txt` and `sitemap.xml`

---

## Future Backlog

Not committed to any phase. Revisit after launch based on real usage.

| Feature                 | What it requires                                                        |
| ----------------------- | ----------------------------------------------------------------------- |
| In-app messaging        | New `conversations` + `messages` tables; real-time subscription         |
| Automated meeting links | Meeting provider API integration on booking confirmation                |
| Recurring time slots    | `is_recurring` + `recurrence_rule` already in schema — needs UI         |
| Multiple teachers       | `teacher_id` FK on `time_slots`; RLS policies updated for multi-tenancy |
| Student progress notes  | New `student_notes` table linked to `profiles`                          |
| Course reviews          | New `reviews` table linked to `bookings`                                |
| Waitlist                | New `waitlist` table; trigger when booked slot is cancelled             |
| Calendar export         | Generate `.ics` from booking data                                       |

---

## Known Technical Debt

| Item                                | Severity | Resolution                                                    |
| ----------------------------------- | -------- | ------------------------------------------------------------- |
| Zoom link is manual entry           | Low      | Acceptable for v1; automate in backlog if teacher requests it |
| No automated tests                  | High     | Add integration tests before Phase 3 ships to real users      |
| No rate limiting on API routes      | Medium   | Add before public launch (Phase 4)                            |
| 24h reminder job not yet configured | Medium   | Must be done before Phase 3 Definition of Done is met         |

---

## Risks

| Risk                                         | Likelihood | Impact   | Mitigation                                                                                                           |
| -------------------------------------------- | ---------- | -------- | -------------------------------------------------------------------------------------------------------------------- |
| RLS misconfiguration causes data leakage     | Medium     | Critical | Manual RLS verification in each phase DoD; test with separate student/teacher sessions                               |
| Booking race condition causes double booking | Low        | High     | Row-level lock (`SELECT FOR UPDATE`) inside DB transaction; covered in Phase 2 DoD                                   |
| OAuth redirect misconfiguration blocks login | Medium     | High     | Test Google OAuth and Magic Link end-to-end before Phase 1 is closed; document redirect URIs in `setup.md`           |
| Schema drift between ORM and SQL migrations  | Medium     | Medium   | ORM schema (`lib/db/schema.ts`) is a mirror only — SQL migrations are source of truth; review on every schema change |
