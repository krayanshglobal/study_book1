import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://localhost:8000";
export const API_BASE = `${BACKEND_URL}/api`;

const api = axios.create({
  baseURL: BACKEND_URL,
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
});

export function formatApiError(err) {
  const d = err?.response?.data?.detail;
  if (d == null) return err?.message || "Something went wrong.";
  if (typeof d === "string") return d;
  if (Array.isArray(d))
    return d.map((e) => (e && typeof e.msg === "string" ? e.msg : JSON.stringify(e))).join(" ");
  if (typeof d === "object" && typeof d.msg === "string") return d.msg;
  return String(d);
}

// Global 401 interceptor: auto-redirect to /login on session expiry.
// We use a lazy import to avoid circular dependency with AuthContext.
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error?.response?.status === 401) {
      // Only redirect if not already on an auth page
      const pathname = window.location.pathname;
      const authPaths = ["/login", "/register", "/forgot-password", "/reset-password"];
      if (!authPaths.some((p) => pathname.startsWith(p))) {
        // Clear any stale state and redirect
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

export default api;
