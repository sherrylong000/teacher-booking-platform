import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"

function getSafeNext(next: string | null): string {
  if (!next) return "/"
  if (next.startsWith("/") && !next.startsWith("//")) return next
  return "/"
}

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get("code")
  const next = getSafeNext(requestUrl.searchParams.get("next"))
  const origin = requestUrl.origin

  if (!code) {
    return NextResponse.redirect(`${origin}/login?error=missing_code`)
  }

  const supabase = await createClient()
  const { error } = await supabase.auth.exchangeCodeForSession(code)

  if (error) {
    return NextResponse.redirect(`${origin}/login?error=auth_callback_error`)
  }

  return NextResponse.redirect(`${origin}${next}`)
}