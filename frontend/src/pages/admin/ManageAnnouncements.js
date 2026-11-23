import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Trash2, Megaphone, Users, Shield, Globe, ArrowLeft, Plus, Image as ImageIcon, Pencil, X } from "lucide-react";

const emptyForm = (classLevel) => ({
  title: "", body: "", audience: "students", class_level: classLevel,
  active: true, image_url: "",
});
const mediaUrl = (url) => url?.startsWith("/api/")
  ? `${process.env.REACT_APP_BACKEND_URL || "http://localhost:8000"}${url}`
  : url;

export default function ManageAnnouncements() {
  const [activeClass, setActiveClass] = useState(localStorage.getItem("admin_class_level") || "8");
  const [step, setStep] = useState(1);
  const [items, setItems] = useState([]);
  const [form, setForm] = useState(() => emptyForm(activeClass));
  const [editingId, setEditingId] = useState(null);
  const [uploading, setUploading] = useState(false);
  const fileInputRef = React.useRef(null);

  const str = (v) => String(v || "");

  const load = async () => {
    try {
      const r = await api.get("/api/announcements", { params: { admin_view: true } });
      let filtered = r.data.items || [];
      if (activeClass !== "all") {
        filtered = filtered.filter((a) => !a.class_level || str(a.class_level) === str(activeClass) || a.class_level === "all");
      }
      setItems(filtered);
    } catch {}
  };

  useEffect(() => {
    setForm((f) => ({ ...f, class_level: activeClass }));
    load();
  }, [activeClass]);

  const handleSelectClass = (cls) => {
    setActiveClass(cls);
    setStep(2);
  };

  const save = async () => {
    if (!form.title.trim() || !form.body.trim()) { toast.error("Title and message are required"); return; }
    try {
      const payload = { ...form, class_level: form.class_level === "all" ? null : form.class_level };
      if (editingId) await api.put(`/api/announcements/${editingId}`, payload);
      else await api.post("/api/announcements", payload);
      toast.success(editingId ? "Announcement updated!" : "Announcement broadcast!");
      setEditingId(null);
      setForm(emptyForm(activeClass));
      load();
    } catch (err) { toast.error(formatApiError(err)); }
  };

  const uploadImage = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const data = new FormData();
      data.append("file", file);
      const response = await api.post("/api/uploads/image", data, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      setForm((current) => ({ ...current, image_url: response.data.url }));
      toast.success("Announcement image uploaded");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setUploading(false);
      event.target.value = "";
    }
  };

  const edit = (announcement) => {
    setEditingId(announcement._id);
    setForm({
      title: announcement.title || "",
      body: announcement.body || "",
      audience: announcement.audience || "students",
      class_level: announcement.class_level || "all",
      active: announcement.active !== false,
      image_url: announcement.image_url || "",
    });
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const cancelEdit = () => {
    setEditingId(null);
    setForm(emptyForm(activeClass));
  };

  const del = async (id) => {
    if (!window.confirm("Delete this announcement?")) return;
    try {
      await api.delete(`/api/announcements/${id}`);
      toast.success("Deleted");
      load();
    } catch (err) { toast.error(formatApiError(err)); }
  };

  const audienceIcon = (a) => {
    if (a === "students") return <Users size={12} />;
    if (a === "admins") return <Shield size={12} />;
    return <Globe size={12} />;
  };

  const audienceColor = (a) => {
    if (a === "students") return "bg-blue-100 text-blue-700";
    if (a === "admins") return "bg-violet-100 text-violet-700";
    return "bg-slate-100 text-slate-600";
  };

  const classesList = [
    { id: "all", label: "All Classes", desc: "Broadcast announcements to all grade levels globally", tone: "bg-purple-50 text-[#7C3AED] border-purple-200" },
    { id: "8", label: "Class 8", desc: "Grade 8 Class Notifications and Broadcasts", tone: "bg-blue-50 text-[#2563EB] border-blue-200" },
    { id: "9", label: "Class 9", desc: "Grade 9 Class Notifications and Broadcasts", tone: "bg-emerald-50 text-emerald-700 border-emerald-200" },
    { id: "10", label: "Class 10", desc: "Grade 10 Class Notifications and Broadcasts", tone: "bg-amber-50 text-amber-700 border-amber-200" },
  ];

  return (
    <div className="max-w-5xl mx-auto px-6 sm:px-10 py-10">
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
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Announcements — Select Class</h1>
          <p className="mt-1 text-[#64748B] text-sm">Choose a class level to broadcast or manage class notifications.</p>

          <div className="mt-8 grid sm:grid-cols-2 gap-5">
            {classesList.map((c) => (
              <Card
                key={c.id}
                onClick={() => handleSelectClass(c.id)}
                className="p-6 rounded-3xl border-slate-200 hover:border-[#7C3AED] hover:shadow-xl transition-all cursor-pointer bg-white group flex flex-col justify-between"
              >
                <div className="flex items-start justify-between">
                  <div className={`w-12 h-12 rounded-2xl grid place-items-center border ${c.tone}`}>
                    <Megaphone size={24} />
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
                  <span>Manage Class Broadcasts</span>
                  <Plus size={16} className="group-hover:translate-x-1 transition-transform" />
                </div>
              </Card>
            ))}
          </div>
        </div>
      ) : (
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Broadcast</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">
            {activeClass === "all" ? "All Class Announcements" : `Class ${activeClass} Announcements`}
          </h1>

          {/* Compose form */}
          <Card className="mt-6 rounded-2xl border-slate-200 p-6">
            <div className="space-y-4">
              <div>
                <Label>Title</Label>
                <Input
                  data-testid="ann-title-input"
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  className="mt-1"
                  placeholder="e.g. Test on Monday"
                />
              </div>
              <div>
                <Label>Message</Label>
                <Textarea
                  rows={3}
                  data-testid="ann-body-input"
                  value={form.body}
                  onChange={(e) => setForm({ ...form, body: e.target.value })}
                  placeholder="Write your announcement here…"
                />
              </div>
              <div>
                <div className="flex items-center justify-between gap-3">
                  <Label>Announcement image (optional)</Label>
                  <input ref={fileInputRef} type="file" accept="image/jpeg,image/png,image/webp,image/gif" className="hidden" onChange={uploadImage} />
                  <Button type="button" variant="outline" size="sm" disabled={uploading} onClick={() => fileInputRef.current?.click()} className="rounded-full gap-1">
                    <ImageIcon size={14} /> {uploading ? "Uploading…" : "Upload image"}
                  </Button>
                </div>
                {form.image_url && (
                  <div className="mt-3 relative w-full max-w-md overflow-hidden rounded-xl border bg-slate-50">
                    <img src={mediaUrl(form.image_url)} alt="Announcement preview" className="w-full max-h-52 object-cover" />
                    <button type="button" onClick={() => setForm({ ...form, image_url: "" })} className="absolute right-2 top-2 rounded-full bg-black/60 p-1.5 text-white" aria-label="Remove image">
                      <X size={14} />
                    </button>
                  </div>
                )}
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <Label>Audience</Label>
                  <Select value={form.audience} onValueChange={(v) => setForm({ ...form, audience: v })}>
                    <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All</SelectItem>
                      <SelectItem value="students">Students only</SelectItem>
                      <SelectItem value="admins">Admins only</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <div>
                  <Label>Target Class</Label>
                  <Select value={form.class_level || "all"} onValueChange={(v) => setForm({ ...form, class_level: v })}>
                    <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">All Classes</SelectItem>
                      <SelectItem value="8">Class 8</SelectItem>
                      <SelectItem value="9">Class 9</SelectItem>
                      <SelectItem value="10">Class 10</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <div className="flex justify-end gap-2">
                {editingId && <Button type="button" variant="outline" onClick={cancelEdit} className="rounded-full">Cancel</Button>}
                <Button onClick={save} data-testid="send-ann-btn" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">
                  {editingId ? "Save Changes" : "Broadcast Announcement"}
                </Button>
              </div>
            </div>
          </Card>

          {/* List */}
          <div className="mt-8 space-y-3">
            <h2 className="font-serif text-xl text-[#0F1B4C] font-semibold">Active Announcements ({items.length})</h2>
            {items.map((ann) => (
              <Card key={ann._id} className="p-5 rounded-2xl border-slate-200 flex items-start justify-between gap-4 bg-white">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap mb-2">
                    <span className={`inline-flex items-center gap-1 text-[10px] uppercase tracking-wider font-semibold px-2.5 py-0.5 rounded-full ${audienceColor(ann.audience)}`}>
                      {audienceIcon(ann.audience)} {ann.audience}
                    </span>
                    {ann.class_level ? (
                      <span className="text-[10px] bg-purple-100 text-purple-700 font-bold px-2.5 py-0.5 rounded-full uppercase tracking-wider">
                        Class {ann.class_level}
                      </span>
                    ) : (
                      <span className="text-[10px] bg-slate-100 text-slate-500 font-bold px-2.5 py-0.5 rounded-full uppercase tracking-wider">
                        All Classes
                      </span>
                    )}
                  </div>
                  <h3 className="font-serif text-lg text-[#0F1B4C] font-semibold">{ann.title}</h3>
                  <p className="text-sm text-[#475569] mt-1">{ann.body}</p>
                  {ann.image_url && <img src={mediaUrl(ann.image_url)} alt="" className="mt-3 w-full max-w-sm max-h-40 rounded-xl object-cover border" />}
                  {ann.created_at && (
                    <div className="text-xs text-slate-400 mt-2">
                      {new Date(ann.created_at).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" })}
                    </div>
                  )}
                </div>

                <div className="shrink-0 flex gap-1">
                  <Button variant="ghost" size="sm" onClick={() => edit(ann)} className="text-blue-600 hover:bg-blue-50 rounded-xl gap-1"><Pencil size={15} /> Edit</Button>
                  <Button variant="ghost" size="sm" onClick={() => del(ann._id)} className="text-red-500 hover:text-red-700 hover:bg-red-50 rounded-xl gap-1"><Trash2 size={15} /> Delete</Button>
                </div>
              </Card>
            ))}
            {items.length === 0 && (
              <div className="text-center text-[#64748B] py-16 bg-slate-50 rounded-2xl border border-slate-200">
                <Megaphone className="mx-auto mb-3 text-slate-300" size={36} />
                No announcements for Class {activeClass}.
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
