export const ROUTES = {
  LOGIN: "/login",
  HOME: "/",
  PROTECTED: ["/booking", "/dashboard"] as const,
  TEACHER_ONLY: ["/dashboard/teacher"] as const,
  ADMIN_ONLY: ["/dashboard/admin"] as const,
} as const

export function isProtectedPath(pathname: string): boolean {
  return ROUTES.PROTECTED.some((path) => pathname.startsWith(path))
}

export function isTeacherOnlyPath(pathname: string): boolean {
  return ROUTES.TEACHER_ONLY.some((path) => pathname.startsWith(path))
}

export function isAdminOnlyPath(pathname: string): boolean {
  return ROUTES.ADMIN_ONLY.some((path) => pathname.startsWith(path))
}