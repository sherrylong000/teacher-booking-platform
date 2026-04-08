# Setup Guide

## Teacher Booking Platform

**Version:** 1.0.0
**Last Updated:** 2026-04-07

---

## Prerequisites

Before starting, ensure you have:

| Tool    | Version            | Check            |
| ------- | ------------------ | ---------------- |
| Node.js | 20.x LTS or higher | `node --version` |
| pnpm    | 9.x                | `pnpm --version` |
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
pnpm create next-app@latest teacher-booking-platform
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
pnpm dev
```

Verify: `http://localhost:3000` shows the Next.js welcome page.

---

### 1.2 Install Core Dependencies

```bash
# Supabase
pnpm add @supabase/supabase-js @supabase/ssr

# Drizzle ORM
pnpm add drizzle-orm postgres
pnpm add -D drizzle-kit

# Date / Timezone
pnpm add dayjs dayjs

# Utility
pnpm add clsx tailwind-merge

# Forms + Validation
pnpm add react-hook-form zod @hookform/resolvers

# Toast notifications
pnpm add sonner

# Email (server only)
pnpm add resend
```

---

### 1.3 Environment Variables

Create `.env.local` (never commit this file):

```bash
cp .env.example .env.local
```

`.env.example` contents (commit this file with empty values):

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# Resend
RESEND_API_KEY=

# App
NEXT_PUBLIC_SITE_URL=http://localhost:3000
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
6. Also add your production URL to authorised JavaScript origins

**Email Magic Link:**

1. Supabase → Authentication → Providers → Email → Enable
2. Disable "Confirm email" if you want passwordless only
3. Set Site URL: `https://yourname.com`
4. Add redirect URLs: `https://yourname.com/api/auth/callback`

### 5.3 Run Database Migrations

```bash
# Install Supabase CLI
pnpm add -D supabase

# Link to your project
pnpm supabase login
pnpm supabase link --project-ref YOUR_PROJECT_REF

# Run the initial schema migration
pnpm supabase db push
```

Or paste the SQL directly into Supabase Dashboard → SQL Editor.

### 5.4 Generate TypeScript Types

```bash
pnpm supabase gen types typescript --project-id YOUR_PROJECT_REF > types/database.ts
```

Re-run this command whenever you change the database schema.

---

## Part 6 — VS Code Setup

### 6.1 Recommended Extensions

Create `.vscode/extensions.json`:

```json
{
  "recommendations": [
    "bradlc.vscode-tailwindcss",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "prisma.prisma",
    "ms-vscode.vscode-typescript-next"
  ]
}
```

### 6.2 Workspace Settings

Create `.vscode/settings.json`:

```json
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "tailwindCSS.experimental.classRegex": [
    ["cn\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]"]
  ]
}
```
