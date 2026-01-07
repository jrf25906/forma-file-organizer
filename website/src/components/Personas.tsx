"use client";

import { motion } from "framer-motion";
import { useRef, useState, useEffect, useCallback } from "react";
import { useInView } from "framer-motion";
import {
  Palette,
  Code,
  Camera,
  GraduationCap,
  Briefcase,
  Video,
  FileText,
  Microscope,
} from "lucide-react";
import AnimatedStat from "./AnimatedStat";
import PersonaFileDemo from "./PersonaFileDemo";
import MorphingFileTypes from "./MorphingFileTypes";
import ParallaxOrb from "./ParallaxOrb";

const personas = [
  {
    id: "designer",
    icon: Palette,
    title: "Designers",
    subtitle: "UI/UX, Graphic, Product",
    painPoint: "Drowning in .sketch, .fig, and .psd files across 50 projects",
    solution: "Auto-sort by project, client, or file type. Find that mockup in seconds.",
    fileTypes: ["Figma", "Sketch", "PSD", "AI"],
    color: "warm-orange",
    stat: "4.2 hrs saved/week",
  },
  {
    id: "developer",
    icon: Code,
    title: "Developers",
    subtitle: "Frontend, Backend, Mobile",
    painPoint: "Screenshots, logs, exports scattered across Downloads",
    solution: "Smart rules for repos, debug files, and documentation.",
    fileTypes: ["ZIP", "JSON", "LOG", "SQL"],
    color: "steel-blue",
    stat: "3.8 hrs saved/week",
  },
  {
    id: "photographer",
    icon: Camera,
    title: "Photographers",
    subtitle: "Portrait, Commercial, Events",
    painPoint: "Thousands of RAW files with cryptic camera names",
    solution: "Organize by date, shoot, or metadata. Batch rename included.",
    fileTypes: ["RAW", "CR3", "NEF", "DNG"],
    color: "sage",
    stat: "6.1 hrs saved/week",
  },
  {
    id: "researcher",
    icon: Microscope,
    title: "Researchers",
    subtitle: "Academic, Scientific, Market",
    painPoint: "PDFs, datasets, and citations in complete chaos",
    solution: "Sort papers by topic, year, or citation status automatically.",
    fileTypes: ["PDF", "CSV", "XLSX", "BIB"],
    color: "muted-blue",
    stat: "5.3 hrs saved/week",
  },
  {
    id: "creator",
    icon: Video,
    title: "Content Creators",
    subtitle: "YouTube, Podcast, Social",
    painPoint: "B-roll, audio clips, and thumbnails everywhere",
    solution: "Project-based organization with automatic asset detection.",
    fileTypes: ["MP4", "MOV", "WAV", "PNG"],
    color: "warm-orange",
    stat: "4.7 hrs saved/week",
  },
  {
    id: "writer",
    icon: FileText,
    title: "Writers",
    subtitle: "Authors, Journalists, Bloggers",
    painPoint: "Drafts named 'final_final_v3_REAL.docx' scattered everywhere",
    solution: "Version tracking and project folders that make sense.",
    fileTypes: ["DOCX", "MD", "TXT", "PDF"],
    color: "soft-green",
    stat: "3.2 hrs saved/week",
  },
  {
    id: "student",
    icon: GraduationCap,
    title: "Students",
    subtitle: "Undergrad, Graduate, PhD",
    painPoint: "Assignments, readings, and notes from 6 different courses",
    solution: "Semester → Course → Assignment hierarchy, automatically.",
    fileTypes: ["PDF", "DOCX", "PPTX", "ZIP"],
    color: "steel-blue",
    stat: "2.9 hrs saved/week",
  },
  {
    id: "freelancer",
    icon: Briefcase,
    title: "Freelancers",
    subtitle: "Consultants, Contractors",
    painPoint: "Client files, invoices, and contracts in one messy pile",
    solution: "Client-based folders with automatic invoice detection.",
    fileTypes: ["PDF", "XLSX", "DOCX", "PNG"],
    color: "sage",
    stat: "4.5 hrs saved/week",
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
              Built For Professionals
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Who Uses <span className="gradient-text">Forma</span>?
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            From creative professionals to researchers, Forma adapts to how you work.
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
                  {persona.title}
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
                <div className={`w-10 h-10 rounded-xl bg-forma-${activePersona.color}/20 flex items-center justify-center`}>
                  <activePersona.icon className={`w-5 h-5 text-forma-${activePersona.color}`} />
                </div>
                <div>
                  <h3 className="font-display font-bold text-lg text-forma-bone">
                    {activePersona.title}
                  </h3>
                  <p className="text-xs text-forma-bone/50">{activePersona.subtitle}</p>
                </div>
              </div>

              <div className="mb-4">
                <div className="text-xs uppercase tracking-wider text-forma-bone/40 mb-1.5">
                  The Problem
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
                  The Forma Solution
                </div>
                <p className="text-forma-bone/80 leading-relaxed">
                  {activePersona.solution}
                </p>
              </div>

              {/* Stat */}
              <AnimatedStat
                value={parseFloat(activePersona.stat.split(' ')[0])}
                suffix={activePersona.stat.split(' ').slice(1).join(' ')}
                description={`average for ${activePersona.title.toLowerCase()}`}
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
            Don&apos;t see your profession? Forma&apos;s rules adapt to any workflow.
          </p>
          <motion.a
            href="#pricing"
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="inline-flex items-center gap-2 btn-primary text-forma-bone px-8 py-3"
          >
            Try it free for your use case
            <span>→</span>
          </motion.a>
        </motion.div>
      </div>
    </section>
  );
}
