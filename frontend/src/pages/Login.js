import React, { useState } from "react";
import { Link, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

export default function Login() {
  const { login, formatApiError } = useAuth();
  const navigate = useNavigate();
  const loc = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const submit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const u = await login(email, password);
      toast.success(`Welcome back, ${u.name}`);
      const dest = loc.state?.from || (u.role === "student" ? "/dashboard" : "/admin");
      navigate(dest, { replace: true });
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="max-w-md mx-auto px-6 py-16 sm:py-24">
      <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Sign in</div>
      <h1 className="mt-3 font-serif text-4xl sm:text-5xl text-[#0F1B4C] font-semibold">Welcome back.</h1>
      <p className="mt-2 text-[#64748B]">Keep the streak going.</p>

      <form onSubmit={submit} className="mt-10 space-y-5" data-testid="login-form">
        <div>
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            type="email"
            data-testid="login-email-input"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
            placeholder="you@studybook.com"
            className="mt-1.5 rounded-lg"
          />
        </div>
        <div>
          <div className="flex items-center justify-between">
            <Label htmlFor="password">Password</Label>
            <Link to="/forgot-password" className="text-xs text-[#2563EB] hover:underline">Forgot?</Link>
          </div>
          <Input
            id="password"
            type="password"
            data-testid="login-password-input"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            className="mt-1.5 rounded-lg"
          />
        </div>
        <Button
          type="submit"
          disabled={submitting}
          data-testid="login-submit-btn"
          className="w-full rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] py-6 text-base"
        >
          {submitting ? <Loader2 className="animate-spin" size={18} /> : "Sign in"}
        </Button>
      </form>

      <p className="mt-8 text-sm text-[#64748B]">
        New to StudyBook?{" "}
        <Link to="/register" className="text-[#7C3AED] font-medium hover:underline">Create an account</Link>
      </p>
    </div>
  );
}
