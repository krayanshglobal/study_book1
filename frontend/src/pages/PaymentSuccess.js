import React, { useEffect, useState } from "react";
import { useSearchParams, Link } from "react-router-dom";
import api from "@/lib/api";
import { Button } from "@/components/ui/button";
import { CheckCircle2, Loader2, XCircle } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";

export default function PaymentSuccess() {
  const [params] = useSearchParams();
  const sessionId = params.get("session_id");
  const [status, setStatus] = useState("pending"); // pending | paid | failed
  const { refresh } = useAuth();

  useEffect(() => {
    if (!sessionId) { setStatus("failed"); return; }
    let cancelled = false;
    let attempts = 0;
    const poll = async () => {
      if (cancelled) return;
      attempts += 1;
      try {
        const r = await api.get(`/api/payments/status/${sessionId}`);
        if (r.data.payment_status === "paid") {
          setStatus("paid");
          refresh();
          return;
        }
        if (r.data.status === "expired") { setStatus("failed"); return; }
      } catch { /* ignore */ }
      if (attempts < 8) setTimeout(poll, 2000);
      else setStatus("failed");
    };
    poll();
    return () => { cancelled = true; };
  }, [sessionId, refresh]);

  return (
    <div className="max-w-lg mx-auto px-6 py-24 text-center">
      {status === "pending" && (
        <>
          <Loader2 className="mx-auto animate-spin text-[#2563EB]" size={40} data-testid="payment-loading" />
          <h1 className="mt-6 font-serif text-3xl text-[#0F1B4C]">Confirming payment…</h1>
          <p className="mt-2 text-[#64748B]">Hold on while we verify with Stripe.</p>
        </>
      )}
      {status === "paid" && (
        <>
          <CheckCircle2 className="mx-auto text-green-600" size={56} data-testid="payment-success" />
          <h1 className="mt-6 font-serif text-3xl text-[#0F1B4C]">You&apos;re premium!</h1>
          <p className="mt-2 text-[#64748B]">All premium content is now unlocked.</p>
          <Link to="/dashboard"><Button className="mt-8 rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">Go to dashboard</Button></Link>
        </>
      )}
      {status === "failed" && (
        <>
          <XCircle className="mx-auto text-red-600" size={56} data-testid="payment-failed" />
          <h1 className="mt-6 font-serif text-3xl text-[#0F1B4C]">Something went wrong</h1>
          <p className="mt-2 text-[#64748B]">Please try again or contact support.</p>
          <Link to="/pricing"><Button className="mt-8 rounded-full">Back to pricing</Button></Link>
        </>
      )}
    </div>
  );
}
