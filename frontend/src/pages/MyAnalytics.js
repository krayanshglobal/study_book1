import React, { useEffect, useState, useMemo } from "react";
import api from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import BackButton from "@/components/BackButton";
import {
  RadialBarChart, RadialBar, PolarAngleAxis, ResponsiveContainer,
  BarChart, Bar, CartesianGrid, XAxis, YAxis, Tooltip, Cell, LineChart, Line,
} from "recharts";
import { Target, TrendingUp, Flame, Award, Lock, ChevronRight, Calendar, Zap, BookOpen, FileText } from "lucide-react";
import { useNavigate, useSearchParams } from "react-router-dom";

const GREEN = "#10B981", RED = "#EF4444";
const COLORS = ["#2563EB", "#7C3AED", "#0F1B4C", "#8B5CF6", "#3B82F6", "#A78BFA", "#60A5FA"];

function BadgeChip({ label, tone = "blue" }) {
  const map = {
    green: "bg-emerald-50 text-emerald-700 border-emerald-200",
    red: "bg-red-50 text-red-700 border-red-200",
    blue: "bg-[#2563EB]/10 text-[#2563EB] border-[#2563EB]/25",
    violet: "bg-[#7C3AED]/10 text-[#7C3AED] border-[#7C3AED]/25",
    amber: "bg-amber-50 text-amber-700 border-amber-200",
  };
  return <span className={`text-[11px] uppercase tracking-widest border px-2 py-0.5 rounded-full font-semibold ${map[tone]}`}>{label}</span>;
}

function HeatmapCell({ day }) {
  const q = day.questions;
  let bg = "bg-slate-100";
  if (q >= 10) bg = "bg-blue-700";
  else if (q >= 7) bg = "bg-blue-500";
  else if (q >= 4) bg = "bg-blue-400";
  else if (q >= 1) bg = "bg-blue-200";
  const label = day.date?.slice(5);
  return (
    <div className="relative group">
      <div className={`w-7 h-7 rounded-md ${bg} cursor-default transition-transform group-hover:scale-110`} />
      <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 hidden group-hover:flex flex-col items-center z-10 pointer-events-none">
        <div className="bg-[#0F1B4C] text-white text-[10px] rounded-lg px-2 py-1 whitespace-nowrap shadow-lg">
          {label}: {q} Q · {day.accuracy}%
        </div>
      </div>
    </div>
  );
}

export default function MyAnalytics() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();

  const [data, setData] = useState(null);
  const [monthly, setMonthly] = useState(null);
  const [selectedTestId, setSelectedTestId] = useState("all");

  const isPremium = user?.role === "admin" || user?.role === "superadmin" || user?.subscription_active;

  // Support ?tab=test or ?tab=month
  const urlTab = searchParams.get("tab");
  const [tab, setTab] = useState(urlTab === "month" ? "month" : "test");

  useEffect(() => {
    if (urlTab === "test" || urlTab === "month") setTab(urlTab);
  }, [urlTab]);

  useEffect(() => {
    api.get("/api/students/me/analytics").then(r => setData(r.data)).catch(() => {});
    api.get("/api/students/me/monthly-analysis").then(r => setMonthly(r.data)).catch(() => {});
  }, []);

  const mockData = {
    overall_accuracy: 72, total_attempts: 12,
    recent_scores: [
      { date: "07/12", percent: 60, title: "Mock Test 1" },
      { date: "07/13", percent: 80, title: "Mock Test 2" },
      { date: "07/15", percent: 75, title: "Final Test 1" },
    ],
    history: [
      { test_id: "t1", title: "Mock Test 1", score: 30, total_marks: 50, percent: 60, date: "07/12" },
      { test_id: "t2", title: "Mock Test 2", score: 40, total_marks: 50, percent: 80, date: "07/13" },
      { test_id: "t3", title: "Final Test 1", score: 75, total_marks: 100, percent: 75, date: "07/15" },
    ],
    strengths: [{ topic: "Algebra", accuracy: 85 }],
    weaknesses: [{ topic: "Geometry", accuracy: 48 }],
    topics: [
      { topic: "Algebra", accuracy: 85 }, { topic: "Geometry", accuracy: 48 },
      { topic: "Trigonometry", accuracy: 64 },
    ],
  };

  const activeData = isPremium ? data : mockData;
  if (!activeData) return <div className="max-w-6xl mx-auto px-6 py-16 text-[#64748B]">Loading…</div>;

  // Filter test analytics by selected test
  const selectedTestObj = selectedTestId !== "all"
    ? (activeData.history || []).find(t => t.test_id === selectedTestId || t.title === selectedTestId)
    : null;

  const displayAccuracy = selectedTestObj ? selectedTestObj.percent : (activeData.overall_accuracy || 0);
  const gaugeData = [{ name: "acc", value: displayAccuracy, fill: displayAccuracy >= 75 ? GREEN : displayAccuracy >= 50 ? "#7C3AED" : RED }];

  const switchTab = (tId) => {
    setTab(tId);
    setSearchParams({ tab: tId });
  };

  const tabs = [
    { id: "test", label: "Test Analytics", icon: FileText },
    { id: "month", label: "Last 30 Days Daily Questions", icon: Calendar },
  ];

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10 relative">
      <div className={!isPremium ? "filter blur-md pointer-events-none select-none" : ""}>
        <BackButton to="/dashboard" label="Dashboard" className="mb-6" />

        {/* Header */}
        <div className="flex items-start justify-between gap-4 flex-wrap">
          <div>
            <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Your journey</div>
            <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
              Hey {user?.name?.split(" ")[0] || "Student"}, here&apos;s your analysis
            </h1>
          </div>
          <div className="flex items-center gap-2 flex-wrap">
            <BadgeChip label={`${activeData.total_attempts} tests taken`} tone="blue" />
            {monthly?.streak > 0 && <BadgeChip label={`🔥 ${monthly.streak} day streak`} tone="amber" />}
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="mt-6 flex items-center gap-2 flex-wrap">
          {tabs.map(t => (
            <button
              key={t.id}
              onClick={() => switchTab(t.id)}
              className={`flex items-center gap-2 px-5 py-2.5 rounded-full text-sm font-semibold transition-all cursor-pointer ${
                tab === t.id
                  ? "bg-[#0F1B4C] text-white shadow-md"
                  : "bg-white text-slate-600 border border-slate-200 hover:border-[#2563EB]"
              }`}
            >
              <t.icon size={15} /> {t.label}
            </button>
          ))}
        </div>

        {/* ── 1. TEST ANALYTICS TAB ── */}
        {tab === "test" && (
          <div className="mt-6 space-y-6">
            
            {/* Select Test Filter Dropdown */}
            <div className="flex items-center justify-between gap-4 flex-wrap bg-white p-4 rounded-2xl border border-slate-200">
              <div className="flex items-center gap-2">
                <FileText size={18} className="text-[#2563EB]" />
                <span className="text-sm font-semibold text-[#0F1B4C]">Select Test to Analyze:</span>
              </div>
              <Select value={selectedTestId} onValueChange={setSelectedTestId}>
                <SelectTrigger className="w-64 rounded-full bg-white font-semibold text-xs border-slate-300">
                  <SelectValue placeholder="All Tests (Overall)" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">📊 All Tests (Overall Summary)</SelectItem>
                  {(activeData.history || []).map((t, idx) => (
                    <SelectItem key={t.test_id || idx} value={t.test_id || t.title}>
                      📝 {t.title} ({t.percent}%)
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="grid md:grid-cols-3 gap-5">
              {/* Accuracy Gauge */}
              <div className="md:col-span-1">
                <Card className="rounded-2xl border-slate-200 p-6 h-full bg-white">
                  <div className="text-xs tracking-widest uppercase text-[#2563EB] font-semibold">
                    {selectedTestObj ? selectedTestObj.title : "Overall Test Accuracy"}
                  </div>
                  <div className="relative h-52 mt-3" data-testid="gauge-accuracy">
                    <ResponsiveContainer width="100%" height="100%">
                      <RadialBarChart innerRadius="70%" outerRadius="100%" data={gaugeData} startAngle={220} endAngle={-40}>
                        <PolarAngleAxis type="number" domain={[0, 100]} tick={false} />
                        <RadialBar dataKey="value" cornerRadius={16} background={{ fill: "#F1F5F9" }} />
                      </RadialBarChart>
                    </ResponsiveContainer>
                    <div className="absolute inset-0 grid place-items-center pointer-events-none">
                      <div className="text-center">
                        <div className="font-serif text-5xl text-[#0F1B4C] font-semibold">{displayAccuracy}%</div>
                        <div className="text-xs uppercase tracking-widest text-[#64748B]">Score / Acc</div>
                      </div>
                    </div>
                  </div>
                </Card>
              </div>

              {/* Score Trend Chart */}
              <div className="md:col-span-2">
                <Card className="rounded-2xl border-slate-200 p-6 h-full bg-white">
                  <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">
                    <TrendingUp size={14} /> Performance History
                  </div>
                  <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Test Score Trend</h2>
                  <div className="mt-5 h-48" data-testid="chart-recent">
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart data={(activeData.recent_scores || []).map((s, i) => ({ ...s, x: i + 1 }))}>
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

            {/* Strengths & Weaknesses in Tests */}
            <div className="grid md:grid-cols-2 gap-5">
              <Card className="rounded-2xl border-slate-200 p-6 bg-white">
                <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-emerald-700 font-semibold">
                  <Award size={14} /> Strong Topics in Tests
                </div>
                <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Strengths</h2>
                <div className="mt-4 space-y-3">
                  {(activeData.strengths || []).map((s) => (
                    <div key={s.topic} className="flex items-center gap-3">
                      <span className="text-sm font-medium text-[#0F1B4C] w-36 truncate">{s.topic}</span>
                      <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
                        <div className="h-full bg-emerald-500 rounded-full" style={{ width: `${s.accuracy}%` }} />
                      </div>
                      <span className="font-mono text-xs font-bold text-emerald-700">{s.accuracy}%</span>
                    </div>
                  ))}
                </div>
              </Card>

              <Card className="rounded-2xl border-slate-200 p-6 bg-white">
                <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-red-600 font-semibold">
                  <Target size={14} /> Needs Practice
                </div>
                <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Weaknesses</h2>
                <div className="mt-4 space-y-3">
                  {(activeData.weaknesses || []).map((w) => (
                    <div key={w.topic} className="flex items-center gap-3">
                      <span className="text-sm font-medium text-[#0F1B4C] w-36 truncate">{w.topic}</span>
                      <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden">
                        <div className="h-full bg-red-500 rounded-full" style={{ width: `${w.accuracy}%` }} />
                      </div>
                      <span className="font-mono text-xs font-bold text-red-600">{w.accuracy}%</span>
                    </div>
                  ))}
                </div>
              </Card>
            </div>

          </div>
        )}

        {/* ── 2. LAST 30 DAYS DAILY QUESTIONS TAB ── */}
        {tab === "month" && (
          <div className="mt-6 space-y-5">
            {/* Stat Cards */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { label: "Questions Solved", value: monthly?.total_questions ?? 0, icon: BookOpen, color: "text-blue-600", bg: "bg-blue-50" },
                { label: "Daily Accuracy", value: `${monthly?.overall_accuracy ?? 0}%`, icon: Target, color: "text-emerald-600", bg: "bg-emerald-50" },
                { label: "Daily Streak", value: `${monthly?.streak ?? 0} days`, icon: Flame, color: "text-amber-600", bg: "bg-amber-50" },
                { label: "Best Day", value: monthly?.best_day?.questions ? `${monthly.best_day.questions} Q` : "–", icon: Zap, color: "text-violet-600", bg: "bg-violet-50" },
              ].map(({ label, value, icon: Icon, color, bg }) => (
                <Card key={label} className="p-4 rounded-2xl border-0 shadow-sm bg-white">
                  <div className={`w-9 h-9 rounded-xl ${bg} flex items-center justify-center mb-2`}>
                    <Icon size={18} className={color} />
                  </div>
                  <div className={`text-xl font-bold ${color}`}>{value}</div>
                  <div className="text-xs text-slate-500 mt-0.5">{label} this month</div>
                </Card>
              ))}
            </div>

            {/* Heatmap */}
            <Card className="p-6 rounded-2xl border-0 shadow-sm bg-white">
              <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#2563EB] font-semibold mb-4">
                <Calendar size={14} /> 30-Day Activity Heatmap (Daily Questions)
              </div>
              <div className="flex flex-wrap gap-1.5">
                {(monthly?.daily || []).map((day) => (
                  <HeatmapCell key={day.date} day={day} />
                ))}
              </div>
              <div className="flex items-center gap-2 mt-4 text-xs text-slate-400">
                <span>Less</span>
                {["bg-slate-100", "bg-blue-200", "bg-blue-400", "bg-blue-500", "bg-blue-700"].map((c, i) => (
                  <div key={i} className={`w-4 h-4 rounded ${c}`} />
                ))}
                <span>More</span>
              </div>
            </Card>

            {/* Daily Bar Chart */}
            <Card className="p-6 rounded-2xl border-0 shadow-sm bg-white">
              <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#7C3AED] font-semibold mb-1">
                <TrendingUp size={14} /> Daily Questions
              </div>
              <h2 className="font-serif text-xl text-[#0F1B4C] mb-4">Questions answered per day</h2>
              <div className="h-44">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={(monthly?.daily || []).map((d) => ({ ...d, label: d.date?.slice(5) }))}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#F1F5F9" />
                    <XAxis dataKey="label" stroke="#94A3B8" fontSize={9} interval={2} />
                    <YAxis stroke="#94A3B8" fontSize={10} allowDecimals={false} />
                    <Tooltip
                      contentStyle={{ borderRadius: 12, border: "0", boxShadow: "0 10px 25px -5px rgba(0,0,0,0.1)", fontSize: 12 }}
                      formatter={(val, name) => [name === "questions" ? `${val} questions` : `${val}%`, name === "questions" ? "Answered" : "Accuracy"]}
                    />
                    <Bar dataKey="questions" fill="#2563EB" radius={[4, 4, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </Card>

            {/* Topic Breakdown */}
            {(monthly?.topics || []).length > 0 && (
              <Card className="p-6 rounded-2xl border-0 shadow-sm bg-white">
                <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-emerald-700 font-semibold mb-1">
                  <BookOpen size={14} /> Chapter Breakdown
                </div>
                <h2 className="font-serif text-xl text-[#0F1B4C] mb-4">Daily Questions Accuracy by Topic</h2>
                <div className="space-y-3">
                  {(monthly.topics || []).map((t, i) => (
                    <div key={t.topic} className="flex items-center justify-between text-xs">
                      <div className="flex items-center gap-2 w-44 truncate">
                        <div className="w-2.5 h-2.5 rounded-full shrink-0" style={{ backgroundColor: COLORS[i % COLORS.length] }} />
                        <span className="font-medium text-slate-700 truncate">{t.topic}</span>
                      </div>
                      <div className="flex-1 max-w-xs mx-4">
                        <div className="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all duration-500"
                            style={{ width: `${t.accuracy}%`, backgroundColor: COLORS[i % COLORS.length] }}
                          />
                        </div>
                      </div>
                      <div className="flex items-center gap-3 font-mono">
                        <span className="text-slate-400">{t.questions} Q</span>
                        <span className="font-bold text-slate-800 w-10 text-right">{t.accuracy}%</span>
                      </div>
                    </div>
                  ))}
                </div>
              </Card>
            )}
          </div>
        )}

      </div>
    </div>
  );
}
