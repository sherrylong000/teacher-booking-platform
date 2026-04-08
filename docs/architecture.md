# Architecture Document
## Teacher Booking Platform

**Version:** 1.2.0
**Last Updated:** 2026-04-08

---

## 1. Design Principles

| Principle | Implementation |
|---|---|
| Security at the data layer | Authorization is enforced at the database level via Row Level Security. Middleware and API checks are UX-only — they can be bypassed, RLS cannot. |
| Server-first | Default to Server Components. Add `'use client'` only when interactivity requires it. |
| Thin controllers | API routes parse requests and delegate to a service layer. No business logic in route handlers. |
| Single source of truth | Schema and constraints live in PostgreSQL. The ORM mirrors them for type safety — it does not replace them. |

---

## 2. System Layers

```
Browser
  │
  ▼
React-based Framework (Edge-deployed)
  │  ├── Server Components  →  direct DB queries via server client
  │  └── Client Components  →  browser client for interactive state
  │
  ▼
API Route Handlers  →  thin controllers, auth check, delegate to services
  │
  ▼
Service Layer (lib/services/)  →  business logic, orchestration
  │
  ▼
Data Layer (lib/db/queries/)  →  pure data access, no logic
  │
  ▼
PostgreSQL + RLS + Auth + Serverless Functions
  │
  ├── Transactional Email Service
  └── DNS Provider → Edge Hosting
```

**Layer rule:** `api/` → `services/` → `db/queries/` → database.
Never skip layers (no direct DB calls in route handlers, no business logic in queries).

---

## 3. Tech Stack

### Abstract

| Layer | Technology |
|---|---|
| Frontend framework | React-based framework with SSR and file-based routing |
| Language | TypeScript (strict mode) |
| Styling | Utility-first CSS framework |
| Database | PostgreSQL with Row Level Security |
| Authentication | OAuth 2.0 + Passwordless (magic link) |
| Authorization | Row Level Security policies |
| ORM | Type-safe SQL query builder |
| Email | Transactional email API |
| Hosting | Edge deployment platform |
| Package manager | npm |


---

## 4. Project Structure

```
teacher-booking-platform/
├── app/
│   ├── (public)/               # Guest-accessible pages
│   │   ├── layout.tsx          # Navbar + Footer
│   │   ├── page.tsx            # Home
│   │   ├── about/page.tsx
│   │   ├── contact/page.tsx
│   │   └── courses/page.tsx
│   ├── (auth)/
│   │   └── login/page.tsx
│   ├── (protected)/            # Requires authenticated session
│   │   ├── layout.tsx          # Auth guard
│   │   ├── booking/
│   │   │   ├── page.tsx
│   │   │   └── confirmed/page.tsx
│   │   └── dashboard/
│   │       ├── student/page.tsx
│   │       ├── teacher/page.tsx
│   │       └── admin/page.tsx
│   ├── api/
│   │   ├── auth/callback/route.ts
│   │   └── bookings/
│   │       ├── create/route.ts
│   │       └── cancel/route.ts
│   ├── layout.tsx
│   └── globals.css
│
├── components/
│   ├── ui/                     # Primitive components (Button, Input…)
│   ├── layout/                 # Navbar, Footer
│   ├── booking/                # SlotCard, BookingForm, StatusBadge
│   ├── dashboard/              # BookingTable, SlotManager
│   └── auth/                   # LoginForm
│
├── lib/
│   ├── env.client.ts           # NEXT_PUBLIC_* vars — safe for browser
│   ├── env.server.ts           # Server-only secrets (never import in Client Components)
│   ├── supabase/
│   │   ├── client.ts           # Browser client — Client Components only
│   │   └── server.ts           # Server client — RSC + Route Handlers only
│   ├── db/
│   │   ├── schema.ts           # ORM schema (mirrors SQL migrations)
│   │   └── queries/            # Pure data access — no business logic
│   │       ├── bookings.ts
│   │       ├── slots.ts
│   │       └── courses.ts
│   ├── services/               # Business logic layer
│   │   ├── booking.service.ts  # Booking rules, orchestration
│   │   └── auth.service.ts     # Role helpers
│   ├── constants/
│   │   └── routes.ts           # Route definitions + path guards
│   └── utils/
│       ├── timezone.ts         # Timezone conversion helpers
│       └── cn.ts               # Class name utility
│
├── hooks/
│   ├── useBookings.ts
│   └── useAuth.ts
│
├── types/
│   └── database.ts             # Generated from DB schema — do not edit manually
│
├── supabase/
│   ├── migrations/             # SQL — the real source of truth
│   │   └── 0001_initial_schema.sql
│   └── functions/
│       └── send-notification/index.ts
│
├── docs/
├── middleware.ts               # Session refresh + route protection (Edge Runtime)
├── AGENTS.md
├── .env.example
├── drizzle.config.ts
├── tailwind.config.ts
└── tsconfig.json
```

---

## 5. Authentication Flow

```
Request to protected route
    │
    ▼
middleware.ts  (Edge Runtime — runs on every request)
    │  ├── Refreshes session cookie
    │  └── No session → redirect to /login?redirectTo=<path>
    │
    ▼
(protected)/layout.tsx  ←  secondary server-side session check
    │
    ▼
Page renders with valid session

Login options:
  Google OAuth   →  Auth provider  →  /api/auth/callback  →  redirect
  Magic Link     →  Auth provider  →  email click  →  /api/auth/callback  →  redirect
```

> Middleware redirects protect UX. The actual security boundary is RLS at the database level.

---

## 6. Booking Creation Flow

```
Student clicks "Book"
    │
    ▼
POST /api/bookings/create
    ├── Verify session
    └── Delegate to booking.service.ts
            │
            ▼
        DB stored procedure: create_booking(slot_id, student_id)
            ├── BEGIN
            ├── SELECT slot FOR UPDATE    ← row lock, prevents race condition
            ├── Assert slot.status = 'available'  → 409 if not
            ├── INSERT booking  (status = pending)
            ├── UPDATE slot     (status = reserved)
            └── COMMIT
            │
            ▼
        Return booking_id
            │
            ▼
        DB trigger → Serverless Function → transactional email to teacher
```

Row lock + transaction guarantees no double booking under concurrent requests.

---

## 7. Environment Variables

```bash
# .env.example

# Database + Auth (public — safe for browser)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=

# Server-only — never expose to client
SUPABASE_SERVICE_ROLE_KEY=
RESEND_API_KEY=

# App
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

Server-only keys are imported exclusively via `lib/env.server.ts`.
Missing keys throw at startup — no silent failures in production.

---

## 8. Deployment

```
git push → main branch
    │
    ▼
CI: build + type check (npm run build)
    │
    ▼
Deploy to edge hosting platform
    │
    ▼
Custom domain (DNS A + CNAME → hosting platform)
SSL certificate auto-provisioned
```

Every branch push generates an isolated preview URL.
Always verify on preview before merging to `main`.

---

## 9. Performance

| Concern | Approach |
|---|---|
| Static pages | Home, About, Contact → statically generated at build time |
| Dynamic pages | Dashboard, Booking → Server Components + Suspense streaming |
| Images | Framework image component (WebP, lazy loading, sized) |
| Fonts | Self-hosted via framework font system (no layout shift) |
| Heavy components | Dynamic `import()` for calendar and date pickers |
| DB queries | Select only needed columns; joins to avoid N+1 |