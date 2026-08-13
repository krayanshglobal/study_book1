import React, { useEffect, useState } from "react";
import api from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import BackButton from "@/components/BackButton";
import { motion } from "framer-motion";
import {
  RadialBarChart, RadialBar, PolarAngleAxis, ResponsiveContainer,
  BarChart, Bar, CartesianGrid, XAxis, YAxis, Tooltip, Cell, LineChart, Line,
} from "recharts";
import { Sparkles, Target, TrendingUp, Flame, Award, Lock, ChevronRight } from "lucide-react";

const GREEN = "#10B981", RED = "#EF4444", GRAY = "#94A3B8";
const COLORS = ["#2563EB", "#7C3AED", "#0F1B4C", "#8B5CF6", "#3B82F6", "#A78BFA", "#60A5FA"];

function BadgeChip({ label, tone = "blue" }) {
  const map = {
    green: "bg-emerald-50 text-emerald-700 border-emerald-200",
    red: "bg-red-50 text-red-700 border-red-200",
    blue: "bg-[#2563EB]/10 text-[#2563EB] border-[#2563EB]/25",
    violet: "bg-[#7C3AED]/10 text-[#7C3AED] border-[#7C3AED]/25",
  };
  return <span className={`text-[11px] uppercase tracking-widest border px-2 py-0.5 rounded-full font-semibold ${map[tone]}`}>{label}</span>;
}

export default function MyAnalytics() {
  const { user } = useAuth();
  const [data, setData] = useState(null);
  const isPremium = user?.role in { admin: 1, superadmin: 1 } || user?.subscription_active;

  useEffect(() => {
    (async () => {
      try {
        const r = await api.get("/api/students/me/analytics");
        setData(r.data);
      } catch {}
    })();
  }, []);

  // Standard mock data to render blurred in the background if not premium
  const mockData = {
    overall_accuracy: 72,
    total_attempts: 12,
    total_points: 350,
    recent_scores: [
      { date: "07/12", percent: 60 },
      { date: "07/13", percent: 80 },
      { date: "07/15", percent: 75 },
      { date: "07/18", percent: 72 },
    ],
    strengths: [{ topic: "Algebra", accuracy: 85 }],
    weaknesses: [{ topic: "Geometry", accuracy: 48 }],
    topics: [
      { topic: "Algebra", accuracy: 85 },
      { topic: "Geometry", accuracy: 48 },
      { topic: "Trigonometry", accuracy: 64 },
    ],
  };

  const activeData = isPremium ? data : mockData;

  if (!activeData) return <div className="max-w-6xl mx-auto px-6 py-16 text-[#64748B]">Loading…</div>;

  const overall = activeData.overall_accuracy || 0;
  const gaugeData = [{ name: "acc", value: overall, fill: overall >= 75 ? GREEN : overall >= 50 ? "#7C3AED" : RED }];

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10 relative">
      {/* Blurred background content layout if free tier */}
      <div className={!isPremium ? "filter blur-md pointer-events-none select-none" : ""}>
        <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Your journey</div>
            <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
              Hey {user?.name?.split(" ")[0] || "Student"}, here&apos;s how you&apos;re doing
            </h1>
          </div>
          <div className="flex items-center gap-2">
            <BadgeChip label={`${activeData.total_attempts} tests taken`} tone="blue" />
            <BadgeChip label={`${activeData.total_points} points`} tone="violet" />
          </div>
        </div>

        {/* Overall gauge + streak card */}
        <div className="mt-8 grid md:grid-cols-3 gap-5">
          <div className="md:col-span-1">
            <Card className="rounded-2xl border-slate-200 p-6 h-full bg-white">
              <div className="text-xs tracking-widest uppercase text-[#2563EB] font-semibold">Overall accuracy</div>
              <div className="relative h-52 mt-3" data-testid="gauge-accuracy">
                <ResponsiveContainer width="100%" height="100%">
                  <RadialBarChart innerRadius="70%" outerRadius="100%" data={gaugeData} startAngle={220} endAngle={-40}>
                    <PolarAngleAxis type="number" domain={[0, 100]} tick={false} />
                    <RadialBar dataKey="value" cornerRadius={16} background={{ fill: "#F1F5F9" }} />
                  </RadialBarChart>
                </ResponsiveContainer>
                <div className="absolute inset-0 grid place-items-center pointer-events-none">
                  <div className="text-center">
                    <div className="font-serif text-5xl text-[#0F1B4C] font-semibold">{overall}%</div>
                    <div className="text-xs uppercase tracking-widest text-[#64748B]">accuracy</div>
                  </div>
                </div>
              </div>
            </Card>
          </div>

          <div className="md:col-span-2">
            <Card className="rounded-2xl border-slate-200 p-6 h-full bg-white">
              <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">
                <TrendingUp size={14} /> Recent tests
              </div>
              <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Score trend</h2>
              <div className="mt-5 h-48" data-testid="chart-recent">
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={activeData.recent_scores.map((s, i) => ({ ...s, x: i + 1 }))}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                    <XAxis dataKey="date" stroke="#64748B" fontSize={10} />
                    <YAxis stroke="#64748B" fontSize={11} unit="%" domain={[0, 100]} />
                    <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0", fontSize: 12 }} formatter={(v) => `${v}%`} />
                    <Line type="monotone" dataKey="percent" stroke="#7C3AED" strokeWidth={3} dot={{ r: 4, fill: "#7C3AED" }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </Card>
          </div>
        </div>

        {/* Strengths + weaknesses */}
        <div className="mt-6 grid md:grid-cols-2 gap-5">
          <div>
            <Card className="rounded-2xl border-slate-200 p-6 h-full bg-white">
              <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-emerald-700 font-semibold">
                <Award size={14} /> Your superpowers
              </div>
              <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Strengths</h2>
              <div className="mt-4 space-y-3" data-testid="strengths-list">
                {activeData.strengths.map((s) => (
                  <div key={s.topic} className="flex items-center gap-3">
                    <div className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                    <div className="flex-1 text-[#0F1B4C] font-medium">{s.topic}</div>
                    <div className="font-mono text-emerald-600 font-semibold">{s.accuracy}%</div>
                  </div>
                ))}
              </div>
            </Card>
          </div>

          <div>
            <Card className="rounded-2xl border-slate-200 p-6 h-full bg-white">
              <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-red-700 font-semibold">
                <Flame size={14} /> Focus zone
              </div>
              <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Weaknesses</h2>
              <div className="mt-4 space-y-3" data-testid="weaknesses-list">
                {activeData.weaknesses.map((w) => (
                  <div key={w.topic} className="flex items-center gap-3">
                    <div className="w-2.5 h-2.5 rounded-full bg-red-500" />
                    <div className="flex-1 text-[#0F1B4C] font-medium">{w.topic}</div>
                    <div className="font-mono text-red-600 font-semibold">{w.accuracy}%</div>
                  </div>
                ))}
              </div>
            </Card>
          </div>
        </div>

        {/* Full topic bar chart */}
        <div className="mt-6">
          <Card className="rounded-2xl border-slate-200 p-6 bg-white">
            <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#2563EB] font-semibold">
              <Target size={14} /> Every topic
            </div>
            <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Accuracy per topic</h2>
            <div className="mt-6 h-72" data-testid="chart-topic-accuracy">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={activeData.topics} margin={{ bottom: 20 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                  <XAxis dataKey="topic" stroke="#64748B" fontSize={10} angle={-15} textAnchor="end" height={60} />
                  <YAxis stroke="#64748B" fontSize={11} unit="%" domain={[0, 100]} />
                  <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0", fontSize: 12 }} formatter={(v) => `${v}%`} />
                  <Bar dataKey="accuracy" radius={[8, 8, 0, 0]}>
                    {activeData.topics.map((t, i) => (
                      <Cell key={i} fill={t.accuracy >= 70 ? GREEN : t.accuracy >= 50 ? COLORS[i % COLORS.length] : RED} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>
        </div>
      </div>

      {/* Floating Premium Gate Overlay if student is free tier */}
      {!isPremium && (
        <div className="absolute inset-0 bg-[#0F1B4C]/5 backdrop-blur-[2px] flex items-center justify-center p-6 z-30">
          <Card className="w-full max-w-md p-8 rounded-3xl border border-slate-200 shadow-2xl bg-white text-center flex flex-col justify-between items-center relative overflow-hidden">
            <div className="absolute -right-12 -top-12 w-32 h-32 rounded-full bg-gradient-to-tr from-[#7C3AED]/10 to-[#2563EB]/20 blur-xl pointer-events-none" />
            <div className="w-14 h-14 rounded-full bg-amber-100 text-amber-500 grid place-items-center mb-5 shadow-inner">
              <Lock size={24} />
            </div>
            
            <h2 className="font-serif text-2xl text-[#0F1B4C] font-semibold">Your Personalized Analysis</h2>
            <div className="text-xs uppercase font-bold tracking-widest text-[#7C3AED] bg-violet-50 px-3 py-1 rounded-full mt-2">
              Premium Subscription Required
            </div>

            <p className="text-slate-500 text-xs mt-4 leading-relaxed max-w-xs">
              Unlock a detailed breakdown of your learning accuracy, score trends across tests, and key weaknesses to target with priority revision exercises.
            </p>

            <div className="w-full space-y-3 mt-6 border-t border-slate-100 pt-5">
              {[
                "Average Accuracy Breakdown",
                "Performance Percentile comparison",
                "Mock tests score trend line",
                "Detailed strengths and weaknesses per chapter"
              ].map((item, idx) => (
                <div key={idx} className="flex items-center gap-2 text-left text-slate-600 text-xs">
                  <div className="w-1.5 h-1.5 rounded-full bg-amber-500 shrink-0" />
                  <span>{item}</span>
                </div>
              ))}
            </div>

            <div className="mt-8 w-full">
              <a href="/pricing" className="block w-full">
                <Button className="w-full rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-sm py-2.5 font-bold flex items-center justify-center gap-1">
                  Upgrade to StudyBook Premium <ChevronRight size={16} />
                </Button>
              </a>
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
