import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import api from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { Trophy, Medal, Crown, Lock, ArrowRight, ChevronRight, GraduationCap, FileText, RotateCcw } from "lucide-react";
import { motion, AnimatePresence } from "framer-motion";
import { useAuth } from "@/contexts/AuthContext";

function AvatarCircle({ avatarUrl, name, size = 36 }) {
  const initials = (name || "?")
    .split(" ")
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
  return (
    <div
      className="rounded-full overflow-hidden border-2 border-white shadow-sm bg-gradient-to-br from-[#2563EB] to-[#7C3AED] flex items-center justify-center shrink-0"
      style={{ width: size, height: size }}
    >
      {avatarUrl ? (
        <img src={avatarUrl} alt={name} className="w-full h-full object-cover" />
      ) : (
        <span className="text-white font-bold" style={{ fontSize: size * 0.36 }}>
          {initials}
        </span>
      )}
    </div>
  );
}

function UnreleasedCard({ message }) {
  return (
    <div className="mt-12 flex flex-col items-center gap-4 text-center p-8 rounded-3xl bg-slate-50 border border-slate-200">
      <div className="w-20 h-20 mx-auto rounded-3xl bg-amber-50 border border-amber-200 grid place-items-center text-amber-500 shadow-md">
        <Lock size={36} />
      </div>
      <h2 className="font-serif text-2xl text-[#0F1B4C] font-semibold">Leaderboard Coming Soon</h2>
      <p className="text-[#64748B] text-sm max-w-sm leading-relaxed">{message}</p>
    </div>
  );
}

export default function Leaderboard() {
  const { user } = useAuth();
  const isAdmin = user?.role === "admin" || user?.role === "superadmin";

  const isStudent = user?.role === "student";
  const defaultClass = isStudent ? (user?.class_level || "10") : "all";

  // Flow Step: 1 = Select Class (Admin only), 2 = Select Test, 3 = Leaderboard & Release Control
  const [step, setStep] = useState(isStudent ? 2 : 1);

  const [classLevel, setClassLevel] = useState(defaultClass);
  const [selectedTestId, setSelectedTestId] = useState("total");
  const [tests, setTests] = useState([]);
  const [items, setItems] = useState([]);
  const [blockedMsg, setBlockedMsg] = useState(null);

  // Admin release status state
  const [releaseStatus, setReleaseStatus] = useState(false);
  const [releaseLoading, setReleaseLoading] = useState(false);

  // Fetch published tests when class changes
  useEffect(() => {
    (async () => {
      const params = {};
      if (classLevel !== "all") params.class_level = classLevel;
      try {
        const r = await api.get("/api/tests", { params });
        setTests((r.data.items || []).filter((t) => t.is_published));
      } catch (err) {
        console.error("Failed to load tests", err);
      }
    })();
  }, [classLevel]);

  // Fetch release status for admin when step 3 or selected test changes
  useEffect(() => {
    if (!isAdmin || step !== 3) return;
    (async () => {
      try {
        if (selectedTestId === "total") {
          const res = await api.get("/api/admin/leaderboard/release-status");
          setReleaseStatus(res.data.released);
        } else {
          const res = await api.get(`/api/admin/leaderboard/test/${selectedTestId}/release-status`);
          setReleaseStatus(res.data.released);
        }
      } catch (err) {
        console.error("Failed to fetch release status", err);
      }
    })();
  }, [isAdmin, selectedTestId, step]);

  const toggleRelease = async () => {
    setReleaseLoading(true);
    try {
      if (selectedTestId === "total") {
        const res = await api.post("/api/admin/leaderboard/release", { released: !releaseStatus });
        setReleaseStatus(res.data.released);
        toast.success(res.data.released ? "Overall leaderboard released to students!" : "Overall leaderboard hidden.");
      } else {
        const res = await api.post(`/api/admin/leaderboard/test/${selectedTestId}/release`, { released: !releaseStatus });
        setReleaseStatus(res.data.released);
        toast.success(res.data.released ? "Test leaderboard released to students!" : "Test leaderboard hidden.");
      }
    } catch (err) {
      toast.error("Failed to toggle release status.");
    } finally {
      setReleaseLoading(false);
    }
  };

  // Fetch rankings for step 3
  useEffect(() => {
    if (step !== 3) return;
    (async () => {
      const params = { limit: 100 };
      if (classLevel !== "all") params.class_level = classLevel;
      if (selectedTestId !== "total") params.test_id = selectedTestId;
      try {
        setBlockedMsg(null);
        const r = await api.get("/api/leaderboard", { params });
        setItems(r.data.items || []);
      } catch (err) {
        if (err?.response?.status === 403) {
          setBlockedMsg(err.response.data?.detail || "Leaderboard will be displayed shortly by the admin...");
          setItems([]);
        } else {
          console.error("Failed to load rankings", err);
        }
      }
    })();
  }, [classLevel, selectedTestId, step]);

  // Premium lock for non-premium students
  if (user?.role === "student" && !user?.subscription_active) {
    return (
      <div className="max-w-md mx-auto px-6 py-20 text-center space-y-6">
        <div className="w-20 h-20 mx-auto rounded-3xl bg-amber-50 border border-amber-200 grid place-items-center text-amber-500 shadow-md">
          <Trophy size={40} className="animate-bounce" />
        </div>
        <h1 className="font-serif text-3xl text-[#0F1B4C] font-semibold">Premium Feature</h1>
        <p className="text-[#64748B] text-sm leading-relaxed">
          The leaderboard is exclusive to premium users. Upgrade your subscription today to see where you rank!
        </p>
        <div className="pt-2">
          <Link to="/pricing">
            <Button className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] px-6 py-2">
              Upgrade to Premium
            </Button>
          </Link>
        </div>
      </div>
    );
  }

  const selectedTest = tests.find((t) => t._id === selectedTestId);

  const handleSelectClass = (cls) => {
    setClassLevel(cls);
    setStep(2);
  };

  const handleSelectTest = (tId) => {
    setSelectedTestId(tId);
    setStep(3);
  };

  const classesList = [
    { id: "all", label: "All Classes", desc: "Overall school-wide rankings across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Leaderboards for Grade 8 students", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Leaderboards for Grade 9 students", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Leaderboards for Grade 10 students", tone: "bg-amber-50 text-amber-700 border-amber-200" },
  ];

  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />

      {/* Progress Steps Header */}
      <div className="mb-8 p-4 rounded-2xl bg-white border border-slate-200 shadow-sm flex items-center justify-between gap-2 overflow-x-auto">
        {!isStudent && (
          <>
            <button
              onClick={() => setStep(1)}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
                step === 1 ? "bg-[#0F1B4C] text-white shadow-md" : "text-[#64748B] hover:bg-slate-100"
              }`}
            >
              <span className="w-5 h-5 rounded-full bg-white/20 grid place-items-center text-[10px]">1</span>
              1. Select Class
            </button>
            <ChevronRight size={16} className="text-slate-300 shrink-0" />
          </>
        )}

        <button
          onClick={() => setStep(2)}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
            step === 2 ? "bg-[#0F1B4C] text-white shadow-md" : "text-[#64748B] hover:bg-slate-100"
          }`}
        >
          <span className="w-5 h-5 rounded-full bg-white/20 grid place-items-center text-[10px]">{isStudent ? "1" : "2"}</span>
          {isStudent ? "1. Select Test" : "2. Select Test"}
        </button>

        <ChevronRight size={16} className="text-slate-300 shrink-0" />

        <button
          disabled={step < 3}
          onClick={() => setStep(3)}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
            step === 3 ? "bg-[#0F1B4C] text-white shadow-md" : "text-[#64748B] hover:bg-slate-100 disabled:opacity-50"
          }`}
        >
          <span className="w-5 h-5 rounded-full bg-white/20 grid place-items-center text-[10px]">{isStudent ? "2" : "3"}</span>
          {isStudent ? "2. Class Leaderboard" : "3. Leaderboard & Release"}
        </button>
      </div>

      <AnimatePresence mode="wait">
        {/* ================= STEP 1: SELECT CLASS ================= */}
        {step === 1 && (
          <motion.div key="step1" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}>
            <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Step 1 of 3</div>
            <h1 className="mt-1 font-serif text-3xl sm:text-4xl text-[#0F1B4C] font-semibold">Select Class Level</h1>
            <p className="mt-1 text-[#64748B] text-sm">Choose a class to view its tests and leaderboard rankings.</p>

            <div className="mt-8 grid sm:grid-cols-2 gap-5">
              {classesList.map((c) => (
                <Card
                  key={c.id}
                  onClick={() => handleSelectClass(c.id)}
                  className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
                >
                  <div className="flex items-start justify-between">
                    <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                      <GraduationCap size={24} />
                    </div>
                    {classLevel === c.id && (
                      <Badge className="bg-[#7C3AED] text-white text-[10px]">Selected</Badge>
                    )}
                  </div>

                  <div className="mt-6">
                    <h3 className="font-serif text-2xl text-[#0F1B4C] font-semibold group-hover:text-[#7C3AED] transition-colors">{c.label}</h3>
                    <p className="text-xs text-[#64748B] mt-1 leading-relaxed">{c.desc}</p>
                  </div>

                  <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between text-xs font-semibold text-[#7C3AED]">
                    <span>View Class Tests</span>
                    <ArrowRight size={16} className="group-hover:translate-x-1 transition-transform" />
                  </div>
                </Card>
              ))}
            </div>
          </motion.div>
        )}

        {/* ================= STEP 2: SELECT TEST ================= */}
        {step === 2 && (
          <motion.div key="step2" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}>
            <div className="flex items-center justify-between gap-4 flex-wrap">
              <div>
                <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Step 2 of 3</div>
                <h1 className="mt-1 font-serif text-3xl sm:text-4xl text-[#0F1B4C] font-semibold">
                  Select Leaderboard / Test
                </h1>
                <p className="mt-1 text-[#64748B] text-sm">
                  Showing rankings options for <span className="font-semibold text-[#0F1B4C]">{classLevel === "all" ? "All Classes" : `Class ${classLevel}`}</span>
                </p>
              </div>

              <Button variant="outline" size="sm" onClick={() => setStep(1)} className="rounded-full text-xs">
                <RotateCcw size={12} className="mr-1.5" /> Change Class
              </Button>
            </div>

            <div className="mt-8 space-y-4">
              {/* Overall Total Card */}
              <Card
                onClick={() => handleSelectTest("total")}
                className="p-6 rounded-3xl border-2 border-amber-200 bg-gradient-to-r from-amber-50/80 to-purple-50/50 hover:border-amber-400 hover:shadow-xl transition-all cursor-pointer group flex items-center justify-between"
              >
                <div className="flex items-center gap-4">
                  <div className="w-14 h-14 rounded-2xl bg-amber-100 text-amber-700 grid place-items-center shrink-0 group-hover:scale-105 transition-transform">
                    <Trophy size={28} />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="font-serif text-xl text-[#0F1B4C] font-semibold">Overall (Cumulative Points)</h3>
                      <Badge className="bg-amber-600 text-white text-[10px]">ALL TESTS</Badge>
                    </div>
                    <p className="text-xs text-[#64748B] mt-1">Total points accumulated across mock and final exams.</p>
                  </div>
                </div>
                <ArrowRight size={20} className="text-amber-600 group-hover:translate-x-1 transition-transform shrink-0" />
              </Card>

              <div className="pt-4 text-xs font-semibold uppercase tracking-wider text-[#64748B]">Individual Tests</div>

              {tests.length === 0 ? (
                <div className="p-8 text-center bg-white rounded-3xl border border-slate-200 text-[#64748B] text-sm">
                  No published tests available for Class {classLevel}. Select "Overall" above or choose another class.
                </div>
              ) : (
                tests.map((t) => (
                  <Card
                    key={t._id}
                    onClick={() => handleSelectTest(t._id)}
                    className="p-5 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-lg transition-all cursor-pointer bg-white group flex items-center justify-between"
                  >
                    <div className="flex items-center gap-4">
                      <div className={`w-12 h-12 rounded-2xl grid place-items-center shrink-0 ${
                        t.test_type === "final" ? "bg-amber-100 text-amber-700" : "bg-purple-100 text-purple-700"
                      }`}>
                        {t.test_type === "final" ? <Crown size={22} /> : <FileText size={22} />}
                      </div>
                      <div>
                        <div className="flex items-center gap-2 flex-wrap">
                          <h4 className="font-serif text-lg text-[#0F1B4C] font-semibold group-hover:text-[#7C3AED] transition-colors">{t.title}</h4>
                          <Badge variant="outline" className={t.test_type === "final" ? "border-amber-300 text-amber-700 bg-amber-50 text-[10px]" : "text-purple-700 border-purple-200 text-[10px]"}>
                            {t.test_type === "final" ? "FINAL EXAM" : "MOCK TEST"}
                          </Badge>
                        </div>
                        <p className="text-xs text-[#64748B] mt-0.5">
                          {t.total_questions ? `${t.total_questions} Questions` : "Practice Test"} · Duration: {t.duration_minutes || 30} mins
                        </p>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 text-xs font-semibold text-[#7C3AED] shrink-0">
                      <span>View Leaderboard</span>
                      <ArrowRight size={16} className="group-hover:translate-x-1 transition-transform" />
                    </div>
                  </Card>
                ))
              )}
            </div>
          </motion.div>
        )}

        {/* ================= STEP 3: LEADERBOARD & RELEASE CONTROL ================= */}
        {step === 3 && (
          <motion.div key="step3" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}>
            {/* Header & Controls */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Step 3 of 3</div>
                <h1 className="mt-1 font-serif text-3xl sm:text-4xl text-[#0F1B4C] font-semibold">
                  {selectedTestId === "total" ? "Overall Leaderboard" : selectedTest?.title || "Test Leaderboard"}
                </h1>
                <p className="mt-1 text-[#64748B] text-sm">
                  Class: <span className="font-semibold text-[#0F1B4C]">{classLevel === "all" ? "All Classes" : `Class ${classLevel}`}</span> · Ranking &amp; Scores
                </p>
              </div>

              <div className="flex items-center gap-2">
                <Button variant="outline" size="sm" onClick={() => setStep(2)} className="rounded-full text-xs">
                  Change Test
                </Button>
                <Button variant="outline" size="sm" onClick={() => setStep(1)} className="rounded-full text-xs">
                  Change Class
                </Button>
              </div>
            </div>

            {/* Admin Release Control Banner */}
            {isAdmin && (
              <Card className="mt-6 p-6 rounded-3xl border-slate-200 bg-gradient-to-r from-amber-500/10 via-purple-500/10 to-blue-500/10 flex flex-col sm:flex-row sm:items-center justify-between gap-4 border shadow-sm">
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-serif text-lg text-[#0F1B4C] font-semibold">
                      {selectedTestId === "total"
                        ? "Overall Leaderboard Visibility"
                        : `Leaderboard Visibility — ${selectedTest?.title}`}
                    </span>
                    <Badge
                      variant={releaseStatus ? "default" : "outline"}
                      className={releaseStatus ? "bg-emerald-600 text-white font-bold" : "text-amber-700 border-amber-300 bg-amber-50 font-bold"}
                    >
                      {releaseStatus ? "LIVE TO STUDENTS" : "HIDDEN FROM STUDENTS"}
                    </Badge>
                  </div>
                  <p className="text-xs text-[#64748B] mt-1">
                    {selectedTestId === "total"
                      ? "Control whether general cumulative rankings are visible to students across the app."
                      : `Control whether leaderboard rankings for "${selectedTest?.title}" are visible to students.`}
                  </p>
                </div>
                <Button
                  size="sm"
                  variant={releaseStatus ? "outline" : "default"}
                  className={releaseStatus ? "rounded-full border-amber-300 text-amber-700 bg-amber-50 shrink-0 font-semibold px-5" : "rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] text-white shrink-0 font-semibold px-5"}
                  onClick={toggleRelease}
                  disabled={releaseLoading}
                  data-testid="admin-toggle-lb-release"
                >
                  {releaseStatus ? "Hide Leaderboard from Students" : "Release Leaderboard to Students"}
                </Button>
              </Card>
            )}

            {/* Blocked state or Rankings Table */}
            {blockedMsg ? (
              <UnreleasedCard message={blockedMsg} />
            ) : items.length === 0 ? (
              <div className="mt-12 p-12 text-center bg-white rounded-3xl border border-slate-200 text-[#64748B]">
                {selectedTestId === "total"
                  ? "No rankings yet — students need to take a test to appear!"
                  : "No student submissions found for this test yet."}
              </div>
            ) : (
              <div className="mt-8 rounded-3xl bg-white border border-slate-200 overflow-hidden shadow-sm">
                <div className="p-4 bg-slate-50 border-b border-slate-100 flex items-center justify-between text-xs font-semibold uppercase text-slate-500 px-6">
                  <span>Student Rank</span>
                  <span>Score / Points</span>
                </div>
                {items.map((r, i) => {
                  const isMe = r.user_id === user?._id;
                  return (
                    <motion.div
                      key={r.user_id}
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: i * 0.03 }}
                      className={`flex items-center justify-between p-4 px-6 border-b border-slate-100 last:border-0 ${
                        isMe ? "bg-purple-50/80 font-medium" : "hover:bg-slate-50"
                      }`}
                    >
                      <div className="flex items-center gap-4">
                        <div className="w-8 text-center font-mono font-bold text-sm text-[#0F1B4C]">
                          {i === 0 ? (
                            <div className="w-8 h-8 rounded-full bg-amber-100 grid place-items-center text-amber-600 mx-auto">
                              <Crown size={18} />
                            </div>
                          ) : i === 1 ? (
                            <div className="w-8 h-8 rounded-full bg-slate-200 grid place-items-center text-slate-600 mx-auto">
                              <Medal size={18} />
                            </div>
                          ) : i === 2 ? (
                            <div className="w-8 h-8 rounded-full bg-amber-700/20 grid place-items-center text-amber-800 mx-auto">
                              <Trophy size={16} />
                            </div>
                          ) : (
                            `#${i + 1}`
                          )}
                        </div>

                        <AvatarCircle avatarUrl={r.avatar_url} name={r.name} size={40} />

                        <div>
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="text-[#0F1B4C] font-semibold text-base">{r.name}</span>
                            {r.student_id && (
                              <span className="font-mono text-[11px] px-2 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-200 font-semibold">
                                {r.student_id}
                              </span>
                            )}
                            {isMe && <Badge className="bg-[#7C3AED] text-white text-[10px]">YOU</Badge>}
                          </div>
                          <div className="text-xs text-[#64748B]">Class {r.class_level || classLevel}</div>
                        </div>
                      </div>

                      <div className="text-right">
                        <div className="font-mono text-xl text-[#2563EB] font-bold">{r.score ?? r.points ?? 0} pts</div>
                      </div>
                    </motion.div>
                  );
                })}
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
