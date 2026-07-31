import React, { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import api, { formatApiError } from "@/lib/api";
import { Link } from "react-router-dom";

export default function ForgotPassword() {
  const [email, setEmail] = useState("");
  const [sent, setSent] = useState(false);
  const [busy, setBusy] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      await api.post("/api/auth/forgot-password", { email });
      setSent(true);
      toast.success("If the email exists, a reset link has been sent.");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="max-w-md mx-auto px-6 py-16 sm:py-24">
      <h1 className="font-serif text-4xl text-[#0F1B4C] font-semibold">Forgot password</h1>
      <p className="mt-2 text-[#64748B]">Enter your email and we&apos;ll send you a reset link.</p>
      {sent ? (
        <div className="mt-8 rounded-xl bg-white border border-slate-200 p-6" data-testid="forgot-success">
          <p className="text-[#334155]">Check the server console for the reset link (email delivery not enabled in this environment).</p>
        </div>
      ) : (
        <form onSubmit={submit} className="mt-8 space-y-5">
          <div>
            <Label htmlFor="email">Email</Label>
            <Input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} data-testid="forgot-email-input" className="mt-1.5 rounded-lg" />
          </div>
          <Button type="submit" disabled={busy} data-testid="forgot-submit-btn" className="w-full rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] py-6">
            Send reset link
          </Button>
        </form>
      )}
      <p className="mt-6 text-sm text-[#64748B]">
        <Link to="/login" className="text-[#2563EB] hover:underline">Back to sign in</Link>
      </p>
    </div>
  );
}
