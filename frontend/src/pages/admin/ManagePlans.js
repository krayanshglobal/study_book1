import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Pencil } from "lucide-react";
import { inr } from "@/lib/format";

const empty = { name: "", description: "", price: 299, currency: "inr", duration_days: 30, features: [""], is_active: true };

export default function ManagePlans() {
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState(empty);
  const [editing, setEditing] = useState(null);

  const load = async () => { const r = await api.get("/api/admin/plans"); setItems(r.data.items || []); };
  useEffect(() => { load(); }, []);

  const save = async () => {
    try {
      const payload = { ...form, features: form.features.filter((f) => f.trim()) };
      if (editing) await api.put(`/api/admin/plans/${editing}`, payload);
      else await api.post("/api/admin/plans", payload);
      toast.success("Saved"); setOpen(false); setEditing(null); setForm(empty); load();
    } catch (err) { toast.error(formatApiError(err)); }
  };
  const del = async (id) => { if (!window.confirm("Delete?")) return; await api.delete(`/api/admin/plans/${id}`); load(); };
  const openEdit = (p) => { setForm({ ...empty, ...p, features: p.features || [""] }); setEditing(p._id); setOpen(true); };
  const openNew = () => { setForm(empty); setEditing(null); setOpen(true); };

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Monetise</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Subscription plans</h1>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild><Button onClick={openNew} data-testid="admin-add-plan-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]"><Plus size={16} className="mr-1" /> New plan</Button></DialogTrigger>
          <DialogContent>
            <DialogHeader><DialogTitle className="font-serif">{editing ? "Edit plan" : "New plan"}</DialogTitle></DialogHeader>
            <div className="space-y-3">
              <div><Label>Name</Label><Input data-testid="plan-name-input" className="mt-1" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} /></div>
              <div><Label>Description</Label><Textarea rows={2} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} /></div>
              <div className="grid grid-cols-3 gap-3">
                <div><Label>Price (₹)</Label><Input type="number" step="1" data-testid="plan-price-input" value={form.price} onChange={(e) => setForm({ ...form, price: parseFloat(e.target.value) })} className="mt-1" /></div>
                <div><Label>Currency</Label><Input value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value.toLowerCase() })} className="mt-1" placeholder="inr" /></div>
                <div><Label>Duration (days)</Label><Input type="number" data-testid="plan-days-input" value={form.duration_days} onChange={(e) => setForm({ ...form, duration_days: parseInt(e.target.value) })} className="mt-1" /></div>
              </div>
              <div>
                <Label>Features</Label>
                {form.features.map((f, i) => (
                  <Input key={i} value={f} onChange={(e) => { const c = [...form.features]; c[i] = e.target.value; setForm({ ...form, features: c }); }} className="mt-2" placeholder="Feature description" />
                ))}
                <Button variant="link" size="sm" onClick={() => setForm({ ...form, features: [...form.features, ""] })} className="mt-1 h-auto p-0 text-[#2563EB]">+ Add feature</Button>
              </div>
              <div className="flex items-center gap-2"><Switch checked={form.is_active} onCheckedChange={(v) => setForm({ ...form, is_active: v })} id="pa" /><Label htmlFor="pa">Active (visible to students)</Label></div>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" className="rounded-full" onClick={() => setOpen(false)}>Cancel</Button>
                <Button onClick={save} className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" data-testid="plan-save-btn">{editing ? "Update" : "Create"}</Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      <div className="mt-8 grid md:grid-cols-2 lg:grid-cols-3 gap-5">
        {items.map((p) => (
          <Card key={p._id} className="rounded-2xl border-slate-200 p-6" data-testid={`admin-plan-${p._id}`}>
            <div className="flex items-start justify-between">
              <div>
                <div className="font-serif text-xl text-[#0F1B4C] font-semibold">{p.name}</div>
                <div className="text-xs text-[#64748B]">{p.duration_days} days · {p.is_active ? "Active" : "Hidden"}</div>
              </div>
              <div className="text-right">
                <div className="font-serif text-2xl text-[#0F1B4C]">{inr(p.price)}</div>
                <div className="text-xs uppercase text-[#64748B]">{p.currency}</div>
              </div>
            </div>
            <p className="mt-3 text-sm text-[#475569]">{p.description}</p>
            <ul className="mt-3 space-y-1 text-sm text-[#334155] list-disc list-inside">
              {p.features?.map((f, i) => <li key={i}>{f}</li>)}
            </ul>
            <div className="mt-4 flex gap-1 justify-end">
              <Button variant="ghost" size="icon" onClick={() => openEdit(p)}><Pencil size={16} /></Button>
              <Button variant="ghost" size="icon" onClick={() => del(p._id)}><Trash2 size={16} className="text-red-500" /></Button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
