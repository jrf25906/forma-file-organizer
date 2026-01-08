"use client";

import { motion } from "framer-motion";
import { useRef, useState, useEffect, useCallback } from "react";
import { useInView } from "framer-motion";
import {
  Download,
  FileStack,
  BookOpen,
  FileQuestion,
  Inbox,
  FolderSync,
} from "lucide-react";
import AnimatedStat from "./AnimatedStat";
import PersonaFileDemo from "./PersonaFileDemo";
import MorphingFileTypes from "./MorphingFileTypes";
import ParallaxOrb from "./ParallaxOrb";

// Behavior-based personas - targeting patterns, not job titles
const personas = [
  {
    id: "downloads-chaos",
    icon: Download,
    title: "Downloads Folder Hostage",
    subtitle: "When your productivity depends on a mess",
    painPoint:
      "Your Downloads folder is where files go to disappear. Screenshots from last week, that PDF you need right now, invoices from three months ago - all in one infinite scroll.",
    solution:
      "Declarative rules that route files as they arrive. Screenshots to dated folders, invoices detected and filed, documents sorted by project pattern.",
    fileTypes: ["PDF", "PNG", "ZIP", "DMG"],
    color: "warm-orange",
    stat: "47 files",
    statSuffix: "organized daily",
  },
  {
    id: "version-hell",
    icon: FileStack,
    title: "Final_v2_FINAL_FOR-REAL.mov",
    subtitle: "Version control without the control",
    painPoint:
      "You've named a file 'final' more than once this week. Your Desktop has three versions of the same pitch deck, and you're not sure which one you actually sent.",
    solution:
      "Pattern-based organization that detects versions and consolidates them. Clear naming, dated folders, and a history you can actually trace.",
    fileTypes: ["DOCX", "PDF", "MOV", "PSD"],
    color: "steel-blue",
    stat: "12 versions",
    statSuffix: "consolidated",
  },
  {
    id: "research-buried",
    icon: BookOpen,
    title: "Buried in PDFs",
    subtitle: "Research that disappears into folders",
    painPoint:
      "Papers, exports, screenshots of charts, notes in three different formats. You know you saved that study somewhere - you just can't remember where.",
    solution:
      "Topic-based rules that organize research materials automatically. PDFs by source, notes by project, exports by date. Find anything in seconds.",
    fileTypes: ["PDF", "CSV", "PNG", "MD"],
    color: "sage",
    stat: "89%",
    statSuffix: "faster retrieval",
  },
  {
    id: "pitch-deck-founder",
    icon: FileQuestion,
    title: "14 Pitch Decks, No Canonical",
    subtitle: "When every version might be 'the one'",
    painPoint:
      "Investor deck, board deck, team deck. V1, V2, 'final', 'actually final'. Each in a different folder, and you're never quite sure which is current.",
    solution:
      "Project-based organization with version tracking. Latest versions surface automatically, old versions archived but accessible.",
    fileTypes: ["PPTX", "PDF", "KEY", "XLSX"],
    color: "muted-blue",
    stat: "1 source",
    statSuffix: "of truth",
  },
  {
    id: "inbox-overflow",
    icon: Inbox,
    title: "Attachment Avalanche",
    subtitle: "Email attachments scattered everywhere",
    painPoint:
      "Every email attachment lands in Downloads. Contracts, receipts, that document your colleague sent last month - all mixed together with everything else.",
    solution:
      "Intelligent routing based on file patterns. Contracts to legal folders, receipts to expenses, documents matched to existing projects.",
    fileTypes: ["PDF", "DOCX", "XLSX", "PNG"],
    color: "warm-orange",
    stat: "4.2 hrs",
    statSuffix: "saved weekly",
  },
  {
    id: "screenshot-graveyard",
    icon: FolderSync,
    title: "Screenshot Archaeologist",
    subtitle: "Important captures lost in time",
    painPoint:
      "Screenshots of bugs, receipts, reference designs, conversation snippets. All with cryptic timestamps, all in one folder, all impossible to find.",
    solution:
      "Date-based organization with smart renaming. Screenshots sorted by month, duplicates detected, important captures surfaced.",
    fileTypes: ["PNG", "JPG", "HEIC", "GIF"],
    color: "steel-blue",
    stat: "156 files",
    statSuffix: "auto-sorted monthly",
  },
];

export default function Personas() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });
  const [activeIndex, setActiveIndex] = useState(0);
  const [isHovering, setIsHovering] = useState(false);
  const [isPaused, setIsPaused] = useState(false);

  const activePersona = personas[activeIndex];

  // Auto-rotate carousel
  const nextPersona = useCallback(() => {
    setActiveIndex((prev) => (prev + 1) % personas.length);
  }, []);

  useEffect(() => {
    // Don't auto-rotate if user is interacting
    if (isHovering || isPaused) return;

    const interval = setInterval(nextPersona, 4000); // Rotate every 4 seconds
    return () => clearInterval(interval);
  }, [isHovering, isPaused, nextPersona]);

  return (
    <section className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-steel-blue/5 to-transparent" />
      <ParallaxOrb
        color="blue"
        size="lg"
        position={{ top: "0", right: "-10%" }}
        speed={-50}
        opacity={0.2}
        className="animate-float-slow"
      />
      <ParallaxOrb
        color="sage"
        size="md"
        position={{ bottom: "25%", left: "-8%" }}
        speed={-35}
        opacity={0.2}
        className="animate-float"
      />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        {/* Section Header */}
        <div ref={headerRef} className="text-center max-w-3xl mx-auto mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
          >
            <span className="w-2 h-2 rounded-full bg-forma-steel-blue animate-pulse" />
            <span className="text-sm font-medium text-forma-bone/80">
              Sound Familiar?
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Built for People Who <span className="text-forma-sage">Care</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            Not for a job title. For anyone whose files outgrow folders faster
            than they can organize them.
          </motion.p>
        </div>

        {/* Persona Selector - Horizontal Scroll */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mb-12"
        >
          <div
            className="flex gap-3 overflow-x-auto pb-4 scrollbar-hide justify-start md:justify-center"
            onMouseEnter={() => setIsHovering(true)}
            onMouseLeave={() => setIsHovering(false)}
          >
            {personas.map((persona, index) => (
              <motion.button
                key={persona.id}
                onClick={() => {
                  setActiveIndex(index);
                  setIsPaused(true); // Pause auto-rotation when user clicks
                  // Resume auto-rotation after 8 seconds of no interaction
                  setTimeout(() => setIsPaused(false), 8000);
                }}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.05 }}
                className={`relative flex-shrink-0 flex items-center gap-2 px-4 py-2.5 rounded-full transition-all duration-300 overflow-hidden ${
                  activePersona.id === persona.id
                    ? `bg-forma-${persona.color}/20 border border-forma-${persona.color}/40`
                    : "glass-card hover:bg-white/10"
                }`}
              >
                <persona.icon
                  className={`w-4 h-4 ${
                    activePersona.id === persona.id
                      ? `text-forma-${persona.color}`
                      : "text-forma-bone/50"
                  }`}
                />
                <span
                  className={`text-sm font-medium whitespace-nowrap ${
                    activePersona.id === persona.id
                      ? "text-forma-bone"
                      : "text-forma-bone/60"
                  }`}
                >
                  {persona.title.length > 20
                    ? persona.title.slice(0, 20) + "..."
                    : persona.title}
                </span>
                {/* Progress bar for active item */}
                {activePersona.id === persona.id && !isHovering && !isPaused && (
                  <motion.div
                    className="absolute bottom-0 left-0 h-0.5 bg-gradient-to-r from-forma-steel-blue to-forma-sage rounded-full"
                    initial={{ width: "0%" }}
                    animate={{ width: "100%" }}
                    transition={{ duration: 4, ease: "linear" }}
                    key={`progress-${activeIndex}`}
                  />
                )}
              </motion.button>
            ))}
          </div>
        </motion.div>

        {/* Active Persona Detail Card */}
        <motion.div
          key={activePersona.id}
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4 }}
          className="glass-card-strong rounded-2xl overflow-hidden"
        >
          {/* Top - File Demo Animation */}
          <div className="border-b border-white/10">
            <PersonaFileDemo
              personaId={activePersona.id}
              color={activePersona.color}
            />
          </div>

          <div className="grid md:grid-cols-2 gap-0">
            {/* Left - Problem */}
            <div className="p-6 md:p-8 border-b md:border-b-0 md:border-r border-white/10">
              <div className="flex items-center gap-3 mb-4">
                <div
                  className={`w-10 h-10 rounded-xl bg-forma-${activePersona.color}/20 flex items-center justify-center`}
                >
                  <activePersona.icon
                    className={`w-5 h-5 text-forma-${activePersona.color}`}
                  />
                </div>
                <div>
                  <h3 className="font-display font-bold text-lg text-forma-bone">
                    {activePersona.title}
                  </h3>
                  <p className="text-xs text-forma-bone/50">
                    {activePersona.subtitle}
                  </p>
                </div>
              </div>

              <div className="mb-4">
                <div className="text-xs uppercase tracking-wider text-forma-bone/40 mb-1.5">
                  The Reality
                </div>
                <p className="text-forma-bone/70 leading-relaxed text-sm">
                  {activePersona.painPoint}
                </p>
              </div>

              <MorphingFileTypes
                fileTypes={activePersona.fileTypes}
                color={activePersona.color}
                personaKey={activePersona.id}
              />
            </div>

            {/* Right - Solution */}
            <div className={`p-6 md:p-8 bg-forma-${activePersona.color}/5`}>
              <div className="mb-4">
                <div className="text-xs uppercase tracking-wider text-forma-bone/40 mb-1.5">
                  How Forma Helps
                </div>
                <p className="text-forma-bone/80 leading-relaxed">
                  {activePersona.solution}
                </p>
              </div>

              {/* Stat */}
              <AnimatedStat
                value={parseFloat(activePersona.stat.replace(/[^0-9.]/g, ""))}
                suffix={activePersona.statSuffix}
                prefix={activePersona.stat.replace(/[0-9.]/g, "").trim()}
                description="with Forma automation"
                color={activePersona.color}
                personaKey={activePersona.id}
              />
            </div>
          </div>
        </motion.div>

        {/* Mid-Page CTA */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.3 }}
          className="text-center mt-16"
        >
          <p className="text-forma-bone/50 mb-6">
            The unifying thread isn&apos;t profession. It&apos;s care - for your
            work and your time.
          </p>
          <motion.a
            href="#pricing"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="inline-flex items-center gap-2 btn-primary text-forma-bone px-8 py-3"
          >
            Join the beta
            <span>-&gt;</span>
          </motion.a>
        </motion.div>
      </div>
    </section>
  );
}
