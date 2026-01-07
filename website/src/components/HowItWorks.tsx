"use client";

import { motion, useInView, useScroll, useTransform } from "framer-motion";
import { useRef, useEffect, useState } from "react";
import { FolderOpen, Sparkles, CheckCircle2 } from "lucide-react";
import ParallaxOrb from "./ParallaxOrb";

// Animated connection line with flowing particles
function ConnectionFlow() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start center", "end center"],
  });

  // Transform scroll progress to line draw progress
  const lineProgress = useTransform(scrollYProgress, [0, 1], [0, 1]);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const unsubscribe = lineProgress.on("change", (v) => setProgress(v));
    return () => unsubscribe();
  }, [lineProgress]);

  // Colors for each step
  const stepColors = [
    "rgb(91, 124, 153)", // steel-blue
    "rgb(122, 157, 126)", // sage
    "rgb(204, 134, 99)", // warm-orange
  ];

  return (
    <div
      ref={containerRef}
      className="hidden lg:block absolute left-1/2 top-0 bottom-0 w-8 -translate-x-1/2 pointer-events-none"
    >
      {/* Main SVG container */}
      <svg className="absolute inset-0 w-full h-full" preserveAspectRatio="none">
        {/* Background line (faded) */}
        <line
          x1="50%"
          y1="0"
          x2="50%"
          y2="100%"
          stroke="url(#lineGradient)"
          strokeWidth="2"
          strokeOpacity="0.15"
        />

        {/* Animated progress line */}
        <motion.line
          x1="50%"
          y1="0"
          x2="50%"
          y2="100%"
          stroke="url(#lineGradient)"
          strokeWidth="2"
          strokeLinecap="round"
          style={{
            pathLength: lineProgress,
          }}
          initial={{ pathLength: 0 }}
        />

        {/* Gradient definition */}
        <defs>
          <linearGradient id="lineGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stopColor={stepColors[0]} />
            <stop offset="50%" stopColor={stepColors[1]} />
            <stop offset="100%" stopColor={stepColors[2]} />
          </linearGradient>
        </defs>
      </svg>

      {/* Flowing particles */}
      {[0, 1, 2, 3, 4].map((i) => (
        <motion.div
          key={i}
          className="absolute left-1/2 -translate-x-1/2 w-2 h-2 rounded-full"
          style={{
            background: `linear-gradient(to bottom, ${stepColors[0]}, ${stepColors[2]})`,
            boxShadow: `0 0 8px ${stepColors[1]}`,
          }}
          animate={{
            top: ["0%", "100%"],
            opacity: [0, 1, 1, 0],
            scale: [0.5, 1, 1, 0.5],
          }}
          transition={{
            duration: 4,
            delay: i * 0.8,
            repeat: Infinity,
            ease: "linear",
          }}
        />
      ))}

      {/* Step indicator nodes */}
      {[0, 1, 2].map((i) => {
        const topPosition = `${16.67 + i * 33.33}%`; // Position at 1/6, 1/2, 5/6
        const isActive = progress > i * 0.33;

        return (
          <motion.div
            key={i}
            className="absolute left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{ top: topPosition }}
            initial={{ scale: 0 }}
            animate={{ scale: isActive ? 1 : 0.5, opacity: isActive ? 1 : 0.3 }}
            transition={{ duration: 0.4, type: "spring", stiffness: 300 }}
          >
            {/* Outer glow ring */}
            <motion.div
              className="absolute inset-0 rounded-full"
              style={{
                width: 24,
                height: 24,
                marginLeft: -12,
                marginTop: -12,
                background: stepColors[i],
                opacity: 0.2,
              }}
              animate={isActive ? { scale: [1, 1.5, 1], opacity: [0.2, 0.1, 0.2] } : {}}
              transition={{ duration: 2, repeat: Infinity }}
            />
            {/* Inner circle */}
            <div
              className="w-3 h-3 rounded-full border-2"
              style={{
                borderColor: stepColors[i],
                background: isActive ? stepColors[i] : "transparent",
              }}
            />
          </motion.div>
        );
      })}
    </div>
  );
}

const steps = [
  {
    number: "01",
    icon: FolderOpen,
    title: "Point to Your Folders",
    description:
      "Select the locations Forma should watch—Downloads, Desktop, Documents, or any custom folders. Forma respects your privacy and only accesses folders you explicitly choose.",
    visual: "scan",
  },
  {
    number: "02",
    icon: Sparkles,
    title: "Review Smart Suggestions",
    description:
      "Forma analyzes your files and suggests organization rules based on patterns it detects. Accept suggestions with one click, or create your own custom rules.",
    visual: "suggest",
  },
  {
    number: "03",
    icon: CheckCircle2,
    title: "Approve & Organize",
    description:
      "Review proposed file movements before they happen. Accept all, or pick and choose. Once approved, files move instantly to their new homes.",
    visual: "approve",
  },
];

function StepVisual({ type }: { type: string }) {
  if (type === "scan") {
    return (
      <div className="glass-card rounded-xl p-4 space-y-3">
        <div className="text-xs text-forma-bone/50 uppercase tracking-wider">
          Watched Locations
        </div>
        {["~/Downloads", "~/Desktop", "~/Documents"].map((path, i) => (
          <motion.div
            key={path}
            initial={{ opacity: 0, x: -10 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.15 }}
            className="flex items-center gap-3 p-3 rounded-lg bg-white/5"
          >
            <div className="w-8 h-8 rounded-lg bg-forma-steel-blue/20 flex items-center justify-center">
              <FolderOpen className="w-4 h-4 text-forma-steel-blue" />
            </div>
            <span className="text-sm text-forma-bone/80 font-mono">{path}</span>
            <div className="ml-auto w-2 h-2 rounded-full bg-forma-sage animate-pulse" />
          </motion.div>
        ))}
      </div>
    );
  }

  if (type === "suggest") {
    return (
      <div className="glass-card rounded-xl p-4 space-y-3">
        <div className="text-xs text-forma-bone/50 uppercase tracking-wider">
          Suggested Rules
        </div>
        {[
          { pattern: "*.pdf", action: "→ Documents/PDFs", confidence: "94%" },
          { pattern: "IMG_*.jpg", action: "→ Pictures/Camera", confidence: "89%" },
          { pattern: "Screenshot*", action: "→ Pictures/Screenshots", confidence: "97%" },
        ].map((rule, i) => (
          <motion.div
            key={rule.pattern}
            initial={{ opacity: 0, y: 10 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.15 }}
            className="flex items-center gap-3 p-3 rounded-lg bg-white/5"
          >
            <div className="flex-1">
              <div className="text-sm text-forma-bone font-mono">
                {rule.pattern}
              </div>
              <div className="text-xs text-forma-bone/50">{rule.action}</div>
            </div>
            <div className="px-2 py-1 rounded-full bg-forma-sage/20 text-xs text-forma-sage">
              {rule.confidence}
            </div>
          </motion.div>
        ))}
      </div>
    );
  }

  return (
    <div className="glass-card rounded-xl p-4 space-y-3">
      <div className="text-xs text-forma-bone/50 uppercase tracking-wider">
        Ready to Organize
      </div>
      {[
        { name: "report_final.pdf", dest: "Documents/Work", status: "ready" },
        { name: "vacation.jpg", dest: "Pictures/2024", status: "ready" },
        { name: "backup.zip", dest: "Archives", status: "ready" },
      ].map((file, i) => (
        <motion.div
          key={file.name}
          initial={{ opacity: 0, scale: 0.95 }}
          whileInView={{ opacity: 1, scale: 1 }}
          viewport={{ once: true }}
          transition={{ delay: i * 0.15 }}
          className="flex items-center gap-3 p-3 rounded-lg bg-white/5"
        >
          <motion.div
            initial={{ scale: 0 }}
            whileInView={{ scale: 1 }}
            viewport={{ once: true }}
            transition={{ delay: 0.3 + i * 0.15, type: "spring" }}
            className="w-6 h-6 rounded-full bg-forma-sage/20 flex items-center justify-center"
          >
            <CheckCircle2 className="w-4 h-4 text-forma-sage" />
          </motion.div>
          <div className="flex-1">
            <div className="text-sm text-forma-bone">{file.name}</div>
            <div className="text-xs text-forma-bone/50">→ {file.dest}</div>
          </div>
        </motion.div>
      ))}
      <motion.button
        whileHover={{ scale: 1.02 }}
        whileTap={{ scale: 0.98 }}
        className="w-full mt-2 btn-primary text-forma-bone text-sm"
      >
        Organize All
      </motion.button>
    </div>
  );
}

export default function HowItWorks() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });

  return (
    <section id="how-it-works" className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-steel-blue/5 to-transparent" />
      <ParallaxOrb
        color="orange"
        size="lg"
        position={{ top: "25%", left: "-10%" }}
        speed={-55}
        opacity={0.3}
        className="animate-float-slow"
      />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        {/* Section Header */}
        <div ref={headerRef} className="text-center max-w-3xl mx-auto mb-20">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
          >
            <span className="w-2 h-2 rounded-full bg-forma-steel-blue animate-pulse" />
            <span className="text-sm font-medium text-forma-bone/80">
              Simple Process
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Get Organized in
            <br />
            <span className="gradient-text">Three Simple Steps</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            No complex setup, no lengthy configuration. Start organizing your
            files in under a minute.
          </motion.p>
        </div>

        {/* Steps */}
        <div className="space-y-24 relative">
          {/* Animated connection flow */}
          <ConnectionFlow />

          {steps.map((step, index) => (
            <motion.div
              key={step.number}
              initial={{ opacity: 0, y: 60 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
              className={`grid lg:grid-cols-2 gap-12 items-center ${
                index % 2 === 1 ? "lg:flex-row-reverse" : ""
              }`}
            >
              {/* Content */}
              <div className={index % 2 === 1 ? "lg:order-2" : ""}>
                <div className="flex items-center gap-4 mb-6">
                  <motion.span
                    initial={{ scale: 0, opacity: 0 }}
                    whileInView={{ scale: 1, opacity: 0.1 }}
                    viewport={{ once: true }}
                    transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
                    className="font-display font-bold text-5xl text-forma-bone"
                  >
                    {step.number}
                  </motion.span>
                  <motion.div
                    initial={{ scale: 0, rotate: -180 }}
                    whileInView={{ scale: 1, rotate: 0 }}
                    viewport={{ once: true }}
                    transition={{ delay: 0.3, type: "spring", stiffness: 200 }}
                    whileHover={{ scale: 1.1, rotate: 5 }}
                    className="w-14 h-14 rounded-xl bg-gradient-to-br from-forma-steel-blue to-forma-sage p-[1px]"
                  >
                    <div className="w-full h-full rounded-xl bg-forma-obsidian flex items-center justify-center">
                      <motion.div
                        animate={{ y: [0, -2, 0] }}
                        transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                      >
                        <step.icon className="w-6 h-6 text-forma-bone" />
                      </motion.div>
                    </div>
                  </motion.div>
                </div>

                <motion.h3
                  initial={{ opacity: 0, x: -20 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: 0.4, duration: 0.5 }}
                  className="font-display font-bold text-3xl text-forma-bone mb-4"
                >
                  {step.title}
                </motion.h3>

                <motion.p
                  initial={{ opacity: 0, x: -20 }}
                  whileInView={{ opacity: 1, x: 0 }}
                  viewport={{ once: true }}
                  transition={{ delay: 0.5, duration: 0.5 }}
                  className="text-lg text-forma-bone/60 leading-relaxed"
                >
                  {step.description}
                </motion.p>
              </div>

              {/* Visual */}
              <motion.div
                className={index % 2 === 1 ? "lg:order-1" : ""}
                initial={{ opacity: 0, scale: 0.9, x: index % 2 === 1 ? -30 : 30 }}
                whileInView={{ opacity: 1, scale: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ delay: 0.3, duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
              >
                <div className="relative">
                  <div className="app-mockup-glow">
                    <StepVisual type={step.visual} />
                  </div>
                </div>
              </motion.div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
