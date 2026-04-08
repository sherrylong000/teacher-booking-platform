# Product Requirements Document

## Teacher Booking Platform

**Version:** 1.1.0
**Last Updated:** 2026-04-08
**Status:** In Progress

---

## 1. Overview

A single-teacher booking platform where students request lessons and the teacher retains full control through a manual approval workflow. One teacher, multiple students, no payments in v1.

### Goals

- Request → approval → confirmation booking flow (teacher controls all state transitions)
- Minimal operational overhead for the teacher
- Foundation that can extend to payments and multi-teacher without restructuring

### Out of Scope (v1)

- Payments — deferred to reduce financial and refund complexity
- Real-time messaging — deferred to avoid state synchronisation overhead
- Automated meeting link generation — manual entry reduces integration risk
- Multi-teacher — deferred to avoid multi-tenancy complexity

---

## 2. Roles

| Role      | Who                                        | Can do                                                       |
| --------- | ------------------------------------------ | ------------------------------------------------------------ |
| `guest`   | Unauthenticated visitor                    | Browse public pages, view courses and available slots        |
| `student` | Registered user                            | Request bookings, manage own bookings                        |
| `teacher` | The single instructor                      | Manage slots, approve/reject/cancel any booking              |
| `admin`   | Site administrator (separate from teacher) | Read all data, cancel bookings, manage users, view audit log |

**Role assignment:**

- New sign-ups default to `student`
- `teacher` and `admin` are provisioned manually — not available through the sign-up flow
- `guest` has no database record; access is controlled by database-level anonymous policies

**Auth methods (student):** Google OAuth, Email Magic Link

---

## 3. Features by Phase

### Phase 1 — Foundation

Goal: live site, working auth, correct role separation

| Feature                                                   | Priority |
| --------------------------------------------------------- | -------- |
| Public pages: Home, About, Contact, Courses               | P0       |
| Google OAuth + Email Magic Link sign-in                   | P0       |
| Auto-create user profile on sign-up with role = student   | P0       |
| Redirect unauthenticated users away from protected routes | P0       |
| Responsive layout (mobile-first, 390px+)                  | P0       |

### Phase 2 — Booking System

Goal: complete request → approval → confirm/cancel flow

| Feature                                                     | Priority |
| ----------------------------------------------------------- | -------- |
| Teacher: create, edit, delete time slots                    | P0       |
| Student: browse available slots with local timezone display | P0       |
| Student: submit booking request (status: pending)           | P0       |
| Teacher: approve booking → status: confirmed, slot: booked  | P0       |
| Teacher: reject booking → status: cancelled, slot: released | P0       |
| Student: cancel pending or confirmed booking                | P0       |
| Teacher: cancel any booking                                 | P0       |
| Booking status history (automatic, immutable)               | P0       |
| Booking confirmation page (time, date, course)              | P1       |
| Concurrency protection (no double-booking)                  | P0       |

### Phase 3 — Dashboards & Notifications

Goal: usable day-to-day by both teacher and students

| Feature                                                              | Priority |
| -------------------------------------------------------------------- | -------- |
| Student dashboard: upcoming and past bookings                        | P0       |
| Teacher dashboard: slot management + booking list with status filter | P0       |
| Email: booking submitted (to teacher)                                | P0       |
| Email: booking confirmed (to student)                                | P0       |
| Email: booking cancelled (to both parties)                           | P0       |
| Email: 24h reminder before lesson (to student)                       | P0       |
| Admin dashboard: read all bookings, cancel bookings, view audit log  | P1       |
| Loading states, empty states, error handling, toast feedback         | P1       |

---

## 4. Pages

| Route                | Access     | Purpose                                       |
| -------------------- | ---------- | --------------------------------------------- |
| `/`                  | Public     | Hero, teacher intro, featured courses         |
| `/about`             | Public     | Teacher bio, background, teaching style       |
| `/contact`           | Public     | Contact form or email                         |
| `/courses`           | Public     | Course type listing with pricing              |
| `/login`             | Guest only | Sign in / sign up                             |
| `/booking`           | Student    | Browse available slots, submit request        |
| `/booking/confirmed` | Student    | Post-submission confirmation                  |
| `/dashboard/student` | Student    | Upcoming + past bookings                      |
| `/dashboard/teacher` | Teacher    | Slot management + booking review              |
| `/dashboard/admin`   | Admin      | User management, audit log, booking oversight |

---

## 5. Booking Flow

```
Student selects slot → booking created (pending) → slot reserved
    │
    ▼
Teacher reviews in dashboard
    ├── Approve → booking: confirmed, slot: booked, email to student
    └── Reject  → booking: cancelled, slot: available, email to student

Cancellation (either party):
    Student → allowed while pending or confirmed
    Teacher → allowed at any point before completed
    Both    → write cancellation record, trigger releases slot automatically
```

State transitions are enforced at the database level, not just the application layer.

---

## 6. Non-Functional Requirements

| Requirement        | Target                                                    |
| ------------------ | --------------------------------------------------------- |
| Mobile support     | Functional on 390px+ (iPhone SE and above)                |
| Page load (LCP)    | < 2.5s on mobile 4G                                       |
| Session management | Token auto-refreshed on every request                     |
| Timezone display   | All stored in UTC; displayed in viewer's local timezone   |
| Data integrity     | State transitions enforced by DB constraints and triggers |
| Accessibility      | WCAG 2.1 AA (keyboard nav, colour contrast, ARIA labels)  |

---

## 7. Success Criteria

### Phase 1

- Custom domain live with HTTPS
- Student can sign in with Google and Magic Link
- New sign-in creates a user record with `role = student`
- Authenticated routes reject unauthenticated access
- Teacher and student roles cannot access each other's data

### Phase 2

- Student can browse available slots in their local timezone
- Full booking flow works: request → approve → confirm
- Cancellation by either party correctly releases the slot
- Two simultaneous booking attempts for the same slot → only one succeeds

### Phase 3

- Teacher receives email when a booking is submitted
- Student receives email on confirmation and cancellation
- Student receives 24h reminder
- Both dashboards reflect current booking state without manual refresh
