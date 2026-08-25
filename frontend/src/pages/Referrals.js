import React, { useEffect, useState } from "react";
import api from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Copy, Users, Share2 } from "lucide-react";
import { toast } from "sonner";

export default function Referrals() {
  const [data, setData] = useState(null);
  useEffect(() => { (async () => { const r = await api.get("/api/referrals/me"); setData(r.data); })(); }, []);

  const copy = () => {
    if (!data?.referral_code) return;
    const link = `${window.location.origin}/register?ref=${data.referral_code}`;
    navigator.clipboard.writeText(link);
    toast.success("Referral link copied!");
  };

  return (
    <div className="max-w-3xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Grow together</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Referrals</h1>
      <p className="mt-1 text-[#64748B]">Every friend you bring boosts your rank and unlocks bonus features.</p>

      <Card className="mt-8 rounded-2xl border-slate-200 p-8 relative overflow-hidden">
        <div className="absolute -right-8 -top-8 w-40 h-40 bg-[#7C3AED]/10 rounded-full blur-3xl" />
        <div className="relative">
          <div className="text-xs tracking-widest uppercase text-[#64748B] font-semibold">Your code</div>
          <div className="mt-2 font-mono text-5xl font-bold text-[#0F1B4C]" data-testid="referral-code-display">{data?.referral_code || "…"}</div>
          <div className="mt-6 flex flex-wrap gap-3">
            <Button onClick={copy} data-testid="referral-copy-btn" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">
              <Copy size={16} className="mr-2" /> Copy referral link
            </Button>
            <Button variant="outline" onClick={() => navigator.share?.({ title: "Join StudyBook", url: `${window.location.origin}/register?ref=${data?.referral_code}` })} className="rounded-full">
              <Share2 size={16} className="mr-2" /> Share
            </Button>
          </div>
        </div>
      </Card>

      <Card className="mt-6 rounded-2xl border-slate-200 p-8">
        <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#2563EB] font-semibold">
          <Users size={14} /> Friends joined ({data?.count ?? 0})
        </div>
        <div className="mt-4 space-y-2">
          {(data?.referrals || []).length === 0 && <div className="text-sm text-[#64748B]">No referrals yet. Share your code!</div>}
          {data?.referrals?.map((r, i) => (
            <div key={i} className="flex items-center justify-between border-b border-slate-100 py-2 last:border-b-0">
              <div className="text-[#0F1B4C]">{r.name}</div>
              <div className="text-xs text-[#64748B] font-mono">{r.joined_at?.slice(0, 10)}</div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}
