// app/(auth)/login/page.tsx
'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const supabase = createClient()

  async function handleMagicLink(e: React.FormEvent) {
    e.preventDefault()
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: {
        emailRedirectTo: `${window.location.origin}/api/auth/callback`,
      },
    })
    if (!error) setSent(true)
    else alert(error.message)
  }

  async function handleGoogle() {
    await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/api/auth/callback`,
      },
    })
  }

  if (sent) {
    return (
      <div style={{ padding: 40 }}>
        <h2>Check your email</h2>
        <p>Magic link sent to {email}</p>
      </div>
    )
  }

  return (
    <div style={{ padding: 40, maxWidth: 400 }}>
      <h1>Sign in</h1>

      <button onClick={handleGoogle} style={{ display: 'block', marginBottom: 24 }}>
        Continue with Google
      </button>

      <form onSubmit={handleMagicLink}>
        <input
          type="email"
          placeholder="your@email.com"
          value={email}
          onChange={e => setEmail(e.target.value)}
          required
          style={{ display: 'block', marginBottom: 8, width: '100%' }}
        />
        <button type="submit">Send Magic Link</button>
      </form>
    </div>
  )
}