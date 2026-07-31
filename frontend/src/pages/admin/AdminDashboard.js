import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import api from "@/lib/api";
import { Card } from "@/components/ui/card";
import { motion } from "framer-motion";
import { Users, BookOpen, GraduationCap, Video, CreditCard, ClipboardList, ArrowUpRight, Plus, Calendar, Film, Gem, Megaphone, BarChart3, ShieldAlert, Layers } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";

const tiles = [
  { icon: BookOpen, label: "Questions", to: "/admin/questions", key: "questions", tone: "text-[#2563EB]" },
  { icon: ClipboardList, label: "Tests", to: "/admin/tests", key: "tests", tone: "text-[#7C3AED]" },
  { icon: Video, label: "Videos", to: "/admin/videos", key: "videos", tone: "text-[#0F1B4C]" },
  { icon: Layers, label: "Flashcards", to: "/admin/flashcards", key: "flashcards", tone: "text-[#7C3AED]" },
  { icon: BarChart3, label: "Analytics", to: "/admin/analytics", key: "attempts", tone: "text-[#7C3AED]" },
  { icon: Users, label: "Students", to: "/admin/users", key: "students", tone: "text-[#2563EB]" },
  { icon: CreditCard, label: "Active subs", to: "/admin/plans", key: "active_subs", tone: "text-[#0F1B4C]" },
  { icon: ShieldAlert, label: "Class Requests", to: "/admin/class-requests", key: "class_requests", tone: "text-amber-500" },
  { icon: Megaphone, label: "Notifications", to: "/admin/announcements", key: "announcements", tone: "text-[#7C3AED]" },
];

export default function AdminDashboard() {
  const { user } = useAuth();
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [stats, setStats] = useState({});

  useEffect(() => {
    (async () => {
      try {
        const r = await api.get("/api/admin/stats", { params: { class_level: activeClass } });
        setStats(r.data);
      } catch {}
    })();
  }, [activeClass]);

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-[#0F1B4C]/10 pb-6 mb-8">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Command centre</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
            {user?.role === "superadmin" ? "SuperAdmin dashboard" : "Admin dashboard"}
          </h1>
          <p className="mt-1 text-[#64748B]">You control the entire StudyBook experience.</p>
        </div>

        {/* Global Admin Class Filter Switcher */}
        <div className="flex items-center gap-1.5 bg-slate-100 p-1.5 rounded-full border border-slate-200 self-start md:self-auto shadow-sm">
          {["8", "9", "10"].map((lvl) => (
            <button
              key={lvl}
              onClick={() => {
                localStorage.setItem("admin_class_level", lvl);
                setActiveClass(lvl);
              }}
              className={`px-4 py-1.5 rounded-full text-xs font-semibold font-mono transition-all ${
                activeClass === lvl
                  ? "bg-[#0F1B4C] text-white shadow-md scale-105"
                  : "text-[#475569] hover:text-[#0F1B4C] hover:bg-slate-200/50"
              }`}
            >
              Class {lvl}
            </button>
          ))}
        </div>
      </div>

      <div className="mt-8 grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {tiles.map((t, i) => (
          <motion.div key={t.key} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}>
            <Link to={t.to}>
              <Card className="p-7 rounded-2xl border-slate-200 hover:border-[#2563EB]/40 hover:shadow-[0_18px_40px_-24px_rgba(37,99,235,0.35)] transition-all cursor-pointer bg-white" data-testid={`admin-tile-${t.key}`}>
                <div className="flex items-start justify-between">
                  <div>
                    <div className="text-xs tracking-widest uppercase text-[#64748B] font-semibold">Class {activeClass} · {t.label}</div>
                    <div className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">{stats[t.key] ?? "—"}</div>
                  </div>
                  <div className={`w-11 h-11 rounded-xl grid place-items-center bg-slate-50 ${t.tone}`}><t.icon size={22} /></div>
                </div>
                <div className="mt-4 inline-flex items-center gap-1 text-sm text-[#2563EB]">Manage <ArrowUpRight size={14} /></div>
              </Card>
            </Link>
          </motion.div>
        ))}
      </div>

      <div className="mt-10 grid md:grid-cols-2 gap-6">
        <Card className="p-8 rounded-2xl border-slate-200 bg-white">
          <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold font-medium">Quick actions</div>
          <div className="mt-4 space-y-2">
            <Link to="/admin/questions" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-question"><Plus className="text-[#2563EB]" size={16} /> Add a new question to the bank</Link>
            <Link to="/admin/tests" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-create-test"><Calendar className="text-[#7C3AED]" size={16} /> Schedule a Sunday mock test</Link>
            <Link to="/admin/videos" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-video"><Film className="text-[#2563EB]" size={16} /> Publish a new video lesson</Link>
            <Link to="/admin/flashcards" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-flashcards"><Layers className="text-[#7C3AED]" size={16} /> Manage flashcards</Link>
            <Link to="/admin/plans" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-plan"><Gem className="text-[#7C3AED]" size={16} /> Create a premium plan</Link>
            <Link to="/admin/announcements" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-ann"><Megaphone className="text-[#0F1B4C]" size={16} /> Broadcast an announcement</Link>
            <Link to="/admin/class-requests" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-class-requests"><ShieldAlert className="text-amber-500" size={16} /> Approve or reject class change requests</Link>
          </div>
        </Card>
        <Card className="p-8 rounded-2xl border-slate-200 bg-white">
          <div className="text-xs tracking-widest uppercase text-[#2563EB] font-semibold font-medium">Class {activeClass} Pulse</div>
          <div className="mt-4 space-y-3">
            <div className="flex items-center justify-between"><span className="text-[#334155] text-sm">Total students</span><span className="font-mono text-[#0F1B4C] font-semibold">{stats.students ?? 0}</span></div>
            <div className="flex items-center justify-between"><span className="text-[#334155] text-sm">Question bank size</span><span className="font-mono text-[#0F1B4C] font-semibold">{stats.questions ?? 0}</span></div>
            <div className="flex items-center justify-between"><span className="text-[#334155] text-sm">Tests scheduled</span><span className="font-mono text-[#0F1B4C] font-semibold">{stats.tests ?? 0}</span></div>
            <div className="flex items-center justify-between"><span className="text-[#334155] text-sm">Videos published</span><span className="font-mono text-[#0F1B4C] font-semibold">{stats.videos ?? 0}</span></div>
            <div className="flex items-center justify-between"><span className="text-[#334155] text-sm">Premium members</span><span className="font-mono text-[#0F1B4C] font-semibold">{stats.active_subs ?? 0}</span></div>
          </div>
        </Card>
      </div>
    </div>
  );
}
