# Decisions Log (ADR)

## Teacher Booking Platform

Key architectural decisions, tradeoffs, and long-term implications.
New decisions are appended — existing ADRs are never edited retroactively.

---

## ADR-001: React framework with server-side rendering

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Single-teacher booking site. Most pages are read-heavy (course listings, slot availability). Need file-based routing, SSR, and a deployment target that supports edge functions.

**Decision:**
Use Next.js App Router (React Server Components) over the legacy Pages Router.

**Tradeoff:**
Accept a steeper learning curve (server/client component boundary, RSC mental model) in exchange for reduced client bundle size and server-driven rendering.

**Alternatives considered:**

- Pages Router → simpler, but in maintenance mode; layout nesting is awkward
- Remix → good SSR story, but smaller ecosystem and less Vercel-native

**Consequences:**

- Must distinguish server vs client components on every file
- Some third-party libraries require `'use client'` wrappers
- Route groups `(public)/(auth)/(protected)` map cleanly to auth boundaries

---

## ADR-002: Managed backend platform (Supabase)

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Solo-built product. Need database, auth (OAuth + passwordless), row-level access control, and serverless functions — without maintaining a custom backend.

**Decision:**
Use a managed backend platform that bundles PostgreSQL, auth, and serverless functions in one service.

**Tradeoff:**
Accept vendor dependency in exchange for eliminating auth, infrastructure, and DB management overhead entirely.

**Alternatives considered:**

- Firebase → document database; poor fit for relational booking/slot/user model
- Custom Node.js backend + managed Postgres → full control, but high setup and maintenance cost for a solo project

**Consequences:**

- PostgreSQL is standard SQL — migration to another managed Postgres provider is feasible if needed
- RLS policies must be designed carefully; incorrect policies are a silent security risk
- Edge Functions are the only serverless execution layer available (no custom server)

---

## ADR-003: SQL-adjacent ORM (Drizzle)

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Need type-safe database access from TypeScript. The backend platform uses PostgreSQL with a connection pooler optimised for serverless (PgBouncer in transaction mode).

**Decision:**
Use Drizzle ORM over Prisma.

**Tradeoff:**
Accept less developer ergonomics (no auto-generated CRUD) in exchange for transparent SQL, smaller bundle, and reliable behaviour with serverless connection pooling.

**Alternatives considered:**

- Prisma → higher abstraction and better DX for CRUD, but generates opaque SQL, has known issues with PgBouncer transaction mode, and adds significant bundle weight
- Raw SQL → full control, but no type safety and higher maintenance burden

**Consequences:**

- Schema exists in two places: `supabase/migrations/` (SQL, source of truth) and `lib/db/schema.ts` (Drizzle mirror for types). These must stay in sync manually.
- Developers must understand SQL joins and query composition
- No magic CRUD methods — all queries are explicit

---

## ADR-004: Prices stored as integer cents

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Course types have prices. Need to store monetary values in PostgreSQL without floating point precision errors. Future payment integration is likely.

**Decision:**
Store prices as `integer` (smallest currency unit, e.g. cents) with a separate `currency` text column.

**Tradeoff:**
Accept a formatting step on the frontend (`cents / 100`) in exchange for arithmetic correctness and payment processor compatibility.

**Alternatives considered:**

- `numeric(10,2)` → correct precision in SQL, but requires careful handling at the application layer and adds conversion friction with payment APIs

**Consequences:**

- Frontend must always format: `(price_cents / 100).toFixed(2)`
- A shared `formatPrice(cents, currency)` utility is required
- Any future payment integration receives the value in the expected format with no conversion

---

## ADR-005: Guests are not persisted

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Unauthenticated visitors can browse public pages and course listings. The question is whether to track them as records in the database.

**Decision:**
Guests are not stored in the database. Public access is controlled entirely via database-level anonymous role policies.

**Tradeoff:**
Accept less visibility into guest behaviour in exchange for a simpler data model and zero cleanup overhead.

**Alternatives considered:**

- Session-based guest records → adds orphaned row cleanup, no clear benefit for this use case

**Consequences:**

- `profiles.role` only contains `student`, `teacher`, `admin` — no `guest` value
- All public read access must be explicitly granted via anonymous-role policies
- No guest analytics from the database layer (would require an external tool)

---

## ADR-006: Cancellations as a separate audit table

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Bookings can be cancelled by either the student or teacher. Need to track who cancelled, why, and when — while keeping booking queries fast.

**Decision:**
Store cancellation events in a dedicated `cancellations` table. A database trigger syncs `bookings.status = cancelled` automatically on insert.

**Tradeoff:**
Accept increased schema complexity in exchange for a clean separation between current state (`bookings.status`) and event history (`cancellations`).

**Alternatives considered:**

- Cancelled reason columns on `bookings` → loses the event model (who, when), and makes multi-cancellation history impossible

**Consequences:**

- Application code only writes to `cancellations`; `bookings.status` is updated by trigger
- If the trigger fails, the two tables diverge — trigger health must be monitored
- Full cancellation history is queryable without touching `bookings`

---

## ADR-007: npm as package manager

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Starting a new project. Choosing a package manager affects install speed, lockfile behaviour, and CI setup.

**Decision:**
Use npm. Migrate to pnpm if the project evolves into a monorepo or CI install time becomes a bottleneck.

**Tradeoff:**
Accept slower installs and a larger `node_modules` in exchange for zero additional tooling setup.

**Alternatives considered:**

- pnpm → faster installs, strict dependency isolation, better for monorepos; adds a setup step that is unnecessary at current scale

**Consequences:**

- `package-lock.json` must be committed
- All install commands use `npm install`, not `pnpm install`
- If migrating to pnpm later, delete `package-lock.json`, regenerate with pnpm, update CI

---

## ADR-008: UTC storage, local display for timestamps

**Status:** Accepted
**Date:** 2026-04-07

**Context:**
Teacher is based in Melbourne. Students may connect from different timezones. Booking times must be unambiguous regardless of where either party is.

**Decision:**
Store all timestamps as `timestamptz` (UTC internally). Convert to the viewer's local timezone at display time using a date library with timezone support.

**Tradeoff:**
Accept frontend conversion logic in exchange for a single unambiguous representation in the database.

**Alternatives considered:**

- Store in AEST → breaks for international students; requires re-engineering if teacher relocates

**Consequences:**

- Every timestamp display requires a timezone conversion — a shared utility function is mandatory
- Emails must state the timezone explicitly (e.g. "3:00 PM AEST") not just the time
- The `time_slots` table stores a `timezone` column as the teacher's reference timezone for display context
