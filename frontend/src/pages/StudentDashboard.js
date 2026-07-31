import React, { useEffect, useState } from "react";
import { LOGO_URL_EXPORT } from "@/components/Logo";
import { Link } from "react-router-dom";
import api from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { motion } from "framer-motion";
import { Calendar, Trophy, Users, Video, ArrowUpRight, Sparkles, TrendingUp, Bell, Clock, ArrowRight, Ruler, GraduationCap, Copy, Check } from "lucide-react";
import { toast } from "sonner";

function timeUntil(t) {
  const now = new Date();
  const start = new Date(`${t.scheduled_date}T${t.start_time}:00+05:30`);
  let end = new Date(`${t.scheduled_date}T${t.end_time}:00+05:30`);
  if (end <= start) {
    end.setDate(end.getDate() + 1);
  }
  return { start, end, now, msToStart: start - now, msToEnd: end - now };
}
function fmtCountdown(ms) {
  if (ms <= 0) return "starts now";
  const s = Math.floor(ms / 1000);
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (d > 0) return `in ${d}d ${h}h`;
  if (h > 0) return `in ${h}h ${m}m`;
  return `in ${m}m`;
}

function StatCard({ icon: Icon, label, value, tone = "blue" }) {
  const toneMap = {
    blue: "text-[#2563EB]",
    violet: "text-[#7C3AED]",
    navy: "text-[#0F1B4C]",
  };
  return (
    <Card className="p-6 rounded-2xl border-slate-200 shadow-none hover:shadow-[0_16px_36px_-24px_rgba(15,27,76,0.35)] transition-shadow">
      <div className="flex items-start justify-between">
        <div>
          <div className="text-xs tracking-[0.22em] uppercase text-[#64748B] font-semibold">{label}</div>
          <div className="mt-2 font-serif text-3xl text-[#0F1B4C] font-semibold">{value}</div>
        </div>
        <div className={`w-10 h-10 rounded-xl grid place-items-center bg-slate-50 ${toneMap[tone]}`}>
          <Icon size={20} />
        </div>
      </div>
    </Card>
  );
}

const bannerConfigs = [
  // Slide 1: Creamy Gold & Red — now FIRST
  {
    theme: "creamy",
    gradient: "linear-gradient(135deg, #FFFBEB 0%, #FEF3C7 50%, #FDE68A 100%)",
    layoutClass: "flex-col md:flex-row",
    textColor: "text-slate-900",
    shapes: (
      <>
        <div className="absolute -right-10 -top-10 w-48 h-48 rounded-full bg-orange-400/10 blur-2xl pointer-events-none" />
        <div className="absolute -left-20 -bottom-20 w-64 h-64 rounded-full bg-rose-500/10 blur-3xl pointer-events-none" />
      </>
    ),
    renderContent: (p) => (
      <div className="flex-1 space-y-3 z-10 text-left text-slate-900">
        <h2 className="font-serif text-2xl md:text-3xl font-extrabold tracking-tight text-red-600">
          {p.title || "Get upto 80% Off"}
        </h2>
        <p className="text-sm text-[#0F1B4C] leading-relaxed font-extrabold">{p.subtitle || "Unlock all Videos, Tests & Notes"}</p>
        {p.code ? (
          <div className="text-xs text-slate-900 font-semibold bg-white/40 px-3 py-1 rounded-full border border-red-500/20 inline-block">
            Use Code: <span className="font-mono text-red-600 font-bold">{p.code}</span>
          </div>
        ) : null}
        <div className="pt-2">
          <Link to={p.link_url || "/pricing"}>
            <Button className="rounded-md bg-[#0F1B4C] hover:bg-slate-800 text-white font-extrabold px-6 py-2 h-auto text-xs transition-transform hover:scale-105 shadow-md border-0">
              Join Now
            </Button>
          </Link>
        </div>
      </div>
    ),
    renderRight: () => (
      <div className="hidden md:flex flex-col items-center justify-center shrink-0 w-32 h-24 bg-red-600 border border-red-700 rounded-xl p-3 text-center shadow-lg transform -rotate-3 z-10 text-white">
        <div className="text-[9px] uppercase tracking-widest text-amber-200 font-bold">StudyBook Infinity</div>
        <div className="font-serif text-sm font-extrabold mt-0.5 tracking-tight">LAUNCH</div>
        <div className="text-[9px] uppercase font-bold text-white bg-black/20 px-2 py-0.5 rounded mt-1.5">OFFER</div>
      </div>
    )
  },
  // Slide 2: Geometric Outline Theme
  {
    theme: "geometric",
    gradient: "linear-gradient(135deg, #1E3A8A 0%, #0D9488 100%)",
    layoutClass: "flex-col md:flex-row",
    textColor: "text-white",
    shapes: (
      <>
        <div className="absolute -left-10 -top-10 w-56 h-56 rounded-full bg-emerald-400/10 blur-3xl pointer-events-none" />
        <div className="absolute -right-20 -bottom-20 w-44 h-44 rounded-full bg-teal-300/10 blur-2xl pointer-events-none" />
      </>
    ),
    renderContent: (p) => (
      <div className="flex-1 space-y-3 z-10 text-left">
        <h2 className="font-serif text-2xl md:text-3xl font-extrabold tracking-tight text-[#FBBF24]">
          {p.title || "₹200 off for New Users"}
        </h2>
        <p className="text-sm text-slate-100 leading-relaxed font-semibold">{p.subtitle}</p>
        {p.code ? (
          <div className="text-xs text-white/95 font-semibold bg-white/10 px-3 py-1 rounded-full border border-yellow-500/20 inline-block">
            Use Code: <span className="font-mono text-[#FBBF24] font-bold">{p.code}</span>
          </div>
        ) : null}
        <div className="pt-2">
          <Link to={p.link_url || "/pricing"}>
            <Button className="rounded-md bg-[#FBBF24] hover:bg-yellow-500 text-slate-900 font-extrabold px-6 py-2 h-auto text-xs uppercase tracking-wider transition-transform hover:scale-105 shadow-md border-0">
              JOIN NOW
            </Button>
          </Link>
        </div>
      </div>
    ),
    renderRight: () => (
      <div className="hidden md:block relative shrink-0 z-10">
        <div className="absolute -left-9 top-[35%] w-0 h-0 border-l-[9px] border-l-transparent border-r-[9px] border-r-transparent border-b-[16px] border-b-yellow-400/35 transform rotate-12 pointer-events-none" />
        <div className="absolute -right-5 bottom-[20%] w-0 h-0 border-l-[11px] border-l-transparent border-r-[11px] border-r-transparent border-b-[18px] border-b-white/25 transform -rotate-45 pointer-events-none" />
        <div className="flex flex-col items-center justify-center w-28 h-28 bg-[#1E3A8A]/50 border-2 border-[#FBBF24] rounded-2xl p-4 text-[#FBBF24] text-center shadow-xl transform rotate-6">
          <div className="font-serif text-xs font-bold text-[#FBBF24]">StudyBook</div>
          <div className="text-xs font-bold text-white uppercase tracking-wider mt-0.5">Infinity</div>
          <div className="text-[8px] text-yellow-300 mt-1.5 uppercase font-semibold tracking-wider">*Limited Offer</div>
        </div>
      </div>
    )
  },
  // Slide 3: Astro Starry Space theme
  {
    theme: "astro",
    gradient: "radial-gradient(circle, rgba(255,255,255,0.08) 1px, transparent 1px) 0 0/18px 18px, linear-gradient(135deg, #020617 0%, #0F172A 50%, #1E293B 100%)",
    layoutClass: "flex-col md:flex-row",
    textColor: "text-white",
    shapes: (
      <>
        <div className="absolute -right-10 -top-10 w-60 h-60 rounded-full bg-white/5 blur-3xl pointer-events-none" />
        <div className="absolute -left-20 -bottom-20 w-44 h-44 rounded-full bg-purple500/10 blur-2xl pointer-events-none" />
      </>
    ),
    renderContent: (p, user) => (
      <div className="flex-1 space-y-3.5 z-10 text-left">
        <h2 className="font-serif text-2xl md:text-3xl font-extrabold tracking-tight text-[#FBBF24]">
          {p.title || `Get ₹500 off on Grade ${user?.class_level || "8"} package today`}
        </h2>
        <p className="text-sm text-slate-200 leading-relaxed font-semibold">{p.subtitle}</p>
        {p.code ? (
          <div className="text-xs text-white/95 font-semibold bg-white/10 px-3 py-1 rounded-full border border-yellow-500/20 inline-block">
            Use Code: <span className="font-mono text-[#FBBF24] font-bold">{p.code}</span>
          </div>
        ) : null}
        <div className="flex items-center gap-3 pt-2">
          <Link to={p.link_url || "/pricing"}>
            <Button className="rounded-md bg-[#FBBF24] hover:bg-yellow-500 text-slate-900 font-extrabold px-5 py-2 h-auto text-xs transition-transform hover:scale-105 shadow-md border-0">
              View Plans
            </Button>
          </Link>
        </div>
      </div>
    ),
    renderRight: () => (
      <div className="hidden md:flex items-center justify-center shrink-0 w-24 h-24 bg-white rounded-full shadow-lg z-10 border border-slate-100/10">
        <GraduationCap size={44} className="text-yellow-500" />
      </div>
    )
  },
];

export default function StudentDashboard() {
  const { user } = useAuth();
  const [upcoming, setUpcoming] = useState([]);
  const [lb, setLb] = useState([]);
  const [refs, setRefs] = useState(null);
  const [announcements, setAnn] = useState([]);
  const [tick, setTick] = useState(0);

  // Promos state
  const [promos, setPromos] = useState([]);
  const [promoTimes, setPromoTimes] = useState({});
  const [activePromoIndex, setActivePromoIndex] = useState(0);

  // Referral copy state
  const [copied, setCopied] = useState(false);
  const handleCopyCode = () => {
    if (!refs?.referral_code) return;
    navigator.clipboard.writeText(refs.referral_code);
    setCopied(true);
    toast.success("Referral code copied!");
    setTimeout(() => setCopied(false), 2000);
  };

  // Auto-play timer for dynamic moving banners
  useEffect(() => {
    if (promos.length <= 1) return;
    const timer = setInterval(() => {
      setActivePromoIndex((prev) => (prev + 1) % promos.length);
    }, 5000);
    return () => clearInterval(timer);
  }, [promos]);

  useEffect(() => {
    const t = setInterval(() => setTick((x) => x + 1), 30000);
    return () => clearInterval(t);
  }, []);

  // Browser notifications for tests starting within 15 min
  useEffect(() => {
    if (typeof Notification === "undefined") return;
    if (Notification.permission === "default") Notification.requestPermission();
    if (Notification.permission !== "granted") return;
    upcoming.forEach((t) => {
      const { msToStart } = timeUntil(t);
      const key = `notified_${t._id}`;
      if (msToStart > 0 && msToStart < 15 * 60 * 1000 && !sessionStorage.getItem(key)) {
        try {
          new Notification("StudyBook — test starting soon", {
            body: `${t.title} starts ${fmtCountdown(msToStart)}`,
            icon: "https://customer-assets-eiarnc6j.emergentagent.net/job_leaderbook-study/artifacts/8fbe1ch1_image.png",
          });
          sessionStorage.setItem(key, "1");
        } catch {}
      }
    });
  }, [upcoming, tick]);

  useEffect(() => {
    (async () => {
      try {
        const [u, l, r, a, p] = await Promise.all([
          api.get("/api/tests/upcoming"),
          api.get("/api/leaderboard", { params: { class_level: user?.class_level, limit: 5 } }),
          api.get("/api/referrals/me"),
          api.get("/api/announcements"),
          api.get("/api/promos"),
        ]);
        setUpcoming(u.data.items || []);
        setLb(l.data.items || []);
        setRefs(r.data);
        setAnn(a.data.items || []);
        setPromos(p.data.items || []);
      } catch {}
    })();
  }, [user]);

  // Live countdown timer for active promos
  useEffect(() => {
    if (promos.length === 0) return;
    const interval = setInterval(() => {
      const updated = {};
      promos.forEach((p) => {
        const endTime = new Date(p.created_at).getTime() + p.countdown_hours * 60 * 60 * 1000;
        const diff = endTime - Date.now();
        if (diff > 0) {
          const hours = Math.floor(diff / 3600000);
          const mins = Math.floor((diff % 3600000) / 60000);
          const secs = Math.floor((diff % 60000) / 1000);
          updated[p._id] = `${hours}h : ${mins}m : ${secs}s`;
        } else {
          updated[p._id] = "Expired";
        }
      });
      setPromoTimes(updated);
    }, 1000);
    return () => clearInterval(interval);
  }, [promos]);

  const myRank = lb.findIndex((x) => x.user_id === user?._id) + 1 || "—";

  // Compute reminder banner for the closest upcoming test starting within 24h
  const soonest = upcoming
    .map((t) => ({ t, ...timeUntil(t) }))
    .filter((x) => x.msToEnd > 0)
    .sort((a, b) => a.msToStart - b.msToStart)[0];
  const showReminder = soonest && soonest.msToStart > 0 && soonest.msToStart < 24 * 60 * 60 * 1000;
  const isLiveNow = soonest && soonest.msToStart <= 0 && soonest.msToEnd > 0;

  const currentPromo = promos[activePromoIndex];

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}>
        <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Welcome</div>
        <h1 className="mt-2 font-serif text-4xl sm:text-5xl text-[#0F1B4C] font-semibold">
          Hey, {user?.name?.split(" ")[0]}.
        </h1>
        <p className="mt-2 text-[#475569]">
          {user?.subscription_active ? "Premium member" : "Free plan"} · Your personalised study space.
        </p>
      </motion.div>

      {/* Promos Banner Slider Section */}
      {promos.length > 0 && (
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          className="mt-8 relative overflow-hidden w-full"
        >
          {/* Sliding inner container */}
          <div
            className="flex transition-transform duration-500 ease-in-out w-full"
            style={{ transform: `translateX(-${activePromoIndex * 100}%)` }}
          >
            {promos.map((p, idx) => {
              const cfg = bannerConfigs[idx % bannerConfigs.length];
              return (
                <div key={p._id} className="w-full flex-shrink-0 flex flex-col">
                  {/* The Banner Card */}
                  <div
                    className={`rounded-3xl p-8 pb-11 flex justify-between items-start md:items-center gap-6 relative overflow-hidden shadow-xl min-h-[220px] md:h-[220px] ${cfg.textColor} ${cfg.layoutClass}`}
                    style={{ background: cfg.gradient }}
                  >
                    {cfg.shapes}
                    {cfg.renderContent(p, user)}
                    {cfg.renderRight()}

                    {/* Dot navigation inside the card at the bottom */}
                    {promos.length > 1 && (
                      <div className="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5 z-20">
                        {promos.map((_, i) => (
                          <button
                            key={i}
                            type="button"
                            onClick={() => setActivePromoIndex(i)}
                            className={`w-2 h-2 rounded-full transition-all ${
                              activePromoIndex === i ? "bg-white w-4" : "bg-white/40"
                            }`}
                          />
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Centered Dynamic Countdown Timer below the card (slides with the card!) */}
                  <div className="mt-3 text-center text-xs sm:text-sm font-semibold text-slate-600">
                    Offer ends in: <span className="font-mono text-red-600 font-bold">{promoTimes[p._id] || `${p.countdown_hours || 12}h : 00m : 00s`}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </motion.div>
      )}

      {/* Announcements — shown right below the banner (single line, no description) */}
      {announcements.length > 0 && (
        <div className="mt-6 space-y-2">
          {announcements.map((ann) => (
            <div
              key={ann._id}
              className="flex items-center gap-3 bg-[#0F1B4C] border border-[#0F1B4C] rounded-2xl px-4 py-2.5"
            >
              <div className="w-6 h-6 rounded-lg grid place-items-center bg-white/10 text-white shrink-0">
                <Bell size={13} />
              </div>
              <div className="flex-1 min-w-0 font-medium text-sm text-white truncate">
                {ann.title}
              </div>
              <span className="text-[10px] text-white/50 shrink-0">
                {new Date(ann.created_at).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}
              </span>
            </div>
          ))}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-5 mt-8">
        {/* Left Card: Test Status */}
        {isLiveNow || showReminder ? (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            className={`rounded-3xl p-6 border flex flex-col justify-between h-44 shadow-sm hover:shadow-md transition-shadow ${
              isLiveNow ? "bg-[#7C3AED]/5 border-[#7C3AED]/20" : "bg-[#2563EB]/5 border-[#2563EB]/20"
            }`}
            data-testid="test-reminder-banner"
          >
            <div className="flex items-start gap-4">
              <div className={`w-12 h-12 rounded-2xl grid place-items-center shrink-0 ${isLiveNow ? "bg-[#7C3AED] text-white" : "bg-[#2563EB]/10 text-[#2563EB]"}`}>
                {isLiveNow ? <Clock size={22} className="animate-pulse" /> : <Bell size={22} />}
              </div>
              <div>
                <div className={`text-xs tracking-widest uppercase font-semibold ${isLiveNow ? "text-[#7C3AED]" : "text-[#2563EB]"}`}>
                  {isLiveNow ? "Test is live" : "Upcoming test"}
                </div>
                <div className="font-serif text-lg text-[#0F1B4C] font-semibold mt-1 line-clamp-1">
                  {soonest.t.title}
                </div>
                <div className="text-xs text-[#64748B] mt-0.5 font-medium">
                  {isLiveNow ? `Ends ${fmtCountdown(soonest.msToEnd)}` : `Starts ${fmtCountdown(soonest.msToStart)}`}
                </div>
              </div>
            </div>
            <div className="flex justify-end pt-2">
              <Link to={isLiveNow ? `/tests/${soonest.t._id}/live` : "/tests"}>
                <Button className={`rounded-full px-5 py-1.5 h-auto text-xs font-bold ${isLiveNow ? "bg-[#7C3AED] hover:bg-[#6D28D9]" : "bg-[#0F1B4C] hover:bg-[#2563EB]"}`} data-testid="reminder-cta-btn">
                  {isLiveNow ? "Start now" : "View details"}
                </Button>
              </Link>
            </div>
          </motion.div>
        ) : (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            className="rounded-3xl p-6 border border-slate-200 bg-slate-50/50 flex flex-col justify-between h-44 shadow-sm hover:shadow-md transition-shadow"
          >
            <div className="flex items-start gap-4">
              <div className="w-12 h-12 rounded-2xl grid place-items-center bg-slate-100 text-slate-500 shrink-0">
                <Calendar size={22} />
              </div>
              <div>
                <div className="text-xs tracking-widest uppercase font-semibold text-slate-500">
                  Test Schedule
                </div>
                <div className="font-serif text-lg text-[#0F1B4C] font-semibold mt-1">
                  No active tests
                </div>
                <div className="text-xs text-[#64748B] mt-0.5 font-medium">
                  All caught up! No mock tests scheduled today.
                </div>
              </div>
            </div>
            <div className="flex justify-end pt-2">
              <Link to="/tests">
                <Button variant="outline" className="rounded-full px-5 py-1.5 h-auto text-xs font-bold border-slate-300 text-[#0F1B4C]">
                  View Schedule
                </Button>
              </Link>
            </div>
          </motion.div>
        )}

        {/* Right Card: Practice Questions */}
        <motion.div
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="rounded-3xl p-6 border border-amber-500/20 bg-amber-500/5 flex flex-col justify-between h-44 shadow-sm hover:shadow-md transition-shadow"
        >
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 rounded-2xl grid place-items-center bg-amber-100 text-amber-600 shrink-0">
              <Sparkles size={22} />
            </div>
            <div>
              <div className="text-xs tracking-widest uppercase font-semibold text-amber-600">
                Daily Prep
              </div>
              <div className="font-serif text-lg text-[#0F1B4C] font-semibold mt-1">
                Practice Today's Question
              </div>
              <div className="text-xs text-[#64748B] mt-0.5 font-medium">
                Solve questions in the bank to level up your score.
              </div>
            </div>
          </div>
          <div className="flex justify-end pt-2">
            <Link to="/questions">
              <Button className="rounded-full px-5 py-1.5 h-auto text-xs font-bold bg-[#0F1B4C] hover:bg-[#2563EB] text-white">
                Practice Now
              </Button>
            </Link>
          </div>
        </motion.div>
      </div>

      <div className="mt-8 grid sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard icon={Trophy} label="Total points" value={user?.total_points ?? 0} tone="violet" />

        {/* Class Rank — blurred with big blue Unlock for non-premium */}
        <Card className="p-6 rounded-2xl border-slate-200 shadow-none hover:shadow-[0_16px_36px_-24px_rgba(15,27,76,0.35)] transition-shadow">
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <div className="text-xs tracking-[0.22em] uppercase text-[#64748B] font-semibold">Class rank</div>
              {user?.subscription_active ? (
                <div className="mt-2 font-serif text-3xl text-[#0F1B4C] font-semibold">#{myRank}</div>
              ) : (
                <div className="mt-2 flex flex-col gap-2">
                  <span className="blur-[6px] select-none font-serif text-3xl text-[#0F1B4C] font-semibold">#88</span>
                  <Link to="/pricing">
                    <button type="button" className="flex items-center gap-1.5 bg-[#2563EB] hover:bg-[#1d4ed8] text-white text-xs font-bold px-3 py-1.5 rounded-lg transition-all shadow-sm w-full justify-center">
                      🔒 Unlock Premium
                    </button>
                  </Link>
                </div>
              )}
            </div>
            <div className="w-10 h-10 rounded-xl grid place-items-center bg-slate-50 text-[#2563EB] shrink-0">
              <TrendingUp size={20} />
            </div>
          </div>
        </Card>

        <StatCard icon={Users} label="Referrals" value={refs?.count ?? 0} tone="navy" />

        {/* Referral code card */}
        <Card className="p-6 rounded-2xl border-slate-200 shadow-none hover:shadow-[0_16px_36px_-24px_rgba(15,27,76,0.35)] transition-shadow flex flex-col justify-between gap-4">
          <div className="flex items-start justify-between">
            <div>
              <div className="text-xs tracking-[0.22em] uppercase text-[#64748B] font-semibold">Referral code</div>
              <div className="mt-2 font-mono text-3xl text-[#0F1B4C] font-semibold tracking-widest">
                {refs?.referral_code || "—"}
              </div>
            </div>
            <div className="w-10 h-10 rounded-xl grid place-items-center bg-slate-50 text-[#7C3AED] shrink-0">
              <Sparkles size={20} />
            </div>
          </div>
          {refs?.referral_code && (
            <div className="flex justify-end">
              <button
                type="button"
                onClick={handleCopyCode}
                className="flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg border border-slate-200 hover:bg-[#2563EB] hover:text-white hover:border-[#2563EB] text-slate-600 bg-white transition-all shadow-sm"
                title="Copy referral code"
              >
                {copied ? <Check size={13} className="text-green-500" /> : <Copy size={13} />}
                {copied ? "Copied!" : "Copy Code"}
              </button>
            </div>
          )}
        </Card>
      </div>

      <div className="mt-10 grid lg:grid-cols-3 gap-6">
        {/* Upcoming */}
        <div className={`rounded-2xl bg-white border border-slate-200 p-7 ${user?.subscription_active ? "lg:col-span-2" : "lg:col-span-3"}`}>
          <div className="flex items-center justify-between">
            <div>
              <div className="text-xs tracking-[0.22em] uppercase text-[#7C3AED] font-semibold">Upcoming</div>
              <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Your next mock tests</h2>
            </div>
            <Link to="/tests" className="text-sm text-[#2563EB] hover:underline inline-flex items-center gap-1">
              All tests <ArrowUpRight size={14} />
            </Link>
          </div>
          <div className="mt-6 space-y-3">
            {upcoming.slice(0, 3).map((t) => {
              const { start, msToStart, msToEnd } = timeUntil(t);
              const live = msToStart <= 0 && msToEnd > 0;
              const over = msToEnd <= 0;
              return (
                <div key={t._id} className="flex items-center gap-4 p-4 rounded-xl border border-slate-100 hover:border-slate-200 transition-colors">
                  <div className="flex-1">
                    <div className="font-serif text-base text-[#0F1B4C] font-semibold">{t.title}</div>
                    <div className="text-xs text-[#64748B] mt-0.5">
                      {new Date(t.scheduled_date).toLocaleDateString()} · {t.start_time} - {t.end_time} IST
                    </div>
                  </div>
                  {live ? (
                    <span className="text-xs font-bold text-red-500 animate-pulse uppercase">Live</span>
                  ) : over ? (
                    <span className="text-xs text-[#64748B]">Finished</span>
                  ) : (
                    <span className="text-xs bg-slate-100 text-[#334155] px-2.5 py-1 rounded-full font-medium">
                      {fmtCountdown(msToStart)}
                    </span>
                  )}
                </div>
              );
            })}
            {upcoming.length === 0 && (
              <div className="text-center text-[#64748B] py-10">No tests scheduled at the moment. Check back soon!</div>
            )}
          </div>
        </div>

        {/* Leaderboard (Only shown for Premium Users) */}
        {user?.subscription_active && (
          <div className="lg:col-span-1 rounded-2xl bg-white border border-slate-200 p-7">
            <div>
              <div className="text-xs tracking-[0.22em] uppercase text-[#2563EB] font-semibold">Top Performers</div>
              <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Leaderboard</h2>
            </div>
            <div className="mt-6 space-y-4">
              {lb.map((x, i) => (
                <div key={x.user_id} className="flex items-center gap-3">
                  <div className={`w-6 h-6 rounded-full grid place-items-center text-xs font-bold ${
                    i === 0 ? "bg-amber-100 text-amber-700" : i === 1 ? "bg-slate-100 text-slate-700" : "text-[#64748B]"
                  }`}>
                    {i + 1}
                  </div>
                  <div className="flex-1 text-[#0F1B4C] font-medium text-sm truncate">{x.name}</div>
                  <div className="font-mono text-xs text-[#64748B]">{x.total_points} pts</div>
                </div>
              ))}
              {lb.length === 0 && (
                <div className="text-center text-[#64748B] py-10">Leaderboard is empty.</div>
              )}
            </div>
          </div>
        )}
      </div>

    </div>
  );
}
