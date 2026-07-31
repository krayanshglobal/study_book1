import React from "react";
import { Link } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { motion } from "framer-motion";
import { ArrowRight, Sparkles } from "lucide-react";
import { LOGO_URL_EXPORT } from "@/components/Logo";

const stagger = { visible: { transition: { staggerChildren: 0.09 } } };
const item = { hidden: { opacity: 0, y: 20 }, visible: { opacity: 1, y: 0, transition: { duration: 0.55 } } };

export default function Landing() {
  return (
    <div className="relative overflow-hidden">
      <div className="pointer-events-none absolute -top-32 -right-40 w-[520px] h-[520px] rounded-full bg-[#7C3AED]/12 blur-[110px]" />
      <div className="pointer-events-none absolute top-40 -left-40 w-[520px] h-[520px] rounded-full bg-[#2563EB]/10 blur-[120px]" />

      {/* HERO */}
      <section className="relative">
        <div className="max-w-7xl mx-auto px-6 sm:px-10 pt-16 sm:pt-24 pb-24 grid lg:grid-cols-12 gap-14 relative items-center">
          <motion.div initial="hidden" animate="visible" variants={stagger} className="lg:col-span-6">
            <motion.div variants={item} className="inline-flex items-center gap-2 rounded-full border border-[#0F1B4C]/15 bg-white px-3.5 py-1.5 text-[11px] tracking-[0.24em] uppercase text-[#2563EB] font-semibold">
              <Sparkles size={13} /> A modern place to learn
            </motion.div>

            <motion.h1 variants={item} className="mt-7 font-serif text-5xl sm:text-6xl lg:text-[76px] font-semibold tracking-tight text-[#0F1B4C] leading-[0.98]">
              Learn deeper.<br />
              <span className="text-shine">Grow faster.</span>
            </motion.h1>

            <motion.p variants={item} className="mt-6 text-lg text-[#334155] leading-relaxed max-w-xl">
              StudyBook is a premium learning space designed to help you master any subject at your own pace —
              organised, distraction-free and beautifully crafted.
            </motion.p>

            <motion.div variants={item} className="mt-9 flex flex-wrap items-center gap-3">
              <Link to="/register">
                <Button data-testid="hero-cta-register" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-white px-8 py-6 text-base">
                  Get started <ArrowRight className="ml-1" size={18} />
                </Button>
              </Link>
              <Link to="/login">
                <Button data-testid="hero-cta-login" variant="outline" className="rounded-full border-[#0F1B4C]/25 px-8 py-6 text-base hover:bg-white">
                  Sign in
                </Button>
              </Link>
            </motion.div>
          </motion.div>

          {/* Study/learning hero visual */}
          <motion.div
            initial={{ opacity: 0, scale: 0.94, y: 40 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ duration: 0.9, delay: 0.15, ease: [0.19, 1, 0.22, 1] }}
            className="lg:col-span-6 relative"
          >
            <div className="relative aspect-[4/5] max-w-md mx-auto">
              <div className="absolute inset-8 rounded-[2.4rem] bg-gradient-to-br from-[#2563EB]/25 to-[#7C3AED]/25 blur-2xl" />
              <div className="absolute inset-14 rounded-[2rem] rotate-6 bg-gradient-to-br from-[#2563EB] to-[#7C3AED] opacity-25" />
              <motion.div
                animate={{ y: [0, -10, 0] }}
                transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
                className="absolute inset-0 rounded-[2.4rem] overflow-hidden border border-white/40 shadow-[0_40px_120px_-20px_rgba(15,27,76,0.45)]"
              >
                <img
                  src="https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&w=1200&q=85"
                  alt="Library filled with books"
                  className="w-full h-full object-cover"
                />
                <div className="absolute inset-0" style={{ background: "linear-gradient(160deg, rgba(15,27,76,0.55) 0%, rgba(37,99,235,0.35) 55%, rgba(124,58,237,0.55) 100%)" }} />
                <div className="absolute inset-0 grain opacity-30" />

                {/* Floating brand chip */}
                <motion.div
                  animate={{ y: [0, -12, 0] }}
                  transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
                  className="absolute top-6 left-6 flex items-center gap-2 bg-white/90 backdrop-blur-md rounded-full px-3 py-1.5 shadow-lg"
                >
                  <img src={LOGO_URL_EXPORT} alt="" className="w-6 h-6 rounded-md" />
                  <span className="font-serif text-sm text-[#0F1B4C] font-semibold">StudyBook</span>
                </motion.div>

                <motion.div
                  animate={{ y: [0, -20, 0], x: [0, 12, 0] }}
                  transition={{ duration: 7, repeat: Infinity, ease: "easeInOut" }}
                  className="absolute top-16 right-8 w-14 h-14 rounded-full"
                  style={{ background: "radial-gradient(circle at 30% 30%, #C4B5FD, #7C3AED)" }}
                />
                <motion.div
                  animate={{ y: [0, 16, 0], x: [0, -14, 0] }}
                  transition={{ duration: 8, repeat: Infinity, ease: "easeInOut", delay: 1 }}
                  className="absolute bottom-24 left-6 w-10 h-10 rounded-full"
                  style={{ background: "radial-gradient(circle at 30% 30%, #93C5FD, #2563EB)" }}
                />
              </motion.div>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Feature strip */}
      <section className="max-w-7xl mx-auto px-6 sm:px-10 pb-24">
        <div className="grid md:grid-cols-3 gap-5">
          {[
            { title: "Learn", desc: "Curated lessons and practice, thoughtfully organised so you always know what's next." },
            { title: "Focus", desc: "A calm, distraction-free interface built to keep you in flow, session after session." },
            { title: "Achieve", desc: "Measurable progress with clear results — celebrate every milestone as you grow." },
          ].map((f, i) => (
            <motion.div
              key={f.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.08, duration: 0.55 }}
              className="rounded-3xl bg-white border border-slate-200 p-8 hover:border-[#7C3AED]/40 hover:shadow-[0_24px_60px_-30px_rgba(124,58,237,0.35)] transition-all duration-300"
            >
              <div className="text-xs tracking-[0.28em] uppercase text-[#7C3AED] font-semibold">0{i + 1}</div>
              <h3 className="mt-3 font-serif text-3xl text-[#0F1B4C] font-semibold">{f.title}</h3>
              <p className="mt-3 text-[#475569] leading-relaxed">{f.desc}</p>
            </motion.div>
          ))}
        </div>
      </section>

      {/* Second photo — split showcase */}
      <section className="max-w-7xl mx-auto px-6 sm:px-10 pb-24">
        <div className="grid lg:grid-cols-2 gap-10 items-center">
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.7 }}
            className="relative"
          >
            <div className="absolute -inset-4 rounded-[2rem] bg-gradient-to-tr from-[#2563EB]/20 to-[#7C3AED]/20 blur-2xl" />
            <div className="relative rounded-[2rem] overflow-hidden border border-[#0F1B4C]/10 shadow-[0_30px_80px_-30px_rgba(15,27,76,0.4)]">
              <img
                src="https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&w=1200&q=85"
                alt="Focused student studying"
                className="w-full h-[480px] object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-[#0F1B4C]/60 via-transparent to-transparent" />
              <div className="absolute bottom-5 left-5 right-5 flex items-center justify-between text-white">
                <div>
                  <div className="text-[10px] tracking-[0.24em] uppercase text-white/70 font-semibold">Everyday moments</div>
                  <div className="font-serif text-xl mt-1">Made for students who show up</div>
                </div>
              </div>
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, x: 30 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.7, delay: 0.1 }}
          >
            <div className="text-xs tracking-[0.28em] uppercase text-[#2563EB] font-semibold">Why StudyBook</div>
            <h2 className="mt-4 font-serif text-4xl sm:text-5xl text-[#0F1B4C] font-semibold leading-tight">
              Built like a place<br /> you&apos;ll actually return to.
            </h2>
            <p className="mt-5 text-[#475569] text-lg leading-relaxed">
              Beautiful typography. Zero clutter. Progress you can feel. StudyBook is engineered for young learners
              who take their growth seriously — and their aesthetics too.
            </p>
            <ul className="mt-6 space-y-3 text-[#334155]">
              <li className="flex items-start gap-3">
                <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-[#7C3AED]" />
                <span>A rich question bank with images and equations, updated by your teacher</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-[#7C3AED]" />
                <span>Live tests with a real timer — the pressure of a real exam, the polish of a great app</span>
              </li>
              <li className="flex items-start gap-3">
                <span className="mt-1.5 w-1.5 h-1.5 rounded-full bg-[#7C3AED]" />
                <span>Personal analytics that celebrate your wins and highlight what to work on next</span>
              </li>
            </ul>
          </motion.div>
        </div>
      </section>
    </div>
  );
}
