import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import api from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import { Trophy, Medal, Crown } from "lucide-react";
import { motion } from "framer-motion";
import { useAuth } from "@/contexts/AuthContext";

export default function Leaderboard() {
  const { user } = useAuth();
  
  // Set default class: students see their own class, admins see "all" by default
  const defaultClass = user?.role === "student" ? (user?.class_level || "8") : "all";
  const [classLevel, setClassLevel] = useState(defaultClass);
  const [selectedTestId, setSelectedTestId] = useState("total");
  const [tests, setTests] = useState([]);
  const [items, setItems] = useState([]);

  // Fetch tests to populate the test selector dropdown
  useEffect(() => {
    (async () => {
      const params = {};
      if (classLevel !== "all") {
        params.class_level = classLevel;
      }
      try {
        const r = await api.get("/api/tests", { params });
        setTests((r.data.items || []).filter((t) => t.is_published));
      } catch (err) {
        console.error("Failed to load tests", err);
      }
    })();
  }, [classLevel]);

  // Reset test selector when class changes
  useEffect(() => {
    setSelectedTestId("total");
  }, [classLevel]);

  // Fetch rankings
  useEffect(() => {
    (async () => {
      const params = { limit: 100 };
      if (classLevel !== "all") params.class_level = classLevel;
      if (selectedTestId !== "total") params.test_id = selectedTestId;
      try {
        const r = await api.get("/api/leaderboard", { params });
        setItems(r.data.items || []);
      } catch (err) {
        console.error("Failed to load rankings", err);
      }
    })();
  }, [classLevel, selectedTestId]);

  // Premium lock screen for students who are not premium
  if (user?.role === "student" && !user?.subscription_active) {
    return (
      <div className="max-w-md mx-auto px-6 py-20 text-center space-y-6">
        <div className="w-20 h-20 mx-auto rounded-3xl bg-amber-50 border border-amber-200 grid place-items-center text-amber-500 shadow-md">
          <Trophy size={40} className="animate-bounce" />
        </div>
        <h1 className="font-serif text-3xl text-[#0F1B4C] font-semibold">Premium Feature</h1>
        <p className="text-[#64748B] text-sm leading-relaxed">
          The leaderboard is exclusive to premium users. Upgrade your subscription today to see where you rank among your peers, compete in mock tests, and view detailed analysis!
        </p>
        <div className="pt-2">
          <Link to="/pricing">
            <Button className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] px-6 py-2">
              Upgrade to Premium
            </Button>
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Rankings</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Leaderboard</h1>
      <p className="mt-1 text-[#64748B]">
        {selectedTestId === "total"
          ? "Points accumulate across mock and final tests."
          : "Rankings and scores specifically for this test."}
      </p>

      <div className="mt-6 flex flex-wrap gap-4 items-center">
        {user?.role === "admin" && (
          <div className="w-44">
            <label className="text-xs text-slate-500 font-semibold uppercase tracking-wider block mb-1">Class</label>
            <Select value={classLevel} onValueChange={setClassLevel}>
              <SelectTrigger className="w-full rounded-full" data-testid="lb-class-select">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All classes</SelectItem>
                <SelectItem value="8">Class 8</SelectItem>
                <SelectItem value="9">Class 9</SelectItem>
                <SelectItem value="10">Class 10</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}
        
        <div className="w-64">
          <label className="text-xs text-slate-500 font-semibold uppercase tracking-wider block mb-1">Leaderboard Type</label>
          <Select value={selectedTestId} onValueChange={setSelectedTestId}>
            <SelectTrigger className="w-full rounded-full">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="total">Overall (Total Points)</SelectItem>
              {tests.filter((t) => t._id && t._id !== "").map((t) => (
                <SelectItem key={t._id} value={t._id}>
                  Test: {t.title}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {items.length === 0 ? (
        <div className="mt-16 text-center text-[#64748B]">
          {selectedTestId === "total" 
            ? "No rankings yet — take a test to appear!" 
            : "No students have submitted this test yet."}
        </div>
      ) : (
        <div className="mt-8 rounded-2xl bg-white border border-slate-200 overflow-hidden">
          {items.map((r, i) => {
            const isMe = r.user_id === user?._id;
            return (
              <motion.div
                key={r.user_id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: Math.min(i * 0.03, 0.5) }}
                data-testid={`lb-row-${i}`}
                className={`flex items-center gap-4 px-5 py-4 border-b border-slate-100 last:border-b-0 ${isMe ? "bg-[#7C3AED]/5" : ""}`}
              >
                <div className={`w-10 h-10 rounded-xl grid place-items-center font-mono font-semibold ${
                  r.rank === 1 ? "bg-amber-100 text-amber-700" :
                  r.rank === 2 ? "bg-slate-200 text-slate-700" :
                  r.rank === 3 ? "bg-orange-100 text-orange-700" :
                  "bg-slate-50 text-[#334155]"
                }`}>
                  {r.rank === 1 ? <Crown size={18} /> : r.rank === 2 ? <Trophy size={18} /> : r.rank === 3 ? <Medal size={18} /> : `#${r.rank}`}
                </div>
                <div className="flex-1">
                  <div className="font-medium text-[#0F1B4C]">{r.name} {isMe && <span className="text-xs text-[#7C3AED]">(you)</span>}</div>
                  <div className="text-xs text-[#64748B]">Class {r.class_level || "—"}</div>
                </div>
                <div className="font-mono text-lg text-[#2563EB] font-semibold">{r.total_points} pts</div>
              </motion.div>
            );
          })}
        </div>
      )}
    </div>
  );
}
