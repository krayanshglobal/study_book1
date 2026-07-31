import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Switch } from "@/components/ui/switch";
import { toast } from "sonner";
import { Pencil, Trash2, ShieldCheck, RefreshCw, ChevronLeft, ChevronRight } from "lucide-react";

const PAGE_SIZE = 20;

export default function ManageUsers() {
  const adminClass = localStorage.getItem("admin_class_level") || "8";
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(false);

  // Edit dialog
  const [editOpen, setEditOpen] = useState(false);
  const [editUser, setEditUser] = useState(null);
  const [editForm, setEditForm] = useState({ name: "", phone: "", class_level: "", role: "" });
  const [editLoading, setEditLoading] = useState(false);

  // Subscription dialog
  const [subOpen, setSubOpen] = useState(false);
  const [subUser, setSubUser] = useState(null);
  const [subForm, setSubForm] = useState({ subscription_active: false, duration_days: 30 });
  const [subLoading, setSubLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get("/api/admin/users", {
        params: {
          class_level: adminClass,
          search: search || undefined,
          limit: PAGE_SIZE,
          skip: page * PAGE_SIZE,
        },
      });
      setItems(r.data.items || []);
      setTotal(r.data.total || 0);
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [adminClass, search, page]);

  useEffect(() => {
    setPage(0);
  }, [search, adminClass]);

  useEffect(() => {
    load();
  }, [load]);

  // ── Edit user ──
  const openEdit = (u) => {
    setEditUser(u);
    setEditForm({ name: u.name || "", phone: u.phone || "", class_level: u.class_level || "", role: u.role || "student" });
    setEditOpen(true);
  };

  const saveEdit = async () => {
    setEditLoading(true);
    try {
      const upd = {};
      if (editForm.name !== editUser.name) upd.name = editForm.name;
      if (editForm.phone !== editUser.phone) upd.phone = editForm.phone;
      if (editForm.class_level && editForm.class_level !== editUser.class_level) upd.class_level = editForm.class_level;
      if (editForm.role !== editUser.role) upd.role = editForm.role;
      await api.put(`/api/admin/users/${editUser._id}`, upd);
      toast.success("User updated");
      setEditOpen(false);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setEditLoading(false);
    }
  };

  // ── Delete user ──
  const deleteUser = async (u) => {
    if (!window.confirm(`Delete user "${u.name}"? This cannot be undone.`)) return;
    try {
      await api.delete(`/api/admin/users/${u._id}`);
      toast.success("User deleted");
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // ── Subscription ──
  const openSub = (u) => {
    setSubUser(u);
    setSubForm({ subscription_active: u.subscription_active || false, duration_days: 30 });
    setSubOpen(true);
  };

  const saveSub = async () => {
    setSubLoading(true);
    try {
      await api.patch(`/api/admin/users/${subUser._id}/subscription`, subForm);
      toast.success("Subscription updated");
      setSubOpen(false);
      load();
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setSubLoading(false);
    }
  };

  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">People</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Users</h1>

      <div className="mt-6 flex flex-wrap gap-3 items-center">
        <Input
          className="max-w-sm rounded-full"
          placeholder="Search by name or email…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          data-testid="user-search"
        />
        <div className="ml-auto text-sm text-[#64748B]">
          {total} total · page {page + 1} of {Math.max(totalPages, 1)}
        </div>
      </div>

      <Card className="mt-4 rounded-2xl border-slate-200 overflow-hidden">
        {/* Header */}
        <div className="grid grid-cols-[1fr,1fr,70px,90px,100px,110px] px-5 py-3 bg-slate-50 border-b border-slate-200 text-xs tracking-widest uppercase text-[#64748B] font-semibold">
          <div>Name</div><div>Email</div><div>Class</div><div>Role</div><div>Premium</div><div>Actions</div>
        </div>

        {loading ? (
          <div className="p-10 text-center text-[#64748B]">
            <RefreshCw size={20} className="animate-spin mx-auto mb-2" />
            Loading users…
          </div>
        ) : items.length === 0 ? (
          <div className="p-8 text-center text-[#64748B]">No users found.</div>
        ) : (
          items.map((u) => (
            <div
              key={u._id}
              className="grid grid-cols-[1fr,1fr,70px,90px,100px,110px] px-5 py-3 items-center border-b border-slate-100 last:border-b-0 text-sm"
              data-testid={`user-row-${u._id}`}
            >
              <div className="text-[#0F1B4C] font-medium truncate">{u.name}</div>
              <div className="text-[#334155] truncate">{u.email}</div>
              <div className="font-mono text-[#64748B]">{u.class_level || "—"}</div>
              <div><Badge variant="outline" className="text-xs">{u.role}</Badge></div>
              <div>
                {u.subscription_active
                  ? <span className="text-emerald-600 text-xs font-medium">Active</span>
                  : <span className="text-[#64748B] text-xs">Free</span>}
              </div>
              <div className="flex gap-1">
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => openEdit(u)}
                  data-testid={`user-edit-${u._id}`}
                  title="Edit user"
                >
                  <Pencil size={14} />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => openSub(u)}
                  data-testid={`user-sub-${u._id}`}
                  title="Manage subscription"
                >
                  <ShieldCheck size={14} className={u.subscription_active ? "text-emerald-600" : "text-[#64748B]"} />
                </Button>
                {u.role === "student" && (
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => deleteUser(u)}
                    data-testid={`user-del-${u._id}`}
                    title="Delete user"
                  >
                    <Trash2 size={14} className="text-red-500" />
                  </Button>
                )}
              </div>
            </div>
          ))
        )}
      </Card>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-center gap-3">
          <Button
            variant="outline"
            size="sm"
            className="rounded-full gap-1"
            disabled={page === 0}
            onClick={() => setPage((p) => p - 1)}
          >
            <ChevronLeft size={14} /> Prev
          </Button>
          <span className="text-sm text-[#64748B]">Page {page + 1} / {totalPages}</span>
          <Button
            variant="outline"
            size="sm"
            className="rounded-full gap-1"
            disabled={page >= totalPages - 1}
            onClick={() => setPage((p) => p + 1)}
          >
            Next <ChevronRight size={14} />
          </Button>
        </div>
      )}

      {/* Edit User Dialog */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="font-serif">Edit User</DialogTitle>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <Label>Name</Label>
              <Input className="mt-1" value={editForm.name} onChange={(e) => setEditForm((f) => ({ ...f, name: e.target.value }))} />
            </div>
            <div>
              <Label>Phone</Label>
              <Input className="mt-1" value={editForm.phone} onChange={(e) => setEditForm((f) => ({ ...f, phone: e.target.value }))} />
            </div>
            <div>
              <Label>Class</Label>
              <Select value={editForm.class_level || "none"} onValueChange={(v) => setEditForm((f) => ({ ...f, class_level: v === "none" ? "" : v }))}>
                <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">— Not set —</SelectItem>
                  <SelectItem value="8">Class 8</SelectItem>
                  <SelectItem value="9">Class 9</SelectItem>
                  <SelectItem value="10">Class 10</SelectItem>
                </SelectContent>
              </Select>
            </div>
            {editUser?.role !== "superadmin" && (
              <div>
                <Label>Role</Label>
                <Select value={editForm.role} onValueChange={(v) => setEditForm((f) => ({ ...f, role: v }))}>
                  <SelectTrigger className="mt-1"><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="student">Student</SelectItem>
                    <SelectItem value="admin">Admin</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            )}
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="outline" className="rounded-full" onClick={() => setEditOpen(false)}>Cancel</Button>
              <Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]" onClick={saveEdit} disabled={editLoading}>
                {editLoading ? <RefreshCw size={14} className="animate-spin mr-1" /> : null}
                Save changes
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>

      {/* Subscription Dialog */}
      <Dialog open={subOpen} onOpenChange={setSubOpen}>
        <DialogContent className="max-w-sm">
          <DialogHeader>
            <DialogTitle className="font-serif">Manage Subscription</DialogTitle>
          </DialogHeader>
          {subUser && (
            <div className="space-y-4">
              <p className="text-sm text-[#64748B]">User: <span className="text-[#0F1B4C] font-medium">{subUser.name}</span></p>
              <div className="flex items-center gap-3">
                <Switch
                  id="sub-active"
                  checked={subForm.subscription_active}
                  onCheckedChange={(v) => setSubForm((f) => ({ ...f, subscription_active: v }))}
                />
                <Label htmlFor="sub-active">
                  {subForm.subscription_active ? "Premium Active" : "Free Plan"}
                </Label>
              </div>
              {subForm.subscription_active && (
                <div>
                  <Label>Duration (days from now)</Label>
                  <Input
                    type="number"
                    className="mt-1"
                    value={subForm.duration_days}
                    onChange={(e) => setSubForm((f) => ({ ...f, duration_days: parseInt(e.target.value) || 30 }))}
                    min={1}
                    max={1825}
                  />
                  <p className="text-xs text-[#64748B] mt-1">Current: {subUser.subscription_expires_at?.slice(0, 10) || "not set"}</p>
                </div>
              )}
              <div className="flex justify-end gap-2 pt-2">
                <Button variant="outline" className="rounded-full" onClick={() => setSubOpen(false)}>Cancel</Button>
                <Button
                  className="rounded-full bg-emerald-600 hover:bg-emerald-700"
                  onClick={saveSub}
                  disabled={subLoading}
                >
                  {subLoading ? <RefreshCw size={14} className="animate-spin mr-1" /> : null}
                  Save subscription
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
