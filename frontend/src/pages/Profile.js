import React, { useRef, useState } from "react";
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
import { Pencil, X, Check, RefreshCw, Camera, IdCard, Trash2 } from "lucide-react";

function AvatarCircle({ avatarUrl, name, size = 96, onClick }) {
  const initials = (name || "?")
    .split(" ")
    .map((w) => w[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);

  return (
    <div
      onClick={onClick}
      className="relative inline-block cursor-pointer group"
      style={{ width: size, height: size }}
    >
      <div
        className="rounded-full overflow-hidden border-4 border-white shadow-lg bg-gradient-to-br from-[#2563EB] to-[#7C3AED] flex items-center justify-center"
        style={{ width: size, height: size }}
      >
        {avatarUrl ? (
          <img src={avatarUrl} alt={name} className="w-full h-full object-cover" />
        ) : (
          <span className="text-white font-bold" style={{ fontSize: size * 0.33 }}>
            {initials}
          </span>
        )}
      </div>
      {onClick && (
        <div className="absolute inset-0 rounded-full bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <Camera size={size * 0.28} className="text-white" />
        </div>
      )}
    </div>
  );
}

export default function Profile() {
  const { user, refresh } = useAuth();
  const [editing, setEditing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [photoLoading, setPhotoLoading] = useState(false);
  const [classChangeLoading, setClassChangeLoading] = useState(false);
  const fileInputRef = useRef(null);

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

  const handlePhotoChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    if (!file.type.startsWith("image/")) {
      toast.error("Please select an image file");
      return;
    }
    if (file.size > 2 * 1024 * 1024) {
      toast.error("Image must be under 2 MB");
      return;
    }
    setPhotoLoading(true);
    try {
      const formData = new FormData();
      formData.append("file", file);
      await api.post("/api/auth/profile/photo", formData, {
        headers: { "Content-Type": "multipart/form-data" },
      });
      await refresh();
      toast.success("Profile photo updated!");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setPhotoLoading(false);
      e.target.value = "";
    }
  };

  const handleRemovePhoto = async () => {
    setPhotoLoading(true);
    try {
      await api.delete("/api/auth/profile/photo");
      await refresh();
      toast.success("Profile photo removed!");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setPhotoLoading(false);
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
    user.student_id && ["Student ID",
      <span className="font-mono text-sm bg-[#EEF2FF] text-[#2563EB] px-2 py-0.5 rounded-md border border-[#BFDBFE] flex items-center gap-1.5">
        <IdCard size={13} />{user.student_id}
      </span>
    ],
    ["Referral code", <span className="font-mono">{user.referral_code || "—"}</span>],
    ["Total points", user.total_points ?? 0],
    ["Premium", user.subscription_active
      ? <span className="text-emerald-600 font-medium">Active {user.subscription_expires_at ? `(until ${user.subscription_expires_at.slice(0,10)})` : ""}</span>
      : <span className="text-[#64748B]">Free plan</span>
    ],
  ].filter(Boolean);

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

      {/* Avatar section */}
      <div className="mt-8 flex flex-col items-center gap-3">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={handlePhotoChange}
        />
        <div className="relative">
          <AvatarCircle
            avatarUrl={user.avatar_url}
            name={user.name}
            size={96}
            onClick={() => fileInputRef.current?.click()}
          />
          {photoLoading && (
            <div className="absolute inset-0 rounded-full bg-black/50 flex items-center justify-center">
              <RefreshCw size={20} className="text-white animate-spin" />
            </div>
          )}
        </div>
        <p className="text-xs text-[#64748B]">Click photo to change · Max 2 MB</p>

        {user.avatar_url && (
          <button
            type="button"
            onClick={handleRemovePhoto}
            disabled={photoLoading}
            className="text-xs font-semibold text-red-600 hover:text-red-700 bg-red-50 hover:bg-red-100 border border-red-200 px-3 py-1 rounded-full transition-colors flex items-center gap-1 mt-0.5"
            data-testid="remove-photo-btn"
          >
            <Trash2 size={12} /> Remove photo
          </button>
        )}

        {user.student_id && (
          <div className="mt-1 flex items-center gap-2 font-mono text-sm font-bold bg-[#0F1B4C] text-white px-4 py-1.5 rounded-full shadow border border-[#2563EB]">
            <IdCard size={16} className="text-blue-400" />
            <span>ID: {user.student_id}</span>
          </div>
        )}
      </div>

      <Card className="mt-6 p-8 rounded-2xl border-slate-200">
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
                Save name &amp; phone
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
