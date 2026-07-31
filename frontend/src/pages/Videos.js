import React, { useEffect, useState } from "react";
import api from "@/lib/api";
import BackButton from "@/components/BackButton";
import { Card } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { PlayCircle, Lock } from "lucide-react";
import { useAuth } from "@/contexts/AuthContext";

function embedUrl(url) {
  try {
    const u = new URL(url);
    if (u.hostname.includes("youtube.com")) {
      const v = u.searchParams.get("v");
      return v ? `https://www.youtube.com/embed/${v}` : url;
    }
    if (u.hostname.includes("youtu.be")) {
      return `https://www.youtube.com/embed/${u.pathname.slice(1)}`;
    }
    return url;
  } catch { return url; }
}

export default function Videos() {
  const { user } = useAuth();
  const isStaff = user?.role === "admin" || user?.role === "superadmin";
  const [items, setItems] = useState([]);
  const [classLevel, setClassLevel] = useState(isStaff ? "all" : (user?.class_level || "8"));
  const [current, setCurrent] = useState(null);

  useEffect(() => {
    (async () => {
      const params = {};
      const targetClass = isStaff ? classLevel : (user?.class_level || "8");
      if (targetClass && targetClass !== "all") params.class_level = targetClass;
      const r = await api.get("/api/videos", { params });
      setItems(r.data.items || []);
    })();
  }, [classLevel, user, isStaff]);

  return (
    <div className="max-w-6xl mx-auto px-6 sm:px-10 py-10">
      <BackButton to="/dashboard" label="Dashboard" className="mb-6" />
      <div className="text-xs tracking-[0.24em] uppercase text-[#2563EB] font-semibold">Learn</div>
      <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Video lessons</h1>

      {isStaff && (
        <div className="mt-6">
          <Select value={classLevel} onValueChange={setClassLevel}>
            <SelectTrigger className="w-44 rounded-full" data-testid="videos-class-select"><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All classes</SelectItem>
              <SelectItem value="8">Class 8</SelectItem>
              <SelectItem value="9">Class 9</SelectItem>
              <SelectItem value="10">Class 10</SelectItem>
            </SelectContent>
          </Select>
        </div>
      )}

      {items.length === 0 ? (
        <div className="mt-16 text-center text-[#64748B]" data-testid="videos-empty">
          No videos yet. Admin will drop lessons soon.
        </div>
      ) : (
        <div className="mt-8 grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {items.map((v) => (
            <Card key={v._id} className="rounded-2xl border-slate-200 p-0 overflow-hidden group cursor-pointer" onClick={() => setCurrent(v)} data-testid={`video-card-${v._id}`}>
              <div className="relative aspect-video bg-slate-100">
                <img src={v.thumbnail_url || "https://images.unsplash.com/photo-1509228468518-180dd4864904"} alt="" className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" />
                <div className="absolute inset-0 grid place-items-center bg-black/20 group-hover:bg-black/40 transition-colors">
                  {v.premium_only && !user?.subscription_active ? (
                    <Lock className="text-white" size={40} />
                  ) : (
                    <PlayCircle className="text-white" size={54} />
                  )}
                </div>
                {v.premium_only && <span className="absolute top-3 left-3 bg-amber-500 text-white text-xs font-semibold px-2 py-1 rounded">PREMIUM</span>}
              </div>
              <div className="p-5">
                <div className="text-xs tracking-widest uppercase text-[#7C3AED] font-semibold">Class {v.class_level} · {v.topic || "General"}</div>
                <div className="mt-1 font-serif text-lg text-[#0F1B4C] font-semibold">{v.title}</div>
                <p className="text-sm text-[#64748B] mt-1 line-clamp-2">{v.description}</p>
              </div>
            </Card>
          ))}
        </div>
      )}

      {current && (
        <div className="fixed inset-0 bg-black/70 z-50 grid place-items-center p-4" onClick={() => setCurrent(null)} data-testid="video-modal">
          <div className="max-w-4xl w-full" onClick={(e) => e.stopPropagation()}>
            <div className="aspect-video rounded-xl overflow-hidden bg-black">
              <iframe src={embedUrl(current.url)} title={current.title} allowFullScreen className="w-full h-full" />
            </div>
            <div className="mt-3 text-white font-serif text-xl">{current.title}</div>
          </div>
        </div>
      )}
    </div>
  );
}
