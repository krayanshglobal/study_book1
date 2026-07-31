import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Checkbox } from "@/components/ui/checkbox";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import { Plus, Trash2, Pencil, ClipboardCheck, RefreshCw } from "lucide-react";
import RichEditor from "@/components/RichEditor";

const empty = {
  title: "", description: "", test_type: "mock", class_level: "10", subject: "maths",
  scheduled_date: "", start_time: "20:00", end_time: "21:00", duration_minutes: 60,
  negative_marking: true, question_ids: [], is_published: false,
  unlock_score_required: null, prerequisite_test_id: null, premium_only: false,
};

const emptyQ = {
  subject: "maths", topic: "", question_text: "",
  q_type: "mcq",
  options: [{ label: "A", text: "" }, { label: "B", text: "" }, { label: "C", text: "" }, { label: "D", text: "" }],
  correct_index: 0,
  correct_answer_text: "",
  explanation: "",
  positive_marks: 1.0, negative_marks: 0.25,
  difficulty: "medium",
  image_url: "",
};

export default function ManageTests() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [tests, setTests] = useState([]);
  const [questions, setQuestions] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ ...empty, class_level: activeClass });
  const [editing, setEditing] = useState(null);

  // Inline question creator states
  const [showAddQ, setShowAddQ] = useState(false);
  const [qForm, setQForm] = useState({ ...emptyQ });
  const [draftQuestions, setDraftQuestions] = useState([]);

  // Attempts modal
  const [attemptsOpen, setAttemptsOpen] = useState(false);
  const [attemptsTest, setAttemptsTest] = useState(null);
  const [attempts, setAttempts] = useState([]);
  const [attemptsLoading, setAttemptsLoading] = useState(false);

  const load = useCallback(async () => {
    const t = await api.get("/api/tests", { params: { class_level: activeClass } });
    setTests(t.data.items || []);
  }, [activeClass]);
  
  useEffect(() => { load(); }, [activeClass, load]);

  useEffect(() => {
    (async () => {
      if (!open) return;
      const r = await api.get("/api/questions", { params: { class_level: form.class_level, limit: 500 } });
      setQuestions(r.data.items || []);
    })();
  }, [open, form.class_level]);

  const setF = (k, v) => setForm((s) => ({ ...s, [k]: v }));
  const toggleQ = (id) => {
    setForm((s) => ({ ...s, question_ids: s.question_ids.includes(id) ? s.question_ids.filter((x) => x !== id) : [...s.question_ids, id] }));
  };

  const handleAddDraftQuestion = () => {
    if (!qForm.topic.trim()) {
      toast.error("Topic is required");
      return;
    }
    if (!qForm.question_text.trim()) {
      toast.error("Question text is required");
      return;
    }
    if (qForm.q_type === "mcq") {
      const emptyOpt = qForm.options.some((o) => !o.text.trim());
      if (emptyOpt) {
        toast.error("Please fill all MCQ options");
        return;
      }
    } else {
      if (!qForm.correct_answer_text.trim()) {
        toast.error("Correct answer text is required for typed question");
        return;
      }
    }

    const draft = { ...qForm, _localId: Date.now() };
    setDraftQuestions((prev) => [...prev, draft]);
    toast.success("Question added to drafts");
    setQForm({ ...emptyQ });
  };

  const handleRemoveDraftQuestion = (localId) => {
    setDraftQuestions((prev) => prev.filter((d) => d._localId !== localId));
    toast.success("Draft question removed");
  };

  const handleSubmitDrafts = async () => {
    if (draftQuestions.length === 0) return;
    try {
      const createdIds = [];
      const newQuestions = [];
      for (const q of draftQuestions) {
        const payload = { ...q, class_level: form.class_level };
        if (q.q_type === "typed") payload.options = null;
        delete payload._localId;
        
        const r = await api.post("/api/questions", payload);
        createdIds.push(r.data._id);
        newQuestions.push(r.data);
      }
      toast.success(`Successfully saved ${draftQuestions.length} new question(s)`);
      setQuestions((prev) => [...newQuestions, ...prev]);
      setForm((s) => ({ ...s, question_ids: [...s.question_ids, ...createdIds] }));
      setDraftQuestions([]);
      setShowAddQ(false);
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const handleDeleteQuestion = async (id) => {
    if (!window.confirm("Are you sure you want to delete this question from the question bank? This action cannot be undone.")) return;
    try {
      await api.delete(`/api/questions/${id}`);
      toast.success("Question deleted");
      setQuestions((prev) => prev.filter((q) => q._id !== id));
      setForm((s) => ({ ...s, question_ids: s.question_ids.filter((qid) => qid !== id) }));
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const openNew = () => { setForm({ ...empty, class_level: activeClass }); setEditing(null); setShowAddQ(false); setQForm({ ...emptyQ }); setDraftQuestions([]); setOpen(true); };
  const openEdit = (t) => { setForm({ ...empty, ...t }); setEditing(t._id); setShowAddQ(false); setQForm({ ...emptyQ }); setDraftQuestions([]); setOpen(true); };

  const save = async () => {
    try {
      const payload = { ...form };
      if (payload.unlock_score_required === "" || payload.unlock_score_required === null) payload.unlock_score_required = null;
      if (payload.prerequisite_test_id === "" || payload.prerequisite_test_id === "none") payload.prerequisite_test_id = null;
      if (editing) await api.put(`/api/tests/${editing}`, payload);
      else await api.post("/api/tests", payload);
      toast.success("Saved"); setOpen(false); load();
    } catch (err) { toast.error(formatApiError(err)); }
  };

  const del = async (id) => {
    if (!window.confirm("Delete test?")) return;
    await api.delete(`/api/tests/${id}`); toast.success("Deleted"); load();
  };

  const togglePublish = async (t) => {
    await api.put(`/api/tests/${t._id}`, { is_published: !t.is_published });
    load();
  };

  const openAttempts = async (t) => {
    setAttemptsTest(t);
    setAttemptsOpen(true);
    setAttemptsLoading(true);
    try {
      const r = await api.get(`/api/tests/${t._id}/attempts`);
      setAttempts(r.data.items || []);
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setAttemptsLoading(false);
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Schedule</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Mock & final tests</h1>
        </div>
        <div className="flex items-center gap-3">
          {/* Class Filter Switcher */}
          <div className="flex items-center gap-1.5 bg-slate-100 p-1.5 rounded-full border border-slate-200 shadow-sm">
            {["8", "9", "10"].map((lvl) => (
              <button
                key={lvl}
                type="button"
                onClick={() => {
                  localStorage.setItem("admin_class_level", lvl);
                  setActiveClass(lvl);
                }}
                className={`px-4 py-1.5 rounded-full text-xs font-semibold font-mono transition-all ${
                  activeClass === lvl
                    ? "bg-[#0F1B4C] text-white shadow-md scale-105"
                    : "text-[#475569] hover:text-[#0F1B4C] hover:bg-slate-200/50"
                }`}
              >
                Class {lvl}
              </button>
            ))}
          </div>

          <Dialog open={open} onOpenChange={setOpen}>
            <DialogTrigger asChild>
              <Button onClick={openNew} data-testid="admin-add-test-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]"><Plus size={16} className="mr-1" /> New test</Button>
            </DialogTrigger>
          <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
            <DialogHeader>
              <DialogTitle className="font-serif">
                {showAddQ ? "Add questions to test" : editing ? "Edit test" : "Create test"}
              </DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              {!showAddQ && (
                <>
                  <div className="grid grid-cols-2 gap-3">
                    <div><Label>Title</Label><Input data-testid="test-title-input" value={form.title} onChange={(e) => setF("title", e.target.value)} className="mt-1" /></div>
                    <div><Label>Type</Label>
                      <Select value={form.test_type} onValueChange={(v) => setF("test_type", v)}>
                        <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                        <SelectContent><SelectItem value="mock">Mock</SelectItem><SelectItem value="final">Final</SelectItem></SelectContent>
                      </Select>
                    </div>
                  </div>
                  <div><Label>Description</Label><Textarea rows={2} value={form.description} onChange={(e) => setF("description", e.target.value)} /></div>
                  <div className="grid grid-cols-4 gap-3">
                    <div><Label>Class</Label><Select value={form.class_level} onValueChange={(v) => setF("class_level", v)}><SelectTrigger className="mt-1"><SelectValue /></SelectTrigger><SelectContent>{["8","9","10"].map((c) => <SelectItem key={c} value={c}>{c}</SelectItem>)}</SelectContent></Select></div>
                    <div><Label>Date</Label><Input type="date" data-testid="test-date-input" value={form.scheduled_date} onChange={(e) => setF("scheduled_date", e.target.value)} className="mt-1" /></div>
                    <div><Label>Start (UTC)</Label><Input type="time" value={form.start_time} onChange={(e) => setF("start_time", e.target.value)} className="mt-1" /></div>
                    <div><Label>End (UTC)</Label><Input type="time" value={form.end_time} onChange={(e) => setF("end_time", e.target.value)} className="mt-1" /></div>
                  </div>
                  <div className="grid grid-cols-3 gap-3">
                    <div><Label>Duration (min)</Label><Input type="number" value={form.duration_minutes} onChange={(e) => setF("duration_minutes", parseInt(e.target.value))} className="mt-1" /></div>
                    <div className="flex items-end gap-2"><Switch checked={form.negative_marking} onCheckedChange={(v) => setF("negative_marking", v)} id="neg" /><Label htmlFor="neg">Negative marking</Label></div>
                    <div className="flex items-end gap-2"><Switch checked={form.premium_only} onCheckedChange={(v) => setF("premium_only", v)} id="prem" /><Label htmlFor="prem">Premium only</Label></div>
                  </div>

                  {form.test_type === "final" && (
                    <div className="grid grid-cols-2 gap-3 rounded-lg bg-[#7C3AED]/5 border border-[#7C3AED]/20 p-4">
                      <div>
                        <Label>Prerequisite test</Label>
                        <Select value={form.prerequisite_test_id || "none"} onValueChange={(v) => setF("prerequisite_test_id", v === "none" ? null : v)}>
                          <SelectTrigger className="mt-1"><SelectValue placeholder="None" /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="none">None</SelectItem>
                            {tests.filter((t) => t.test_type === "mock" && t._id && t._id !== editing && t._id !== "").map((t) => (
                              <SelectItem key={t._id} value={t._id}>{t.title}</SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      </div>
                      <div>
                        <Label>Unlock score % (e.g. 50)</Label>
                        <Input type="number" value={form.unlock_score_required ?? ""} onChange={(e) => setF("unlock_score_required", e.target.value === "" ? null : parseFloat(e.target.value))} className="mt-1" />
                      </div>
                    </div>
                  )}
                </>
              )}

              <div>
                <div className="flex items-center justify-between">
                  <Label>Questions ({form.question_ids.length} selected)</Label>
                  <Button
                    type="button"
                    variant="link"
                    size="sm"
                    className="h-auto p-0 text-[#7C3AED] hover:text-[#6D28D9] font-medium"
                    onClick={() => {
                      setQForm({ ...emptyQ });
                      setShowAddQ(!showAddQ);
                    }}
                  >
                    {showAddQ ? "Cancel new question" : "+ Create new question"}
                  </Button>
                </div>

                {showAddQ && (
                  <div className="mt-3 p-4 rounded-xl border border-[#7C3AED]/20 bg-[#7C3AED]/5 space-y-3">
                    <div className="text-xs font-semibold uppercase tracking-wider text-[#7C3AED]">Create inline question</div>
                    
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <Label>Topic</Label>
                        <Input
                          className="mt-1 bg-white"
                          value={qForm.topic}
                          onChange={(e) => setQForm((s) => ({ ...s, topic: e.target.value }))}
                          placeholder="Algebra"
                        />
                      </div>
                      <div>
                        <Label>Type</Label>
                        <Select
                          value={qForm.q_type}
                          onValueChange={(v) => setQForm((s) => ({ ...s, q_type: v }))}
                        >
                          <SelectTrigger className="mt-1 bg-white"><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="mcq">MCQ</SelectItem>
                            <SelectItem value="typed">Typed</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                    </div>

                    <div>
                      <Label>Question Text</Label>
                      <div className="mt-1 bg-white border rounded-md overflow-hidden">
                        <RichEditor
                          value={qForm.question_text}
                          onChange={(html) => setQForm((s) => ({ ...s, question_text: html }))}
                          placeholder="Type or paste the question text..."
                        />
                      </div>
                    </div>

                    {qForm.q_type === "mcq" ? (
                      <div>
                        <Label>Options</Label>
                        <div className="mt-1 space-y-2">
                          {qForm.options.map((o, idx) => (
                            <div key={idx} className="flex items-center gap-2">
                              <input
                                type="radio"
                                name="inline_correct_index"
                                checked={qForm.correct_index === idx}
                                onChange={() => setQForm((s) => ({ ...s, correct_index: idx }))}
                                className="w-4 h-4 accent-[#7C3AED]"
                              />
                              <span className="font-mono text-xs text-[#7C3AED] w-4">{o.label}</span>
                              <Input
                                className="bg-white"
                                value={o.text}
                                onChange={(e) => {
                                  const newOpts = [...qForm.options];
                                  newOpts[idx] = { ...newOpts[idx], text: e.target.value };
                                  setQForm((s) => ({ ...s, options: newOpts }));
                                }}
                                placeholder={`Option ${o.label}`}
                              />
                            </div>
                          ))}
                        </div>
                      </div>
                    ) : (
                      <div>
                        <Label>Correct typed answer</Label>
                        <Input
                          className="mt-1 font-mono bg-white"
                          value={qForm.correct_answer_text}
                          onChange={(e) => setQForm((s) => ({ ...s, correct_answer_text: e.target.value }))}
                          placeholder="Correct answer text"
                        />
                      </div>
                    )}

                    <div>
                      <Label>Explanation</Label>
                      <Textarea
                        className="bg-white mt-1"
                        rows={2}
                        value={qForm.explanation}
                        onChange={(e) => setQForm((s) => ({ ...s, explanation: e.target.value }))}
                        placeholder="Explanation of the correct answer..."
                      />
                    </div>

                    <div className="grid grid-cols-3 gap-3">
                      <div>
                        <Label>+ marks</Label>
                        <Input
                          className="bg-white mt-1"
                          type="number"
                          step="0.25"
                          value={qForm.positive_marks}
                          onChange={(e) => setQForm((s) => ({ ...s, positive_marks: parseFloat(e.target.value) }))}
                        />
                      </div>
                      <div>
                        <Label>− marks</Label>
                        <Input
                          className="bg-white mt-1"
                          type="number"
                          step="0.25"
                          value={qForm.negative_marks}
                          onChange={(e) => setQForm((s) => ({ ...s, negative_marks: parseFloat(e.target.value) }))}
                        />
                      </div>
                      <div>
                        <Label>Difficulty</Label>
                        <Select
                          value={qForm.difficulty}
                          onValueChange={(v) => setQForm((s) => ({ ...s, difficulty: v }))}
                        >
                          <SelectTrigger className="bg-white mt-1"><SelectValue /></SelectTrigger>
                          <SelectContent>
                            <SelectItem value="easy">Easy</SelectItem>
                            <SelectItem value="medium">Medium</SelectItem>
                            <SelectItem value="hard">Hard</SelectItem>
                          </SelectContent>
                        </Select>
                      </div>
                    </div>

                    <div className="flex justify-end gap-2 pt-2">
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onClick={() => setShowAddQ(false)}
                      >
                        Cancel
                      </Button>
                      <Button
                        type="button"
                        size="sm"
                        className="bg-[#7C3AED] hover:bg-[#6D28D9] text-white rounded-full"
                        onClick={handleAddDraftQuestion}
                      >
                        Add to Drafts
                      </Button>
                    </div>
                  </div>
                )}

                {draftQuestions.length > 0 && (
                  <div className="mt-3 p-4 rounded-xl border border-slate-200 bg-slate-50 space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="text-xs font-semibold uppercase tracking-wider text-slate-500 font-medium">Draft Questions ({draftQuestions.length})</div>
                      <div className="flex gap-2">
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          className="rounded-full h-8 px-4"
                          onClick={() => setShowAddQ(false)}
                        >
                          Back to test details
                        </Button>
                        <Button
                          type="button"
                          size="sm"
                          className="bg-[#0F1B4C] hover:bg-[#2563EB] text-white rounded-full h-8 px-4"
                          onClick={handleSubmitDrafts}
                        >
                          Save & Add All Drafts
                        </Button>
                      </div>
                    </div>
                    <div className="space-y-2 max-h-40 overflow-y-auto divide-y divide-slate-100">
                      {draftQuestions.map((dq) => (
                        <div key={dq._localId} className="flex items-start justify-between gap-4 py-2 first:pt-0 last:pb-0">
                          <div className="text-sm min-w-0 flex-1">
                            <span className="text-xs text-[#7C3AED] font-semibold uppercase tracking-wider mr-2">{dq.topic || "No Topic"}</span>
                            <span className="text-[10px] bg-slate-200 text-slate-700 px-2 py-0.5 rounded font-mono uppercase font-bold">{dq.q_type}</span>
                            <div className="text-[#0F1B4C] mt-1 line-clamp-1 text-xs" dangerouslySetInnerHTML={{ __html: dq.question_text }} />
                          </div>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            className="h-8 w-8 text-red-500 hover:bg-red-50 shrink-0"
                            onClick={() => handleRemoveDraftQuestion(dq._localId)}
                          >
                            <Trash2 size={14} />
                          </Button>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {!showAddQ && (
                  <div className="mt-2 max-h-56 overflow-y-auto border border-slate-200 rounded-lg divide-y divide-slate-100">
                    {questions.map((q) => (
                      <div key={q._id} className="flex items-center justify-between gap-4 p-3 hover:bg-slate-50" data-testid={`test-pick-q-${q._id}`}>
                        <label className="flex items-start gap-3 cursor-pointer flex-1 min-w-0">
                          <Checkbox checked={form.question_ids.includes(q._id)} onCheckedChange={() => toggleQ(q._id)} />
                          <div className="flex-1 text-sm min-w-0">
                            <div className="text-xs text-[#7C3AED] uppercase tracking-widest font-semibold">{q.topic || "(No topic)"}</div>
                            <div className="text-[#0F1B4C] text-xs truncate" dangerouslySetInnerHTML={{ __html: q.question_text || "(Empty question text)" }} />
                          </div>
                        </label>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 text-red-500 hover:bg-red-50 hover:text-red-600 shrink-0"
                          onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            handleDeleteQuestion(q._id);
                          }}
                        >
                          <Trash2 size={14} />
                        </Button>
                      </div>
                    ))}
                    {questions.length === 0 && <div className="p-4 text-sm text-[#64748B]">No questions for class {form.class_level}. Add some first.</div>}
                  </div>
                )}
              </div>

              {!showAddQ && (
                <div className="flex items-center justify-between pt-2">
                  <div className="flex items-center gap-2"><Switch checked={form.is_published} onCheckedChange={(v) => setF("is_published", v)} id="pub" /><Label htmlFor="pub">Publish immediately</Label></div>
                  <div className="flex gap-2">
                    <Button variant="outline" className="rounded-full" onClick={() => setOpen(false)}>Cancel</Button>
                    <Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" onClick={save} data-testid="test-save-btn">{editing ? "Update" : "Create"}</Button>
                  </div>
                </div>
              )}
            </div>
          </DialogContent>
        </Dialog>
      </div>
    </div>

      <div className="mt-8 grid md:grid-cols-2 gap-4">
        {tests.map((t) => (
          <Card key={t._id} className="rounded-2xl border-slate-200 p-6" data-testid={`admin-test-card-${t._id}`}>
            <div className="flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <Badge className={t.test_type === "final" ? "bg-[#7C3AED]" : "bg-slate-200 text-[#0F1B4C]"}>{t.test_type.toUpperCase()}</Badge>
                  {t.is_published ? <Badge className="bg-green-600">PUBLISHED</Badge> : <Badge variant="outline">DRAFT</Badge>}
                  {t.premium_only && <Badge className="bg-amber-500">PREMIUM</Badge>}
                </div>
                <div className="mt-3 font-serif text-xl text-[#0F1B4C] font-semibold">{t.title}</div>
                <div className="text-xs text-[#64748B] mt-1">Class {t.class_level} · {t.scheduled_date} · {t.start_time}–{t.end_time} IST · {t.question_ids?.length || 0} qns</div>
              </div>
              <div className="flex flex-col items-end gap-2">
                <Button variant="ghost" size="icon" onClick={() => openEdit(t)} data-testid={`test-edit-${t._id}`}><Pencil size={16} /></Button>
                <Button variant="ghost" size="icon" onClick={() => del(t._id)} data-testid={`test-del-${t._id}`}><Trash2 size={16} className="text-red-500" /></Button>
              </div>
            </div>
            <div className="mt-4 flex gap-2">
              <Button variant="outline" size="sm" className="rounded-full" onClick={() => togglePublish(t)} data-testid={`test-toggle-pub-${t._id}`}>
                {t.is_published ? "Unpublish" : "Publish"}
              </Button>
              <a href={`/tests/${t._id}/result`} className="hidden" />
              <Button variant="outline" size="sm" className="rounded-full" onClick={() => openAttempts(t)} data-testid={`test-attempts-${t._id}`}>
                <ClipboardCheck size={14} className="mr-1" /> View attempts
              </Button>
            </div>
          </Card>
        ))}
        {tests.length === 0 && <div className="col-span-full text-center text-[#64748B] py-10">No tests yet.</div>}
      </div>

      {/* Attempts Modal */}
      <Dialog open={attemptsOpen} onOpenChange={setAttemptsOpen}>
        <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="font-serif">
              Attempts — {attemptsTest?.title}
              <span className="ml-2 text-base font-normal text-[#64748B]">({attempts.length} submitted)</span>
            </DialogTitle>
          </DialogHeader>
          {attemptsLoading ? (
            <div className="py-10 text-center text-[#64748B]">
              <RefreshCw size={18} className="animate-spin mx-auto mb-2" /> Loading attempts…
            </div>
          ) : attempts.length === 0 ? (
            <div className="py-10 text-center text-[#64748B]">No attempts yet.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-slate-200 text-xs uppercase tracking-widest text-[#64748B]">
                    <th className="py-2 px-3 text-left">#</th>
                    <th className="py-2 px-3 text-left">Student</th>
                    <th className="py-2 px-3 text-right">Score</th>
                    <th className="py-2 px-3 text-right">%</th>
                    <th className="py-2 px-3 text-right">✓</th>
                    <th className="py-2 px-3 text-right">✗</th>
                    <th className="py-2 px-3 text-left">Submitted</th>
                  </tr>
                </thead>
                <tbody>
                  {attempts.map((a, i) => (
                    <tr key={a._id} className="border-b border-slate-100 hover:bg-slate-50">
                      <td className="py-2 px-3 font-mono text-[#64748B]">{i + 1}</td>
                      <td className="py-2 px-3">
                        <div className="font-medium text-[#0F1B4C]">{a.user_name || "—"}</div>
                        <div className="text-xs text-[#64748B]">{a.user_email || ""}</div>
                      </td>
                      <td className="py-2 px-3 text-right font-mono">{a.score ?? "—"} / {a.total_marks ?? "—"}</td>
                      <td className="py-2 px-3 text-right font-mono">
                        <span className={`font-semibold ${
                          (a.percent ?? 0) >= 70 ? "text-emerald-600" :
                          (a.percent ?? 0) >= 40 ? "text-amber-600" : "text-red-500"
                        }`}>{a.percent ?? "—"}%</span>
                      </td>
                      <td className="py-2 px-3 text-right text-emerald-600 font-mono">{a.correct_count ?? "—"}</td>
                      <td className="py-2 px-3 text-right text-red-500 font-mono">{a.incorrect_count ?? "—"}</td>
                      <td className="py-2 px-3 text-xs text-[#64748B]">
                        {a.submitted_at ? new Date(a.submitted_at).toLocaleString() : "—"}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
