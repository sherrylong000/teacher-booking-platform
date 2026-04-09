// lib/supabase/server.ts
import { createServerClient } from "@supabase/ssr"
import { cookies } from "next/headers"
import { serverEnv } from "@/lib/env.server"


export async function createClient() {
  const cookieStore = await cookies()

  return createServerClient(
    serverEnv.SUPABASE_URL,
    serverEnv.SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll()
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options)
            })
          } catch {
            // In some Server Component contexts, setting cookies is not allowed.
            // Middleware will handle session refresh in those cases.
          }
        },
      },
    }
  )
}