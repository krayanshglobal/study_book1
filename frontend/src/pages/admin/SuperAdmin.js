import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2 } from "lucide-react";

export default function SuperAdmin() {
  const [admins, setAdmins] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ name: "", email: "", phone: "", password: "" });

  const load = async () => { const r = await api.get("/api/admin/users", { params: { role: "admin" } }); setAdmins(r.data.items || []); };
  useEffect(() => { load(); }, []);

  const save = async () => {
    try { await api.post("/api/superadmin/admins", form); toast.success("Admin created"); setOpen(false); setForm({ name: "", email: "", phone: "", password: "" }); load(); }
    catch (err) { toast.error(formatApiError(err)); }
  };
  const del = async (id) => { if (!window.confirm("Remove this admin?")) return; await api.delete(`/api/superadmin/admins/${id}`); load(); };

  return (
    <div className="max-w-4xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">SuperAdmin</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Manage admins</h1>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild><Button data-testid="add-admin-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]"><Plus size={16} className="mr-1" /> New admin</Button></DialogTrigger>
          <DialogContent>
            <DialogHeader><DialogTitle className="font-serif">Create admin account</DialogTitle></DialogHeader>
            <div className="space-y-3">
              <div><Label>Name</Label><Input data-testid="new-admin-name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className="mt-1" /></div>
              <div><Label>Email</Label><Input type="email" data-testid="new-admin-email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} className="mt-1" /></div>
              <div><Label>Phone</Label><Input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} className="mt-1" /></div>
              <div><Label>Password</Label><Input type="password" data-testid="new-admin-password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} className="mt-1" /></div>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" className="rounded-full" onClick={() => setOpen(false)}>Cancel</Button>
                <Button onClick={save} className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" data-testid="new-admin-save-btn">Create</Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      <div className="mt-8 space-y-3">
        {admins.map((a) => (
          <Card key={a._id} className="rounded-2xl border-slate-200 p-5 flex items-center justify-between" data-testid={`admin-row-${a._id}`}>
            <div>
              <div className="font-medium text-[#0F1B4C]">{a.name}</div>
              <div className="text-sm text-[#64748B]">{a.email} · {a.phone}</div>
            </div>
            <Button variant="ghost" size="icon" onClick={() => del(a._id)}><Trash2 size={16} className="text-red-500" /></Button>
          </Card>
        ))}
        {admins.length === 0 && <div className="text-center text-[#64748B] py-10">No admins yet.</div>}
      </div>
    </div>
  );
}
