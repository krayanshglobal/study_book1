import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Pencil, Upload, Download, Send, BookOpen, CheckCircle2 } from "lucide-react";
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
};

export default function ManageQuestions() {
  const adminClass = localStorage.getItem("admin_class_level") || "8";

  // Published questions list
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState({ class_level: adminClass, topic: "" });

  // Batch staging — questions ready to publish
  const [batch, setBatch] = useState([]);

  // Form state for current question being composed
  const [form, setForm] = useState({ ...emptyQ, class_level: adminClass });
  const [open, setOpen] = useState(false);
  const [editingPublished, setEditingPublished] = useState(null); // for editing already-published questions

  const load = async () => {
    const params = { limit: 200 };
    if (filter.class_level !== "all") params.class_level = filter.class_level;
    if (filter.topic) params.topic = filter.topic;
    const r = await api.get("/api/questions", { params });
    setItems(r.data.items || []);
  };

  useEffect(() => { setFilter((f) => ({ ...f, class_level: adminClass })); }, [adminClass]);
  useEffect(() => { load(); }, [filter]); // eslint-disable-line

  const setF = (k, v) => setForm((s) => ({ ...s, [k]: v }));
  const setOpt = (i, v) => setForm((s) => { const opts = [...s.options]; opts[i] = { ...opts[i], text: v }; return { ...s, options: opts }; });

  // Add question to staging batch (not yet published)
  const addToBatch = () => {
    if (!form.question_text.trim()) { toast.error("Question text is required"); return; }
    setBatch((prev) => [...prev, { ...form, _batchId: Date.now() }]);
    setForm({ ...emptyQ, class_level: form.class_level }); // reset but keep same class
    toast.success("Added to batch! Add more or publish all.");
  };

  // Remove from staging
  const removeFromBatch = (batchId) => setBatch((prev) => prev.filter((q) => q._batchId !== batchId));

  // Publish all staged questions at once
  const publishBatch = async () => {
    if (batch.length === 0) { toast.error("No questions staged yet"); return; }
    try {
      let success = 0;
      for (const q of batch) {
        const payload = { ...q };
        delete payload._batchId;
        if (q.q_type === "typed") payload.options = null;
        await api.post("/api/questions", payload);
        success++;
      }
      toast.success(`Published ${success} question${success > 1 ? "s" : ""}!`);
      setBatch([]);
      setOpen(false);
      load();
    } catch (err) { toast.error(formatApiError(err)); }
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

  const QuestionForm = () => (
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
            <SelectContent><SelectItem value="mcq">MCQ</SelectItem><SelectItem value="typed">Typed</SelectItem></SelectContent>
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
      ) : (
        <div><Label>Correct typed answer</Label><Input data-testid="q-typed-correct" className="mt-1 font-mono" value={form.correct_answer_text} onChange={(e) => setF("correct_answer_text", e.target.value)} /></div>
      )}

      <div><Label>Explanation</Label><Textarea rows={2} value={form.explanation} onChange={(e) => setF("explanation", e.target.value)} /></div>

      <div className="grid grid-cols-3 gap-3">
        <div><Label>+ marks</Label><Input type="number" step="0.25" value={form.positive_marks} onChange={(e) => setF("positive_marks", parseFloat(e.target.value))} /></div>
        <div><Label>− marks</Label><Input type="number" step="0.25" value={form.negative_marks} onChange={(e) => setF("negative_marks", parseFloat(e.target.value))} /></div>
        <div><Label>Difficulty</Label>
          <Select value={form.difficulty} onValueChange={(v) => setF("difficulty", v)}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent><SelectItem value="easy">Easy</SelectItem><SelectItem value="medium">Medium</SelectItem><SelectItem value="hard">Hard</SelectItem></SelectContent>
          </Select>
        </div>
      </div>
      <div><Label>Image URL (optional)</Label><Input value={form.image_url} onChange={(e) => setF("image_url", e.target.value)} placeholder="https://…" /></div>
    </div>
  );

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Content</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Question bank</h1>
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
          <Button onClick={() => { setEditingPublished(null); setForm({ ...emptyQ, class_level: adminClass }); setOpen(true); }} data-testid="admin-add-question-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]">
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
          <QuestionForm />

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
          <div className="flex justify-between gap-2 pt-3 border-t border-slate-100 mt-2">
            <Button variant="outline" className="rounded-full" onClick={() => { setOpen(false); setEditingPublished(null); }}>Cancel</Button>
            {editingPublished ? (
              <Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" onClick={saveEditPublished}>Update Question</Button>
            ) : (
              <div className="flex gap-2">
                <Button variant="outline" className="rounded-full border-[#7C3AED] text-[#7C3AED] hover:bg-violet-50" onClick={addToBatch}>
                  <Plus size={15} className="mr-1" /> Add to Batch
                </Button>
                <Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" onClick={publishBatch} disabled={batch.length === 0}>
                  <Send size={15} className="mr-1" /> Publish All ({batch.length})
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
        <Input placeholder="Filter by topic…" className="w-64 rounded-full" value={filter.topic} onChange={(e) => setFilter({ ...filter, topic: e.target.value })} />
        <div className="text-sm text-[#64748B] ml-auto self-center">{items.length} total</div>
      </div>

      {/* Published questions list */}
      <div className="mt-6 space-y-3">
        {items.map((q) => (
          <Card key={q._id} className="rounded-2xl border-slate-200 p-5 flex items-start justify-between gap-4" data-testid={`admin-q-row-${q._id}`}>
            <div className="flex-1">
              <div className="flex items-center gap-2 text-xs text-[#64748B]">
                <span className="uppercase tracking-widest text-[#7C3AED] font-semibold">{q.topic}</span>
                <span>· Class {q.class_level}</span>
                <span>· {q.q_type.toUpperCase()}</span>
                <span>· +{q.positive_marks}/−{q.negative_marks}</span>
                <span className={`ml-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${q.difficulty === "easy" ? "bg-green-100 text-green-700" : q.difficulty === "hard" ? "bg-red-100 text-red-700" : "bg-amber-100 text-amber-700"}`}>{q.difficulty}</span>
              </div>
              <div className="mt-1 text-[#0F1B4C] font-medium prose-sm max-w-none">
                {/^\s*</.test(q.question_text || "") ? <span dangerouslySetInnerHTML={{ __html: q.question_text }} /> : <MathText text={q.question_text} />}
              </div>
            </div>
            <div className="flex gap-1 shrink-0">
              <Button variant="ghost" size="icon" onClick={() => openEditPublished(q)} data-testid={`q-edit-${q._id}`}><Pencil size={16} /></Button>
              <Button variant="ghost" size="icon" onClick={() => del(q._id)} data-testid={`q-del-${q._id}`}><Trash2 size={16} className="text-red-500" /></Button>
            </div>
          </Card>
        ))}
        {items.length === 0 && <div className="text-center text-[#64748B] py-10">No questions.</div>}
      </div>
    </div>
  );
}
