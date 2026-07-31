import React, { useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { toast } from "sonner";
import { Loader2 } from "lucide-react";

export default function Register() {
  const { register, formatApiError } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [form, setForm] = useState({
    name: "", email: "", phone: "", password: "", class_level: "10",
    referral_code: params.get("ref") || "",
  });
  const [submitting, setSubmitting] = useState(false);

  const setField = (k, v) => setForm((s) => ({ ...s, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const u = await register(form);
      toast.success(`Welcome to StudyBook, ${u.name}!`);
      navigate("/dashboard", { replace: true });
    } catch (err) {
      toast.error(formatApiError(err));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="max-w-lg mx-auto px-6 py-14">
      <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Create account</div>
      <h1 className="mt-3 font-serif text-4xl sm:text-5xl text-[#0F1B4C] font-semibold">Begin your ascent.</h1>
      <p className="mt-2 text-[#64748B]">Free forever. Premium if you want the extras.</p>

      <form onSubmit={submit} className="mt-10 space-y-5" data-testid="register-form">
        <div>
          <Label htmlFor="name">Full name</Label>
          <Input id="name" data-testid="register-name-input" value={form.name} onChange={(e) => setField("name", e.target.value)} required className="mt-1.5 rounded-lg" />
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label htmlFor="email">Email</Label>
            <Input id="email" type="email" data-testid="register-email-input" value={form.email} onChange={(e) => setField("email", e.target.value)} required className="mt-1.5 rounded-lg" />
          </div>
          <div>
            <Label htmlFor="phone">Phone</Label>
            <Input id="phone" data-testid="register-phone-input" value={form.phone} onChange={(e) => setField("phone", e.target.value)} required className="mt-1.5 rounded-lg" placeholder="+91…" />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label>Class</Label>
            <Select value={form.class_level} onValueChange={(v) => setField("class_level", v)}>
              <SelectTrigger data-testid="register-class-select" className="mt-1.5 rounded-lg">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="8">Class 8</SelectItem>
                <SelectItem value="9">Class 9</SelectItem>
                <SelectItem value="10">Class 10</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <Label htmlFor="password">Password</Label>
            <Input id="password" type="password" data-testid="register-password-input" value={form.password} onChange={(e) => setField("password", e.target.value)} required minLength={6} className="mt-1.5 rounded-lg" />
          </div>
        </div>
        <div>
          <Label htmlFor="ref">Referral code <span className="text-xs text-[#64748B]">(optional)</span></Label>
          <Input id="ref" data-testid="register-referral-input" value={form.referral_code} onChange={(e) => setField("referral_code", e.target.value.toUpperCase())} className="mt-1.5 rounded-lg font-mono" />
        </div>

        <Button
          type="submit"
          disabled={submitting}
          data-testid="register-submit-btn"
          className="w-full rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] py-6 text-base"
        >
          {submitting ? <Loader2 className="animate-spin" size={18} /> : "Create account"}
        </Button>
      </form>

      <p className="mt-8 text-sm text-[#64748B]">
        Already registered?{" "}
        <Link to="/login" className="text-[#7C3AED] font-medium hover:underline">Sign in</Link>
      </p>
    </div>
  );
}
