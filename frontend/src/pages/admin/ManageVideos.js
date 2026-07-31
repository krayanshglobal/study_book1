import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Pencil } from "lucide-react";

const empty = { title: "", description: "", url: "", thumbnail_url: "", subject: "maths", class_level: "10", topic: "", premium_only: false };

export default function ManageVideos() {
  const adminClass = localStorage.getItem("admin_class_level") || "8";
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ ...empty, class_level: adminClass });
  const [editing, setEditing] = useState(null);

  const load = useCallback(async () => {
    const r = await api.get("/api/videos", { params: { class_level: adminClass } });
    setItems(r.data.items || []);
  }, [adminClass]);

  useEffect(() => {
    setForm((f) => ({ ...f, class_level: adminClass }));
    load();
  }, [adminClass, load]);

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
      setForm({ ...empty, class_level: adminClass });
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
    setForm({ ...empty, class_level: adminClass });
    setEditing(null);
    setOpen(true);
  };

  const del = async (id) => { if (!window.confirm("Delete?")) return; await api.delete(`/api/videos/${id}`); toast.success("Deleted"); load(); };

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Learn</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Video lessons</h1>
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
  );
}
