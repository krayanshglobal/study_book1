import React, { useEffect, useMemo, useState, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import api, { formatApiError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { Logo } from "@/components/Logo";
import { Loader2, Clock, Upload } from "lucide-react";
import MathText from "@/components/MathText";

function fmtDuration(ms) {
  if (ms < 0) ms = 0;
  const total = Math.floor(ms / 1000);
  const h = Math.floor(total / 3600).toString().padStart(2, "0");
  const m = Math.floor((total % 3600) / 60).toString().padStart(2, "0");
  const s = (total % 60).toString().padStart(2, "0");
  return `${h}:${m}:${s}`;
}

export default function LiveTest() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [test, setTest] = useState(null);
  const [questions, setQuestions] = useState([]);
  const [answers, setAnswers] = useState({}); // qid -> {selected_index, typed_answer}
  const [idx, setIdx] = useState(0);
  const [deadline, setDeadline] = useState(null);
  const [now, setNow] = useState(Date.now());
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);
  const autoSubmittedRef = useRef(false);

  useEffect(() => {
    (async () => {
      try {
        const r = await api.post(`/api/tests/${id}/start`);
        setTest(r.data.test);
        setQuestions(r.data.questions);
        setDeadline(new Date(r.data.deadline_at).getTime());
      } catch (err) {
        toast.error(formatApiError(err));
        navigate("/tests");
      } finally { setLoading(false); }
    })();
  }, [id, navigate]);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(t);
  }, []);

  const remaining = deadline ? Math.max(0, deadline - now) : 0;
  const isTimeUp = deadline ? now >= deadline : false;

  const submit = async (auto = false) => {
    if (submitting) return;
    setSubmitting(true);
    try {
      const payload = {
        answers: questions.map((q) => ({
          question_id: q._id,
          selected_index: answers[q._id]?.selected_index ?? null,
          typed_answer: answers[q._id]?.typed_answer ?? null,
        })),
      };
      const r = await api.post(`/api/tests/${id}/submit`, payload);
      toast.success(auto ? "Time up — test submitted!" : `Submitted. Score ${r.data.score}/${r.data.total_marks}`);
      navigate(`/tests/${id}/result`);
    } catch (err) {
      toast.error(formatApiError(err));
      setSubmitting(false);
    }
  };

  useEffect(() => {
    if (deadline && now >= deadline && !autoSubmittedRef.current && !submitting) {
      autoSubmittedRef.current = true;
      submit(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [now, deadline]);

  const current = questions[idx];
  const answered = useMemo(
    () => questions.filter((q) => {
      const a = answers[q._id]; return a && (a.selected_index != null || (a.typed_answer && a.typed_answer.trim()));
    }).length,
    [questions, answers]
  );

  if (loading || !test) {
    return <div className="min-h-screen grid place-items-center bg-[#F8FAFC]"><Loader2 className="animate-spin text-[#2563EB]" /></div>;
  }

  return (
    <div className="min-h-screen bg-[#F8FAFC]">
      <header className="sticky top-0 z-40 backdrop-blur-xl bg-white/90 border-b border-[#0F1B4C]/10">
        <div className="max-w-5xl mx-auto flex items-center justify-between px-5 py-3">
          <Logo size={32} />
          <div className="flex items-center gap-4">
            <div className="text-xs text-[#64748B] hidden sm:block" data-testid="test-answered-count">
              {answered}/{questions.length} answered
            </div>
            <div className={`flex items-center gap-2 text-white px-4 py-2 rounded-full font-mono text-sm ${isTimeUp ? "bg-red-600 animate-pulse" : "bg-[#0F1B4C]"}`} data-testid="test-timer">
              <Clock size={14} />
              {isTimeUp ? "TIME EXPIRED" : fmtDuration(remaining)}
            </div>
            <Button
              onClick={() => submit(false)}
              disabled={submitting || isTimeUp}
              data-testid="test-submit-btn"
              className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]"
            >
              {submitting ? <Loader2 className="animate-spin" size={16} /> : "Submit"}
            </Button>
          </div>
        </div>
      </header>

      <div className="max-w-5xl mx-auto grid lg:grid-cols-[1fr,240px] gap-8 px-5 py-8">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">{test.title}</div>
          <div className="mt-1 font-serif text-2xl text-[#0F1B4C] font-semibold">Question {idx + 1} of {questions.length}</div>

          {current && (
            <div className="mt-6 rounded-2xl bg-white border border-slate-200 p-8">
              <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">{current.topic}</div>
              <div className="mt-3 font-serif text-xl text-[#0F1B4C] leading-snug"><MathText text={current.question_text} /></div>
              {current.image_url && <img src={current.image_url} className="mt-4 rounded-lg max-h-64" alt="" />}

              {current.q_type === "mcq" ? (
                <div className="mt-6 grid sm:grid-cols-2 gap-3">
                  {current.options?.map((o, i) => {
                    const chosen = answers[current._id]?.selected_index === i;
                    return (
                      <button
                        key={i}
                        data-testid={`live-option-${i}`}
                        disabled={submitting || isTimeUp}
                        onClick={() => {
                          if (submitting || isTimeUp) return;
                          setAnswers((s) => ({ ...s, [current._id]: { ...s[current._id], selected_index: i } }));
                        }}
                        className={`text-left p-4 rounded-xl border transition-colors ${chosen ? "border-[#2563EB] bg-[#2563EB]/5" : "border-slate-200 hover:border-[#2563EB]/40"} ${isTimeUp ? "opacity-60 cursor-not-allowed" : ""}`}
                      >
                        <span className="font-mono text-xs text-[#7C3AED] mr-2">{o.label}.</span>
                        <span className="text-[#0F1B4C]"><MathText text={o.text} /></span>
                      </button>
                    );
                  })}
                </div>
              ) : current.q_type === "typed" ? (
                <div className="mt-6">
                  <label className="text-xs tracking-[0.2em] uppercase text-[#64748B]">Your answer</label>
                  <Input
                    data-testid="live-typed-input"
                    disabled={submitting || isTimeUp}
                    value={answers[current._id]?.typed_answer || ""}
                    onChange={(e) => setAnswers((s) => ({ ...s, [current._id]: { ...s[current._id], typed_answer: e.target.value } }))}
                    className="mt-2 rounded-lg font-mono"
                    placeholder="Type your answer…"
                  />
                </div>
              ) : (
                <div className="mt-6 p-4 bg-purple-50/60 rounded-2xl border border-purple-200">
                  <div className="text-xs tracking-[0.2em] uppercase text-[#7C3AED] font-bold mb-2">Solution Upload Required</div>
                  <p className="text-xs text-slate-600 mb-3">Upload your handwritten or typed solution file (.pdf, .jpg, .jpeg, .png):</p>
                  <input
                    type="file"
                    accept=".pdf,.jpg,.jpeg,.png,image/png,image/jpeg,application/pdf"
                    disabled={submitting || isTimeUp}
                    onChange={async (e) => {
                      if (submitting || isTimeUp) return;
                      const file = e.target.files?.[0];
                      if (!file) return;
                      const fd = new FormData();
                      fd.append("file", file);
                      try {
                        const res = await api.post("/api/uploads/image", fd);
                        setAnswers((s) => ({ ...s, [current._id]: { ...s[current._id], file_url: res.data.url, file_name: file.name } }));
                        toast.success(`Uploaded ${file.name}`);
                      } catch {
                        toast.error("Failed to upload file");
                      }
                    }}
                    className="text-xs text-slate-600 file:mr-3 file:py-1.5 file:px-4 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-[#7C3AED] file:text-white hover:file:bg-[#6D28D9] cursor-pointer"
                  />
                  {answers[current._id]?.file_name && (
                    <div className="mt-2 text-xs font-mono text-emerald-700 bg-emerald-50 px-3 py-1.5 rounded-lg border border-emerald-200">
                      ✓ Attached: {answers[current._id].file_name}
                    </div>
                  )}
                </div>
              )}

              {/* Optional File Upload for MCQ or Typed answers */}
              {current.allow_file_upload && current.q_type !== "file_upload" && (
                <div className="mt-4 p-3 bg-slate-50 rounded-xl border border-slate-200">
                  <div className="flex items-center justify-between text-xs font-semibold text-[#0F1B4C] mb-1.5">
                    <span className="flex items-center gap-1.5">
                      <Upload size={14} className="text-[#7C3AED]" /> Optional Solution Attachment (.pdf, .jpg, .jpeg, .png)
                    </span>
                    {answers[current._id]?.file_url && <span className="text-emerald-600 text-[11px] font-bold">✓ Attached</span>}
                  </div>
                  <input
                    type="file"
                    accept=".pdf,.jpg,.jpeg,.png,image/png,image/jpeg,application/pdf"
                    disabled={submitting || isTimeUp}
                    onChange={async (e) => {
                      if (submitting || isTimeUp) return;
                      const file = e.target.files?.[0];
                      if (!file) return;
                      const fd = new FormData();
                      fd.append("file", file);
                      try {
                        const res = await api.post("/api/uploads/image", fd);
                        setAnswers((s) => ({ ...s, [current._id]: { ...s[current._id], file_url: res.data.url, file_name: file.name } }));
                        toast.success(`Attached ${file.name}`);
                      } catch {
                        toast.error("Failed to upload file");
                      }
                    }}
                    className="text-xs text-slate-600 file:mr-2 file:py-1 file:px-3 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-[#7C3AED] file:text-white hover:file:bg-[#6D28D9] cursor-pointer"
                  />
                  {answers[current._id]?.file_name && (
                    <div className="mt-1 text-xs text-slate-500 font-mono">
                      📎 {answers[current._id].file_name}
                    </div>
                  )}
                </div>
              )}

              <div className="mt-8 flex items-center justify-between">
                <Button variant="outline" className="rounded-full" onClick={() => setIdx((i) => Math.max(0, i - 1))} disabled={idx === 0} data-testid="live-prev-btn">
                  Previous
                </Button>
                {idx < questions.length - 1 ? (
                  <Button onClick={() => setIdx((i) => Math.min(questions.length - 1, i + 1))} data-testid="live-next-btn" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">
                    Next
                  </Button>
                ) : (
                  <Button onClick={() => submit(false)} disabled={submitting} data-testid="live-final-submit-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]">
                    Submit test
                  </Button>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Question navigator */}
        <aside className="rounded-2xl bg-white border border-slate-200 p-5 h-fit sticky top-24">
          <div className="text-xs tracking-widest uppercase text-[#64748B] font-semibold">Navigator</div>
          <div className="mt-4 grid grid-cols-5 gap-2">
            {questions.map((q, i) => {
              const a = answers[q._id];
              const isAnswered = a && (a.selected_index != null || (a.typed_answer && a.typed_answer.trim()) || a.file_url);
              return (
                <button
                  key={q._id}
                  onClick={() => setIdx(i)}
                  data-testid={`nav-q-${i}`}
                  className={`w-full aspect-square rounded-lg text-sm font-mono border transition-colors ${
                    i === idx
                      ? "bg-[#0F1B4C] text-white border-[#0F1B4C]"
                      : isAnswered
                        ? "bg-[#2563EB]/10 border-[#2563EB]/40 text-[#2563EB]"
                        : "bg-white border-slate-200 text-[#64748B]"
                  }`}
                >
                  {i + 1}
                </button>
              );
            })}
          </div>
          <div className="mt-4 text-xs text-[#64748B]">
            <div className="flex items-center gap-2 mt-1"><div className="w-3 h-3 rounded bg-[#0F1B4C]" /> Current</div>
            <div className="flex items-center gap-2 mt-1"><div className="w-3 h-3 rounded bg-[#2563EB]/30 border border-[#2563EB]/40" /> Answered</div>
            <div className="flex items-center gap-2 mt-1"><div className="w-3 h-3 rounded border border-slate-300" /> Blank</div>
          </div>
        </aside>
      </div>
    </div>
  );
}
