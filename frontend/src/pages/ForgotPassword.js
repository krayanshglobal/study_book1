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
  const [devToken, setDevToken] = useState(null);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    try {
      const res = await api.post("/api/auth/forgot-password", { email });
      if (res.data?.dev_reset_token) {
        setDevToken(res.data.dev_reset_token);
      }
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
        <div className="mt-8 rounded-xl bg-white border border-slate-200 p-6 space-y-4" data-testid="forgot-success">
          <p className="text-[#334155]">
            {devToken
              ? "Reset token generated! Click below to set your new password directly."
              : "Check the server console for the reset link (email delivery not enabled in this environment)."}
          </p>
          <div className="pt-2">
            <Link
              to={devToken ? `/reset-password?token=${devToken}` : "/reset-password"}
              className="inline-block w-full text-center rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-white py-3 font-medium transition-colors"
            >
              {devToken ? "Reset Password Now" : "Enter Token & Reset Password"}
            </Link>
          </div>
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
