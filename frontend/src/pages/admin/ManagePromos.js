import React, { useEffect, useState } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { Plus, Trash2, Calendar, Tag, Link as LinkIcon } from "lucide-react";

const empty = { title: "", subtitle: "", code: "", link_url: "", countdown_hours: 24, is_active: true };

export default function ManagePromos() {
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState(empty);

  const load = async () => {
    try {
      const r = await api.get("/api/promos");
      setItems(r.data.items || []);
    } catch (err) {
      toast.error("Failed to load promo banners.");
    }
  };

  useEffect(() => {
    load();
  }, []);

  const save = async () => {
    if (!form.title.trim() || !form.subtitle.trim()) {
      toast.error("Please fill in title and description.");
      return;
    }
    try {
      await api.post("/api/promos", form);
      toast.success("Promo offer published successfully!");
      setOpen(false);
      setForm(empty);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  const del = async (id) => {
    if (!window.confirm("Are you sure you want to delete this offer?")) return;
    try {
      await api.delete(`/api/promos/${id}`);
      toast.success("Offer deleted.");
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Promotions</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Offers & Promo Banners</h1>
          <p className="text-slate-500 text-sm mt-1">Manage discounts, optional codes, links, and tickers displayed to students on their dashboard.</p>
        </div>
        <Dialog open={open} onOpenChange={setOpen}>
          <DialogTrigger asChild>
            <Button data-testid="admin-add-promo-btn" className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9]">
              <Plus size={16} className="mr-1" /> Add Offer Banner
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle className="font-serif">New Promo Offer</DialogTitle>
            </DialogHeader>
            <div className="space-y-4">
              <div>
                <Label>Offer Banner Title *</Label>
                <Input
                  className="mt-1"
                  value={form.title}
                  onChange={(e) => setForm({ ...form, title: e.target.value })}
                  placeholder="e.g. ₹200 off for New Users"
                />
              </div>
              <div>
                <Label>Subtitle / Description *</Label>
                <Input
                  className="mt-1"
                  value={form.subtitle}
                  onChange={(e) => setForm({ ...form, subtitle: e.target.value })}
                  placeholder="e.g. Join StudyBook Premium today to unlock all materials"
                />
              </div>
              <div>
                <Label>Button / Destination URL (Optional)</Label>
                <Input
                  className="mt-1"
                  value={form.link_url}
                  onChange={(e) => setForm({ ...form, link_url: e.target.value })}
                  placeholder="e.g. /pricing or https://..."
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <Label>Promo Code (Optional)</Label>
                  <Input
                    className="mt-1 uppercase"
                    value={form.code}
                    onChange={(e) => setForm({ ...form, code: e.target.value })}
                    placeholder="e.g. FIRST200 (optional)"
                  />
                </div>
                <div>
                  <Label>Countdown (Hours)</Label>
                  <Input
                    type="number"
                    className="mt-1"
                    value={form.countdown_hours}
                    onChange={(e) => setForm({ ...form, countdown_hours: parseInt(e.target.value) || 24 })}
                    placeholder="24"
                  />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Switch
                  checked={form.is_active}
                  onCheckedChange={(v) => setForm({ ...form, is_active: v })}
                  id="pia"
                />
                <Label htmlFor="pia">Activate Banner Immediately</Label>
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" className="rounded-full" onClick={() => setOpen(false)}>Cancel</Button>
                <Button onClick={save} className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">Publish Banner</Button>
              </div>
            </div>
          </DialogContent>
        </Dialog>
      </div>

      <div className="mt-8 grid md:grid-cols-2 gap-6">
        {items.map((promo) => (
          <Card key={promo._id} className="p-6 rounded-3xl border-slate-200 bg-slate-50 relative overflow-hidden flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between border-b border-slate-200 pb-3 mb-4">
                {promo.code ? (
                  <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-[#7C3AED] bg-violet-50 px-2.5 py-1 rounded-full">
                    <Tag size={12} /> Code: {promo.code}
                  </div>
                ) : (
                  <div className="text-xs text-slate-400 font-medium">No Code Required</div>
                )}
                <div className="flex items-center gap-1.5 text-xs text-slate-500 font-semibold">
                  <Calendar size={13} /> {promo.countdown_hours} hrs countdown
                </div>
              </div>
              <h3 className="font-serif text-xl text-[#0F1B4C] font-semibold">{promo.title}</h3>
              <p className="text-slate-600 text-xs mt-1 leading-relaxed">{promo.subtitle}</p>
              {promo.link_url && (
                <div className="mt-2 text-xs text-[#2563EB] flex items-center gap-1 font-mono">
                  <LinkIcon size={12} /> {promo.link_url}
                </div>
              )}
            </div>

            <div className="mt-6 flex items-center justify-between pt-3 border-t border-slate-200">
              <span className="text-[10px] uppercase font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full">Active</span>
              <Button variant="ghost" size="icon" onClick={() => del(promo._id)} className="text-red-500 hover:bg-slate-100 hover:text-red-600"><Trash2 size={16} /></Button>
            </div>
          </Card>
        ))}
        {items.length === 0 && (
          <div className="col-span-full text-center text-[#64748B] py-16 bg-slate-50 rounded-3xl border border-dashed border-slate-200">No promo banners published yet.</div>
        )}
      </div>
    </div>
  );
}
