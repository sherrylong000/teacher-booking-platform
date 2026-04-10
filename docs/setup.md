# Setup Guide

## Teacher Booking Platform

**Version:** 2.0.0
**Last Updated:** 2026-04-10

---

## Prerequisites

Before starting, ensure you have:

| Tool    | Version            | Check            |
| ------- | ------------------ | ---------------- |
| Node.js | 20.x LTS or higher | `node --version` |
| npm     | 9.x                | `npm --version`  |
| Git     | Any recent         | `git --version`  |
| VS Code | Latest             | —                |

Install pnpm if not present:

```bash
npm install -g pnpm
```

---

## Part 1 — Local Project Initialisation

### 1.1 Create Next.js App

```bash
npx create-next-app@latest teacher-booking-platform
```

Select the following options:

```
✔ Would you like to use TypeScript?              Yes
✔ Would you like to use ESLint?                  Yes
✔ Would you like to use Tailwind CSS?            Yes
✔ Would you like your code inside a src/ dir?    No
✔ Would you like to use App Router?              Yes
✔ Would you like to use Turbopack?               Yes
✔ Would you like to customise the import alias?  No  (@/* is fine)
```

```bash
cd teacher-booking-platform
npm run dev
```

Verify: `http://localhost:3001` shows the Next.js welcome page.

---

### 1.2 Install Core Dependencies

# Supabase

npm install @supabase/supabase-js @supabase/ssr

# Drizzle ORM

npm install drizzle-orm postgres
npm install --save-dev drizzle-kit

# Date / Timezone

npm install dayjs

# Utility

npm install clsx tailwind-merge

# Forms + Validation

npm install react-hook-form zod @hookform/resolvers

# Toast notifications

npm install sonner

# Email (server only)

npm install resend

````

---

### 1.3 Environment Variables

Create `.env.local` (never commit this file):

```bash
cp .env.example .env.local
````

`.env.example` contents (commit this file with empty values):

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Resend
RESEND_API_KEY=

# App
NEXT_PUBLIC_SITE_URL=http://localhost:3001
```

Fill in `.env.local` with real values from:

- Supabase Dashboard → Project Settings → API
- Resend Dashboard → API Keys

---

### 1.4 Supabase Client Setup

Create `lib/supabase/client.ts` (browser):

```typescript
import { createBrowserClient } from "@supabase/ssr";

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
```

Create `lib/supabase/server.ts` (RSC + Route Handlers):

```typescript
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from Server Component — middleware handles refresh
          }
        },
      },
    },
  );
}
```

---

### 1.5 Middleware (Auth Session Refresh)

Create `middleware.ts` at project root:

```typescript
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  // Protected routes — redirect to login if not authenticated
  const protectedPaths = ["/booking", "/dashboard"];
  const isProtected = protectedPaths.some((path) =>
    request.nextUrl.pathname.startsWith(path),
  );

  if (isProtected && !user) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.searchParams.set("redirectTo", request.nextUrl.pathname);
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

---

### 1.6 OAuth Callback Route

Create `app/api/auth/callback/route.ts`:

```typescript
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/";

  if (code) {
    const cookieStore = await cookies();
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        cookies: {
          getAll() {
            return cookieStore.getAll();
          },
          setAll(cookiesToSet) {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          },
        },
      },
    );
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/login?error=auth_callback_error`);
}
```

---

## Part 2 — GitHub Repository

### 2.1 Initialise and Push

```bash
git init
git add .
git commit -m "feat: initialise next.js project with supabase auth setup"
git branch -M main
```

On GitHub: create a new empty repository named `teacher-booking-platform`.

```bash
git remote add origin https://github.com/YOUR_USERNAME/teacher-booking-platform.git
git push -u origin main
```

### 2.2 Branching Strategy

```
main          ← production; deploys to yourname.com
  └── dev     ← integration branch; deploys to dev.yourname.com (Vercel preview)
       └── feature/phase-1-static-pages
       └── feature/supabase-auth
       └── feature/timetable
```

**Workflow:**

```bash
git checkout -b feature/your-feature-name
# make changes
git add .
git commit -m "feat: descriptive message"
git push origin feature/your-feature-name
# open Pull Request → merge to dev → test → merge to main
```

### 2.3 Commit Message Convention

```
feat:     new feature
fix:      bug fix
chore:    tooling, config changes
docs:     documentation only
refactor: code restructure, no behaviour change
style:    formatting, no logic change
test:     adding tests
```

---

## Part 3 — Vercel Deployment

### 3.1 Connect Repository

1. Go to [vercel.com](https://vercel.com) → Log in with GitHub
2. Click `Add New Project`
3. Import `teacher-booking-platform`
4. Framework: **Next.js** (auto-detected)
5. Build settings: leave as default
6. Click `Deploy`

### 3.2 Add Environment Variables

In Vercel → Project → Settings → Environment Variables, add:

| Key                             | Environment                                   |
| ------------------------------- | --------------------------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`      | Production + Preview + Development            |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Production + Preview + Development            |
| `SUPABASE_SERVICE_ROLE_KEY`     | Production + Preview                          |
| `RESEND_API_KEY`                | Production + Preview                          |
| `NEXT_PUBLIC_SITE_URL`          | Production only (set to https://yourname.com) |

> After adding env vars, trigger a redeploy: Deployments → three dots → Redeploy.

### 3.3 Verify Deployment

- Visit `https://teacher-booking-platform-xxx.vercel.app`
- Confirm the page loads without errors
- Check Vercel function logs for any build warnings

---

## Part 4 — GoDaddy Domain Binding

### 4.1 Add Domain in Vercel

1. Vercel → Project → Settings → Domains
2. Enter your domain: `yourname.com`
3. Click `Add`
4. Also add `www.yourname.com` and set it to redirect to the apex domain

Vercel will display the required DNS records:

```
Type   Name   Value
A      @      76.76.21.21
CNAME  www    cname.vercel-dns.com
```

### 4.2 Configure DNS in GoDaddy

1. GoDaddy → My Products → Find your domain → DNS → Manage DNS
2. **Delete** any existing A record pointing to `@` (the default parking page)
3. **Add** the two records from Vercel:

| Type  | Name | Value                | TTL    |
| ----- | ---- | -------------------- | ------ |
| A     | @    | 76.76.21.21          | 600    |
| CNAME | www  | cname.vercel-dns.com | 1 hour |

4. Save changes

### 4.3 Wait for Propagation

- DNS propagation: 10 minutes to 24 hours (usually < 30 min)
- Check status: Vercel → Domains → watch for green checkmark
- Manual check: `dig yourname.com A` in terminal

### 4.4 SSL Certificate

Vercel auto-provisions via Let's Encrypt once DNS resolves. No action required. Both `http://` and `https://` will work; Vercel forces HTTPS by default.

---

## Part 5 — Supabase Project Setup

### 5.1 Create Project

1. Go to [supabase.com](https://supabase.com) → New Project
2. Name: `teacher-booking-platform`
3. Database password: generate strong password, **save it**
4. Region: `ap-southeast-2` (Sydney — closest to your users)
5. Pricing: Free tier is sufficient for Phase 1

### 5.2 Configure Auth Providers

**Google OAuth:**

1. Supabase Dashboard → Authentication → Providers → Google → Enable
2. Go to [Google Cloud Console](https://console.cloud.google.com) → Create project
3. APIs & Services → Credentials → Create OAuth 2.0 Client ID
4. Authorised redirect URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
5. Copy Client ID + Secret → paste into Supabase Google provider settings

# After purchasing the domain, proceed to Step 6.

6. Also add your production URL to authorised JavaScript origins

### OAuth Flow (Google)

1. User clicks "Sign in with Google"
2. Redirect to Google OAuth screen
3. Google redirects back to Supabase callback URL
4. Supabase exchanges code → session
5. User is redirected to the app (Site URL)

The redirect URL must match exactly in both:

- Supabase settings
- Google Cloud Console

**Email Magic Link:**

## The email magic link has not been tested yet; it will be verified after the static pages are set up.

1. Supabase → Authentication → Providers → Email → Enable
2. Disable "Confirm email" if you want passwordless only
3. Set Site URL: `https://yourname.com`
4. Add redirect URLs: `https://yourname.com/api/auth/callback`

### 5.3 Database initialisation

Apply the schema for the first time so the remote database matches `supabase/migrations/0001_initial_schema.sql`.
This is a one-time setup step, not the normal migration workflow.

**Option A — SQL Editor (simplest for Phase 1):**

1. Supabase Dashboard → SQL Editor
2. Open `supabase/migrations/0001_initial_schema.sql` from this repo
3. Paste the full contents and click Run
4. Verify in Table Editor that all expected tables were created

**Option B — Supabase CLI (better for team/multi-environment workflows):**

```bash
npm install --save-dev supabase
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

**Expected state after initialisation:**

- Core tables exist (`profiles`, `bookings`, `time_slots`, `course_types`, etc.)
- RLS is enabled on all user-facing tables
- Required triggers are present
- No pending schema changes

Verify triggers:

```sql
select trigger_name, event_object_table
from information_schema.triggers
where trigger_schema = 'public';
```

Expected triggers: `on_auth_user_created`, `on_booking_cancelled`, `on_cancellation_created`, `booking_status_changed`

**Generate TypeScript types** (run after schema is applied, and again after every schema change):

```bash
npx supabase gen types typescript --project-id YOUR_PROJECT_REF > types/database.ts
```

This file is generated automatically — do not edit manually.

**Common issues:**

| Issue                   | Fix                                                                  |
| ----------------------- | -------------------------------------------------------------------- |
| OAuth redirect mismatch | Ensure the redirect URL matches exactly in Google Cloud Console      |
| Supabase env not loaded | Restart dev server, confirm `.env.local` is in the project root      |
| Wrong local port        | Ensure Site URL in Supabase Auth config matches your actual dev port |

### 5.4 Stitch MCP setup

Stitch MCP lets Codex read your design files directly — no manual export or copy-paste needed.

**Authenticate once:**

```bash
npx @_davideast/stitch-mcp init
# Handles gcloud install, OAuth, and config automatically
```

This runs an interactive wizard that installs gcloud (if needed), handles Google OAuth, and writes credentials to your local config. Run it once — credentials are cached.

**Configure Codex** — add to `~/.codex/config.toml`:

```toml
[mcp_servers.stitch]
command = "npx"
args = ["@_davideast/stitch-mcp", "proxy"]
```

**Verify it works:**

```bash
npx @_davideast/stitch-mcp view --projects
# Should list your Stitch projects
```

**Preview any screen locally before handing to Codex:**
npx @\_davideast/stitch-mcp serve -p 10111007622677145849

# Opens a local server showing all screens

**Screen → route mapping** (project ID: `10111007622677145849`):

| Screen               | Screen ID     | Maps to route        |
| -------------------- | ------------- | -------------------- |
| Homepage (final)     | `af39efb1...` | `/`                  |
| About Dr. Lin        | `2a5916a9...` | `/about`             |
| Contact & Inquiry    | `4e9f1eb2...` | `/contact`           |
| Select a Lesson Time | `8b4d7998...` | `/booking`           |
| Booking Confirmed    | `77cc679c...` | `/booking/confirmed` |
| Student Login        | `972b87dd...` | `/login`             |
| Email Magic Link     | `082b7dac...` | `/login`             |
| Student Dashboard    | `90b1dc77...` | `/dashboard/student` |
| Teacher Dashboard    | `14e3d1e0...` | `/dashboard/teacher` |

These screens are **first drafts** — the designs will be refined in later phases. The IDs are what Codex uses to fetch the current version of each screen at build time, so keeping them here means the mapping is always accurate even as designs change.

**Prompt pattern for Codex when building a page:**

```
Use stitch MCP get_screen_code to fetch screen af39efb1 from project 10111007622677145849.
Convert it to app/(public)/page.tsx:
- Tailwind utility classes only — no inline styles
- Server Component (no 'use client')
- Mobile-first, responsive
- Extract any reusable patterns into components/ui/
```

**Note:** Stitch MCP docs are JavaScript-rendered and Codex sometimes cannot read them directly. If Codex fails to call the tools correctly, paste the tool schema into your prompt explicitly rather than asking it to look up the docs.

### Phase 1 verification

```
✅ localhost:3001 loads
✅ npx tsc --noEmit passes
✅ npm run lint passes
✅ Custom domain live with HTTPS
✅ Google OAuth works end-to-end
✅ Magic Link works end-to-end
✅ Sign-in creates a profiles row with role = student
✅ /dashboard redirects to /login when unauthenticated
✅ npx @_davideast/stitch-mcp view --projects returns your project
```

### 5.5 Writing page prompts for Codex

When Stitch MCP provides the design HTML, Codex has the visual reference it needs. But for pages where you want to override the design, or when you need Codex to understand specific implementation details beyond what Stitch captures, a structured prompt is more reliable than a vague description.

A good page prompt specifies four things: the visual structure, the exact styling tokens, the interaction behaviour, and the implementation constraints. Vague prompts ("make it look nice") produce mediocre output. Precise prompts produce code you can use.

**Format reference** — this is the level of detail that gets good results:

```
Create a full-screen hero section for app/(public)/page.tsx.

## Structure
- Full-screen section, min-h-screen, overflow-hidden, bg-black
- Background: <video> element, autoPlay loop muted playsInline,
  absolute inset-0 w-full h-full object-cover z-0
  src: https://d8j0ntlcm91z4.cloudfront.net/user_38xzZboKViGWJOttwIXH07lWA1P/hf_20260324_151826_c7218672-6e92-402c-9e45-f1e0f454bdc4.mp4
- Navbar (z-10): flex row, justify-between, px-8 py-6, max-w-7xl mx-auto
  Left: brand name — text-3xl tracking-tight white, Instrument Serif
  Center: hidden md:flex — links gap-10, text-sm text-white hover:opacity-80
  Right: "Begin Journey" CTA button (liquid-glass style, see below)
- Hero content (z-10): flex col, items-center justify-center text-center, px-6 pt-32 pb-40
  H1: text-5xl sm:text-7xl md:text-8xl leading-[0.95] tracking-[-2.46px] white, Instrument Serif
  Body: text-base sm:text-lg max-w-2xl mt-8 leading-relaxed white
  CTA: liquid-glass button, rounded-full px-14 py-5 mt-12

## Typography
Import via next/font or <link>:
- Instrument Serif (display) — all headings
- Inter (body) — all body text

## Liquid glass button style
.liquid-glass {
  background: rgba(255,255,255,0.01);
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
  border: none;
  box-shadow: inset 0 1px 1px rgba(255,255,255,0.1);
  position: relative; overflow: hidden;
}
.liquid-glass::before {
  content: ''; position: absolute; inset: 0;
  border-radius: inherit; padding: 1.4px;
  background: linear-gradient(180deg,
    rgba(255,255,255,0.45) 0%, rgba(255,255,255,0.15) 20%,
    rgba(255,255,255,0) 40%, rgba(255,255,255,0) 60%,
    rgba(255,255,255,0.15) 80%, rgba(255,255,255,0.45) 100%);
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor; mask-composite: exclude;
  pointer-events: none;
}
Button hover: hover:scale-[1.03] transition-transform

## Animations
@keyframes fade-rise {
  from { opacity: 0; transform: translateY(24px); }
  to   { opacity: 1; transform: translateY(0); }
}
.animate-fade-rise         { animation: fade-rise 0.8s ease-out both; }
.animate-fade-rise-delay   { animation: fade-rise 0.8s ease-out 0.2s both; }
.animate-fade-rise-delay-2 { animation: fade-rise 0.8s ease-out 0.4s both; }

## Constraints
- Server Component — no 'use client'
- Tailwind for layout and spacing, globals.css for liquid-glass and animations
- Mobile-first responsive
- All text white on dark background
```

The key principle: **specify what Codex cannot infer from the design alone** — animation timings, exact CSS for non-Tailwind effects like liquid glass, font loading strategy, and component boundaries. Everything else Codex can read from the Stitch screen.

---

## Phase 2 — Booking System

New dependencies (add when starting Phase 2):

```bash
npm install @tanstack/react-query
npm install date-fns-tz    # or dayjs/plugin/timezone if not already using
```

### Database changes

Any schema change in Phase 2 follows this sequence:

1. Write SQL in a new migration file: `supabase/migrations/0002_booking_schema.sql`
2. Apply it: Supabase SQL Editor or `npx supabase db push`
3. Regenerate types: `npx supabase gen types typescript --project-id YOUR_PROJECT_REF > types/database.ts`
4. Update `lib/db/schema.ts` to mirror the new tables

Never edit `supabase/migrations/` files that have already been applied — create a new migration instead.

### Phase 2 verification

```
✅ Teacher can create, edit, delete time slots
✅ Student sees available slots in local timezone
✅ Booking creation uses a DB transaction (no double booking)
✅ Teacher approve → booking: confirmed, slot: booked
✅ Teacher reject → booking: cancelled, slot: available
✅ Cancellation by either party releases slot automatically
✅ RLS verified: student A cannot read student B's bookings
```

---

## Phase 3 — Notifications & Dashboards

New dependency:

```bash
npm install @supabase/functions-js   # if calling Edge Functions from server
```

### Supabase Edge Functions

```bash
# Create a new function
npx supabase functions new send-notification

# Serve locally for testing
npx supabase functions serve send-notification --env-file .env.local

# Deploy to production
npx supabase functions deploy send-notification
```

Edge Functions live in `supabase/functions/`. They use Deno, not Node — no `node_modules`.

### Scheduled jobs (24h reminder)

Option A — Supabase pg_cron (runs inside the DB):

```sql
-- Enable extension first
create extension if not exists pg_cron;

-- Schedule the reminder job (runs every hour, checks for lessons in ~24h)
select cron.schedule(
  'send-24h-reminders',
  '0 * * * *',
  $$select net.http_post(
    url := 'https://[ref].functions.supabase.co/send-notification',
    body := '{"type": "reminder_24h"}'::jsonb
  )$$
);
```

Option B — Vercel Cron Jobs (`vercel.json`):

```json
{
  "crons": [
    {
      "path": "/api/cron/reminders",
      "schedule": "0 * * * *"
    }
  ]
}
```

### Phase 3 verification

```
✅ Teacher receives email when booking submitted
✅ Student receives email on confirmation
✅ Both receive email on cancellation
✅ Student receives 24h reminder
✅ Student dashboard shows upcoming + past bookings
✅ Teacher dashboard shows bookings with status filter
✅ All loading/empty/error states handled
```

---

## Recurring operations

### After any schema change

```bash
# 1. Write new migration file
# supabase/migrations/000X_description.sql

# 2. Apply to database
npx supabase db push

# 3. Regenerate types
npx supabase gen types typescript --project-id YOUR_PROJECT_REF > types/database.ts

# 4. Update lib/db/schema.ts to mirror the change
```

### Checking what's deployed

```bash
# See applied migrations
npx supabase migration list

# Check DB diff between local schema and remote
npx supabase db diff
```

### Adding a new API route

Pattern every route must follow:

```
app/api/[resource]/[action]/route.ts
  └── verify session (getUser)
  └── call lib/services/[resource].service.ts
  └── return NextResponse

lib/services/[resource].service.ts
  └── business logic
  └── call lib/db/queries/[resource].ts

lib/db/queries/[resource].ts
  └── pure data access only
  └── no conditionals, no rules
```
