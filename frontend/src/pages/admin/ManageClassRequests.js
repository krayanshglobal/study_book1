import React, { useEffect, useState } from "react";
import api from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { toast } from "sonner";
import { Check, X, ShieldAlert, Clock, ArrowRight } from "lucide-react";

export default function ManageClassRequests() {
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(true);

  const load = async () => {
    try {
      setLoading(true);
      const r = await api.get("/api/admin/class-change-requests", { params: { status: "pending" } });
      setRequests(r.data.items || []);
    } catch {
      toast.error("Failed to load class change requests.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const handleAction = async (id, action) => {
    try {
      await api.post(`/api/admin/class-change-requests/${id}/${action}`);
      toast.success(`Request ${action === "approve" ? "approved" : "rejected"} successfully`);
      load();
    } catch {
      toast.error(`Failed to ${action} request.`);
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="flex items-center gap-2 text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">
        <ShieldAlert size={14} /> Administration
      </div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Class Change Requests</h1>
      <p className="mt-1 text-[#64748B]">Review and approve student grade level transitions.</p>

      {loading ? (
        <div className="mt-12 text-[#64748B] text-center">Loading requests…</div>
      ) : requests.length === 0 ? (
        <Card className="mt-8 p-12 text-center border-slate-200 shadow-sm bg-white rounded-3xl">
          <div className="w-12 h-12 rounded-full bg-slate-50 text-slate-400 grid place-items-center mx-auto mb-4 border border-slate-100">
            <Clock size={20} />
          </div>
          <h3 className="font-serif text-lg text-[#0F1B4C] font-semibold">No Pending Requests</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">All student class change requests have been processed.</p>
        </Card>
      ) : (
        <div className="mt-8 space-y-4">
          {requests.map((r) => (
            <Card key={r._id} className="p-6 border-slate-200 hover:border-slate-300 transition-colors shadow-sm bg-white rounded-2xl flex flex-col md:flex-row justify-between items-start md:items-center gap-4" data-testid={`class-request-row-${r._id}`}>
              <div className="flex-1 space-y-1">
                <div className="text-sm font-semibold text-[#0F1B4C]">{r.user_name}</div>
                <div className="text-xs text-slate-500 font-mono">{r.user_email}</div>
                <div className="flex items-center gap-2 mt-2 text-xs font-semibold text-[#334155]">
                  <span className="bg-slate-100 px-2.5 py-1 rounded-full border border-slate-200">Class {r.current_class}</span>
                  <ArrowRight size={14} className="text-slate-400" />
                  <span className="bg-[#7C3AED]/10 text-[#7C3AED] px-2.5 py-1 rounded-full border border-[#7C3AED]/20">Class {r.requested_class}</span>
                </div>
              </div>

              <div className="flex items-center gap-2 self-end md:self-auto shrink-0">
                <Button
                  onClick={() => handleAction(r._id, "approve")}
                  size="sm"
                  className="rounded-full bg-emerald-600 hover:bg-emerald-700 text-white flex items-center gap-1 text-xs px-4"
                  data-testid={`btn-approve-${r._id}`}
                >
                  <Check size={14} /> Approve
                </Button>
                <Button
                  onClick={() => handleAction(r._id, "reject")}
                  size="sm"
                  variant="outline"
                  className="rounded-full border-red-200 text-red-600 hover:bg-red-50 hover:border-red-300 flex items-center gap-1 text-xs px-4"
                  data-testid={`btn-reject-${r._id}`}
                >
                  <X size={14} /> Reject
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
