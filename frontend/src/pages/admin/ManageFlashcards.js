import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Switch } from "@/components/ui/switch";
import { toast } from "sonner";
import { Plus, Trash2, Pencil, RefreshCw } from "lucide-react";

const empty = {
  subject: "maths", class_level: "10", topic: "", front: "", back: "",
};

export default function ManageFlashcards() {
  const adminClass = localStorage.getItem("admin_class_level") || "8";
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ ...empty, class_level: adminClass });
  const [editing, setEditing] = useState(null);
  const [loading, setLoading] = useState(false);
  const [filter, setFilter] = useState({ class_level: adminClass, topic: "" });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get("/api/flashcards", {
        params: {
          class_level: filter.class_level !== "all" ? filter.class_level : undefined,
          topic: filter.topic || undefined,
        },
      });
      setItems(r.data.items || []);
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [filter]);

  useEffect(() => {
    setFilter((f) => ({ ...f, class_level: adminClass }));
  }, [adminClass]);

  useEffect(() => { load(); }, [load]);

  const openNew = () => {
    setForm({ ...empty, class_level: adminClass });
    setEditing(null);
    setOpen(true);
  };

  const openEdit = (fc) => {
    setForm({ subject: fc.subject, class_level: fc.class_level, topic: fc.topic, front: fc.front, back: fc.back });
    setEditing(fc._id);
    setOpen(true);
  };

  const save = async () => {
    if (!form.front.trim() || !form.back.trim()) {
      toast.error("Front and back are required");
      return;
    }
    try {
      if (editing) {
        await api.put(`/api/flashcards/${editing}`, form);
        toast.success("Flashcard updated");
      } else {
        await api.post("/api/flashcards", form);
        toast.success("Flashcard created");
      }
      setOpen(false);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const del = async (id) => {
    if (!window.confirm("Delete this flashcard?")) return;
    try {
      await api.delete(`/api/flashcards/${id}`);
      toast.success("Deleted");
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Study Tools</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Flashcards</h1>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button onClick={openNew} className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]">
              <Plus size={16} className="mr-1" /> Add flashcard
            </Button>
          </DialogTrigger>
          <DialogContent className="max-w-lg">
            <DialogHeader>
              <DialogTitle className="font-serif">{editing ? "Edit flashcard" : "New flashcard"}</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <div className="grid grid-cols-3 gap-3">
                <div>
                  <Label>Class</Label>
                  <Select value={form.class_level} onValueChange={(v) => setForm((f) => ({ ...f, class_level: v }))}>
                    <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      {["8","9","10"].map((c) => <SelectItem key={c} value={c}>Class {c}</SelectItem>)}
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Subject</Label>
                  <Input className="mt-1" value={form.subject} onChange={(e) => setForm((f) => ({ ...f, subject: e.target.value }))} />
                </div>
                <div>
                  <Label>Topic</Label>
                  <Input className="mt-1" value={form.topic} onChange={(e) => setForm((f) => ({ ...f, topic: e.target.value }))} />
                </div>
              </div>
              <div>
                <Label>Front (question / term)</Label>
                <textarea
                  className="mt-1 w-full min-h-[80px] rounded-md border border-slate-200 px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/40"
                  value={form.front}
                  onChange={(e) => setForm((f) => ({ ...f, front: e.target.value }))}
                  placeholder="e.g. What is sin(30°)?"
                />
              </div>
              <div>
                <Label>Back (answer)</Label>
                <textarea
                  className="mt-1 w-full min-h-[80px] rounded-md border border-slate-200 px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-[#7C3AED]/40"
                  value={form.back}
                  onChange={(e) => setForm((f) => ({ ...f, back: e.target.value }))}
                  placeholder="e.g. 1/2"
                />
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" className="rounded-full" onClick={() => setOpen(false)}>Cancel</Button>
                <Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" onClick={save}>
                  {editing ? "Update" : "Create"}
                </Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      {/* Filters */}
      <div className="mt-6 flex gap-3 flex-wrap">
        <Select value={filter.class_level} onValueChange={(v) => setFilter((f) => ({ ...f, class_level: v }))}>
          <SelectTrigger className="w-40 rounded-full"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All classes</SelectItem>
            <SelectItem value="8">Class 8</SelectItem>
            <SelectItem value="9">Class 9</SelectItem>
            <SelectItem value="10">Class 10</SelectItem>
          </SelectContent>
        </Select>
        <Input
          placeholder="Filter by topic…"
          className="w-56 rounded-full"
          value={filter.topic}
          onChange={(e) => setFilter((f) => ({ ...f, topic: e.target.value }))}
        />
        <div className="text-sm text-[#64748B] self-center ml-auto">{items.length} cards</div>
      </div>

      {/* Cards grid */}
      {loading ? (
        <div className="mt-16 text-center text-[#64748B]">
          <RefreshCw size={20} className="animate-spin mx-auto mb-2" /> Loading flashcards…
        </div>
      ) : items.length === 0 ? (
        <div className="mt-16 text-center text-[#64748B]">No flashcards yet. Create one above.</div>
      ) : (
        <div className="mt-6 grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {items.map((fc) => (
            <Card key={fc._id} className="rounded-2xl border-slate-200 p-5">
              <div className="flex items-start justify-between gap-2">
                <div className="text-xs text-[#7C3AED] uppercase tracking-widest font-semibold truncate">
                  {fc.topic} · Class {fc.class_level}
                </div>
                <div className="flex gap-1 shrink-0">
                  <Button variant="ghost" size="icon" onClick={() => openEdit(fc)}>
                    <Pencil size={13} />
                  </Button>
                  <Button variant="ghost" size="icon" onClick={() => del(fc._id)}>
                    <Trash2 size={13} className="text-red-500" />
                  </Button>
                </div>
              </div>
              <div className="mt-3 border-t border-slate-100 pt-3">
                <div className="text-xs uppercase tracking-widest text-[#64748B] mb-1">Front</div>
                <div className="text-[#0F1B4C] text-sm font-medium">{fc.front}</div>
              </div>
              <div className="mt-3 border-t border-slate-100 pt-3">
                <div className="text-xs uppercase tracking-widest text-[#64748B] mb-1">Back</div>
                <div className="text-[#334155] text-sm">{fc.back}</div>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
