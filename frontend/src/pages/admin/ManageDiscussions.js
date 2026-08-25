import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { MessageSquare, ArrowLeft, Trash2, Send, CornerDownRight, Plus, RefreshCw, Check, ChevronDown, ChevronUp } from "lucide-react";

export default function ManageDiscussions() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [step, setStep] = useState(1);
  const [threads, setThreads] = useState([]);
  const [loading, setLoading] = useState(false);
  const [replyBody, setReplyBody] = useState({});
  const [expandedId, setExpandedId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const params = {};
      if (activeClass !== "all") params.class_level = activeClass;
      const r = await api.get("/api/discussions", { params });
      setThreads(r.data.items || []);
    } catch {
      toast.error("Failed to load doubt discussion board.");
    } finally {
      setLoading(false);
    }
  }, [activeClass]);

  useEffect(() => {
    load();
  }, [load]);

  const handleSelectClass = (cls) => {
    setActiveClass(cls);
    setExpandedId(null);
    setStep(2);
  };

  const handleReply = async (tid) => {
    const text = replyBody[tid];
    if (!text || !text.trim()) { toast.error("Reply text cannot be empty."); return; }
    try {
      await api.post(`/api/discussions/${tid}/reply`, { body: text });
      toast.success("Replied & marked as resolved!");
      setReplyBody((prev) => ({ ...prev, [tid]: "" }));
      setThreads((prev) => prev.filter((t) => t._id !== tid));
      setExpandedId(null);
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const resolveThread = async (tid) => {
    try {
      await api.post(`/api/discussions/${tid}/resolve`);
      toast.success("Doubt marked as resolved.");
      setThreads((prev) => prev.filter((t) => t._id !== tid));
      setExpandedId(null);
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const delThread = async (tid) => {
    if (!window.confirm("Delete this thread?")) return;
    try {
      await api.delete(`/api/discussions/${tid}`);
      toast.success("Thread deleted.");
      setThreads((prev) => prev.filter((t) => t._id !== tid));
      setExpandedId(null);
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const classesList = [
    { id: "all", label: "All Classes", desc: "View and resolve student doubt discussions across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8",   label: "Class 8",     desc: "Grade 8 student doubt clarifications and Q&A",                      tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9",   label: "Class 9",     desc: "Grade 9 student doubt clarifications and Q&A",                      tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10",  label: "Class 10",    desc: "Grade 10 student doubt clarifications and Q&A",                     tone: "bg-amber-50 text-amber-700 border-amber-200" },
  ];

  return (
    <div className="max-w-5xl mx-auto px-6 sm:px-10 py-10">
      <div className="flex items-center justify-between gap-4 mb-6">
        <BackButton to="/admin" label="Admin dashboard" />
        {step === 2 && (
          <Button
            onClick={() => { setStep(1); setExpandedId(null); }}
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
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Doubt Clarification — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to inspect student doubts and discussion threads.</p>

          <div className="mt-8 grid sm:grid-cols-2 gap-5">
            {classesList.map((c) => (
              <Card
                key={c.id}
                onClick={() => handleSelectClass(c.id)}
                className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
              >
                <div className="flex items-start justify-between">
                  <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                    <MessageSquare size={24} />
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
                  <span>Manage Doubts</span>
                  <Plus size={16} className="group-hover:translate-x-1 transition-transform" />
                </div>
              </Card>
            ))}
          </div>
        </div>
      ) : (
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Doubt Clarification</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
            {activeClass === "all" ? "All Doubt Discussions" : `Class ${activeClass} Student Doubts`}
          </h1>
          <p className="mt-1 text-[#64748B] text-sm">Click a thread to view the full conversation.</p>

          {loading ? (
            <div className="mt-12 text-center text-[#64748B]">
              <RefreshCw size={20} className="animate-spin mx-auto mb-2" /> Loading doubts…
            </div>
          ) : threads.length === 0 ? (
            <div className="mt-12 text-center text-[#64748B] bg-slate-50 p-12 rounded-3xl border border-slate-200">
              No active student doubt threads for Class {activeClass}.
            </div>
          ) : (
            <div className="mt-6 space-y-2">
              {threads.map((t) => {
                const isOpen = expandedId === t._id;
                return (
                  <div key={t._id} className="rounded-2xl border border-slate-200 bg-white overflow-hidden shadow-sm transition-all">

                    {/* ── Compact row — always visible ── */}
                    <button
                      onClick={() => setExpandedId(isOpen ? null : t._id)}
                      className="w-full flex items-center justify-between gap-3 px-5 py-4 hover:bg-slate-50 transition-colors text-left"
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {/* Avatar */}
                        <div className="w-9 h-9 rounded-full bg-[#7C3AED]/10 border border-[#7C3AED]/20 text-[#7C3AED] font-bold text-sm grid place-items-center shrink-0">
                          {(t.user_name || "?").charAt(0).toUpperCase()}
                        </div>
                        <div className="min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-semibold text-sm text-[#0F1B4C]">{t.user_name}</span>
                            {t.student_id && (
                              <span className="text-[11px] text-slate-500 font-mono bg-slate-100 px-2 py-0.5 rounded-full border border-slate-200">
                                {t.student_id}
                              </span>
                            )}
                            {t.replies_count > 0 && (
                              <Badge className="bg-purple-100 text-purple-700 text-[10px] px-2">
                                {t.replies_count} repl{t.replies_count === 1 ? "y" : "ies"}
                              </Badge>
                            )}
                          </div>
                          <p className="text-xs text-[#64748B] truncate mt-0.5">{t.title}</p>
                        </div>
                      </div>
                      {isOpen
                        ? <ChevronUp size={16} className="text-slate-400 shrink-0" />
                        : <ChevronDown size={16} className="text-slate-400 shrink-0" />}
                    </button>

                    {/* ── Expanded full conversation ── */}
                    {isOpen && (
                      <div className="border-t border-slate-100 px-5 pb-5 pt-4 space-y-4">

                        {/* Thread header + actions */}
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="flex items-center gap-2 flex-wrap">
                              <Badge className="bg-purple-100 text-purple-700 text-[10px]">
                                Class {t.class_level} · {t.subject}
                              </Badge>
                              {t.student_id && (
                                <span className="text-[11px] text-slate-500 font-mono bg-slate-100 px-2 py-0.5 rounded-full border border-slate-200">
                                  {t.student_id}
                                </span>
                              )}
                            </div>
                            <h3 className="font-serif text-xl text-[#0F1B4C] font-semibold mt-2">{t.title}</h3>
                          </div>
                          <div className="flex items-center gap-2 shrink-0">
                            <Button
                              size="sm"
                              onClick={() => resolveThread(t._id)}
                              className="bg-emerald-500 hover:bg-emerald-600 text-white text-xs px-3 py-1.5 rounded-full flex items-center gap-1.5"
                            >
                              <Check size={13} /> Mark as Resolved
                            </Button>
                            <Button variant="ghost" size="icon" onClick={() => delThread(t._id)} className="text-red-400 hover:text-red-600">
                              <Trash2 size={15} />
                            </Button>
                          </div>
                        </div>

                        {/* Original question bubble */}
                        <div className="bg-slate-50 rounded-2xl px-4 py-3 border border-slate-200 text-sm text-[#475569] whitespace-pre-wrap">
                          <span className="font-semibold text-[#0F1B4C] block mb-1">{t.user_name}:</span>
                          {t.body}
                        </div>

                        {/* Replies */}
                        {t.replies && t.replies.length > 0 && (
                          <div className="space-y-2">
                            {t.replies.map((r) => {
                              const isAdmin = r.role === "admin" || r.role === "superadmin";
                              return (
                                <div
                                  key={r.reply_id}
                                  className={`flex items-start gap-3 rounded-2xl px-4 py-3 text-sm ${
                                    isAdmin
                                      ? "bg-[#7C3AED]/5 border border-[#7C3AED]/20"
                                      : "bg-white border border-slate-200"
                                  }`}
                                >
                                  <div className={`w-7 h-7 rounded-full grid place-items-center shrink-0 text-xs font-bold ${
                                    isAdmin ? "bg-[#7C3AED] text-white" : "bg-slate-200 text-slate-600"
                                  }`}>
                                    {(r.user_name || "?").charAt(0).toUpperCase()}
                                  </div>
                                  <div className="min-w-0">
                                    <div className="flex items-center gap-1.5">
                                      <span className="font-semibold text-xs text-[#0F1B4C]">{r.user_name}</span>
                                      {isAdmin && (
                                        <span className="text-[9px] font-bold uppercase tracking-wide bg-[#7C3AED] text-white px-1.5 py-0.5 rounded-full">Admin</span>
                                      )}
                                    </div>
                                    <p className="text-[#475569] mt-0.5">{r.body}</p>
                                  </div>
                                </div>
                              );
                            })}
                          </div>
                        )}

                        {/* Admin reply input */}
                        <div className="flex items-center gap-3 pt-1">
                          <CornerDownRight size={15} className="text-[#7C3AED] shrink-0" />
                          <Input
                            placeholder="Write an official admin reply…"
                            className="rounded-full text-xs"
                            value={replyBody[t._id] || ""}
                            onChange={(e) => setReplyBody({ ...replyBody, [t._id]: e.target.value })}
                            onKeyDown={(e) => e.key === "Enter" && handleReply(t._id)}
                          />
                          <Button
                            onClick={() => handleReply(t._id)}
                            size="sm"
                            className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] text-xs px-4 shrink-0"
                          >
                            <Send size={12} className="mr-1" /> Reply
                          </Button>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
