import React, { useEffect, useState, useCallback } from "react";
import api, { formatApiError } from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { RefreshCw, ChevronLeft, ChevronRight, ExternalLink } from "lucide-react";

const PAGE_SIZE = 25;

const STATUS_COLORS = {
  paid: "bg-emerald-100 text-emerald-700",
  initiated: "bg-slate-100 text-slate-600",
  pending: "bg-amber-100 text-amber-700",
  failed: "bg-red-100 text-red-600",
};

export default function ManagePayments() {
  const [items, setItems] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [statusFilter, setStatusFilter] = useState("");
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get("/api/admin/payments", {
        params: {
          limit: PAGE_SIZE,
          skip: page * PAGE_SIZE,
          payment_status: statusFilter || undefined,
        },
      });
      setItems(r.data.items || []);
      setTotal(r.data.total || 0);
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter]);

  useEffect(() => {
    setPage(0);
  }, [statusFilter]);

  useEffect(() => {
    load();
  }, [load]);

  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/admin" label="Admin dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Finance</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Payment Transactions</h1>

      <div className="mt-6 flex flex-wrap gap-3 items-center">
        <Select value={statusFilter || "all"} onValueChange={(v) => setStatusFilter(v === "all" ? "" : v)}>
          <SelectTrigger className="w-44 rounded-full">
            <SelectValue placeholder="All statuses" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="paid">Paid</SelectItem>
            <SelectItem value="pending">Pending</SelectItem>
            <SelectItem value="initiated">Initiated</SelectItem>
            <SelectItem value="failed">Failed</SelectItem>
          </SelectContent>
        </Select>
        <div className="ml-auto text-sm text-[#64748B]">
          {total} total · page {page + 1} of {Math.max(totalPages, 1)}
        </div>
      </div>

      <Card className="mt-4 rounded-2xl border-slate-200 overflow-hidden">
        <div className="grid grid-cols-[1fr,1fr,100px,80px,100px,90px] px-5 py-3 bg-slate-50 border-b border-slate-200 text-xs tracking-widest uppercase text-[#64748B] font-semibold">
          <div>Student</div><div>Plan</div><div>Amount</div><div>Currency</div><div>Status</div><div>Date</div>
        </div>

        {loading ? (
          <div className="p-10 text-center text-[#64748B]">
            <RefreshCw size={20} className="animate-spin mx-auto mb-2" />
            Loading transactions…
          </div>
        ) : items.length === 0 ? (
          <div className="p-8 text-center text-[#64748B]">No transactions found.</div>
        ) : (
          items.map((tx) => (
            <div
              key={tx._id}
              className="grid grid-cols-[1fr,1fr,100px,80px,100px,90px] px-5 py-3 items-center border-b border-slate-100 last:border-b-0 text-sm"
            >
              <div>
                <div className="text-[#0F1B4C] font-medium truncate">{tx.user_name || "—"}</div>
                <div className="text-xs text-[#64748B] truncate">{tx.user_email || ""}</div>
              </div>
              <div className="text-[#334155] truncate">{tx.metadata?.plan_name || "—"}</div>
              <div className="font-mono text-[#0F1B4C]">
                {tx.currency?.toUpperCase() === "INR" ? "₹" : "$"}{tx.amount?.toFixed(2)}
              </div>
              <div className="text-[#64748B] uppercase text-xs font-mono">{tx.currency}</div>
              <div>
                <span className={`px-2 py-0.5 rounded-full text-xs font-semibold ${STATUS_COLORS[tx.payment_status] || "bg-slate-100 text-slate-600"}`}>
                  {tx.payment_status}
                </span>
              </div>
              <div className="text-xs text-[#64748B]">
                {tx.created_at ? new Date(tx.created_at).toLocaleDateString() : "—"}
              </div>
            </div>
          ))
        )}
      </Card>

      {totalPages > 1 && (
        <div className="mt-4 flex items-center justify-center gap-3">
          <Button variant="outline" size="sm" className="rounded-full gap-1" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            <ChevronLeft size={14} /> Prev
          </Button>
          <span className="text-sm text-[#64748B]">Page {page + 1} / {totalPages}</span>
          <Button variant="outline" size="sm" className="rounded-full gap-1" disabled={page >= totalPages - 1} onClick={() => setPage((p) => p + 1)}>
            Next <ChevronRight size={14} />
          </Button>
        </div>
      )}
    </div>
  );
}
