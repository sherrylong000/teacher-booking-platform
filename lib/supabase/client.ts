// lib/supabase/client.ts
import { createBrowserClient } from "@supabase/ssr"
import { clientEnv } from "@/lib/env.client"

export function createClient() {
  return createBrowserClient(
    clientEnv.SUPABASE_URL,
    clientEnv.SUPABASE_ANON_KEY
  )
}