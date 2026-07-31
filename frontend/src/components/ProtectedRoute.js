import React from "react";
import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";

export default function ProtectedRoute({ children, roles }) {
  const { user, loading } = useAuth();
  const loc = useLocation();

  if (loading || user === null) {
    return (
      <div className="min-h-screen grid place-items-center bg-[#F8FAFC]">
        <div className="text-[#0F1B4C] font-medium">Loading…</div>
      </div>
    );
  }
  if (!user) return <Navigate to="/login" state={{ from: loc.pathname }} replace />;
  if (roles && !roles.includes(user.role)) return <Navigate to="/dashboard" replace />;
  return children;
}
