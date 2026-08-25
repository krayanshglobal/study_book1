import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Check, Sparkles } from "lucide-react";
import { toast } from "sonner";
import { useAuth } from "@/contexts/AuthContext";
import { inr } from "@/lib/format";

export default function Pricing() {
  const { user, refresh } = useAuth();
  const [plans, setPlans] = useState([]);
  const [busy, setBusy] = useState(null);

  useEffect(() => { (async () => { const r = await api.get("/api/plans"); setPlans(r.data.items || []); })(); }, []);

  const subscribe = async (plan) => {
    setBusy(plan._id);
    try {
      const r = await api.post("/api/payments/checkout", {
        plan_id: plan._id,
        origin_url: window.location.origin,
      });
      window.location.href = r.data.url;
    } catch (err) {
      toast.error(formatApiError(err));
      setBusy(null);
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Membership</div>
      <h1 className="mt-2 font-serif text-4xl sm:text-5xl text-[#0F1B4C] font-semibold">Choose your plan</h1>
      <p className="mt-2 text-[#64748B]">Your admin sets what&apos;s free and what&apos;s premium. Upgrade anytime.</p>

      {user?.subscription_active && (
        <div className="mt-6 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-700">
          You&apos;re premium! Expires {user.subscription_expires_at?.slice(0, 10) || "soon"}.
        </div>
      )}

      <div className="mt-10 grid md:grid-cols-3 gap-6">
        {plans.map((p, i) => (
          <Card key={p._id} className={`rounded-2xl p-8 border-slate-200 relative overflow-hidden ${i === 1 ? "ring-2 ring-[#7C3AED]" : ""}`} data-testid={`plan-card-${p._id}`}>
            {i === 1 && (
              <div className="absolute top-4 right-4 flex items-center gap-1 text-xs bg-[#7C3AED] text-white px-2 py-1 rounded-full">
                <Sparkles size={12} /> Popular
              </div>
            )}
            <div className="text-xs tracking-widest uppercase text-[#2563EB] font-semibold">{p.duration_days} days</div>
            <h3 className="mt-2 font-serif text-2xl text-[#0F1B4C] font-semibold">{p.name}</h3>
            <div className="mt-4 flex items-baseline gap-1">
              <span className="font-serif text-5xl text-[#0F1B4C] font-semibold">{inr(p.price)}</span>
              <span className="text-sm text-[#64748B]">/plan</span>
            </div>
            <p className="mt-3 text-sm text-[#64748B]">{p.description}</p>
            <ul className="mt-6 space-y-2">
              {p.features?.map((f, k) => (
                <li key={k} className="flex items-start gap-2 text-sm text-[#334155]">
                  <Check className="text-[#2563EB] mt-0.5 shrink-0" size={16} /> {f}
                </li>
              ))}
            </ul>
            <Button
              onClick={() => subscribe(p)}
              disabled={busy === p._id || user?.subscription_active}
              data-testid={`plan-subscribe-${p._id}`}
              className={`mt-8 w-full rounded-full py-6 ${i === 1 ? "bg-[#7C3AED] hover:bg-[#6D28D9]" : "bg-[#0F1B4C] hover:bg-[#2563EB]"}`}
            >
              {user?.subscription_active ? "Already premium" : busy === p._id ? "Redirecting…" : "Subscribe"}
            </Button>
          </Card>
        ))}
      </div>
    </div>
  );
}
