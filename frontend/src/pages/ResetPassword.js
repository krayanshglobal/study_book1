import React, { useState, useEffect } from "react";
import { useSearchParams, Link, useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import api, { formatApiError } from "@/lib/api";

export default function ResetPassword() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  const [token, setToken] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    const urlToken = searchParams.get("token");
    if (urlToken) {
      setToken(urlToken);
    }
  }, [searchParams]);

  const handleSubmit = async (e) => {
    e.preventDefault();

    if (!token.trim()) {
      toast.error("Password reset token is required.");
      return;
    }

    if (password.length < 6) {
      toast.error("Password must be at least 6 characters long.");
      return;
    }

    if (password !== confirmPassword) {
      toast.error("Passwords do not match.");
      return;
    }

    setBusy(true);
    try {
      await api.post("/api/auth/reset-password", {
        token: token.trim(),
        password,
      });
      setSuccess(true);
      toast.success("Password reset successfully! You can now log in.");
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="max-w-md mx-auto px-6 py-16 sm:py-24">
      <h1 className="font-serif text-4xl text-[#0F1B4C] font-semibold">Reset Password</h1>
      <p className="mt-2 text-[#64748B]">
        Enter your reset token and new password below.
      </p>

      {success ? (
        <div className="mt-8 rounded-xl bg-white border border-slate-200 p-6 space-y-4" data-testid="reset-success">
          <div className="text-emerald-600 font-medium text-lg">
            ✓ Password reset successfully!
          </div>
          <p className="text-slate-600 text-sm">
            Your password has been updated. You can now sign in with your new credentials.
          </p>
          <Button
            onClick={() => navigate("/login")}
            className="w-full rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] py-3 mt-2"
          >
            Go to Sign In
          </Button>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="mt-8 space-y-5">
          <div>
            <Label htmlFor="token">Reset Token</Label>
            <Input
              id="token"
              type="text"
              required
              placeholder="Paste token from link or console"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              data-testid="reset-token-input"
              className="mt-1.5 rounded-lg font-mono text-sm"
            />
          </div>

          <div>
            <Label htmlFor="password">New Password</Label>
            <Input
              id="password"
              type="password"
              required
              placeholder="At least 6 characters"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              data-testid="reset-password-input"
              className="mt-1.5 rounded-lg"
            />
          </div>

          <div>
            <Label htmlFor="confirmPassword">Confirm New Password</Label>
            <Input
              id="confirmPassword"
              type="password"
              required
              placeholder="Re-enter new password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              data-testid="reset-confirm-password-input"
              className="mt-1.5 rounded-lg"
            />
          </div>

          <Button
            type="submit"
            disabled={busy}
            data-testid="reset-submit-btn"
            className="w-full rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] py-6"
          >
            {busy ? "Resetting..." : "Reset Password"}
          </Button>
        </form>
      )}

      <p className="mt-6 text-sm text-[#64748B]">
        <Link to="/login" className="text-[#2563EB] hover:underline">
          Back to sign in
        </Link>
      </p>
    </div>
  );
}
