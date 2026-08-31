import React, { useEffect, useState, useMemo } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { motion, AnimatePresence } from "framer-motion";
import {
  CheckCircle2, XCircle, BookOpen, CalendarDays, CircleCheck, CircleDashed,
  ChevronDown, ChevronUp, Flame, ArrowLeft, ArrowRight, BarChart2, Clock, Sparkles
} from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import MathText from "@/components/MathText";
import { useNavigate, useSearchParams } from "react-router-dom";

// Helper to format ISO date string into Year-Month string (e.g. "August 2026")
const formatMonthYear = (isoStr) => {
  if (!isoStr) return "";
  const d = new Date(isoStr);
  return d.toLocaleDateString("en-IN", { month: "long", year: "numeric" });
};

// Helper to get YYYY-MM string for filtering
const toYearMonthKey = (isoStr) => {
  if (!isoStr) return "";
  const dt = new Date(isoStr);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}`;
};

export default function QuestionBank() {
  const { user, refresh } = useAuth();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  const isStaff = user?.role === "admin" || user?.role === "superadmin";

  // Lock class to user's registered class for students
  const [classLevel, setClassLevel] = useState(isStaff ? "10" : (user?.class_level || "10"));

  // Mode: "landing" | "bank" | "daily"
  const urlMode = searchParams.get("mode");
  const [mode, setMode] = useState(urlMode === "daily" ? "daily" : urlMode === "bank" ? "bank" : "landing");

  useEffect(() => {
    if (urlMode) setMode(urlMode);
  }, [urlMode]);

  const [topic, setTopic] = useState("all");
  const [monthFilter, setMonthFilter] = useState("all"); // "all" | "YYYY-MM"
  const [topics, setTopics] = useState([]);
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);

  // Per-question answer state: { [qId]: { selected, typed, feedback, open } }
  const storageKey = `qbank_state_${user?._id || "guest"}`;
  const [qState, setQState] = useState(() => {
    try {
      const saved = localStorage.getItem(storageKey);
      return saved ? JSON.parse(saved) : {};
    } catch {
      return {};
    }
  });

  // Fetch topics (Question Bank category only)
  useEffect(() => {
    (async () => {
      try {
        const t = await api.get("/api/questions/topics", { params: { class_level: classLevel, category: "question_bank" } });
        setTopics(t.data.topics || []);
      } catch {}
    })();
  }, [classLevel]);

  // Fetch questions for current mode & class and sync daily attempt state with server
  useEffect(() => {
    if (mode === "landing") return;
    (async () => {
      setLoading(true);
      try {
        const categoryParam = mode === "daily" ? "daily_24h" : "question_bank";
        const params = { class_level: classLevel, limit: 500, category: categoryParam };
        if (mode === "bank" && topic && topic !== "all") params.topic = topic;

        const [r, dp] = await Promise.all([
          api.get("/api/questions", { params }),
          mode === "daily" ? api.get("/api/students/daily-practice").catch(() => null) : Promise.resolve(null),
        ]);

        const fetchedItems = r.data.items || [];
        setItems(fetchedItems);

        // If daily practice mode, sync qState with backend attempted_map
        if (mode === "daily" && dp?.data) {
          const serverAttemptedMap = dp.data.attempted_map || {};
          setQState((prev) => {
            const next = { ...prev };
            fetchedItems.forEach((q) => {
              if (!(q._id in serverAttemptedMap)) {
                delete next[q._id];
              } else {
                const isCorrect = serverAttemptedMap[q._id];
                next[q._id] = { ...(next[q._id] || {}), feedback: { correct: isCorrect } };
              }
            });
            try {
              localStorage.setItem(storageKey, JSON.stringify(next));
            } catch {}
            return next;
          });
        }
      } catch {
        toast.error("Failed to load questions");
      } finally {
        setLoading(false);
      }
    })();
  }, [classLevel, topic, mode, storageKey]);

  // Available unique months for month filter in Question Bank mode
  const availableMonths = useMemo(() => {
    const map = new Map();
    items.forEach((q) => {
      if (q.created_at) {
        const key = toYearMonthKey(q.created_at);
        const label = formatMonthYear(q.created_at);
        if (key && !map.has(key)) {
          map.set(key, label);
        }
      }
    });
    return Array.from(map.entries()).map(([key, label]) => ({ key, label }));
  }, [items]);

  // Apply month filter for Question Bank view
  const filteredItems = useMemo(() => {
    let result = items;
    if (mode === "bank" && monthFilter !== "all") {
      result = result.filter((q) => q.created_at && toYearMonthKey(q.created_at) === monthFilter);
    }
    // Ensure latest questions are on top
    return [...result].sort((a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0));
  }, [items, monthFilter, mode]);

  // Daily questions completion check
  const allDailyAnswered = useMemo(() => {
    if (mode !== "daily" || filteredItems.length === 0) return false;
    return filteredItems.every((q) => !!qState[q._id]?.feedback);
  }, [mode, filteredItems, qState]);

  const setQ = (id, patch) => {
    setQState((prev) => {
      const next = { ...prev, [id]: { ...prev[id], ...patch } };
      try {
        localStorage.setItem(storageKey, JSON.stringify(next));
      } catch {}
      return next;
    });
  };

  const checkAnswer = async (q) => {
    const s = qState[q._id] || {};
    try {
      const r = await api.post(`/api/questions/${q._id}/check`, {
        selected_index: s.selected ?? null,
        typed_answer: s.typed ?? "",
      });
      setQ(q._id, { feedback: r.data, open: true });
      if (r.data?.daily_bonus_earned) {
        toast.success("🎉 Daily Bonus! +1 point earned!");
      }
      if (refresh) refresh();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const switchMode = (newMode) => {
    setMode(newMode);
    setSearchParams({ mode: newMode });
  };

  // ── 1. LANDING MODE (Choose Question Bank vs Daily Questions) ──────────
  if (mode === "landing") {
    return (
      <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
        <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
        <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Class {classLevel} Practice</div>
        <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Questions</h1>
        <p className="mt-1 text-[#64748B]">Choose how you want to practice today.</p>

        {isStaff && (
          <div className="mt-4 flex items-center gap-2">
            <span className="text-xs font-semibold text-slate-500">Admin View Class:</span>
            <Select value={classLevel} onValueChange={setClassLevel}>
              <SelectTrigger className="w-32 h-8 text-xs rounded-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="8">Class 8</SelectItem>
                <SelectItem value="9">Class 9</SelectItem>
                <SelectItem value="10">Class 10</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}

        <div className="mt-8 grid sm:grid-cols-2 gap-6">
          {/* Card 1: Question Bank */}
          <Card
            onClick={() => switchMode("bank")}
            className="p-8 rounded-3xl border-slate-200 hover:border-[#2563EB] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
          >
            <div>
              <div className="w-14 h-14 rounded-2xl bg-blue-50 text-[#2563EB] grid place-items-center mb-6 group-hover:scale-110 transition-transform">
                <BookOpen size={28} />
              </div>
              <h2 className="font-serif text-2xl text-[#0F1B4C] font-semibold group-hover:text-[#2563EB] transition-colors">
                Question Bank
              </h2>
              <p className="text-sm text-slate-500 mt-2 leading-relaxed">
                Browse all uploaded practice questions for Class {classLevel}. Filter by chapter topic or month.
              </p>
            </div>
            <div className="mt-8 pt-4 border-t border-slate-100 flex items-center justify-between text-sm font-semibold text-[#2563EB]">
              <span>Open Question Bank</span>
              <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
            </div>
          </Card>

          {/* Card 2: Daily Questions 24h */}
          <Card
            onClick={() => switchMode("daily")}
            className="p-8 rounded-3xl border-amber-200 bg-gradient-to-br from-amber-50/60 to-orange-50/60 hover:border-amber-500 hover:shadow-xl transition-all cursor-pointer group flex flex-col justify-between"
          >
            <div>
              <div className="w-14 h-14 rounded-2xl bg-amber-500 text-white grid place-items-center mb-6 group-hover:scale-110 transition-transform shadow-md">
                <Flame size={28} className="animate-pulse" />
              </div>
              <div className="flex items-center gap-2 mb-1">
                <span className="text-[10px] uppercase font-extrabold tracking-widest text-amber-700 bg-amber-200/60 px-2 py-0.5 rounded-full">
                  24-Hour Expiration
                </span>
              </div>
              <h2 className="font-serif text-2xl text-[#0F1B4C] font-semibold group-hover:text-amber-600 transition-colors">
                Daily Questions (24h)
              </h2>
              <p className="text-sm text-slate-600 mt-2 leading-relaxed">
                Solve today&apos;s daily practice questions uploaded by admin before the 24-hour timer runs out!
              </p>
            </div>
            <div className="mt-8 pt-4 border-t border-amber-200/60 flex items-center justify-between text-sm font-semibold text-amber-700">
              <span>Start Daily Practice</span>
              <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
            </div>
          </Card>
        </div>
      </div>
    );
  }

  // ── 2. QUESTION BANK MODE or DAILY QUESTIONS MODE ─────────────────────
  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">

      {/* Top Header with Back to Mode Selection */}
      <div className="flex items-center justify-between mb-6">
        <button
          onClick={() => switchMode("landing")}
          className="flex items-center gap-1.5 text-sm font-semibold text-slate-600 hover:text-[#2563EB] transition-colors"
        >
          <ArrowLeft size={16} /> Choose Section
        </button>

        {isStaff && (
          <div className="flex items-center gap-2">
            <span className="text-xs text-slate-500 font-medium">Class:</span>
            <Select value={classLevel} onValueChange={setClassLevel}>
              <SelectTrigger className="w-28 h-8 text-xs rounded-full"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="8">Class 8</SelectItem>
                <SelectItem value="9">Class 9</SelectItem>
                <SelectItem value="10">Class 10</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}
      </div>

      <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">
        Class {classLevel} · {mode === "daily" ? "Daily Questions (24h)" : "Question Bank"}
      </div>
      <h1 className="mt-1 font-serif text-3xl sm:text-4xl text-[#0F1B4C] font-semibold">
        {mode === "daily" ? "Today's Daily Practice" : "Question Bank"}
      </h1>

      {/* Filters (Question Bank mode only) */}
      {mode === "bank" && (
        <div className="mt-6 flex flex-wrap gap-3 items-center">
          {/* Topic filter */}
          <Select value={topic} onValueChange={setTopic}>
            <SelectTrigger className="w-48 rounded-full bg-white"><SelectValue placeholder="All topics" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All topics</SelectItem>
              {topics.filter((t) => t.topic && t.topic.trim() !== "").map((t) => (
                <SelectItem key={t.topic} value={t.topic}>{t.topic} ({t.count})</SelectItem>
              ))}
            </SelectContent>
          </Select>

          {/* Month filter */}
          <Select value={monthFilter} onValueChange={setMonthFilter}>
            <SelectTrigger className="w-44 rounded-full bg-white">
              <CalendarDays size={14} className="mr-1 text-slate-400" />
              <SelectValue placeholder="All months" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All months</SelectItem>
              {availableMonths.map((m) => (
                <SelectItem key={m.key} value={m.key}>{m.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>

          <div className="ml-auto text-sm text-[#64748B]">
            <span className="font-mono font-semibold text-[#0F1B4C]">{filteredItems.length}</span> questions
          </div>
        </div>
      )}

      {/* Daily Mode Info Banner */}
      {mode === "daily" && (
        <div className="mt-5 p-4 rounded-2xl bg-amber-50 border border-amber-200 flex items-center justify-between text-xs sm:text-sm font-medium text-amber-900">
          <div className="flex items-center gap-2">
            <Flame size={18} className="text-amber-500 shrink-0" />
            <span>Direct Daily Practice — Active for <strong>24 hours from upload</strong>. Latest questions on top.</span>
          </div>
        </div>
      )}

      {/* Daily Completion Banner with CTA to My Analytics */}
      {mode === "daily" && (allDailyAnswered || (filteredItems.length > 0 && filteredItems.every(q => qState[q._id]?.feedback))) && (
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="mt-6 p-6 rounded-3xl bg-gradient-to-r from-[#0F1B4C] via-[#1a2a6c] to-[#2563EB] text-white shadow-xl text-center space-y-4"
        >
          <div className="w-12 h-12 rounded-full bg-amber-400/20 text-amber-400 grid place-items-center mx-auto">
            <Sparkles size={24} />
          </div>
          <div>
            <h3 className="font-serif text-2xl font-bold">Daily Practice Complete! 🎉</h3>
            <p className="text-xs text-blue-200 mt-1">You&apos;ve finished all active daily questions. Check your strengths and weaknesses in your analysis.</p>
          </div>
          <Button
            onClick={() => navigate("/my-analytics")}
            className="rounded-full bg-white text-[#0F1B4C] hover:bg-blue-50 font-bold px-6 py-2.5 text-xs shadow-md"
          >
            <BarChart2 size={16} className="mr-1.5" /> Take me to My Analytics
          </Button>
        </motion.div>
      )}

      {/* Questions list */}
      {loading ? (
        <div className="py-20 text-center text-slate-400">Loading questions…</div>
      ) : filteredItems.length === 0 ? (
        <div className="mt-16 text-center text-[#64748B]">
          <BookOpen className="mx-auto text-[#94a3b8]" size={40} />
          <p className="mt-3">No questions found for this view.</p>
        </div>
      ) : (
        <div className="mt-6 space-y-4">
          {filteredItems.map((q, idx) => {
            const s = qState[q._id] || {};
            const answered = !!s.feedback;
            const isOpen = s.open !== false;

            return (
              <motion.div
                key={q._id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: Math.min(idx * 0.03, 0.3) }}
              >
                <Card className={`rounded-2xl border transition-all ${answered ? "border-green-200 bg-green-50/30" : "border-slate-200 bg-white"}`}>

                  {/* Question header */}
                  <button
                    type="button"
                    className="w-full text-left px-6 pt-5 pb-3 flex items-start justify-between gap-3"
                    onClick={() => setQ(q._id, { open: !isOpen })}
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap mb-1">
                        <span className="text-[10px] text-slate-400">
                          {q.category === "daily_24h" ? `· +${q.positive_marks}/−${q.negative_marks} · ${q.difficulty}` : `· ${q.difficulty}`}
                        </span>

                        {q.category === "daily_24h" && (
                          <span className="text-[10px] font-bold bg-amber-100 text-amber-800 border border-amber-300 px-2 py-0.5 rounded-full">
                            ⚡ Daily 24h
                          </span>
                        )}
                        {answered && (
                          <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${s.feedback.correct ? "bg-green-100 text-green-700" : "bg-red-100 text-red-600"}`}>
                            {s.feedback.correct ? "✓ Correct" : "✗ Wrong"}
                          </span>
                        )}
                      </div>
                      <div className="font-serif text-base text-[#0F1B4C] leading-snug pr-4">
                        <span className="font-mono text-slate-400 text-xs mr-1">Q{idx + 1}.</span>
                        {/^\s*</.test(q.question_text || "")
                          ? <span dangerouslySetInnerHTML={{ __html: q.question_text }} />
                          : <MathText text={q.question_text} />}
                      </div>
                    </div>
                    <div className="shrink-0 text-slate-400 mt-1">
                      {isOpen ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </div>
                  </button>

                  {/* Body */}
                  <AnimatePresence initial={false}>
                    {isOpen && (
                      <motion.div
                        key="body"
                        initial={{ height: 0, opacity: 0 }}
                        animate={{ height: "auto", opacity: 1 }}
                        exit={{ height: 0, opacity: 0 }}
                        transition={{ duration: 0.2 }}
                        className="overflow-hidden"
                      >
                        <div className="px-6 pb-5">
                          {q.image_url && <img src={q.image_url} className="mb-4 rounded-lg max-h-56" alt="" />}

                          {/* MCQ */}
                          {q.q_type === "mcq" && (
                            <div className="space-y-2 mb-4">
                              {(q.options || []).map((o, optIdx) => {
                                const isSel = s.selected === optIdx;
                                return (
                                  <label
                                    key={optIdx}
                                    className={`flex items-center gap-3 p-3 rounded-xl border text-sm cursor-pointer transition-all ${
                                      isSel ? "border-[#2563EB] bg-blue-50/60 font-semibold" : "border-slate-200 hover:border-slate-300"
                                    }`}
                                  >
                                    <input
                                      type="radio"
                                      name={`q_${q._id}`}
                                      checked={isSel}
                                      disabled={answered}
                                      onChange={() => setQ(q._id, { selected: optIdx })}
                                      className="w-4 h-4 accent-[#2563EB]"
                                    />
                                    <span className="font-mono text-xs text-[#7C3AED]">{o.label || String.fromCharCode(65 + optIdx)}</span>
                                    <MathText text={o.text} />
                                  </label>
                                );
                              })}
                            </div>
                          )}

                          {/* Typed */}
                          {q.q_type === "typed" && (
                            <div className="mb-4">
                              <label className="text-xs text-[#64748B] block mb-1">Your answer:</label>
                              <input
                                type="text"
                                disabled={answered}
                                value={s.typed || ""}
                                onChange={(e) => setQ(q._id, { typed: e.target.value })}
                                placeholder="Type answer here…"
                                className="w-full border rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-[#2563EB]"
                              />
                            </div>
                          )}

                          {/* Feedback / Solution */}
                          {s.feedback && (
                            <div className={`p-4 rounded-xl text-xs space-y-1 mb-3 ${s.feedback.correct ? "bg-green-100/60 text-green-900" : "bg-red-100/60 text-red-900"}`}>
                              <div className="font-bold">
                                {s.feedback.correct ? "✓ Correct!" : "✗ Incorrect"}
                              </div>
                              {s.feedback.correct_answer_text && (
                                <div>Correct answer: <span className="font-semibold">{s.feedback.correct_answer_text}</span></div>
                              )}
                              {s.feedback.explanation && (
                                <div className="mt-1 pt-1 border-t border-black/10">
                                  <strong>Explanation:</strong> <MathText text={s.feedback.explanation} />
                                </div>
                              )}
                            </div>
                          )}

                          {/* Submit button */}
                          {!answered && (
                            <Button
                              onClick={() => checkAnswer(q)}
                              disabled={q.q_type === "mcq" ? s.selected == null : !s.typed}
                              className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-white text-xs px-5 py-2 h-auto"
                            >
                              Check Answer
                            </Button>
                          )}
                        </div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </Card>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
