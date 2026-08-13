import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { toast } from "sonner";
import { Share2, ArrowLeft, Trophy, RefreshCw } from "lucide-react";

export default function AdminReferrals() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [step, setStep] = useState(1);
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const r = await api.get("/api/admin/referrals", { params: { class_level: activeClass } });
      setItems(r.data.items || []);
    } catch (err) {
      toast.error("Failed to load referral rankings.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [activeClass]);

  const handleSelectClass = (cls) => {
    setActiveClass(cls);
    setStep(2);
  };

  const classesList = [
    { id: "all", label: "All Classes", desc: "View top referrer student rankings across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Grade 8 student referral performance and invitation ranks", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Grade 9 student referral performance and invitation ranks", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Grade 10 student referral performance and invitation ranks", tone: "bg-[#7C3AED]/10 text-[#7C3AED] border-[#7C3AED]/20" },
  ];

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <div className="flex items-center justify-between gap-4 mb-6">
        <BackButton to="/admin" label="Admin dashboard" />
        {step === 2 && (
          <Button
            onClick={() => setStep(1)}
            variant="outline"
            className="rounded-full border-[#7C3AED]/30 bg-purple-50/60 hover:bg-purple-100/80 text-[#7C3AED] font-semibold text-sm h-10 px-5 shadow-sm transition-all flex items-center gap-2"
          >
            <ArrowLeft size={16} />
            <span>Change Class ({activeClass === "all" ? "All Classes" : `Class ${activeClass}`})</span>
          </Button>
        )}
      </div>

      {step === 1 ? (
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Step 1 of 2</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Top Referrals — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to inspect top student invite ranks &amp; conversion stats.</p>

          <div className="mt-8 grid sm:grid-cols-2 gap-5">
            {classesList.map((c) => (
              <Card
                key={c.id}
                onClick={() => handleSelectClass(c.id)}
                className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
              >
                <div className="flex items-start justify-between">
                  <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                    <Share2 size={24} />
                  </div>
                  {activeClass === c.id && (
                    <Badge className="bg-[#7C3AED] text-white text-[10px]">Selected</Badge>
                  )}
                </div>

                <div className="mt-6">
                  <h3 className="font-serif text-2xl text-[#0F1B4C] font-semibold group-hover:text-[#7C3AED] transition-colors">{c.label}</h3>
                  <p className="text-xs text-[#64748B] mt-1 leading-relaxed">{c.desc}</p>
                </div>

                <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between text-xs font-semibold text-[#7C3AED]">
                  <span>View Referral Leaderboard</span>
                  <Trophy size={16} className="group-hover:translate-x-1 transition-transform" />
                </div>
              </Card>
            ))}
          </div>
        </div>
      ) : (
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Referral Analytics</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
            {activeClass === "all" ? "All Top Referrers" : `Class ${activeClass} Top Referrers`}
          </h1>

          {loading ? (
            <div className="mt-16 text-center text-[#64748B]">
              <RefreshCw size={20} className="animate-spin mx-auto mb-2" /> Loading referral rankings…
            </div>
          ) : items.length === 0 ? (
            <div className="mt-16 text-center text-[#64748B] bg-slate-50 p-10 rounded-2xl border border-slate-200">
              No referral data found for Class {activeClass}.
            </div>
          ) : (
            <div className="mt-8 space-y-4">
              <div className="grid sm:grid-cols-3 gap-4">
                <Card className="p-5 rounded-2xl border-slate-200 bg-purple-50/40">
                  <div className="text-xs text-purple-600 uppercase tracking-widest font-bold">Total Top Referrers</div>
                  <div className="font-serif text-3xl font-semibold text-[#0F1B4C] mt-2">{items.length}</div>
                </Card>
                <Card className="p-5 rounded-2xl border-slate-200 bg-blue-50/40">
                  <div className="text-xs text-blue-600 uppercase tracking-widest font-bold">Total Invites Sent</div>
                  <div className="font-serif text-3xl font-semibold text-[#0F1B4C] mt-2">
                    {items.reduce((acc, x) => acc + (x.total_referred || 0), 0)}
                  </div>
                </Card>
                <Card className="p-5 rounded-2xl border-slate-200 bg-emerald-50/40">
                  <div className="text-xs text-emerald-700 uppercase tracking-widest font-bold">Subscribed Conversions</div>
                  <div className="font-serif text-3xl font-semibold text-[#0F1B4C] mt-2">
                    {items.reduce((acc, x) => acc + (x.converted || 0), 0)}
                  </div>
                </Card>
              </div>

              <div className="mt-6 rounded-2xl border border-slate-200 overflow-hidden bg-white shadow-sm">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-50 border-b border-slate-200 text-xs font-bold text-[#64748B] uppercase tracking-wider">
                      <th className="py-3.5 px-4">Rank</th>
                      <th className="py-3.5 px-4">Student Name</th>
                      <th className="py-3.5 px-4">Class</th>
                      <th className="py-3.5 px-4">Student ID</th>
                      <th className="py-3.5 px-4">Code</th>
                      <th className="py-3.5 px-4 text-center">Invites</th>
                      <th className="py-3.5 px-4 text-center">Converted</th>
                      <th className="py-3.5 px-4 text-right">Conv. Rate</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 text-sm">
                    {items.map((r, idx) => (
                      <tr key={r.referrer_id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 px-4 font-bold text-[#0F1B4C]">
                          {idx === 0 ? "🥇 #1" : idx === 1 ? "🥈 #2" : idx === 2 ? "🥉 #3" : `#${idx + 1}`}
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="font-medium text-[#0F1B4C]">{r.name}</div>
                          <div className="text-xs text-[#64748B]">{r.email}</div>
                        </td>
                        <td className="py-3.5 px-4 font-semibold text-[#7C3AED]">
                          Class {r.class_level}
                        </td>
                        <td className="py-3.5 px-4 font-mono text-xs font-semibold text-[#2563EB]">
                          {r.student_id || "N/A"}
                        </td>
                        <td className="py-3.5 px-4 font-mono text-xs font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-md inline-block my-2">
                          {r.referral_code || "N/A"}
                        </td>
                        <td className="py-3.5 px-4 text-center font-bold text-[#0F1B4C]">
                          {r.total_referred}
                        </td>
                        <td className="py-3.5 px-4 text-center font-bold text-emerald-600">
                          {r.converted}
                        </td>
                        <td className="py-3.5 px-4 text-right font-semibold text-[#7C3AED]">
                          {r.conversion_pct}%
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
