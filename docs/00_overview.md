# Teacher Booking Platform

## Documentation Overview

---

## What this is

A single-teacher booking platform. Students request lesson slots; the teacher approves or rejects each request manually. No auto-confirmation, no payments in v1.

Core workflow: **request → approval → confirm or cancel**

---

## Documentation Map

| File              | What it answers                                                         |
| ----------------- | ----------------------------------------------------------------------- |
| `PRD.md`          | What are we building and why? Features, roles, success criteria.        |
| `architecture.md` | How is the system structured? Layers, data flow, project structure.     |
| `decisions.md`    | Why did we make specific technical choices? Tradeoffs and alternatives. |
| `setup.md`        | How do I run this locally? Step-by-step environment setup.              |
| `roadmap.md`      | What is done, what is next, what are the known risks?                   |

**Start here if you are:**

- New to the project → read `PRD.md` then `architecture.md`
- Setting up locally → go to `setup.md`
- Reviewing a technical decision → check `decisions.md`
- Planning the next phase → check `roadmap.md`

---

## Current Status

| Phase                                     | Status      |
| ----------------------------------------- | ----------- |
| Phase 1 — Foundation (auth + static site) | In progress |
| Phase 2 — Booking system                  | Not started |
| Phase 3 — Dashboards + notifications      | Not started |

---

## Key Constraints

- Single teacher only (no multi-tenancy)
- No payments in v1
- Authorization enforced at the database level — middleware is UX only
- All timestamps stored in UTC, displayed in viewer's local timezone
