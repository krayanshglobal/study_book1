import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Trash2, Megaphone, Users, Shield, Globe } from "lucide-react";

export default function ManageAnnouncements() {
  const [items, setItems] = useState([]);
  const [form, setForm] = useState({ title: "", body: "", audience: "students", class_level: "all", active: true });

  // Use admin_view=true so ALL announcements are returned regardless of audience
  const load = async () => {
    const r = await api.get("/api/announcements", { params: { admin_view: true } });
    setItems(r.data.items || []);
  };
  useEffect(() => { load(); }, []);

  const save = async () => {
    if (!form.title.trim() || !form.body.trim()) { toast.error("Title and message are required"); return; }
    try {
      const payload = { ...form, class_level: form.class_level === "all" ? null : form.class_level };
      await api.post("/api/announcements", payload);
      toast.success("Announcement broadcast!");
      setForm({ title: "", body: "", audience: "students", class_level: "all", active: true });
      load();
    } catch (err) { toast.error(formatApiError(err)); }
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

  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Broadcast</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Announcements</h1>

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
              <Label>Class</Label>
              <Select value={form.class_level} onValueChange={(v) => setForm({ ...form, class_level: v })}>
                <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Classes</SelectItem>
                  <SelectItem value="8">Class 8 only</SelectItem>
                  <SelectItem value="9">Class 9 only</SelectItem>
                  <SelectItem value="10">Class 10 only</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <div className="flex justify-end">
            <Button
              onClick={save}
              data-testid="ann-save-btn"
              className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] flex items-center gap-2"
            >
              <Megaphone size={15} /> Broadcast
            </Button>
          </div>
        </div>
      </Card>

      {/* Broadcasted list */}
      <div className="mt-8">
        <div className="flex items-center justify-between mb-4">
          <h2 className="font-serif text-xl text-[#0F1B4C] font-semibold">
            Broadcasted <span className="text-slate-400 font-normal text-base">({items.length})</span>
          </h2>
        </div>

        <div className="space-y-3">
          {items.map((a) => (
            <Card key={a._id} className="rounded-2xl border-slate-200 p-5">
              <div className="flex items-start justify-between gap-4">
                <div className="flex-1 min-w-0">
                  {/* Badges */}
                  <div className="flex items-center gap-2 flex-wrap mb-2">
                    <span className={`inline-flex items-center gap-1 text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider ${audienceColor(a.audience)}`}>
                      {audienceIcon(a.audience)} {a.audience}
                    </span>
                    {a.class_level ? (
                      <span className="text-[10px] bg-indigo-100 text-indigo-700 font-bold px-2 py-0.5 rounded-full uppercase tracking-wider">
                        Class {a.class_level}
                      </span>
                    ) : (
                      <span className="text-[10px] bg-slate-100 text-slate-500 font-bold px-2 py-0.5 rounded-full uppercase tracking-wider">
                        All Classes
                      </span>
                    )}
                  </div>
                  <div className="font-serif text-lg text-[#0F1B4C] font-semibold">{a.title}</div>
                  <div className="text-sm text-[#475569] mt-1">{a.body}</div>
                  {a.created_at && (
                    <div className="text-xs text-slate-400 mt-2">
                      {new Date(a.created_at).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" })}
                    </div>
                  )}
                </div>

                {/* Delete button */}
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => del(a._id)}
                  className="shrink-0 text-red-500 hover:text-red-700 hover:bg-red-50 rounded-xl flex items-center gap-1"
                >
                  <Trash2 size={15} /> Delete
                </Button>
              </div>
            </Card>
          ))}
          {items.length === 0 && (
            <div className="text-center text-[#64748B] py-16">
              <Megaphone className="mx-auto mb-3 text-slate-300" size={36} />
              No announcements yet.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
