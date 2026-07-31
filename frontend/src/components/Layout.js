import React from "react";
import Navbar from "@/components/Navbar";

export default function Layout({ children }) {
  return (
    <div className="min-h-screen bg-[#F8FAFC] text-[#0F1B4C]">
      <Navbar />
      <main>{children}</main>
      <footer className="mt-24 border-t border-[#0F1B4C]/10 bg-white">
        <div className="max-w-7xl mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-3 text-sm text-[#64748B]">
          <div>© {new Date().getFullYear()} StudyBook. Learn • Focus • Achieve.</div>
          <div className="flex gap-5">
            <a href="/pricing" className="hover:text-[#0F1B4C]">Premium</a>
            <a href="/leaderboard" className="hover:text-[#0F1B4C]">Leaderboard</a>
          </div>
        </div>
      </footer>
    </div>
  );
}
