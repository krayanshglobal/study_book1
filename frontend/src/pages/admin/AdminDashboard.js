import React, { useEffect, useState } from "react";
import { Link as RouterLink } from "react-router-dom";
import api, { formatApiError } from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { motion } from "framer-motion";
import { Users, BookOpen, GraduationCap, Video, CreditCard, ClipboardList, ArrowUpRight, Plus, Calendar, Film, Gem, Megaphone, BarChart3, ShieldAlert, Layers, Trophy, Share2, MessageSquare } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";

const tiles = [
  { icon: Trophy, label: "Leaderboard", to: "/leaderboard", key: "leaderboard", tone: "text-amber-500" },
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
  const [lbReleased, setLbReleased] = useState(false);
  const [lbLoading, setLbLoading] = useState(false);
  const [referrals, setReferrals] = useState([]);

  useEffect(() => {
    (async () => {
      try {
        const r = await api.get("/api/admin/stats", { params: { class_level: activeClass } });
        setStats(r.data);
      } catch {}
    })();
  }, [activeClass]);

  useEffect(() => {
    (async () => {
      try {
        const [lbRes, refRes] = await Promise.all([
          api.get("/api/admin/leaderboard/release-status"),
          api.get("/api/admin/referrals"),
        ]);
        setLbReleased(lbRes.data.released);
        setReferrals(refRes.data.items || []);
      } catch (err) {
        console.error("Failed to load admin dashboard settings", err);
      }
    })();
  }, []);

  const toggleLeaderboardRelease = async (checked) => {
    setLbLoading(true);
    try {
      const res = await api.post("/api/admin/leaderboard/release", { released: checked });
      setLbReleased(res.data.released);
      toast.success(res.data.released ? "Leaderboard released to students!" : "Leaderboard hidden from students.");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setLbLoading(false);
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <div className="border-b border-[#0F1B4C]/10 pb-6 mb-8">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Command centre</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
            {user?.role === "superadmin" ? "SuperAdmin dashboard" : "Admin dashboard"}
          </h1>
          <p className="mt-1 text-[#64748B]">You control the entire StudyBook experience.</p>
        </div>
      </div>

      {/* Quick Navigation Action Buttons for Leaderboard, Tests, Questions & Top Referrals */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <RouterLink to="/leaderboard" data-testid="admin-nav-leaderboard-btn">
          <Card className="p-5 rounded-2xl border-slate-200 bg-gradient-to-r from-amber-500/10 via-amber-500/5 to-transparent border hover:border-amber-500/40 hover:shadow-lg transition-all flex items-center justify-between group">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 grid place-items-center shrink-0 group-hover:scale-110 transition-transform">
                <Trophy size={20} />
              </div>
              <div className="min-w-0">
                <h2 className="font-serif text-base text-[#0F1B4C] font-semibold truncate">Leaderboard</h2>
                <p className="text-[11px] text-[#64748B] truncate">Scores &amp; release</p>
              </div>
            </div>
            <ArrowUpRight size={18} className="text-amber-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform shrink-0" />
          </Card>
        </RouterLink>

        <RouterLink to="/admin/tests" data-testid="admin-nav-tests-btn">
          <Card className="p-5 rounded-2xl border-slate-200 bg-gradient-to-r from-purple-500/10 via-purple-500/5 to-transparent border hover:border-purple-500/40 hover:shadow-lg transition-all flex items-center justify-between group">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-10 h-10 rounded-xl bg-purple-100 text-purple-700 grid place-items-center shrink-0 group-hover:scale-110 transition-transform">
                <ClipboardList size={20} />
              </div>
              <div className="min-w-0">
                <h2 className="font-serif text-base text-[#0F1B4C] font-semibold truncate">Mock &amp; Final Tests</h2>
                <p className="text-[11px] text-[#64748B] truncate">Schedule &amp; test LBs</p>
              </div>
            </div>
            <ArrowUpRight size={18} className="text-purple-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform shrink-0" />
          </Card>
        </RouterLink>

        <RouterLink to="/admin/questions" data-testid="admin-nav-questions-btn">
          <Card className="p-5 rounded-2xl border-slate-200 bg-gradient-to-r from-blue-500/10 via-blue-500/5 to-transparent border hover:border-blue-500/40 hover:shadow-lg transition-all flex items-center justify-between group">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 grid place-items-center shrink-0 group-hover:scale-110 transition-transform">
                <BookOpen size={20} />
              </div>
              <div className="min-w-0">
                <h2 className="font-serif text-base text-[#0F1B4C] font-semibold truncate">Question Bank</h2>
                <p className="text-[11px] text-[#64748B] truncate">Add &amp; manage questions</p>
              </div>
            </div>
            <ArrowUpRight size={18} className="text-blue-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform shrink-0" />
          </Card>
        </RouterLink>

        <RouterLink to="/admin/referrals" data-testid="admin-nav-referrals-btn">
          <Card className="p-5 rounded-2xl border-slate-200 bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-transparent border hover:border-emerald-500/40 hover:shadow-lg transition-all flex items-center justify-between group">
            <div className="flex items-center gap-3 min-w-0">
              <div className="w-10 h-10 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center shrink-0 group-hover:scale-110 transition-transform">
                <Share2 size={20} />
              </div>
              <div className="min-w-0">
                <h2 className="font-serif text-base text-[#0F1B4C] font-semibold truncate">Top Referrals</h2>
                <p className="text-[11px] text-[#64748B] truncate">Classwise invite rank</p>
              </div>
            </div>
            <ArrowUpRight size={18} className="text-emerald-600 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform shrink-0" />
          </Card>
        </RouterLink>
      </div>

      {/* Global Admin Class Filter Switcher — below quick nav */}
      <div className="mt-6 flex items-center gap-2">
        <span className="text-xs font-semibold text-[#64748B] mr-1">Filter by class:</span>
        <div className="flex items-center gap-1.5 bg-slate-100 p-1.5 rounded-full border border-slate-200 shadow-sm">
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

      {/* Dynamic Action Notification Banners for Admins (under class switcher) */}
      {(stats.class_requests > 0 || stats.doubts > 0) && (
        <div className="mt-4 space-y-3">
          {stats.class_requests > 0 && (
            <div className="flex items-center justify-between gap-4 bg-amber-500/10 border border-amber-500/30 rounded-2xl p-4 shadow-sm text-amber-950">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-amber-500 text-white grid place-items-center shrink-0">
                  <ShieldAlert size={20} className="animate-bounce" />
                </div>
                <div>
                  <div className="font-semibold text-sm">
                    Class {activeClass}: You have {stats.class_requests} pending Class Switch Request{stats.class_requests > 1 ? "s" : ""}
                  </div>
                  <div className="text-xs text-amber-900/80">Students waiting for approval to join Class {activeClass}.</div>
                </div>
              </div>
              <RouterLink to="/admin/class-requests">
                <button className="px-4 py-2 rounded-full bg-amber-600 hover:bg-amber-700 text-white text-xs font-bold shadow-sm transition-all shrink-0 cursor-pointer">
                  Manage Requests →
                </button>
              </RouterLink>
            </div>
          )}

          {stats.doubts > 0 && (
            <div className="flex items-center justify-between gap-4 bg-purple-500/10 border border-purple-500/30 rounded-2xl p-4 shadow-sm text-purple-950">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-[#7C3AED] text-white grid place-items-center shrink-0">
                  <MessageSquare size={20} className="animate-pulse" />
                </div>
                <div>
                  <div className="font-semibold text-sm">
                    Class {activeClass}: You have {stats.doubts} student doubt clarification thread{stats.doubts > 1 ? "s" : ""}
                  </div>
                  <div className="text-xs text-purple-900/80">Class {activeClass} questions submitted on discussion board.</div>
                </div>
              </div>
              <RouterLink to="/admin/discussions">
                <button className="px-4 py-2 rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] text-white text-xs font-bold shadow-sm transition-all shrink-0 cursor-pointer">
                  Resolve Doubts →
                </button>
              </RouterLink>
            </div>
          )}
        </div>
      )}

      <div className="mt-8 grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {tiles.map((t, i) => (
          <motion.div key={t.key} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.05 }}>
            <RouterLink to={t.to}>
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
            </RouterLink>
          </motion.div>
        ))}
      </div>

      <div className="mt-10 grid md:grid-cols-2 gap-6">
        <Card className="p-8 rounded-2xl border-slate-200 bg-white">
          <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold font-medium">Quick actions</div>
          <div className="mt-4 space-y-2">
            <RouterLink to="/leaderboard" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-leaderboard"><Trophy className="text-amber-500" size={16} /> View &amp; manage Leaderboard rankings</RouterLink>
            <RouterLink to="/admin/questions" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-question"><Plus className="text-[#2563EB]" size={16} /> Add a new question to the bank</RouterLink>
            <RouterLink to="/admin/tests" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-create-test"><Calendar className="text-[#7C3AED]" size={16} /> Schedule a Sunday mock test</RouterLink>
            <RouterLink to="/admin/videos" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-video"><Film className="text-[#2563EB]" size={16} /> Publish a new video lesson</RouterLink>
            <RouterLink to="/admin/flashcards" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-flashcards"><Layers className="text-[#7C3AED]" size={16} /> Manage flashcards</RouterLink>
            <RouterLink to="/admin/plans" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-plan"><Gem className="text-[#7C3AED]" size={16} /> Create a premium plan</RouterLink>
            <RouterLink to="/admin/announcements" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-add-ann"><Megaphone className="text-[#0F1B4C]" size={16} /> Broadcast an announcement</RouterLink>
            <RouterLink to="/admin/class-requests" className="flex items-center gap-3 p-3 rounded-lg hover:bg-slate-50 border border-slate-100" data-testid="qa-class-requests"><ShieldAlert className="text-amber-500" size={16} /> Approve or reject class change requests</RouterLink>
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

      {/* Admin Referral Dashboard Section */}
      <div className="mt-10">
        <Card className="p-8 rounded-2xl border-slate-200 bg-white">
          <div className="flex items-center justify-between mb-6">
            <div>
              <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold flex items-center gap-1.5">
                <Share2 size={14} /> Referral Tracking
              </div>
              <h2 className="font-serif text-2xl text-[#0F1B4C] font-semibold mt-1">Top Referrers &amp; Conversion</h2>
            </div>
            <Badge variant="outline" className="text-xs">
              {referrals.length} Referrers
            </Badge>
          </div>

          {referrals.length === 0 ? (
            <div className="text-center text-[#64748B] py-8 text-sm">No referrals recorded yet.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 text-xs uppercase tracking-wider text-slate-500 bg-slate-50">
                    <th className="py-3 px-4 rounded-l-lg">Rank</th>
                    <th className="py-3 px-4">User</th>
                    <th className="py-3 px-4">Code</th>
                    <th className="py-3 px-4 text-center">Total Referred</th>
                    <th className="py-3 px-4 text-center">Converted (Paid)</th>
                    <th className="py-3 px-4 text-right rounded-r-lg">Conversion %</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {referrals.map((r, i) => (
                    <tr key={r.referrer_id} className="hover:bg-slate-50/50">
                      <td className="py-3 px-4 font-mono font-semibold text-slate-500">#{i + 1}</td>
                      <td className="py-3 px-4 font-medium text-[#0F1B4C]">
                        <div>{r.name}</div>
                        <div className="text-xs text-slate-400">{r.email}</div>
                      </td>
                      <td className="py-3 px-4 font-mono text-xs text-[#7C3AED] font-bold">{r.referral_code}</td>
                      <td className="py-3 px-4 text-center font-mono font-semibold">{r.total_referred}</td>
                      <td className="py-3 px-4 text-center font-mono font-semibold text-emerald-600">{r.converted}</td>
                      <td className="py-3 px-4 text-right font-mono font-bold text-[#2563EB]">{r.conversion_pct}%</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
