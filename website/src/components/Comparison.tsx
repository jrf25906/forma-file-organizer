"use client";

import { motion } from "framer-motion";
import { useRef } from "react";
import { useInView } from "framer-motion";
import { Check, X, Minus } from "@phosphor-icons/react";

const comparisonFeatures = [
  {
    feature: "Declarative rule-based organization",
    forma: true,
    folders: false,
    tags: false,
    hazel: true,
    raycast: false,
  },
  {
    feature: "Preview-first execution",
    forma: true,
    folders: false,
    tags: false,
    hazel: false,
    raycast: false,
  },
  {
    feature: "Full reversibility",
    forma: true,
    folders: false,
    tags: false,
    hazel: false,
    raycast: false,
  },
  {
    feature: "Persistent organization",
    forma: true,
    folders: "partial",
    tags: true,
    hazel: true,
    raycast: false,
  },
  {
    feature: "Low maintenance",
    forma: true,
    folders: false,
    tags: false,
    hazel: true,
    raycast: true,
  },
  {
    feature: "No technical expertise required",
    forma: true,
    folders: true,
    tags: true,
    hazel: false,
    raycast: "partial",
  },
  {
    feature: "100% local processing",
    forma: true,
    folders: true,
    tags: true,
    hazel: true,
    raycast: true,
  },
  {
    feature: "Native macOS experience",
    forma: true,
    folders: true,
    tags: true,
    hazel: "partial",
    raycast: true,
  },
  {
    feature: "Free tier available",
    forma: true,
    folders: true,
    tags: true,
    hazel: false,
    raycast: "partial",
  },
];

const competitors = [
  { name: "Forma", highlight: true },
  { name: "Folders", highlight: false },
  { name: "Tags", highlight: false },
  { name: "Hazel", highlight: false },
  { name: "Raycast", highlight: false },
];

function FeatureCheck({ value }: { value: boolean | string }) {
  if (value === true) {
    return (
      <div className="w-6 h-6 rounded-full bg-forma-sage/20 flex items-center justify-center">
        <Check className="w-4 h-4 text-forma-sage" />
      </div>
    );
  }
  if (value === "partial") {
    return (
      <div className="w-6 h-6 rounded-full bg-forma-warm-orange/20 flex items-center justify-center">
        <Minus className="w-4 h-4 text-forma-warm-orange" />
      </div>
    );
  }
  return (
    <div className="w-6 h-6 rounded-full bg-white/5 flex items-center justify-center">
      <X className="w-4 h-4 text-forma-bone/30" />
    </div>
  );
}

export default function Comparison() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });

  return (
    <section className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-warm-orange/5 to-transparent" />
      <div className="orb orb-orange w-72 h-72 top-1/4 -left-36 animate-float-slow opacity-20" />
      <div className="orb orb-blue w-64 h-64 bottom-1/4 -right-32 animate-float opacity-20" />

      <div className="relative z-10 max-w-6xl mx-auto px-6">
        {/* Section Header */}
        <div ref={headerRef} className="text-center max-w-3xl mx-auto mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
          >
            <span className="w-2 h-2 rounded-full bg-forma-warm-orange animate-pulse" />
            <span className="text-sm font-medium text-forma-bone/80">
              Why Choose Forma
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Not Just Another
            <br />
            <span className="gradient-text-warm">File Organizer</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            Forma sits in the sweet spot: declarative rules you define,
            preview-first execution, and full reversibility. No manual upkeep,
            no fragile scripts.
          </motion.p>
        </div>

        {/* Comparison Table */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="glass-card-strong rounded-2xl overflow-hidden"
        >
          {/* Table Header */}
          <div className="grid grid-cols-6 gap-3 p-6 border-b border-white/10 bg-white/5">
            <div className="text-forma-bone/50 font-medium">Feature</div>
            {competitors.map((comp) => (
              <div
                key={comp.name}
                className={`text-center font-display font-semibold text-sm ${
                  comp.highlight ? "text-forma-steel-blue" : "text-forma-bone/70"
                }`}
              >
                {comp.name}
                {comp.highlight && (
                  <span className="block text-xs text-forma-sage font-normal mt-0.5">
                    ✨ That&apos;s us
                  </span>
                )}
              </div>
            ))}
          </div>

          {/* Table Body */}
          <div className="divide-y divide-white/5">
            {comparisonFeatures.map((row, index) => (
              <motion.div
                key={row.feature}
                initial={{ opacity: 0, x: -20 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.05 }}
                className="grid grid-cols-6 gap-3 p-4 hover:bg-white/5 transition-colors"
              >
                <div className="text-forma-bone/80 text-sm flex items-center">
                  {row.feature}
                </div>
                <div className="flex justify-center">
                  <FeatureCheck value={row.forma} />
                </div>
                <div className="flex justify-center">
                  <FeatureCheck value={row.folders} />
                </div>
                <div className="flex justify-center">
                  <FeatureCheck value={row.tags} />
                </div>
                <div className="flex justify-center">
                  <FeatureCheck value={row.hazel} />
                </div>
                <div className="flex justify-center">
                  <FeatureCheck value={row.raycast} />
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Bottom Note */}
        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.3 }}
          className="text-center mt-8 text-sm text-forma-bone/40"
        >
          Comparison based on typical use cases as of January 2025.
        </motion.p>
      </div>
    </section>
  );
}
