import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Pencil, Upload, Download, Send, BookOpen, CheckCircle2, ArrowLeft, FileText } from "lucide-react";
import MathText from "@/components/MathText";
import BackButton from "@/components/BackButton";
import RichEditor from "@/components/RichEditor";

const emptyQ = {
  subject: "maths", class_level: "10", topic: "", question_text: "",
  q_type: "mcq",
  options: [{ label: "A", text: "" }, { label: "B", text: "" }, { label: "C", text: "" }, { label: "D", text: "" }],
  correct_index: 0,
  correct_answer_text: "",
  explanation: "",
  positive_marks: 1.0, negative_marks: 0.25,
  difficulty: "medium",
  image_url: "",
  allow_file_upload: false,
  is_published: true,
  publish_date: "",
};

export default function ManageQuestions() {
  const adminClass = localStorage.getItem("admin_class_level") || "8";

  // Published & Draft questions list
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState({ class_level: adminClass, topic: "", status: "all", difficulty: "all" });

  // Batch staging — questions ready to publish
  const [batch, setBatch] = useState([]);

  // Form state for current question being composed
  const [form, setForm] = useState({ ...emptyQ, class_level: adminClass });
  const [open, setOpen] = useState(false);
  const [editingPublished, setEditingPublished] = useState(null); // for editing already-published questions

  const [step, setStep] = useState(1);

  const load = async () => {
    const params = { limit: 200 };
    if (filter.class_level !== "all") params.class_level = filter.class_level;
    if (filter.topic) params.topic = filter.topic;
    if (filter.status && filter.status !== "all") params.status = filter.status;
    if (filter.difficulty && filter.difficulty !== "all") params.difficulty = filter.difficulty;
    const r = await api.get("/api/questions", { params });
    setItems(r.data.items || []);
  };

  const handleDifficultyChange = (level) => {
    setForm((s) => ({ ...s, difficulty: level }));
  };

  useEffect(() => { setFilter((f) => ({ ...f, class_level: adminClass })); }, [adminClass]);
  useEffect(() => { load(); }, [filter]); // eslint-disable-line

  const togglePublish = async (id) => {
    try {
      await api.post(`/api/questions/${id}/publish`);
      toast.success("Question publish status updated!");
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const handleSelectClass = (cls) => {
    setFilter((f) => ({ ...f, class_level: cls }));
    setStep(2);
  };

  const setF = (key, val) => setForm((s) => ({ ...s, [key]: val }));
  const setOpt = (i, text) =>
    setForm((s) => {
      const opts = [...s.options];
      opts[i] = { ...opts[i], text };
      return { ...s, options: opts };
    });

  // Add to staging batch
  const addToBatch = () => {
    if (!form.question_text.trim()) { toast.error("Question text is required"); return; }
    setBatch((prev) => [...prev, { ...form, _batchId: Date.now() }]);
    setForm({ ...emptyQ, class_level: form.class_level }); // reset but keep same class
    toast.success("Added to batch stage!");
  };

  // Remove from staging
  const removeFromBatch = (batchId) => setBatch((prev) => prev.filter((q) => q._batchId !== batchId));

  // Save all (staged + current form question if filled) as DRAFTS
  const saveAsDrafts = async () => {
    let toSave = [...batch];
    if (form.question_text.trim()) {
      toSave.push({ ...form, is_published: false });
    } else {
      toSave = toSave.map((q) => ({ ...q, is_published: false }));
    }
    if (toSave.length === 0) {
      toast.error("Enter a question or add items to batch first");
      return;
    }
    try {
      let count = 0;
      for (const q of toSave) {
        const payload = { ...q, is_published: false };
        delete payload._batchId;
        if (payload.q_type === "typed") payload.options = null;
        await api.post("/api/questions", payload);
        count++;
      }
      toast.success(`Saved ${count} draft question${count > 1 ? "s" : ""}!`);
      setBatch([]);
      setForm({ ...emptyQ, class_level: form.class_level });
      setOpen(false);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Publish all (staged + current form question if filled) IMMEDIATELY
  const publishImmediately = async () => {
    let toPublish = [...batch];
    if (form.question_text.trim()) {
      toPublish.push({ ...form, is_published: true });
    } else {
      toPublish = toPublish.map((q) => ({ ...q, is_published: true }));
    }
    if (toPublish.length === 0) {
      toast.error("Enter a question or add items to batch first");
      return;
    }
    try {
      let count = 0;
      for (const q of toPublish) {
        const payload = { ...q, is_published: true };
        delete payload._batchId;
        if (payload.q_type === "typed") payload.options = null;
        await api.post("/api/questions", payload);
        count++;
      }
      toast.success(`Published ${count} question${count > 1 ? "s" : ""} immediately!`);
      setBatch([]);
      setForm({ ...emptyQ, class_level: form.class_level });
      setOpen(false);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Edit already-published question
  const openEditPublished = (q) => {
    setForm({ ...emptyQ, ...q, options: q.options || emptyQ.options, correct_index: q.correct_index ?? 0 });
    setEditingPublished(q._id);
    setOpen(true);
  };

  const saveEditPublished = async () => {
    try {
      const payload = { ...form };
      if (form.q_type === "typed") payload.options = null;
      await api.put(`/api/questions/${editingPublished}`, payload);
      toast.success("Updated");
      setOpen(false); setEditingPublished(null);
      setForm({ ...emptyQ, class_level: adminClass });
      load();
    } catch (err) { toast.error(formatApiError(err)); }
  };

  const del = async (id) => {
    if (!window.confirm("Delete this question?")) return;
    await api.delete(`/api/questions/${id}`);
    toast.success("Deleted"); load();
  };

  const CSV_TEMPLATE = `subject,class_level,topic,question_text,q_type,option_a,option_b,option_c,option_d,correct_index,correct_answer_text,explanation,positive_marks,negative_marks,difficulty,image_url
maths,10,Algebra,"Solve for x: 2x+3=11",mcq,3,4,5,6,1,4,"2x=8 so x=4",1,0.25,easy,
maths,10,Quadratic,"Discriminant of $ax^2+bx+c$?",typed,,,,,,b^2-4ac,"D = b^2 - 4ac",2,0.5,medium,`;

  const downloadTemplate = () => {
    const blob = new Blob([CSV_TEMPLATE], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = "studybook-questions-template.csv"; a.click();
    URL.revokeObjectURL(url);
  };

  const onCsvUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const fd = new FormData();
    fd.append("file", file);
    try {
      const r = await api.post("/api/questions/bulk-csv", fd, { headers: { "Content-Type": "multipart/form-data" } });
      const { inserted, errors } = r.data;
      if (errors?.length) toast.warning(`Uploaded ${inserted}. ${errors.length} rows had errors.`);
      else toast.success(`Uploaded ${inserted} questions`);
      load();
    } catch (err) { toast.error(formatApiError(err)); }
    e.target.value = "";
  };

  const renderQuestionForm = () => (
    <div className="space-y-4">
      <div className="grid grid-cols-3 gap-3">
        <div><Label>Class</Label>
          <Select value={form.class_level} onValueChange={(v) => setF("class_level", v)}>
            <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
            <SelectContent>{["8","9","10"].map((c) => <SelectItem key={c} value={c}>Class {c}</SelectItem>)}</SelectContent>
          </Select>
        </div>
        <div><Label>Topic</Label><Input data-testid="q-topic-input" className="mt-1" value={form.topic} onChange={(e) => setF("topic", e.target.value)} placeholder="Algebra" /></div>
        <div><Label>Type</Label>
          <Select value={form.q_type} onValueChange={(v) => setF("q_type", v)}>
            <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="mcq">MCQ</SelectItem>
              <SelectItem value="typed">Typed</SelectItem>
              <SelectItem value="file_upload">File / Image Upload</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>

      <div><Label>Question</Label>
        <div className="mt-1" data-testid="q-text-input">
          <RichEditor value={form.question_text} onChange={(html) => setF("question_text", html)} placeholder="Type or paste the question. Use $x^2$ for math." />
        </div>
      </div>

      {form.q_type === "mcq" ? (
        <div>
          <Label>Options</Label>
          <div className="mt-1 space-y-2">
            {form.options.map((o, i) => (
              <div key={i} className="flex items-center gap-2">
                <input type="radio" data-testid={`q-correct-${i}`} checked={form.correct_index === i} onChange={() => setF("correct_index", i)} className="w-4 h-4 accent-[#7C3AED]" />
                <span className="font-mono text-xs text-[#7C3AED] w-4">{o.label}</span>
                <Input value={o.text} onChange={(e) => setOpt(i, e.target.value)} data-testid={`q-opt-${i}`} />
              </div>
            ))}
          </div>
          <p className="text-xs text-[#64748B] mt-1">Select the radio for the correct option.</p>
        </div>
      ) : form.q_type === "typed" ? (
        <div><Label>Correct typed answer</Label><Input data-testid="q-typed-correct" className="mt-1 font-mono" value={form.correct_answer_text} onChange={(e) => setF("correct_answer_text", e.target.value)} /></div>
      ) : (
        <div className="p-3 bg-purple-50/60 rounded-xl border border-purple-200 text-xs text-[#7C3AED] font-semibold">
          📁 Students will be prompted to upload an image or PDF solution file (.pdf, .jpg, .jpeg, .png).
        </div>
      )}

      <div><Label>Explanation</Label><Textarea rows={2} value={form.explanation} onChange={(e) => setF("explanation", e.target.value)} /></div>

      <div className="grid grid-cols-3 gap-3">
        <div><Label>+ marks</Label><Input type="number" step="0.25" value={form.positive_marks} onChange={(e) => setF("positive_marks", parseFloat(e.target.value))} /></div>
        <div><Label>− marks</Label><Input type="number" step="0.25" value={form.negative_marks} onChange={(e) => setF("negative_marks", parseFloat(e.target.value))} /></div>
        <div><Label>Difficulty Level</Label>
          <Select value={form.difficulty} onValueChange={handleDifficultyChange}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="easy">🟢 Easy</SelectItem>
              <SelectItem value="medium">🟡 Medium</SelectItem>
              <SelectItem value="hard">🔴 Hard</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
      <div className="flex items-center gap-2 p-3 bg-purple-50/60 rounded-xl border border-purple-200">
        <input
          type="checkbox"
          id="allow_file_upload_cb"
          checked={form.allow_file_upload || false}
          onChange={(e) => setF("allow_file_upload", e.target.checked)}
          className="w-4 h-4 accent-[#7C3AED] rounded"
        />
        <Label htmlFor="allow_file_upload_cb" className="cursor-pointer text-xs font-semibold text-[#0F1B4C]">
          Allow student image / file solution upload (.pdf, .jpg, .jpeg, .png)
        </Label>
      </div>

      <div className="grid grid-cols-2 gap-3 p-3 bg-slate-50 rounded-xl border border-slate-200">
        <div>
          <Label className="text-xs font-semibold">Publish Status</Label>
          <Select value={form.is_published ? "published" : "draft"} onValueChange={(v) => setF("is_published", v === "published")}>
            <SelectTrigger className="mt-1 bg-white text-xs"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="published">🟢 Published (Active)</SelectItem>
              <SelectItem value="draft">🟡 Draft (Private / Save for later)</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div>
          <Label className="text-xs font-semibold">Publish Date (optional)</Label>
          <Input
            type="date"
            className="mt-1 bg-white text-xs font-mono"
            value={form.publish_date || ""}
            onChange={(e) => setF("publish_date", e.target.value)}
          />
        </div>
      </div>

      <div><Label>Image URL (optional)</Label><Input value={form.image_url} onChange={(e) => setF("image_url", e.target.value)} placeholder="https://…" /></div>
    </div>
  );

  const classesList = [
    { id: "all", label: "All Classes", desc: "View and manage questions across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Grade 8 Mathematics and Science question bank", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Grade 9 Mathematics and Science question bank", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Grade 10 Mathematics and Science question bank", tone: "bg-amber-50 text-amber-700 border-amber-200" },
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
            <span>Change Class ({filter.class_level === "all" ? "All Classes" : `Class ${filter.class_level}`})</span>
          </Button>
        )}
      </div>

      {step === 1 ? (
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Step 1 of 2</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Question Bank — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to view, add, or edit questions.</p>

          <div className="mt-8 grid sm:grid-cols-2 gap-5">
            {classesList.map((c) => (
              <Card
                key={c.id}
                onClick={() => handleSelectClass(c.id)}
                className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
              >
                <div className="flex items-start justify-between">
                  <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                    <BookOpen size={24} />
                  </div>
                  {filter.class_level === c.id && (
                    <Badge className="bg-[#7C3AED] text-white text-[10px]">Selected</Badge>
                  )}
                </div>

                <div className="mt-6">
                  <h3 className="font-serif text-2xl text-[#0F1B4C] font-semibold group-hover:text-[#7C3AED] transition-colors">{c.label}</h3>
                  <p className="text-xs text-[#64748B] mt-1 leading-relaxed">{c.desc}</p>
                </div>

                <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between text-xs font-semibold text-[#7C3AED]">
                  <span>Open Question Bank</span>
                  <Plus size={16} className="group-hover:translate-x-1 transition-transform" />
                </div>
              </Card>
            ))}
          </div>
        </div>
      ) : (
        <div>
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Question Bank</div>
              <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
                {filter.class_level === "all" ? "All Questions" : `Class ${filter.class_level} Questions`}
              </h1>
            </div>
            <div className="flex items-center gap-2 flex-wrap">
              <Button variant="outline" onClick={downloadTemplate} data-testid="csv-template-btn" className="rounded-full">
                <Download size={16} className="mr-1" /> CSV template
              </Button>
              <label className="cursor-pointer">
                <input type="file" accept=".csv" onChange={onCsvUpload} className="hidden" data-testid="csv-upload-input" />
                <span className="inline-flex items-center gap-1 rounded-full border border-slate-200 px-4 py-2 text-sm font-medium hover:bg-slate-50 transition-colors">
                  <Upload size={16} /> Bulk upload
                </span>
              </label>
              <Button onClick={() => { setEditingPublished(null); setForm({ ...emptyQ, class_level: filter.class_level === "all" ? "8" : filter.class_level }); setOpen(true); }} data-testid="admin-add-question-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]">
                <Plus size={16} className="mr-1" /> Add questions
              </Button>
            </div>
          </div>

      {/* ── Batch Composer Dialog ── */}
      <Dialog open={open} onOpenChange={(v) => { setOpen(v); if (!v) { setEditingPublished(null); } }}>
        <DialogContent className="max-w-3xl max-h-[92vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="font-serif text-xl">
              {editingPublished ? "Edit Question" : `Compose Questions — Batch (${batch.length} staged)`}
            </DialogTitle>
          </DialogHeader>

          {/* Form */}
          {renderQuestionForm()}

          {/* Batch staging list */}
          {!editingPublished && batch.length > 0 && (
            <div className="mt-4 border-t border-slate-100 pt-4">
              <div className="text-xs uppercase tracking-widest text-[#7C3AED] font-bold mb-2 flex items-center gap-1">
                <BookOpen size={13} /> Staged Questions ({batch.length})
              </div>
              <div className="space-y-2 max-h-48 overflow-y-auto pr-1">
                {batch.map((q, idx) => (
                  <div key={q._batchId} className="flex items-start justify-between gap-2 bg-slate-50 rounded-xl px-3 py-2">
                    <div className="flex-1 min-w-0">
                      <span className="text-xs font-bold text-[#7C3AED] mr-2">#{idx + 1}</span>
                      <span className="text-xs text-slate-500 mr-2">Class {q.class_level} · {q.topic || "No topic"} · {q.q_type.toUpperCase()}</span>
                      <div className="text-sm text-[#0F1B4C] truncate mt-0.5">
                        {/^\s*</.test(q.question_text) ? <span dangerouslySetInnerHTML={{ __html: q.question_text }} /> : <MathText text={q.question_text} />}
                      </div>
                    </div>
                    <button type="button" onClick={() => removeFromBatch(q._batchId)} className="text-red-400 hover:text-red-600 shrink-0 mt-0.5">
                      <Trash2 size={14} />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Action buttons */}
          <div className="flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-slate-100 mt-2">
            <Button variant="outline" className="rounded-full text-xs" onClick={() => { setOpen(false); setEditingPublished(null); }}>
              Cancel
            </Button>
            {editingPublished ? (
              <Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-xs font-semibold" onClick={saveEditPublished}>
                Update Question
              </Button>
            ) : (
              <div className="flex flex-wrap items-center gap-2">
                <Button variant="outline" className="rounded-full border-[#7C3AED] text-[#7C3AED] hover:bg-violet-50 text-xs font-semibold" onClick={addToBatch}>
                  <Plus size={14} className="mr-1" /> Add to Batch Stage
                </Button>
                <Button variant="outline" className="rounded-full border-amber-500 text-amber-700 hover:bg-amber-50 text-xs font-semibold" onClick={saveAsDrafts}>
                  <FileText size={14} className="mr-1" /> Save as Draft
                </Button>
                <Button className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] text-xs font-semibold text-white shadow-sm" onClick={publishImmediately}>
                  <Send size={14} className="mr-1" /> Publish Immediately {batch.length > 0 || form.question_text.trim() ? `(${batch.length + (form.question_text.trim() ? 1 : 0)})` : ""}
                </Button>
              </div>
            )}
          </div>
        </DialogContent>
      </Dialog>

      {/* Filter bar */}
      <div className="mt-6 flex gap-3 flex-wrap items-center">
        <Select value={filter.class_level} onValueChange={(v) => setFilter({ ...filter, class_level: v })}>
          <SelectTrigger className="w-40 rounded-full"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All classes</SelectItem>
            <SelectItem value="8">Class 8</SelectItem>
            <SelectItem value="9">Class 9</SelectItem>
            <SelectItem value="10">Class 10</SelectItem>
          </SelectContent>
        </Select>

        <Select value={filter.status || "all"} onValueChange={(v) => setFilter({ ...filter, status: v })}>
          <SelectTrigger className="w-44 rounded-full bg-white"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Statuses</SelectItem>
            <SelectItem value="published">🟢 Published Only</SelectItem>
            <SelectItem value="draft">🟡 Drafts Only</SelectItem>
          </SelectContent>
        </Select>

        <Select value={filter.difficulty || "all"} onValueChange={(v) => setFilter({ ...filter, difficulty: v })}>
          <SelectTrigger className="w-44 rounded-full bg-white"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Difficulties</SelectItem>
            <SelectItem value="easy">🟢 Easy</SelectItem>
            <SelectItem value="medium">🟡 Medium</SelectItem>
            <SelectItem value="hard">🔴 Hard</SelectItem>
          </SelectContent>
        </Select>

        <Input placeholder="Filter by topic…" className="w-56 rounded-full" value={filter.topic} onChange={(e) => setFilter({ ...filter, topic: e.target.value })} />
        <div className="text-sm text-[#64748B] ml-auto self-center font-medium">{items.length} total questions</div>
      </div>

      {/* Questions list */}
      <div className="mt-6 space-y-3">
        {items.map((q) => (
          <Card key={q._id} className="rounded-2xl border-slate-200 p-5 flex items-start justify-between gap-4" data-testid={`admin-q-row-${q._id}`}>
            <div className="flex-1">
              <div className="flex items-center gap-2 text-xs text-[#64748B] flex-wrap">
                <span className="uppercase tracking-widest text-[#7C3AED] font-semibold">{q.topic || "No topic"}</span>
                <span>· Class {q.class_level}</span>
                <span>· {q.q_type?.toUpperCase()}</span>
                <span>· +{q.positive_marks}/−{q.negative_marks}</span>
                <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${q.difficulty === "easy" ? "bg-green-100 text-green-700" : q.difficulty === "hard" ? "bg-red-100 text-red-700" : "bg-amber-100 text-amber-700"}`}>{q.difficulty}</span>

                {/* Status Badge */}
                {q.is_published !== false ? (
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase bg-emerald-100 text-emerald-800 border border-emerald-300 flex items-center gap-1">
                    <CheckCircle2 size={11} /> Published {q.publish_date || q.published_at?.slice(0, 10) || q.created_at?.slice(0, 10)}
                  </span>
                ) : (
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase bg-amber-100 text-amber-800 border border-amber-300">
                    Draft (Unpublished)
                  </span>
                )}
              </div>
              <div className="mt-2 text-[#0F1B4C] font-medium prose-sm max-w-none">
                {/^\s*</.test(q.question_text || "") ? <span dangerouslySetInnerHTML={{ __html: q.question_text }} /> : <MathText text={q.question_text} />}
              </div>
            </div>
            <div className="flex items-center gap-1 shrink-0">
              {q.is_published === false ? (
                <Button variant="outline" size="sm" onClick={() => togglePublish(q._id)} className="rounded-full text-xs font-semibold border-emerald-500 text-emerald-700 hover:bg-emerald-50 h-8 px-3">
                  Publish Now
                </Button>
              ) : (
                <Button variant="ghost" size="sm" onClick={() => togglePublish(q._id)} className="rounded-full text-xs text-slate-500 hover:bg-slate-100 h-8 px-2">
                  Unpublish
                </Button>
              )}
              <Button variant="ghost" size="icon" onClick={() => openEditPublished(q)} data-testid={`q-edit-${q._id}`}><Pencil size={16} /></Button>
              <Button variant="ghost" size="icon" onClick={() => del(q._id)} data-testid={`q-del-${q._id}`}><Trash2 size={16} className="text-red-500" /></Button>
            </div>
          </Card>
        ))}
        {items.length === 0 && <div className="text-center text-[#64748B] py-10">No questions found.</div>}
      </div>
      </div>
      )}
    </div>
  );
}
