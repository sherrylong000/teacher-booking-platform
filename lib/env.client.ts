// lib/env.client.ts

function assertValue(value: string | undefined, name: string): string {
  if (!value) throw new Error(`Missing env: ${name}`)
  return value
}

export const clientEnv = {
  SUPABASE_URL: assertValue(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    "NEXT_PUBLIC_SUPABASE_URL"
  ),
  SUPABASE_ANON_KEY: assertValue(
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    "NEXT_PUBLIC_SUPABASE_ANON_KEY"
  ),
  SITE_URL: process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000",
}