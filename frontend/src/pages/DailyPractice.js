import React, { useState, useEffect, useCallback } from "react";
import api from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import MathText from "@/components/MathText";
import { toast } from "sonner";
import {
  Flame, CheckCircle2, XCircle, ChevronRight,
  RotateCcw, Trophy, Zap, BookOpen, Target, ArrowLeft
} from "lucide-react";
import { useNavigate } from "react-router-dom";

const DIFF_COLOR = { easy: "text-emerald-500", medium: "text-amber-500", hard: "text-rose-500" };

export default function DailyPractice() {
  const { user } = useAuth();
  const navigate = useNavigate();

  const [loading, setLoading] = useState(true);
  const [data, setData] = useState(null);          // API response
  const [idx, setIdx] = useState(0);               // current question index
  const [selected, setSelected] = useState(null);  // selected option index
  const [typedAnswer, setTypedAnswer] = useState("");
  const [result, setResult] = useState(null);      // { correct, explanation, correct_index, correct_answer_text }
  const [sessionAttempted, setSessionAttempted] = useState({}); // qid -> {correct, result}
  const [submitting, setSubmitting] = useState(false);
  const [showCompletion, setShowCompletion] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await api.get("/api/students/daily-practice");
      setData(res.data);
      if (res.data.completed) setShowCompletion(true);
      // Pre-populate already-attempted from API
      const pre = {};
      Object.entries(res.data.attempted_map || {}).forEach(([qid, correct]) => {
        pre[qid] = { correct, alreadyDone: true };
      });
      setSessionAttempted(pre);
    } catch {
      toast.error("Failed to load daily practice");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const questions = data?.questions || [];
  const q = questions[idx];
  const alreadyAttempted = q && (sessionAttempted[q._id] !== undefined);
  const streak = data?.streak || 0;
  const totalDone = Object.keys(sessionAttempted).length;
  const total = data?.total || 10;
  const pct = total > 0 ? Math.round((totalDone / total) * 100) : 0;

  async function submitAnswer() {
    if (!q) return;
    if (q.q_type === "mcq" && selected === null) return;
    if (q.q_type === "typed" && !typedAnswer.trim()) return;
    setSubmitting(true);
    try {
      const body = q.q_type === "mcq"
        ? { selected_index: selected }
        : { typed_answer: typedAnswer };
      const res = await api.post(`/api/questions/${q._id}/check`, body);
      const r = res.data;
      setResult(r);
      setSessionAttempted(prev => ({ ...prev, [q._id]: { correct: r.correct } }));
      if (r.daily_bonus_earned) {
        toast.success("🎉 Daily bonus earned! +1 point", { duration: 4000 });
      }
    } catch {
      toast.error("Failed to submit answer");
    } finally {
      setSubmitting(false);
    }
  }

  function nextQuestion() {
    setResult(null);
    setSelected(null);
    setTypedAnswer("");
    const nextIdx = idx + 1;
    if (nextIdx >= questions.length) {
      setShowCompletion(true);
    } else {
      setIdx(nextIdx);
    }
  }

  const correctCount = Object.values(sessionAttempted).filter(a => a.correct).length;
  const accuracy = totalDone > 0 ? Math.round((correctCount / totalDone) * 100) : 0;

  // ── Completion screen ──────────────────────────────────────────────
  if (showCompletion && !loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-[#0F1B4C] via-[#1a2a6c] to-[#2563EB] flex items-center justify-center p-4">
        <div className="max-w-lg w-full text-center space-y-6">
          <div className="w-24 h-24 rounded-full bg-amber-400/20 border-2 border-amber-400 flex items-center justify-center mx-auto animate-bounce">
            <Trophy size={40} className="text-amber-400" />
          </div>
          <div>
            <h1 className="text-3xl font-serif font-bold text-white mb-2">
              Practice Complete! 🎉
            </h1>
            <p className="text-blue-200">You've finished today's daily practice</p>
          </div>

          <div className="grid grid-cols-3 gap-4">
            {[
              { label: "Score", value: `${correctCount}/${totalDone}`, icon: Target, color: "text-emerald-400" },
              { label: "Accuracy", value: `${accuracy}%`, icon: Zap, color: "text-blue-400" },
              { label: "Streak", value: `🔥 ${streak}`, icon: Flame, color: "text-amber-400" },
            ].map(({ label, value, icon: Icon, color }) => (
              <Card key={label} className="bg-white/10 border-white/20 p-4 text-center">
                <div className={`text-2xl font-bold ${color}`}>{value}</div>
                <div className="text-xs text-blue-200 mt-1">{label}</div>
              </Card>
            ))}
          </div>

          {streak > 0 && (
            <div className="bg-amber-500/20 border border-amber-500/40 rounded-2xl p-4 text-amber-300 text-sm font-medium">
              🔥 {streak}-day streak! Keep it up, come back tomorrow!
            </div>
          )}

          <div className="flex gap-3 justify-center flex-wrap">
            <Button
              onClick={() => navigate("/dashboard")}
              className="rounded-full bg-white text-[#0F1B4C] hover:bg-blue-50 font-semibold px-6"
            >
              Back to Dashboard
            </Button>
            <Button
              onClick={() => navigate("/questions")}
              variant="outline"
              className="rounded-full border-white/40 text-white hover:bg-white/10 px-6"
            >
              <BookOpen size={16} className="mr-2" /> Practice More
            </Button>
          </div>
        </div>
      </div>
    );
  }

  // ── Loading ────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center space-y-3">
          <div className="w-12 h-12 border-4 border-[#2563EB] border-t-transparent rounded-full animate-spin mx-auto" />
          <p className="text-slate-500">Loading today's questions…</p>
        </div>
      </div>
    );
  }

  if (!q) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-center space-y-4 max-w-sm">
          <BookOpen size={48} className="mx-auto text-slate-300" />
          <h2 className="text-xl font-semibold text-slate-700">No Questions Available</h2>
          <p className="text-slate-500 text-sm">Ask your admin to add questions for Class {user?.class_level}.</p>
          <Button onClick={() => navigate("/dashboard")} className="rounded-full">Back to Dashboard</Button>
        </div>
      </div>
    );
  }

  // ── Main Practice UI ───────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-50 py-6 px-4">
      <div className="max-w-2xl mx-auto space-y-4">

        {/* Header */}
        <div className="flex items-center justify-between">
          <button onClick={() => navigate("/dashboard")} className="flex items-center gap-1 text-slate-500 hover:text-slate-700 text-sm">
            <ArrowLeft size={16} /> Dashboard
          </button>
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5 bg-amber-100 text-amber-700 rounded-full px-3 py-1 text-sm font-semibold">
              <Flame size={15} /> {streak} day streak
            </div>
            <Badge variant="outline" className="rounded-full text-xs">
              {data?.date}
            </Badge>
          </div>
        </div>

        {/* Progress */}
        <Card className="p-4 rounded-2xl border-0 shadow-sm bg-white">
          <div className="flex items-center justify-between mb-2">
            <span className="text-sm font-semibold text-slate-700">Today's Progress</span>
            <span className="text-sm text-slate-500">{totalDone} / {total} done</span>
          </div>
          <div className="w-full h-2.5 bg-slate-100 rounded-full overflow-hidden">
            <div
              className="h-full bg-gradient-to-r from-[#2563EB] to-[#7C3AED] rounded-full transition-all duration-500"
              style={{ width: `${pct}%` }}
            />
          </div>
          {/* Question dot indicators */}
          <div className="flex gap-1.5 mt-3 flex-wrap">
            {questions.map((sq, i) => {
              const a = sessionAttempted[sq._id];
              const isCurrent = i === idx;
              let bg = "bg-slate-200";
              if (a?.correct === true) bg = "bg-emerald-500";
              else if (a?.correct === false) bg = "bg-rose-400";
              else if (isCurrent) bg = "bg-[#2563EB]";
              return (
                <button
                  key={sq._id}
                  onClick={() => { setIdx(i); setResult(null); setSelected(null); setTypedAnswer(""); }}
                  className={`w-6 h-6 rounded-full text-xs font-bold text-white transition-all ${bg} ${isCurrent ? "ring-2 ring-offset-1 ring-[#2563EB]" : ""}`}
                >
                  {i + 1}
                </button>
              );
            })}
          </div>
        </Card>

        {/* Question Card */}
        <Card className="p-6 rounded-2xl border-0 shadow-md bg-white">
          <div className="flex items-start justify-between mb-4 gap-3">
            <div className="flex items-center gap-2 flex-wrap">
              <Badge className="bg-[#EEF2FF] text-[#3730A3] hover:bg-[#EEF2FF] text-xs rounded-full">
                Q{idx + 1}
              </Badge>
              {q.topic && (
                <Badge variant="outline" className="text-xs rounded-full">{q.topic}</Badge>
              )}
              {q.difficulty && (
                <span className={`text-xs font-semibold capitalize ${DIFF_COLOR[q.difficulty] || "text-slate-500"}`}>
                  {q.difficulty}
                </span>
              )}
              <span className="text-xs text-slate-400">+{q.positive_marks} / -{q.negative_marks}</span>
            </div>
          </div>

          <div className="text-[#0F1B4C] font-medium text-base leading-relaxed mb-6">
            <MathText text={q.question_text} />
          </div>

          {q.image_url && (
            <img src={q.image_url} alt="question" className="rounded-xl mb-5 max-h-56 object-contain border border-slate-100" />
          )}

          {/* MCQ Options */}
          {q.q_type === "mcq" && (
            <div className="space-y-2.5">
              {(q.options || []).map((opt, i) => {
                let cls = "border-slate-200 hover:border-[#2563EB] hover:bg-blue-50 cursor-pointer";
                if (result) {
                  if (i === result.correct_index) cls = "border-emerald-500 bg-emerald-50";
                  else if (i === selected && !result.correct) cls = "border-rose-400 bg-rose-50";
                  else cls = "border-slate-100 opacity-60";
                } else if (selected === i) {
                  cls = "border-[#2563EB] bg-blue-50";
                }
                if (alreadyAttempted && !result) cls = "border-slate-100 opacity-60 cursor-not-allowed";
                return (
                  <button
                    key={i}
                    disabled={!!result || alreadyAttempted}
                    onClick={() => setSelected(i)}
                    className={`w-full text-left flex items-center gap-3 px-4 py-3 rounded-xl border-2 transition-all text-sm font-medium ${cls}`}
                  >
                    <span className="w-6 h-6 rounded-full bg-slate-100 text-slate-600 text-xs font-bold flex items-center justify-center shrink-0">
                      {opt.label || String.fromCharCode(65 + i)}
                    </span>
                    <MathText text={opt.text} />
                    {result && i === result.correct_index && <CheckCircle2 size={16} className="ml-auto text-emerald-500 shrink-0" />}
                    {result && i === selected && !result.correct && i !== result.correct_index && <XCircle size={16} className="ml-auto text-rose-400 shrink-0" />}
                  </button>
                );
              })}
            </div>
          )}

          {/* Typed Answer */}
          {q.q_type === "typed" && (
            <div className="space-y-3">
              <input
                type="text"
                disabled={!!result || alreadyAttempted}
                value={typedAnswer}
                onChange={e => setTypedAnswer(e.target.value)}
                onKeyDown={e => e.key === "Enter" && !result && submitAnswer()}
                placeholder="Type your answer…"
                className="w-full border-2 border-slate-200 rounded-xl px-4 py-3 text-sm focus:outline-none focus:border-[#2563EB] disabled:opacity-60"
              />
              {result && (
                <div className={`flex items-center gap-2 text-sm font-medium ${result.correct ? "text-emerald-600" : "text-rose-500"}`}>
                  {result.correct ? <CheckCircle2 size={16} /> : <XCircle size={16} />}
                  Correct answer: <span className="font-bold">{result.correct_answer_text}</span>
                </div>
              )}
            </div>
          )}

          {/* Explanation */}
          {result?.explanation && (
            <div className="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-xl text-sm text-amber-800 leading-relaxed">
              <span className="font-semibold">💡 Explanation: </span>
              <MathText text={result.explanation} />
            </div>
          )}

          {/* Already done notice */}
          {alreadyAttempted && !result && (
            <div className="mt-4 p-3 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-500 text-center">
              Already answered — click another question or continue
            </div>
          )}
        </Card>

        {/* Action Buttons */}
        <div className="flex gap-3 justify-end">
          {!result && !alreadyAttempted && (
            <Button
              onClick={submitAnswer}
              disabled={submitting || (q.q_type === "mcq" ? selected === null : !typedAnswer.trim())}
              className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] px-6 font-semibold"
            >
              {submitting ? "Checking…" : "Submit Answer"}
            </Button>
          )}
          {(result || alreadyAttempted) && (
            <Button
              onClick={nextQuestion}
              className="rounded-full bg-gradient-to-r from-[#2563EB] to-[#7C3AED] text-white hover:opacity-90 px-6 font-semibold"
            >
              {idx + 1 >= questions.length ? "See Results" : "Next Question"}
              <ChevronRight size={16} className="ml-1" />
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
