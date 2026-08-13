import React, { useEffect, useState } from "react";
import api from "@/lib/api";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { LineChart, Line, XAxis, YAxis, ResponsiveContainer, Tooltip, BarChart, Bar, CartesianGrid, Cell } from "recharts";
import BackButton from "@/components/BackButton";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Activity, Trophy, Target, TrendingUp, ArrowLeft } from "lucide-react";

const COLORS = ["#2563EB", "#7C3AED", "#0F1B4C", "#8B5CF6", "#3B82F6", "#A78BFA"];

export default function AdminAnalytics() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [step, setStep] = useState(1);
  const [weekly, setWeekly] = useState([]);
  const [topics, setTopics] = useState([]);
  const [tests, setTests] = useState([]);

  useEffect(() => {
    (async () => {
      const params = {};
      if (activeClass !== "all") params.class_level = activeClass;
      const [w, t, s] = await Promise.all([
        api.get("/api/admin/analytics/weekly", { params }),
        api.get("/api/admin/analytics/topics", { params }),
        api.get("/api/admin/analytics/tests", { params }),
      ]);
      setWeekly((w.data.items || []).map((x) => ({ ...x, day: x.date.slice(5) })));
      setTopics((t.data.items || []).slice(0, 10));
      setTests(s.data.items || []);
    })();
  }, [activeClass]);

  const handleSelectClass = (cls) => {
    setActiveClass(cls);
    setStep(2);
  };

  const classesList = [
    { id: "all", label: "All Classes", desc: "View platform performance and attempt data across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Grade 8 student performance analytics and test attempts", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Grade 9 student performance analytics and test attempts", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Grade 10 student performance analytics and test attempts", tone: "bg-amber-50 text-amber-700 border-amber-200" },
  ];

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
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
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Analytics — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to inspect student performance and test analytics.</p>

          <div className="mt-8 grid sm:grid-cols-2 gap-5">
            {classesList.map((c) => (
              <Card
                key={c.id}
                onClick={() => handleSelectClass(c.id)}
                className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
              >
                <div className="flex items-start justify-between">
                  <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                    <Activity size={24} />
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
                  <span>View Analytics</span>
                  <TrendingUp size={16} className="group-hover:translate-x-1 transition-transform" />
                </div>
              </Card>
            ))}
          </div>
        </div>
      ) : (
        <div>
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Analytics</div>
              <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
                {activeClass === "all" ? "All Classes Analytics" : `Class ${activeClass} Analytics`}
              </h1>
              <p className="mt-1 text-[#64748B]">Live performance data for {activeClass === "all" ? "all learners" : `Class ${activeClass}`}.</p>
            </div>
          </div>

      <div className="mt-8 grid lg:grid-cols-2 gap-6">
        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}>
          <Card className="rounded-2xl border-slate-200 p-6">
            <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#2563EB] font-semibold">
              <Activity size={14} /> Last 14 days
            </div>
            <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Attempts & new sign-ups</h2>
            <div className="mt-6 h-64" data-testid="chart-weekly">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={weekly}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                  <XAxis dataKey="day" stroke="#64748B" fontSize={11} />
                  <YAxis stroke="#64748B" fontSize={11} allowDecimals={false} />
                  <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0", fontSize: 12 }} />
                  <Line type="monotone" dataKey="attempts" stroke="#2563EB" strokeWidth={2.5} dot={{ r: 3 }} name="Attempts" />
                  <Line type="monotone" dataKey="registrations" stroke="#7C3AED" strokeWidth={2.5} dot={{ r: 3 }} name="Sign-ups" />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </Card>
        </motion.div>

        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }}>
          <Card className="rounded-2xl border-slate-200 p-6">
            <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">
              <Target size={14} /> Topic performance
            </div>
            <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Pass rate by topic</h2>
            <div className="mt-6 h-64" data-testid="chart-topics">
              {topics.length === 0 ? (
                <div className="text-sm text-[#64748B] py-16 text-center">No topic data yet — students need to attempt tests first.</div>
              ) : (
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={topics}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#E2E8F0" />
                    <XAxis dataKey="topic" stroke="#64748B" fontSize={10} angle={-15} textAnchor="end" height={60} />
                    <YAxis stroke="#64748B" fontSize={11} unit="%" />
                    <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid #E2E8F0", fontSize: 12 }} formatter={(v) => `${v}%`} />
                    <Bar dataKey="pass_rate" radius={[8, 8, 0, 0]}>
                      {topics.map((_, i) => (<Cell key={i} fill={COLORS[i % COLORS.length]} />))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              )}
            </div>
          </Card>
        </motion.div>
      </div>

      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="mt-6">
        <Card className="rounded-2xl border-slate-200 p-6">
          <div className="flex items-center gap-2 text-xs tracking-widest uppercase text-[#2563EB] font-semibold">
            <Trophy size={14} /> Recent tests
          </div>
          <h2 className="mt-1 font-serif text-2xl text-[#0F1B4C]">Average performance</h2>
          <div className="mt-5 divide-y divide-slate-100">
            {tests.length === 0 && <div className="py-8 text-center text-[#64748B]">No published tests yet.</div>}
            {tests.map((t, i) => (
              <div key={i} className="py-3 flex items-center justify-between gap-4" data-testid={`test-row-${i}`}>
                <div>
                  <div className="font-medium text-[#0F1B4C]">{t.title}</div>
                  <div className="text-xs text-[#64748B]">Class {t.class_level} · {t.attempts} attempts</div>
                </div>
                <div className="flex items-center gap-2">
                  <TrendingUp size={14} className="text-[#7C3AED]" />
                  <span className="font-mono text-[#0F1B4C] font-semibold">{t.avg_percent}%</span>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </motion.div>
      </div>
      )}
    </div>
  );
}
