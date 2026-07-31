import React, { useState, useEffect } from "react";
import { Link, NavLink, useNavigate } from "react-router-dom";
import { useAuth } from "@/contexts/AuthContext";
import { Logo } from "@/components/Logo";
import { Button } from "@/components/ui/button";
import { LogOut, Menu, X, User, ChevronRight } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  DropdownMenuSeparator,
  DropdownMenuLabel,
} from "@/components/ui/dropdown-menu";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import api from "@/lib/api";
import { toast } from "sonner";

const studentLinks = [
  { to: "/dashboard", label: "Dashboard" },
  { to: "/explorer", label: "Study Explorer" },
  { to: "/questions", label: "Question Bank" },
  { to: "/tests", label: "Tests" },
  { to: "/videos", label: "Videos" },
  { to: "/my-analytics", label: "My Analytics" },
  { to: "/leaderboard", label: "Leaderboard" },
  { to: "/pricing", label: "Premium" },
];

const adminLinks = [
  { to: "/admin", label: "Overview" },
  { to: "/admin/questions", label: "Questions" },
  { to: "/admin/tests", label: "Tests" },
  { to: "/admin/videos", label: "Videos" },
  { to: "/admin/notes", label: "Study Notes" },
  { to: "/admin/flashcards", label: "Flashcards" },
  { to: "/admin/promos", label: "Offers" },
  { to: "/admin/analytics", label: "Analytics" },
  { to: "/admin/users", label: "Users" },
  { to: "/admin/plans", label: "Plans" },
  { to: "/admin/announcements", label: "Announcements" },
];

const superAdminExtra = [{ to: "/superadmin", label: "SuperAdmin" }];

export default function Navbar() {
  const { user, logout, refresh } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [classChooserOpen, setClassChooserOpen] = useState(false);
  const [pendingRequest, setPendingRequest] = useState(null);

  const fetchPendingRequest = async () => {
    try {
      const r = await api.get("/api/auth/profile/class-change-request");
      setPendingRequest(r.data.status === "pending" ? r.data : null);
    } catch {}
  };

  useEffect(() => {
    if (user && user.role === "student" && !user.class_level) {
      setClassChooserOpen(true);
    }
  }, [user]);

  useEffect(() => {
    if (classChooserOpen && user && user.class_level) {
      fetchPendingRequest();
    }
  }, [classChooserOpen, user]);

  const selectClass = async (lvl) => {
    try {
      if (!user.class_level) {
        await api.post("/api/auth/profile", { class_level: lvl });
        await refresh();
        setClassChooserOpen(false);
        toast.success(`Active grade set to Class ${lvl}`);
      } else {
        if (user.class_level === lvl) {
          toast.info(`You are already in Class ${lvl}`);
          return;
        }
        await api.post("/api/auth/profile/request-class-change", { requested_class: lvl });
        toast.success(`Request to switch to Class ${lvl} submitted for admin approval!`);
        fetchPendingRequest();
      }
    } catch (err) {
      toast.error("Failed to update active grade.");
    }
  };

  let links = [];
  if (user && user.role === "student") links = studentLinks;
  else if (user && user.role === "admin") links = adminLinks;
  else if (user && user.role === "superadmin") links = [...adminLinks, ...superAdminExtra];

  const doLogout = async () => {
    await logout();
    navigate("/login");
  };

  return (
    <header
      className="sticky top-0 z-40 backdrop-blur-xl bg-white/85 border-b border-[#0F1B4C]/10"
      data-testid="app-navbar"
    >
      <div className="max-w-7xl mx-auto flex items-center justify-between gap-6 px-5 sm:px-8 py-3">
        <div className="flex items-center gap-3 shrink-0">
          <Link to={user ? "/dashboard" : "/"} className="shrink-0">
            <Logo size={48} showText={!user} />
          </Link>
          {user && user.role === "student" && (
            <Button
              variant="outline"
              onClick={() => setClassChooserOpen(true)}
              className="rounded-full font-serif text-xs font-semibold border-slate-200 text-[#0F1B4C] hover:bg-slate-50 hover:text-[#0F1B4C] flex items-center gap-1 h-8 px-3 shrink-0"
              data-testid="navbar-class-switcher"
            >
              StudyBook Grade {user.class_level || "?"} <ChevronRight size={14} />
            </Button>
          )}
        </div>

        {user && (
          <nav className="hidden xl:flex items-center gap-1 shrink-0">
            {links.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                end={l.to === "/admin" || l.to === "/dashboard"}
                data-testid={`nav-${l.label.toLowerCase().replace(/\s+/g, "-")}`}
                className={({ isActive }) =>
                  `px-3 py-2 rounded-full text-sm font-medium transition-colors duration-200 ${
                    isActive
                      ? "bg-[#0F1B4C] text-white"
                      : "text-[#334155] hover:text-[#0F1B4C] hover:bg-slate-100"
                  }`
                }
              >
                {l.label}
              </NavLink>
            ))}
          </nav>
        )}

        <div className="flex items-center gap-2 shrink-0">
          {user ? (
            <>
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <button
                    data-testid="user-menu-trigger"
                    className="flex items-center gap-2 rounded-full border border-slate-200 hover:border-[#0F1B4C]/30 px-3 py-1.5 bg-white transition-colors"
                  >
                    <div
                      className="w-7 h-7 rounded-full grid place-items-center text-white text-xs font-semibold"
                      style={{ background: "linear-gradient(135deg,#2563EB,#7C3AED)" }}
                    >
                      {user.name?.[0]?.toUpperCase() || "U"}
                    </div>
                    <span className="hidden md:inline text-sm text-[#0F1B4C] font-medium">
                      {user.name}
                    </span>
                  </button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                  <DropdownMenuLabel className="text-xs text-slate-500">
                    {user.email}
                  </DropdownMenuLabel>
                  <DropdownMenuSeparator />
                  {user.role === "student" && (
                    <>
                      <DropdownMenuItem onClick={() => navigate("/profile")} data-testid="menu-profile">
                        <User className="w-4 h-4 mr-2" /> Profile
                      </DropdownMenuItem>
                      <DropdownMenuItem onClick={() => navigate("/referrals")} data-testid="menu-referrals">
                        Referrals
                      </DropdownMenuItem>
                    </>
                  )}
                  <DropdownMenuSeparator />
                  <DropdownMenuItem onClick={doLogout} data-testid="menu-logout" className="text-red-600">
                    <LogOut className="w-4 h-4 mr-2" /> Logout
                  </DropdownMenuItem>
                </DropdownMenuContent>
              </DropdownMenu>

              <button
                data-testid="mobile-menu-toggle"
                onClick={() => setOpen((v) => !v)}
                className="xl:hidden p-2 rounded-full hover:bg-slate-100"
              >
                {open ? <X size={20} /> : <Menu size={20} />}
              </button>
            </>
          ) : (
            <>
              <Button
                variant="ghost"
                onClick={() => navigate("/login")}
                data-testid="nav-login-btn"
                className="rounded-full"
              >
                Sign in
              </Button>
              <Button
                onClick={() => navigate("/register")}
                data-testid="nav-register-btn"
                className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]"
              >
                Get started
              </Button>
            </>
          )}
        </div>
      </div>

      {user && open && (
        <div className="xl:hidden border-t border-[#0F1B4C]/10 bg-white shadow-lg">
          <div className="px-4 py-3 flex flex-col gap-1 max-h-[70vh] overflow-y-auto">
            {links.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                end={l.to === "/admin" || l.to === "/dashboard"}
                onClick={() => setOpen(false)}
                data-testid={`mobile-nav-${l.label.toLowerCase().replace(/\s+/g, "-")}`}
                className={({ isActive }) =>
                  `px-4 py-3 rounded-xl text-sm font-medium flex items-center gap-2 ${
                    isActive ? "bg-[#0F1B4C] text-white" : "text-[#334155] hover:bg-slate-100"
                  }`
                }
              >
                {l.label}
              </NavLink>
            ))}
          </div>
        </div>
      )}

      <Dialog open={classChooserOpen} onOpenChange={(val) => { if (user?.class_level) setClassChooserOpen(val); }}>
        <DialogContent className="max-w-md rounded-3xl p-6" onPointerDownOutside={(e) => { if (!user?.class_level) e.preventDefault(); }} onEscapeKeyDown={(e) => { if (!user?.class_level) e.preventDefault(); }}>
          <DialogHeader>
            <DialogTitle className="font-serif text-2xl text-[#0F1B4C] text-center font-semibold">Choose Your Class</DialogTitle>
            <p className="text-xs text-slate-500 text-center mt-1">Select your active class to load matching courses, notes, and tests.</p>
          </DialogHeader>

          {pendingRequest && (
            <div className="mt-4 bg-amber-50 border border-amber-200 text-amber-800 text-xs px-4 py-3 rounded-2xl text-center leading-relaxed">
              ⚠️ Request to switch from <strong>Class {pendingRequest.current_class}</strong> to <strong>Class {pendingRequest.requested_class}</strong> is pending admin approval.
            </div>
          )}

          <div className="grid grid-cols-1 gap-4 mt-6">
            {[
              { val: "8", label: "Grade 8", desc: "Algebra, Equations, Geometry & more", icon: "📐" },
              { val: "9", label: "Grade 9", desc: "Linear Equations, Geometry & Science topics", icon: "🧪" },
              { val: "10", label: "Grade 10", desc: "Trigonometry, Quadratic Equations & Finals prep", icon: "🔬" }
            ].map((item) => {
              const isCurrent = user?.class_level === item.val;
              const isPending = pendingRequest && pendingRequest.requested_class === item.val;
              return (
                <button
                  key={item.val}
                  onClick={() => selectClass(item.val)}
                  disabled={isCurrent}
                  className={`flex items-center gap-4 p-5 rounded-2xl border text-left transition-all hover:scale-[1.02] hover:shadow-md ${
                    isCurrent
                      ? "border-[#7C3AED] bg-[#7C3AED]/5 text-[#7C3AED]"
                      : isPending
                      ? "border-amber-400 bg-amber-50/50 text-amber-800"
                      : "border-slate-200 hover:border-slate-355 bg-white"
                  }`}
                >
                  <div className="w-12 h-12 rounded-xl bg-slate-100 flex items-center justify-center text-2xl">{item.icon}</div>
                  <div className="flex-1">
                    <div className="flex items-center justify-between">
                      <h4 className="font-serif text-base text-[#0F1B4C] font-semibold">{item.label}</h4>
                      {isCurrent && <span className="text-[10px] uppercase font-bold tracking-wider text-[#7C3AED]">Current</span>}
                      {isPending && <span className="text-[10px] uppercase font-bold tracking-wider text-amber-600">Pending</span>}
                    </div>
                    <p className="text-xs text-slate-500 mt-0.5">{item.desc}</p>
                  </div>
                </button>
              );
            })}
          </div>
        </DialogContent>
      </Dialog>
    </header>
  );
}
