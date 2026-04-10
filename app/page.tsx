// app/page.tsx
import Link from "next/link"

export default function Home() {
  return (
    <div style={{ padding: 40 }}>
      <h1>首页</h1>

      <Link href="/login">去登录</Link>
    </div>
  )
}