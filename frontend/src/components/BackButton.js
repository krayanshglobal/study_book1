import React from "react";
import { useNavigate } from "react-router-dom";
import { ArrowLeft } from "lucide-react";

export default function BackButton({ to, label = "Back", className = "" }) {
  const navigate = useNavigate();
  return (
    <button
      onClick={() => (to ? navigate(to) : navigate(-1))}
      data-testid="back-btn"
      className={`inline-flex items-center gap-2 text-sm text-[#334155] hover:text-[#0F1B4C] transition-colors ${className}`}
    >
      <span className="w-8 h-8 rounded-full border border-slate-200 grid place-items-center group-hover:bg-slate-100">
        <ArrowLeft size={16} />
      </span>
      <span className="font-medium">{label}</span>
    </button>
  );
}
