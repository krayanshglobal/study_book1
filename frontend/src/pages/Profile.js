import React, { useState } from "react";
import BackButton from "@/components/BackButton";
import { useAuth } from "@/contexts/AuthContext";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { toast } from "sonner";
import api, { formatApiError } from "@/lib/api";
import { Pencil, X, Check, RefreshCw } from "lucide-react";

export default function Profile() {
  const { user, refresh } = useAuth();
  const [editing, setEditing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [classChangeLoading, setClassChangeLoading] = useState(false);

  const [form, setForm] = useState({ name: "", phone: "", class_level: "" });

  if (!user) return null;

  const openEdit = () => {
    setForm({ name: user.name || "", phone: user.phone || "", class_level: user.class_level || "" });
    setEditing(true);
  };

  const cancelEdit = () => setEditing(false);

  const saveProfile = async () => {
    setLoading(true);
    try {
      await api.post("/api/auth/profile", {
        name: form.name,
        phone: form.phone,
      });
      await refresh();
      setEditing(false);
      toast.success("Profile updated");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setLoading(false);
    }
  };

  const requestClassChange = async () => {
    if (!form.class_level || form.class_level === user.class_level) {
      toast.error("Select a different class to request a change");
      return;
    }
    setClassChangeLoading(true);
    try {
      await api.post("/api/auth/profile/request-class-change", {
        requested_class: form.class_level,
      });
      toast.success("Class change request submitted. Awaiting admin approval.");
      setEditing(false);
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setClassChangeLoading(false);
    }
  };

  const rows = [
    ["Email", user.email],
    ["Role", <Badge variant="outline" className="text-xs capitalize">{user.role}</Badge>],
    ["Referral code", <span className="font-mono">{user.referral_code || "—"}</span>],
    ["Total points", user.total_points ?? 0],
    ["Premium", user.subscription_active
      ? <span className="text-emerald-600 font-medium">Active {user.subscription_expires_at ? `(until ${user.subscription_expires_at.slice(0,10)})` : ""}</span>
      : <span className="text-[#64748B]">Free plan</span>
    ],
  ];

  return (
    <div className="max-w-2xl mx-auto px-6 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="flex items-center justify-between">
        <h1 className="font-serif text-4xl text-[#0F1B4C] font-semibold">Profile</h1>
        {!editing && (
          <Button variant="outline" className="rounded-full gap-2" onClick={openEdit}>
            <Pencil size={14} /> Edit
          </Button>
        )}
      </div>

      <Card className="mt-8 p-8 rounded-2xl border-slate-200">
        {editing ? (
          <div className="space-y-5">
            <div>
              <Label htmlFor="p-name">Name</Label>
              <Input
                id="p-name"
                className="mt-1"
                value={form.name}
                onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Your full name"
              />
            </div>
            <div>
              <Label htmlFor="p-phone">Phone</Label>
              <Input
                id="p-phone"
                className="mt-1"
                value={form.phone}
                onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))}
                placeholder="+91 9999999999"
              />
            </div>
            <div>
              <Label htmlFor="p-class">Class (change requires admin approval)</Label>
              <Select
                value={form.class_level || "none"}
                onValueChange={(v) => setForm((f) => ({ ...f, class_level: v === "none" ? "" : v }))}
              >
                <SelectTrigger className="mt-1">
                  <SelectValue placeholder="Select class" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">— Not set —</SelectItem>
                  <SelectItem value="8">Class 8</SelectItem>
                  <SelectItem value="9">Class 9</SelectItem>
                  <SelectItem value="10">Class 10</SelectItem>
                </SelectContent>
              </Select>
              {form.class_level && form.class_level !== user.class_level && (
                <p className="text-xs text-amber-600 mt-1">
                  Changing class requires admin approval. Submit a request below.
                </p>
              )}
            </div>

            <div className="flex items-center gap-3 pt-2 flex-wrap">
              <Button
                className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] gap-2"
                onClick={saveProfile}
                disabled={loading}
              >
                {loading ? <RefreshCw size={14} className="animate-spin" /> : <Check size={14} />}
                Save name & phone
              </Button>
              {form.class_level && form.class_level !== user.class_level && (
                <Button
                  variant="outline"
                  className="rounded-full gap-2"
                  onClick={requestClassChange}
                  disabled={classChangeLoading}
                >
                  {classChangeLoading ? <RefreshCw size={14} className="animate-spin" /> : null}
                  Request class change to {form.class_level}
                </Button>
              )}
              <Button variant="ghost" className="rounded-full gap-2" onClick={cancelEdit}>
                <X size={14} /> Cancel
              </Button>
            </div>
          </div>
        ) : (
          <div className="space-y-4">
            {[["Name", user.name], ["Phone", user.phone || "—"], ["Class", user.class_level || "—"], ...rows].map(
              ([k, v]) => (
                <div key={k} className="flex items-center justify-between border-b border-slate-100 py-2 last:border-b-0">
                  <div className="text-xs tracking-widest uppercase text-[#64748B]">{k}</div>
                  <div className="text-[#0F1B4C] font-medium">{v}</div>
                </div>
              )
            )}
          </div>
        )}
      </Card>
    </div>
  );
}
