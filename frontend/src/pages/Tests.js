import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { Lock, Calendar, Clock, ArrowRight } from "lucide-react";

function getEndDateTime(t) {
  const start = new Date(`${t.scheduled_date}T${t.start_time}:00+05:30`);
  let end = new Date(`${t.scheduled_date}T${t.end_time}:00+05:30`);
  if (end <= start) {
    end.setDate(end.getDate() + 1);
  }
  return { start, end };
}
function isLiveNow(t) {
  const now = new Date();
  const { start, end } = getEndDateTime(t);
  return now >= start && now <= end;
}
function isPast(t) {
  const { end } = getEndDateTime(t);
  return new Date() > end;
}

export default function Tests() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const r = await api.get("/api/tests");
        setItems(r.data.items || []);
      } catch (err) {
        toast.error(formatApiError(err));
      } finally { setLoading(false); }
    })();
  }, []);

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Assessments</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Practice & final tests</h1>
      <p className="mt-1 text-[#64748B]">Take scheduled tests during their live window. Every submission tracks toward your rank.</p>

      {loading ? (
        <div className="mt-16 text-center text-[#64748B]">Loading tests…</div>
      ) : items.length === 0 ? (
        <div className="mt-16 text-center text-[#64748B]" data-testid="tests-empty">
          No tests published yet. Check back soon!
        </div>
      ) : (
        <div className="mt-8 grid md:grid-cols-2 gap-5">
          {items.map((t) => {
            const live = isLiveNow(t);
            const past = isPast(t);
            const submitted = t.my_score !== null && t.my_score !== undefined;
            return (
              <Card key={t._id} className="rounded-2xl border-slate-200 p-6 relative overflow-hidden" data-testid={`test-card-${t._id}`}>
                <div className="flex items-start justify-between">
                  <div>
                    <div className="flex items-center gap-2">
                      <Badge variant={t.test_type === "final" ? "default" : "secondary"} className={t.test_type === "final" ? "bg-[#7C3AED]" : "bg-slate-100 text-[#0F1B4C]"}>
                        {t.test_type.toUpperCase()}
                      </Badge>
                      {t.premium_only && <Badge className="bg-amber-500">PREMIUM</Badge>}
                      {live && !submitted && <Badge className="bg-green-600 animate-pulse">LIVE NOW</Badge>}
                    </div>
                    <h3 className="mt-3 font-serif text-xl text-[#0F1B4C] font-semibold">{t.title}</h3>
                    {t.description && <p className="text-sm text-[#64748B] mt-1">{t.description}</p>}
                  </div>
                  {t.locked && <Lock className="text-slate-400" />}
                </div>

                <div className="mt-4 flex flex-wrap gap-4 text-sm text-[#475569]">
                  <div className="flex items-center gap-1.5"><Calendar size={14} className="text-[#2563EB]" /> {t.scheduled_date}</div>
                  <div className="flex items-center gap-1.5"><Clock size={14} className="text-[#2563EB]" /> {t.start_time}–{t.end_time} IST</div>
                  <div>Class {t.class_level}</div>
                  <div>{t.question_ids?.length || 0} qns</div>
                </div>

                {t.unlock_score_required !== null && t.unlock_score_required !== undefined && t.locked && (
                  <div className="mt-3 text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-2">
                    Requires ≥ {t.unlock_score_required}% on prerequisite test.
                  </div>
                )}

                <div className="mt-5 flex items-center justify-between">
                  {submitted ? (
                    <>
                      <div className="text-sm">
                        <span className="text-[#64748B]">Your score:</span>{" "}
                        <span className="font-mono text-[#0F1B4C] font-semibold">{t.my_score}</span>
                      </div>
                      <Link to={`/tests/${t._id}/result`}>
                        <Button variant="outline" className="rounded-full" data-testid={`view-result-${t._id}`}>View result</Button>
                      </Link>
                    </>
                  ) : t.locked ? (
                    <div className="text-sm text-slate-500 italic">Locked</div>
                  ) : live ? (
                    <Link to={`/tests/${t._id}/live`}>
                      <Button data-testid={`start-test-${t._id}`} className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]">
                        Start now <ArrowRight size={16} className="ml-1" />
                      </Button>
                    </Link>
                  ) : past ? (
                    <div className="text-sm text-slate-500 italic">Window ended</div>
                  ) : (
                    <div className="text-sm text-[#2563EB] font-medium">Opens {t.scheduled_date} · {t.start_time} IST</div>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
