import { clientEnv } from "./env.client"

function requireServerEnv(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`Missing server env: ${name}`)
  return value
}

export const serverEnv = {
  ...clientEnv,
  SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY ?? "",
  RESEND_API_KEY: requireServerEnv("RESEND_API_KEY"),
}
