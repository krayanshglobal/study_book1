import React, { useEffect, useState, useMemo } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { motion, AnimatePresence } from "framer-motion";
import { CheckCircle2, XCircle, BookOpen, CalendarDays, CircleCheck, CircleDashed, ChevronDown, ChevronUp } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";
import MathText from "@/components/MathText";

// Returns "YYYY-MM-DD" in local time
const toDateStr = (d) => {
  const dt = new Date(d);
  return `${dt.getFullYear()}-${String(dt.getMonth() + 1).padStart(2, "0")}-${String(dt.getDate()).padStart(2, "0")}`;
};
const todayStr = () => toDateStr(new Date());
const yesterdayStr = () => {
  const d = new Date(); d.setDate(d.getDate() - 1); return toDateStr(d);
};

export default function QuestionBank() {
  const { user } = useAuth();
  const isStaff = user?.role === "admin" || user?.role === "superadmin";
  const [classLevel, setClassLevel] = useState(isStaff ? "10" : (user?.class_level || "8"));
  const [topic, setTopic] = useState("all");
  const [topics, setTopics] = useState([]);
  const [items, setItems] = useState([]);
  const [dateFilter, setDateFilter] = useState("all"); // "all" | "today" | "yesterday" | "YYYY-MM-DD"

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

  useEffect(() => {
    (async () => {
      try {
        const t = await api.get("/api/questions/topics", { params: { class_level: classLevel } });
        setTopics(t.data.topics || []);
      } catch {}
    })();
  }, [classLevel]);

  useEffect(() => {
    (async () => {
      try {
        const params = { class_level: classLevel, limit: 500 };
        if (topic && topic !== "all") params.topic = topic;
        const r = await api.get("/api/questions", { params });
        setItems(r.data.items || []);
      } catch {}
    })();
  }, [classLevel, topic]);

  // All unique dates from items (YYYY-MM-DD)
  const availableDates = useMemo(() => {
    const set = new Set(items.map((q) => q.created_at ? toDateStr(q.created_at) : null).filter(Boolean));
    return Array.from(set).sort((a, b) => b.localeCompare(a)); // newest first
  }, [items]);

  // Apply date filter
  const filtered = useMemo(() => {
    if (dateFilter === "all") return items;
    const target = dateFilter === "today" ? todayStr() : dateFilter === "yesterday" ? yesterdayStr() : dateFilter;
    return items.filter((q) => q.created_at && toDateStr(q.created_at) === target);
  }, [items, dateFilter]);

  // Stats
  const answered = useMemo(() => filtered.filter((q) => qState[q._id]?.feedback).length, [filtered, qState]);
  const unanswered = filtered.length - answered;

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
    if (s.feedback) return; // Prevent reattempting if already answered
    try {
      const r = await api.post(`/api/questions/${q._id}/check`, {
        selected_index: s.selected ?? null,
        typed_answer: s.typed ?? "",
      });
      setQ(q._id, { feedback: r.data, open: true });
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const formatDate = (str) => {
    if (!str) return "";
    const d = new Date(str);
    return d.toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short", year: "numeric" });
  };

  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Practice</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Question bank</h1>
      <p className="mt-1 text-[#64748B]">All questions for your class. Practice by topic, filter by day.</p>

      {/* Filters row */}
      <div className="mt-6 flex flex-wrap gap-3 items-center">
        {isStaff && (
          <Select value={classLevel} onValueChange={(v) => { setClassLevel(v); setDateFilter("all"); }}>
            <SelectTrigger className="w-36 rounded-full" data-testid="qbank-class-select"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="8">Class 8</SelectItem>
              <SelectItem value="9">Class 9</SelectItem>
              <SelectItem value="10">Class 10</SelectItem>
            </SelectContent>
          </Select>
        )}
        <Select value={topic} onValueChange={setTopic}>
          <SelectTrigger className="w-48 rounded-full" data-testid="qbank-topic-select"><SelectValue placeholder="All topics" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All topics</SelectItem>
            {topics.filter((t) => t.topic && t.topic.trim() !== "").map((t) => (
              <SelectItem key={t.topic} value={t.topic}>{t.topic} ({t.count})</SelectItem>
            ))}
          </SelectContent>
        </Select>

        {/* Day filter */}
        <Select value={dateFilter} onValueChange={setDateFilter}>
          <SelectTrigger className="w-44 rounded-full">
            <CalendarDays size={14} className="mr-1 text-slate-400" />
            <SelectValue placeholder="All days" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All days</SelectItem>
            <SelectItem value="today">Today</SelectItem>
            <SelectItem value="yesterday">Yesterday</SelectItem>
            {availableDates
              .filter((d) => d !== todayStr() && d !== yesterdayStr())
              .map((d) => (
                <SelectItem key={d} value={d}>
                  {new Date(d).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })}
                </SelectItem>
              ))}
          </SelectContent>
        </Select>

        <div className="ml-auto text-sm text-[#64748B]">
          <span className="font-mono font-semibold text-[#0F1B4C]">{filtered.length}</span> questions
        </div>
      </div>

      {/* Stats bar */}
      {filtered.length > 0 && (
        <div className="mt-4 flex gap-3 flex-wrap">
          <div className="flex items-center gap-2 bg-white border border-slate-200 rounded-full px-4 py-1.5 text-xs font-semibold text-[#0F1B4C]">
            <BookOpen size={13} className="text-[#2563EB]" />
            Total: <span className="font-mono">{filtered.length}</span>
          </div>
          <div className="flex items-center gap-2 bg-green-50 border border-green-200 rounded-full px-4 py-1.5 text-xs font-semibold text-green-700">
            <CircleCheck size={13} />
            Answered: <span className="font-mono">{answered}</span>
          </div>
          <div className="flex items-center gap-2 bg-amber-50 border border-amber-200 rounded-full px-4 py-1.5 text-xs font-semibold text-amber-700">
            <CircleDashed size={13} />
            Unanswered: <span className="font-mono">{unanswered}</span>
          </div>
          {dateFilter !== "all" && (
            <div className="flex items-center gap-2 bg-[#0F1B4C]/5 border border-[#0F1B4C]/10 rounded-full px-4 py-1.5 text-xs font-semibold text-[#0F1B4C]">
              <CalendarDays size={13} />
              {dateFilter === "today" ? "Today" : dateFilter === "yesterday" ? "Yesterday" : formatDate(dateFilter)}
            </div>
          )}
        </div>
      )}

      {/* Questions list */}
      {filtered.length === 0 ? (
        <div className="mt-16 text-center text-[#64748B]" data-testid="qbank-empty">
          <BookOpen className="mx-auto text-[#94a3b8]" size={40} />
          <p className="mt-3">No questions here yet. Ask your admin to upload some!</p>
        </div>
      ) : (
        <div className="mt-6 space-y-4">
          {filtered.map((q, idx) => {
            const s = qState[q._id] || {};
            const answered = !!s.feedback;
            const isOpen = s.open !== false; // default open

            return (
              <motion.div
                key={q._id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: Math.min(idx * 0.03, 0.3) }}
              >
                <Card className={`rounded-2xl border transition-all ${answered ? "border-green-200 bg-green-50/30" : "border-slate-200 bg-white"}`}
                  data-testid={`qbank-card-${q._id}`}>

                  {/* Question header — always visible, click to collapse */}
                  <button
                    type="button"
                    className="w-full text-left px-6 pt-5 pb-3 flex items-start justify-between gap-3"
                    onClick={() => setQ(q._id, { open: !isOpen })}
                  >
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap mb-1">
                        <span className="text-[10px] tracking-widest uppercase text-[#7C3AED] font-bold">{q.topic || "General"}</span>
                        <span className="text-[10px] text-slate-400">· +{q.positive_marks}/−{q.negative_marks} · {q.difficulty}</span>
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

                  {/* Collapsible body */}
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

                          {/* Options */}
                          {q.q_type === "mcq" ? (
                            <div className="grid sm:grid-cols-2 gap-2 mt-1">
                              {q.options?.map((o, i) => {
                                const isCorrect = s.feedback && i === s.feedback.correct_index;
                                const isChosen = s.selected === i;
                                return (
                                  <button
                                    key={i}
                                    data-testid={`qbank-option-${q._id}-${i}`}
                                    onClick={() => !s.feedback && setQ(q._id, { selected: i })}
                                    disabled={!!s.feedback}
                                    className={`text-left p-3 rounded-xl border text-sm transition-all ${
                                      s.feedback
                                        ? isCorrect
                                          ? "border-green-500 bg-green-50"
                                          : isChosen
                                            ? "border-red-400 bg-red-50"
                                            : "border-slate-100 opacity-60"
                                        : isChosen
                                          ? "border-[#2563EB] bg-[#2563EB]/5"
                                          : "border-slate-200 hover:border-[#2563EB]/40"
                                    }`}
                                  >
                                    <span className="font-mono text-xs text-[#7C3AED] mr-1.5">{o.label}.</span>
                                    <span className="text-[#0F1B4C]"><MathText text={o.text} /></span>
                                  </button>
                                );
                              })}
                            </div>
                          ) : (
                            <div className="mt-2">
                              <label className="text-xs tracking-[0.2em] uppercase text-[#64748B]">Your answer</label>
                              <Input
                                value={s.typed || ""}
                                onChange={(e) => setQ(q._id, { typed: e.target.value })}
                                disabled={!!s.feedback}
                                className="mt-1.5 rounded-lg font-mono"
                                placeholder="Type your answer…"
                              />
                            </div>
                          )}

                          {/* Feedback */}
                          {s.feedback && (
                            <div className="mt-4 p-4 rounded-xl border-l-4 border-[#7C3AED] bg-[#7C3AED]/5">
                              <div className={`flex items-center gap-2 font-medium text-sm ${s.feedback.correct ? "text-green-600" : "text-red-600"}`}>
                                {s.feedback.correct ? <CheckCircle2 size={16} /> : <XCircle size={16} />}
                                {s.feedback.correct
                                  ? "Correct!"
                                  : `Correct: ${s.feedback.correct_answer_text ?? q.options?.[s.feedback.correct_index]?.text}`}
                              </div>
                              {s.feedback.explanation && (
                                <div className="mt-1.5 text-xs text-[#334155]">
                                  <span className="font-semibold">Why:</span> {s.feedback.explanation}
                                </div>
                              )}
                            </div>
                          )}

                          {/* Action button */}
                          {!s.feedback && (
                            <div className="mt-4">
                              <Button
                                onClick={() => checkAnswer(q)}
                                disabled={q.q_type === "mcq" ? s.selected == null : !(s.typed || "").trim()}
                                className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-sm h-9 px-5"
                                data-testid={`qbank-submit-${q._id}`}
                              >
                                Check answer
                              </Button>
                            </div>
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
