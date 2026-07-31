import React, { useEffect, useState } from "react";
import { useParams, Link } from "react-router-dom";
import api from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { CheckCircle2, XCircle, MinusCircle, Trophy } from "lucide-react";
import MathText from "@/components/MathText";

export default function TestResult() {
  const { id } = useParams();
  const [data, setData] = useState(null);
  const [lb, setLb] = useState([]);

  useEffect(() => {
    (async () => {
      try {
        const [r, l] = await Promise.all([
          api.get(`/api/tests/${id}/result`),
          api.get(`/api/tests/${id}/leaderboard`),
        ]);
        setData(r.data);
        setLb(l.data.items || []);
      } catch {}
    })();
  }, [id]);

  if (!data) return <div className="max-w-4xl mx-auto px-6 py-16 text-[#64748B]">Loading…</div>;
  const a = data.attempt;
  const passed = a.percent >= 50;

  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Result</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">{data.test?.title}</h1>

      <Card className="mt-8 rounded-2xl p-8 border-slate-200" data-testid="result-summary-card">
        <div className="grid sm:grid-cols-4 gap-6">
          <div>
            <div className="text-xs tracking-widest uppercase text-[#64748B]">Score</div>
            <div className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">{a.score}</div>
            <div className="text-sm text-[#64748B]">of {a.total_marks}</div>
          </div>
          <div>
            <div className="text-xs tracking-widest uppercase text-[#64748B]">Percent</div>
            <div className={`mt-2 font-serif text-4xl font-semibold ${passed ? "text-green-600" : "text-red-600"}`}>{a.percent}%</div>
          </div>
          <div>
            <div className="text-xs tracking-widest uppercase text-[#64748B]">Correct / Wrong</div>
            <div className="mt-2 font-mono text-2xl text-[#0F1B4C]">{a.correct_count}/{a.incorrect_count}</div>
          </div>
          <div>
            <div className="text-xs tracking-widest uppercase text-[#64748B]">Unanswered</div>
            <div className="mt-2 font-mono text-2xl text-[#0F1B4C]">{a.unanswered}</div>
          </div>
        </div>
        {passed && data.test?.test_type === "mock" && (
          <div className="mt-6 p-4 rounded-lg bg-green-50 border border-green-200 text-green-700 text-sm">
            You scored above 50%. Any final tests set by your admin with this prerequisite are now unlocked.
          </div>
        )}
      </Card>

      <div className="mt-10 grid lg:grid-cols-[1fr,320px] gap-6">
        <div>
          <h2 className="font-serif text-2xl text-[#0F1B4C] font-semibold">Review</h2>
          <div className="mt-4 space-y-4">
            {data.questions.map((q, i) => {
              const ans = a.answers.find((x) => x.question_id === q._id);
              const status = !ans?.answered ? "skip" : ans.is_correct ? "ok" : "wrong";
              return (
                <Card key={q._id} className="p-6 rounded-2xl border-slate-200" data-testid={`review-q-${i}`}>
                  <div className="flex items-start gap-3">
                    {status === "ok" && <CheckCircle2 className="text-green-600 mt-1" size={20} />}
                    {status === "wrong" && <XCircle className="text-red-600 mt-1" size={20} />}
                    {status === "skip" && <MinusCircle className="text-slate-400 mt-1" size={20} />}
                    <div className="flex-1">
                      <div className="text-xs tracking-widest uppercase text-[#7C3AED]">{q.topic}</div>
                      <div className="mt-1 font-medium text-[#0F1B4C]">{i + 1}. <MathText text={q.question_text} /></div>
                      <div className="mt-2 text-sm text-[#475569]">
                        {q.q_type === "mcq" ? (
                          <>
                            Correct: <span className="font-mono">{q.options?.[q.correct_index]?.text}</span>
                            {ans?.selected_index != null && !ans.is_correct && (
                              <> · Your answer: <span className="font-mono text-red-600">{q.options?.[ans.selected_index]?.text}</span></>
                            )}
                          </>
                        ) : (
                          <>
                            Correct: <span className="font-mono">{q.correct_answer_text}</span>
                            {ans?.typed_answer && !ans.is_correct && (
                              <> · Your answer: <span className="font-mono text-red-600">{ans.typed_answer}</span></>
                            )}
                          </>
                        )}
                      </div>
                      {q.explanation && (
                        <div className="mt-2 text-sm text-[#334155]"><span className="font-semibold">Why:</span> {q.explanation}</div>
                      )}
                    </div>
                  </div>
                </Card>
              );
            })}
          </div>
        </div>

        <aside className="lg:sticky lg:top-24 h-fit">
          <Card className="p-6 rounded-2xl border-slate-200">
            <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">
              <Trophy size={14} /> Test leaderboard
            </div>
            <div className="mt-4 space-y-2">
              {lb.slice(0, 10).map((r) => (
                <div key={r.user_id} className="flex items-center justify-between text-sm">
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs text-[#64748B] w-5">#{r.rank}</span>
                    <span className="text-[#0F1B4C]">{r.name}</span>
                  </div>
                  <span className="font-mono text-[#2563EB]">{r.percent}%</span>
                </div>
              ))}
            </div>
          </Card>
          <Link to="/tests">
            <Button variant="outline" className="mt-4 w-full rounded-full">Back to tests</Button>
          </Link>
        </aside>
      </div>
    </div>
  );
}
