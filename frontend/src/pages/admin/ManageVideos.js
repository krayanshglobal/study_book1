import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Pencil, ArrowLeft } from "lucide-react";

const empty = { title: "", description: "", url: "", thumbnail_url: "", subject: "maths", class_level: "10", topic: "", premium_only: false };

export default function ManageVideos() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [step, setStep] = useState(1);
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ ...empty, class_level: activeClass });
  const [editing, setEditing] = useState(null);

  const load = useCallback(async () => {
    const params = {};
    if (activeClass !== "all") params.class_level = activeClass;
    const r = await api.get("/api/videos", { params });
    setItems(r.data.items || []);
  }, [activeClass]);

  useEffect(() => {
    setForm((f) => ({ ...f, class_level: activeClass === "all" ? "8" : activeClass }));
    load();
  }, [activeClass, load]);

  const handleSelectClass = (cls) => {
    setActiveClass(cls);
    setStep(2);
  };

  const save = async () => {
    try {
      if (editing) {
        await api.put(`/api/videos/${editing}`, form);
        toast.success("Video updated");
      } else {
        await api.post("/api/videos", form);
        toast.success("Video published");
      }
      setOpen(false);
      setEditing(null);
      setForm({ ...empty, class_level: activeClass === "all" ? "8" : activeClass });
      load();
    }
    catch (err) { toast.error(formatApiError(err)); }
  };

  const openEdit = (v) => {
    setForm({ title: v.title, description: v.description || "", url: v.url, thumbnail_url: v.thumbnail_url || "", subject: v.subject, class_level: v.class_level, topic: v.topic || "", premium_only: v.premium_only || false });
    setEditing(v._id);
    setOpen(true);
  };

  const openNew = () => {
    setForm({ ...empty, class_level: activeClass === "all" ? "8" : activeClass });
    setEditing(null);
    setOpen(true);
  };

  const del = async (id) => { if (!window.confirm("Delete?")) return; await api.delete(`/api/videos/${id}`); toast.success("Deleted"); load(); };

  const classesList = [
    { id: "all", label: "All Classes", desc: "View and manage video lessons across all grade levels", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Grade 8 Video Lessons and Lectures", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Grade 9 Video Lessons and Lectures", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Grade 10 Video Lessons and Lectures", tone: "bg-amber-50 text-amber-700 border-amber-200" },
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
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Manage Videos — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to view or publish video lessons.</p>

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
                  <span>Manage Videos</span>
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
              <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Video Lessons</div>
              <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
                {activeClass === "all" ? "All Video Lessons" : `Class ${activeClass} Videos`}
              </h1>
            </div>
            <Dialog open={open} onOpenChange={(v) => { setOpen(v); if (!v) setEditing(null); }}>
              <DialogTrigger asChild><Button onClick={openNew} data-testid="admin-add-video-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]"><Plus size={16} className="mr-1" /> Add video</Button></DialogTrigger>
              <DialogContent>
                <DialogHeader><DialogTitle className="font-serif">{editing ? "Edit video" : "New video lesson"}</DialogTitle></DialogHeader>
                <div className="space-y-3">
                  <div><Label>Title</Label><Input data-testid="video-title-input" className="mt-1" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} /></div>
                  <div><Label>Description</Label><Textarea rows={2} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></div>
                  <div><Label>YouTube URL</Label><Input data-testid="video-url-input" className="mt-1" value={form.url} onChange={(e) => setForm({ ...form, url: e.target.value })} placeholder="https://www.youtube.com/watch?v=…" /></div>
                  <div><Label>Thumbnail URL (optional)</Label><Input value={form.thumbnail_url} onChange={(e) => setForm({ ...form, thumbnail_url: e.target.value })} className="mt-1" /></div>
                  <div className="grid grid-cols-2 gap-3">
                    <div><Label>Class</Label><Select value={form.class_level} onValueChange={(v) => setForm({ ...form, class_level: v })}><SelectTrigger className="mt-1"><SelectValue /></SelectTrigger><SelectContent>{["8","9","10"].map((c) => <SelectItem key={c} value={c}>Class {c}</SelectItem>)}</SelectContent></Select></div>
                    <div><Label>Topic</Label><Input className="mt-1" value={form.topic} onChange={(e) => setForm({ ...form, topic: e.target.value })} /></div>
                  </div>
                  <div className="flex items-center gap-2"><Switch checked={form.premium_only} onCheckedChange={(v) => setForm({ ...form, premium_only: v })} id="vp" /><Label htmlFor="vp">Premium only</Label></div>
                  <div className="flex justify-end gap-2 pt-2">
                    <Button variant="outline" className="rounded-full" onClick={() => { setOpen(false); setEditing(null); }}>Cancel</Button>
                    <Button onClick={save} className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" data-testid="video-save-btn">{editing ? "Update" : "Publish"}</Button>
                  </div>
                </div>
              </DialogContent>
            </Dialog>
          </div>

          <div className="mt-8 grid md:grid-cols-2 lg:grid-cols-3 gap-5">
            {items.map((v) => (
              <Card key={v._id} className="rounded-2xl border-slate-200 overflow-hidden">
                <img src={v.thumbnail_url || "https://images.unsplash.com/photo-1509228468518-180dd4864904"} alt="" className="w-full h-40 object-cover" />
                <div className="p-5">
                  <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">Class {v.class_level} · {v.topic}</div>
                  <div className="mt-1 font-serif text-lg text-[#0F1B4C]">{v.title}</div>
                  <a href={v.url} target="_blank" rel="noreferrer" className="mt-1 text-xs text-[#2563EB] hover:underline truncate block">{v.url}</a>
                  <div className="mt-3 flex justify-between items-center">
                    {v.premium_only && <span className="text-xs bg-amber-500 text-white px-2 py-0.5 rounded">Premium</span>}
                    <div className="flex gap-1 ml-auto">
                      <Button variant="ghost" size="icon" onClick={() => openEdit(v)} data-testid={`video-edit-${v._id}`}><Pencil size={15} /></Button>
                      <Button variant="ghost" size="icon" onClick={() => del(v._id)} data-testid={`video-del-${v._id}`}><Trash2 size={16} className="text-red-500" /></Button>
                    </div>
                  </div>
                </div>
              </Card>
            ))}
            {items.length === 0 && <div className="col-span-full text-center text-[#64748B] py-10">No videos yet.</div>}
          </div>
        </div>
      )}
    </div>
  );
}
