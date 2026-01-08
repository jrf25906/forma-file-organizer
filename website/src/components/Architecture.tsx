"use client";

import { motion, useInView, useScroll, useTransform } from "framer-motion";
import { useRef, useState, useEffect } from "react";
import {
  Sparkles,
  Eye,
  CheckCircle2,
  RotateCcw,
  Layers,
  HardDrive,
  ArrowDown,
} from "lucide-react";
import ParallaxOrb from "./ParallaxOrb";

// Animated flowing connection between layers
function LayerConnector({
  fromColor,
  toColor,
  delay = 0,
}: {
  fromColor: string;
  toColor: string;
  delay?: number;
}) {
  return (
    <div className="relative h-16 w-full flex items-center justify-center">
      {/* Static arrow indicator */}
      <div className="absolute inset-0 flex items-center justify-center">
        <ArrowDown className="w-6 h-6 text-forma-bone/30" />
      </div>

      {/* Flowing particles */}
      {[0, 1, 2].map((i) => (
        <motion.div
          key={i}
          className="absolute w-3 h-3 rounded-full"
          style={{
            background: `linear-gradient(180deg, ${fromColor}, ${toColor})`,
            boxShadow: `0 0 12px ${fromColor}`,
          }}
          initial={{ y: -20, opacity: 0, scale: 0.5 }}
          animate={{
            y: ["-100%", "100%"],
            opacity: [0, 1, 1, 0],
            scale: [0.5, 1, 1, 0.5],
          }}
          transition={{
            duration: 2,
            delay: delay + i * 0.6,
            repeat: Infinity,
            ease: "easeInOut",
          }}
        />
      ))}

      {/* Vertical line */}
      <div
        className="absolute h-full w-px opacity-20"
        style={{
          background: `linear-gradient(180deg, ${fromColor}, ${toColor})`,
        }}
      />
    </div>
  );
}

// Individual architecture layer component
function ArchitectureLayer({
  title,
  subtitle,
  features,
  icon: Icon,
  color,
  delay,
  isMiddle = false,
}: {
  title: string;
  subtitle: string;
  features: string[];
  icon: React.ElementType;
  color: string;
  delay: number;
  isMiddle?: boolean;
}) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-50px" });

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 30, scale: 0.95 }}
      animate={isInView ? { opacity: 1, y: 0, scale: 1 } : {}}
      transition={{ duration: 0.7, delay, ease: [0.16, 1, 0.3, 1] }}
      className={`relative ${isMiddle ? "z-10" : ""}`}
    >
      {/* Glow effect for middle layer */}
      {isMiddle && (
        <motion.div
          className="absolute -inset-4 rounded-3xl opacity-50"
          style={{
            background: `radial-gradient(ellipse at center, ${color}20, transparent 70%)`,
          }}
          animate={{
            opacity: [0.3, 0.6, 0.3],
            scale: [1, 1.02, 1],
          }}
          transition={{
            duration: 3,
            repeat: Infinity,
            ease: "easeInOut",
          }}
        />
      )}

      <div
        className={`relative glass-card-strong rounded-2xl p-6 md:p-8 ${
          isMiddle ? "ring-2 ring-forma-sage/30" : ""
        }`}
      >
        {/* Layer badge for Forma */}
        {isMiddle && (
          <motion.div
            initial={{ opacity: 0, x: -10 }}
            animate={isInView ? { opacity: 1, x: 0 } : {}}
            transition={{ delay: delay + 0.3 }}
            className="absolute -top-3 left-6 px-3 py-1 rounded-full bg-forma-sage/20 border border-forma-sage/30"
          >
            <span className="text-xs font-medium text-forma-sage uppercase tracking-wider">
              The Layer
            </span>
          </motion.div>
        )}

        <div className="flex items-start gap-4 md:gap-6">
          {/* Icon container */}
          <motion.div
            className="flex-shrink-0 w-14 h-14 md:w-16 md:h-16 rounded-xl flex items-center justify-center"
            style={{
              background: `linear-gradient(135deg, ${color}30, ${color}10)`,
              border: `1px solid ${color}40`,
            }}
            whileHover={{ scale: 1.05, rotate: 2 }}
            transition={{ type: "spring", stiffness: 300 }}
          >
            <Icon className="w-7 h-7 md:w-8 md:h-8" style={{ color }} />
          </motion.div>

          {/* Content */}
          <div className="flex-1 min-w-0">
            <h3 className="font-display font-bold text-xl md:text-2xl text-forma-bone mb-1">
              {title}
            </h3>
            <p className="text-sm md:text-base text-forma-bone/60 mb-4">
              {subtitle}
            </p>

            {/* Features list */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
              {features.map((feature, i) => (
                <motion.div
                  key={feature}
                  initial={{ opacity: 0, x: -10 }}
                  animate={isInView ? { opacity: 1, x: 0 } : {}}
                  transition={{ delay: delay + 0.2 + i * 0.1 }}
                  className="flex items-center gap-2 text-sm text-forma-bone/70"
                >
                  <div
                    className="w-1.5 h-1.5 rounded-full flex-shrink-0"
                    style={{ background: color }}
                  />
                  {feature}
                </motion.div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  );
}

// Trust indicators at the bottom
function TrustIndicators() {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-50px" });

  const indicators = [
    { icon: Eye, label: "Preview First", description: "See before it moves" },
    {
      icon: CheckCircle2,
      label: "You Approve",
      description: "Nothing automatic",
    },
    { icon: RotateCcw, label: "Always Reversible", description: "Undo anytime" },
  ];

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 20 }}
      animate={isInView ? { opacity: 1, y: 0 } : {}}
      transition={{ duration: 0.6, delay: 0.8 }}
      className="flex flex-wrap justify-center gap-6 md:gap-10 mt-12"
    >
      {indicators.map((item, i) => (
        <motion.div
          key={item.label}
          initial={{ opacity: 0, scale: 0.9 }}
          animate={isInView ? { opacity: 1, scale: 1 } : {}}
          transition={{ delay: 0.9 + i * 0.1 }}
          className="flex items-center gap-3"
        >
          <div className="w-10 h-10 rounded-lg bg-forma-steel-blue/20 flex items-center justify-center">
            <item.icon className="w-5 h-5 text-forma-steel-blue" />
          </div>
          <div>
            <div className="text-sm font-medium text-forma-bone">
              {item.label}
            </div>
            <div className="text-xs text-forma-bone/50">{item.description}</div>
          </div>
        </motion.div>
      ))}
    </motion.div>
  );
}

export default function Architecture() {
  const sectionRef = useRef(null);
  const isInView = useInView(sectionRef, { once: true, margin: "-100px" });

  // Define the three layers
  const layers = [
    {
      title: "Your Intent",
      subtitle: "Rules you define in plain language",
      features: [
        "Declarative rules",
        "Pattern matching",
        "Context from file types",
        "Your logic, your control",
      ],
      icon: Sparkles,
      color: "rgb(91, 124, 153)", // steel-blue
      isMiddle: false,
    },
    {
      title: "Forma Layer",
      subtitle: "The intelligent coordinator between you and your files",
      features: [
        "Proposes changes",
        "Shows preview",
        "Waits for approval",
        "Maintains undo history",
      ],
      icon: Layers,
      color: "rgb(122, 157, 126)", // sage
      isMiddle: true,
    },
    {
      title: "macOS File System",
      subtitle: "Native APIs, direct moves, every action reversible",
      features: [
        "Native file operations",
        "Direct to Finder",
        "No abstraction layer",
        "Your files stay yours",
      ],
      icon: HardDrive,
      color: "rgb(201, 126, 102)", // warm-orange
      isMiddle: false,
    },
  ];

  return (
    <section
      id="architecture"
      ref={sectionRef}
      className="relative py-24 md:py-32 overflow-hidden"
    >
      {/* Background effects */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-sage/5 to-transparent" />
      <ParallaxOrb
        color="sage"
        size="xl"
        position={{ top: "10%", right: "-15%" }}
        speed={-60}
        opacity={0.25}
        className="animate-float-slow"
      />
      <ParallaxOrb
        color="blue"
        size="lg"
        position={{ bottom: "20%", left: "-10%" }}
        speed={-40}
        opacity={0.2}
        className="animate-float"
      />

      <div className="relative z-10 max-w-4xl mx-auto px-6">
        {/* Section Header */}
        <div className="text-center mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
          >
            <Layers className="w-4 h-4 text-forma-sage" />
            <span className="text-sm font-medium text-forma-bone/80">
              A Layer, Not a Replacement
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-3xl md:text-5xl text-forma-bone mb-6"
          >
            Where Forma Lives in
            <br />
            <span className="gradient-text">Your System</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60 max-w-2xl mx-auto"
          >
            Forma uses native macOS file APIs to organize your files directly —
            but only after you preview and approve each action. Every move is
            recorded and reversible.
          </motion.p>
        </div>

        {/* Architecture Diagram */}
        <div className="relative">
          {/* Layer 1: Your Intent */}
          <ArchitectureLayer {...layers[0]} delay={0.3} />

          {/* Connector 1 */}
          <LayerConnector
            fromColor="rgb(91, 124, 153)"
            toColor="rgb(122, 157, 126)"
            delay={0.4}
          />

          {/* Layer 2: Forma (highlighted) */}
          <ArchitectureLayer {...layers[1]} delay={0.5} />

          {/* Connector 2 */}
          <LayerConnector
            fromColor="rgb(122, 157, 126)"
            toColor="rgb(201, 126, 102)"
            delay={0.6}
          />

          {/* Layer 3: macOS File System */}
          <ArchitectureLayer {...layers[2]} delay={0.7} />
        </div>

        {/* Key message callout */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6, delay: 1 }}
          className="mt-12 p-6 rounded-xl bg-gradient-to-r from-forma-steel-blue/10 via-forma-sage/10 to-forma-warm-orange/10 border border-white/10"
        >
          <p className="text-center text-forma-bone/80 text-lg font-medium">
            <span className="text-forma-sage">
              Forma is not a file manager.
            </span>{" "}
            It&apos;s a system layer that executes your intent — safely,
            transparently, and reversibly.
          </p>
        </motion.div>

        {/* Trust indicators */}
        <TrustIndicators />
      </div>
    </section>
  );
}
