# AGENTS.md

## Dev environment

```bash
npm run dev          # localhost:3001
npx tsc --noEmit     # type check
npm run lint         # eslint
npm run build        # production build — run before opening a PR
```

Single package, no monorepo. All commands run from repo root.

After any schema change, regenerate types before writing queries:

```bash
npx supabase gen types typescript --project-id YOUR_PROJECT_REF > types/database.ts
```

`types/database.ts` is generated — never edit it manually.

## Architecture rules

**Layer order is strict — never skip:**

```
API route handler → lib/services/ → lib/db/queries/ → Supabase
```

- Route handlers: parse request, verify session, delegate to service, return response. No business logic.
- `lib/services/`: business logic and orchestration only. No direct DB calls.
- `lib/db/queries/`: pure data access only. No conditionals, no rules, no side effects.

**Supabase clients are not interchangeable:**

- `lib/supabase/client.ts` — browser only. Import only in Client Components (`'use client'`).
- `lib/supabase/server.ts` — server only. Import in RSC, Route Handlers, middleware.
- Importing `server.ts` in a Client Component (or any file it imports) is a build-time error.

**Authorization:**
RLS in PostgreSQL is the security boundary. Middleware redirects and API session checks are UX only — they do not prevent unauthorized data access. Never rely on application-layer checks alone.

**Server Components are the default.**
Add `'use client'` only when the component requires browser APIs, event handlers, or React state. If unsure, start as a Server Component.

## Env vars

- `lib/env.client.ts` — `NEXT_PUBLIC_*` vars only. Uses literal `process.env.NEXT_PUBLIC_*` references (not dynamic access — Next.js requires this for static replacement).
- `lib/env.server.ts` — server-only secrets. Never import in a Client Component or any file reachable from one.
- Never use `process.env` directly anywhere else.

## Code rules

- No `any`. Use `unknown` and narrow with type guards or Zod.
- No inline styles. Tailwind utility classes for layout/spacing/color. `app/globals.css` for effects Tailwind cannot express (animations, backdrop filters, liquid glass).
- `supabase/migrations/` is append-only. Never edit a migration that has been applied — write a new one.
- Service role key (`SUPABASE_SERVICE_ROLE_KEY`) stays on the server. It must never appear in client-accessible code.
- No `console.log` in committed code. Use proper error handling.

## Stitch design reference

Project ID: `10111007622677145849` — these screens are first drafts and will be revised.

| Screen ID (prefix)      | Route                | Target file                                  |
| ----------------------- | -------------------- | -------------------------------------------- |
| `af39efb1`              | `/`                  | `app/(public)/page.tsx`                      |
| `2a5916a9` / `47b78fb9` | `/about`             | `app/(public)/about/page.tsx`                |
| `1b7398d5` / `4e9f1eb2` | `/contact`           | `app/(public)/contact/page.tsx`              |
| `b7c7dbf5` / `8b4d7998` | `/booking`           | `app/(protected)/booking/page.tsx`           |
| `77cc679c`              | `/booking/confirmed` | `app/(protected)/booking/confirmed/page.tsx` |
| `972b87dd` / `082b7dac` | `/login`             | `app/(auth)/login/page.tsx`                  |
| `90b1dc77`              | `/dashboard/student` | `app/(protected)/dashboard/student/page.tsx` |
| `14e3d1e0`              | `/dashboard/teacher` | `app/(protected)/dashboard/teacher/page.tsx` |

When converting Stitch HTML to Next.js:

- Replace all inline styles with Tailwind utility classes
- Non-Tailwind effects (animations, backdrop-filter, liquid glass) go in `app/globals.css`
- Default to Server Component; add `'use client'` only if needed
- Mobile-first responsive layout

For page prompt format when Stitch design needs supplementing, see `docs/setup.md §1.11`.

## PR checklist

Before opening a PR:

- `npx tsc --noEmit` passes with no errors
- `npm run lint` passes with no errors
- `npm run build` completes successfully
- No `any`, no `console.log`, no inline styles in changed files
- If schema changed: new migration file exists and `types/database.ts` is regenerated
- If a new API route was added: it follows the layer order above
