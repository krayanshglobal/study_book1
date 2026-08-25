import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Edit, ArrowLeft } from "lucide-react";
import RichEditor from "@/components/RichEditor";

const empty = { title: "", content: "", subject: "maths", class_level: "10", topic: "", premium_only: false };

export default function ManageNotes() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [step, setStep] = useState(1);
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ ...empty, class_level: activeClass });
  const [editingId, setEditingId] = useState(null);

  const load = async () => {
    try {
      const params = {};
      if (activeClass !== "all") params.class_level = activeClass;
      const r = await api.get("/api/notes", { params });
      setItems(r.data.items || []);
    } catch (err) {
      toast.error("Failed to load study notes.");
    }
  };

  useEffect(() => {
    setForm((f) => ({ ...f, class_level: activeClass === "all" ? "8" : activeClass }));
    load();
  }, [activeClass]);

  const handleSelectClass = (cls) => {
    setActiveClass(cls);
    setStep(2);
  };

  const startEdit = (note) => {
    setEditingId(note._id);
    setForm({
      title: note.title,
      content: note.content,
      subject: note.subject,
      class_level: note.class_level,
      topic: note.topic,
      premium_only: note.premium_only || false,
    });
    setOpen(true);
  };

  const startAdd = () => {
    setEditingId(null);
    setForm({ ...empty, class_level: activeClass === "all" ? "8" : activeClass });
    setOpen(true);
  };

  const save = async () => {
    if (!form.title.trim() || !form.content.trim()) {
      toast.error("Please fill in title and content.");
      return;
    }
    try {
      if (editingId) {
        await api.put(`/api/notes/${editingId}`, form);
        toast.success("Study note updated successfully");
      } else {
        await api.post("/api/notes", form);
        toast.success("Study note published successfully");
      }
      setOpen(false);
      setForm(empty);
      setEditingId(null);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const del = async (id) => {
    if (!window.confirm("Are you sure you want to delete this study note?")) return;
    try {
      await api.delete(`/api/notes/${id}`);
      toast.success("Note deleted successfully");
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const classesList = [
    { id: "all", label: "All Classes", desc: "View and manage study notes across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Grade 8 Study Notes and Articles", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Grade 9 Study Notes and Articles", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Grade 10 Study Notes and Articles", tone: "bg-amber-50 text-amber-700 border-amber-200" },
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
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Study Notes — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to view or publish study notes.</p>

          <div className="mt-8 grid sm:grid-cols-2 gap-5">
            {classesList.map((c) => (
              <Card
                key={c.id}
                onClick={() => handleSelectClass(c.id)}
                className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
              >
                <div className="flex items-start justify-between">
                  <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                    <Plus size={24} />
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
                  <span>Manage Notes</span>
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
              <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Study Notes</div>
              <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
                {activeClass === "all" ? "All Study Notes" : `Class ${activeClass} Study Notes`}
              </h1>
            </div>
            <Button
              onClick={startAdd}
              data-testid="admin-add-note-btn"
              className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]"
            >
              <Plus size={16} className="mr-1" /> Add Note
            </Button>
          </div>

      <div className="mt-8 grid md:grid-cols-2 lg:grid-cols-3 gap-5">
        {items.map((n) => (
          <Card key={n._id} className="rounded-2xl border-slate-200 overflow-hidden flex flex-col justify-between shadow-sm hover:shadow-md transition-shadow">
            <div className="p-5 flex-1">
              <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">
                Class {n.class_level} · {n.subject} · {n.topic}
              </div>
              <h2 className="mt-2 font-serif text-xl text-[#0F1B4C] font-semibold">{n.title}</h2>
              <div
                className="mt-3 text-xs text-slate-500 line-clamp-3 leading-relaxed"
                dangerouslySetInnerHTML={{ __html: n.content.replace(/<[^>]*>?/gm, "").slice(0, 150) + "..." }}
              />
            </div>
            <div className="px-5 py-3 bg-slate-50/50 border-t border-slate-100 flex items-center justify-between">
              <div>
                {n.premium_only && <span className="text-[10px] bg-amber-500 text-white px-2 py-0.5 rounded-full uppercase tracking-wider font-bold">Premium</span>}
              </div>
              <div className="flex gap-1">
                <Button variant="ghost" size="icon" onClick={() => startEdit(n)}><Edit size={15} className="text-[#334155]" /></Button>
                <Button variant="ghost" size="icon" onClick={() => del(n._id)} data-testid={`note-del-${n._id}`}><Trash2 size={15} className="text-red-500" /></Button>
              </div>
            </div>
          </Card>
        ))}
        {items.length === 0 && (
          <div className="col-span-full text-center text-[#64748B] py-16 bg-slate-50 rounded-2xl border border-dashed border-slate-200">No study notes published yet.</div>
        )}
      </div>

      {/* CREATE / EDIT DIALOG */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-w-3xl rounded-3xl p-6 max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="font-serif text-xl text-[#0F1B4C]">
              {editingId ? "Edit Study Note" : "Create Study Note"}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Title</Label>
              <Input
                data-testid="note-title-input"
                className="mt-1 border-slate-200"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                placeholder="e.g. Fundamental Theorem of Algebra"
              />
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div>
                <Label>Class Level</Label>
                <Select value={form.class_level} onValueChange={(v) => setForm({ ...form, class_level: v })}>
                  <SelectTrigger className="mt-1 border-slate-200">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {["8", "9", "10"].map((c) => (
                      <SelectItem key={c} value={c}>Class {c}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Subject</Label>
                <Select value={form.subject} onValueChange={(v) => setForm({ ...form, subject: v })}>
                  <SelectTrigger className="mt-1 border-slate-200">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="maths">Mathematics</SelectItem>
                    <SelectItem value="science">Science</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Topic</Label>
                <Input
                  className="mt-1 border-slate-200"
                  value={form.topic}
                  onChange={(e) => setForm({ ...form, topic: e.target.value })}
                  placeholder="e.g. Trigonometry"
                />
              </div>
            </div>
            <div className="flex items-center gap-2">
              <Switch
                checked={form.premium_only}
                onCheckedChange={(v) => setForm({ ...form, premium_only: v })}
                id="np"
              />
              <Label htmlFor="np" className="cursor-pointer">Premium only (lock for non-paying users)</Label>
            </div>
            <div>
              <Label>Content (supports rich formatting, images, and math via $...$)</Label>
              <div className="mt-1">
                <RichEditor
                  value={form.content}
                  onChange={(html) => setForm({ ...form, content: html })}
                  placeholder="Explain the concepts, write math formulae (e.g. $E=mc^2$), upload diagrams..."
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" className="rounded-full" onClick={() => setOpen(false)}>Cancel</Button>
              <Button onClick={save} className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" data-testid="note-save-btn">
                {editingId ? "Save Changes" : "Publish Note"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
      </div>
      )}
    </div>
  );
}
