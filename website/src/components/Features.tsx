"use client";

import { motion, useInView } from "framer-motion";
import { useRef, useState } from "react";
import {
  Wand2,
  Puzzle,
  BarChart3,
  FolderSearch,
  Zap,
  Shield,
  Layers,
  Clock,
} from "lucide-react";
import { featureDemos } from "./FeatureMiniDemo";
import ParallaxOrb from "./ParallaxOrb";

const features = [
  {
    icon: Wand2,
    title: "Declarative Rule Builder",
    description:
      "Create organization rules with conditions based on file type, name, date, size, and more. Define your intent in plain language — Forma executes it precisely.",
    color: "steel-blue",
    gradient: "from-forma-steel-blue to-forma-muted-blue",
  },
  {
    icon: Puzzle,
    title: "Pattern Matching",
    description:
      "Forma infers structure from file extensions, naming patterns, dates, and sizes. Correct a suggestion once — Forma adapts.",
    color: "sage",
    gradient: "from-forma-sage to-forma-soft-green",
  },
  {
    icon: BarChart3,
    title: "Storage Analytics",
    description:
      "Visualize your file organization health with detailed analytics. Track trends, identify problem areas, and celebrate your progress.",
    color: "warm-orange",
    gradient: "from-forma-warm-orange to-forma-muted-blue",
  },
  {
    icon: FolderSearch,
    title: "Duplicate Detection",
    description:
      "Find and manage duplicate files across your system. Reclaim gigabytes of storage with content-based similarity matching.",
    color: "muted-blue",
    gradient: "from-forma-muted-blue to-forma-steel-blue",
  },
  {
    icon: Zap,
    title: "Instant Organization",
    description:
      "Review and approve file movements in batches. One click organizes dozens of files while you stay in complete control.",
    color: "soft-green",
    gradient: "from-forma-soft-green to-forma-sage",
  },
  {
    icon: Shield,
    title: "Safe & Reversible",
    description:
      "Every action is logged and reversible. Forma never deletes files without explicit permission—your data is always protected.",
    color: "steel-blue",
    gradient: "from-forma-steel-blue to-forma-sage",
  },
];

const secondaryFeatures = [
  {
    icon: Layers,
    title: "Natural Language Rules",
    description: "Create rules by typing naturally: 'Move PDFs older than 30 days to Archives'",
  },
  {
    icon: Clock,
    title: "Scheduled Scans",
    description: "Set it and forget it—Forma runs on your schedule to keep things tidy",
  },
];

function FeatureCard({
  feature,
  index,
}: {
  feature: (typeof features)[0];
  index: number;
}) {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });
  const [isHovered, setIsHovered] = useState(false);

  // Get the demo component for this feature
  const DemoComponent = featureDemos[feature.title];

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 40, scale: 0.95 }}
      animate={isInView ? { opacity: 1, y: 0, scale: 1 } : {}}
      transition={{
        duration: 0.7,
        delay: index * 0.1,
        ease: [0.16, 1, 0.3, 1],
      }}
      whileHover={{ y: -8 }}
      onHoverStart={() => setIsHovered(true)}
      onHoverEnd={() => setIsHovered(false)}
      className="group relative"
    >
      <div className="glass-card rounded-2xl p-8 h-full transition-all duration-500 hover:shadow-glass-lg hover:border-white/20">
        {/* Icon with enhanced animation */}
        <motion.div
          className={`w-14 h-14 rounded-xl bg-gradient-to-br ${feature.gradient} p-[1px] mb-6`}
          whileHover={{
            scale: 1.1,
            rotate: [0, -5, 5, 0],
          }}
          transition={{ duration: 0.4 }}
        >
          <div className="w-full h-full rounded-xl bg-forma-obsidian/80 flex items-center justify-center backdrop-blur-sm group-hover:bg-forma-obsidian/60 transition-colors">
            <motion.div
              initial={{ scale: 1 }}
              whileHover={{ scale: 1.2, rotate: 10 }}
              transition={{ type: "spring", stiffness: 400, damping: 10 }}
            >
              <feature.icon className={`w-6 h-6 text-forma-${feature.color}`} />
            </motion.div>
          </div>
        </motion.div>

        {/* Content with staggered reveal */}
        <motion.h3
          initial={{ opacity: 0, x: -10 }}
          animate={isInView ? { opacity: 1, x: 0 } : {}}
          transition={{ delay: index * 0.1 + 0.2, duration: 0.4 }}
          className="font-display font-bold text-xl text-forma-bone mb-3 group-hover:text-forma-steel-blue transition-colors"
        >
          {feature.title}
        </motion.h3>
        <motion.p
          initial={{ opacity: 0, x: -10 }}
          animate={isInView ? { opacity: 1, x: 0 } : {}}
          transition={{ delay: index * 0.1 + 0.3, duration: 0.4 }}
          className="text-forma-bone/60 leading-relaxed"
        >
          {feature.description}
        </motion.p>

        {/* Mini Demo on Hover */}
        {DemoComponent && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{
              opacity: isHovered ? 1 : 0,
              height: isHovered ? "auto" : 0,
            }}
            transition={{ duration: 0.3 }}
            className="mt-4 pt-4 border-t border-white/10 overflow-hidden"
          >
            <DemoComponent />
          </motion.div>
        )}

        {/* Hover Glow with enhanced animation */}
        <motion.div
          className={`absolute inset-0 rounded-2xl bg-gradient-to-br ${feature.gradient}`}
          initial={{ opacity: 0 }}
          whileHover={{ opacity: 0.08 }}
          transition={{ duration: 0.3 }}
          style={{ zIndex: -1 }}
        />

        {/* Subtle shimmer effect on hover */}
        <div className="absolute inset-0 rounded-2xl overflow-hidden opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none">
          <div className="animate-shimmer absolute inset-0" />
        </div>
      </div>
    </motion.div>
  );
}

export default function Features() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });

  return (
    <section id="features" className="relative py-32 overflow-hidden">
      {/* Background Orbs with Parallax */}
      <ParallaxOrb
        color="sage"
        size="xl"
        position={{ top: "0", right: "25%" }}
        speed={-60}
        opacity={0.4}
        className="animate-float-slower"
      />
      <ParallaxOrb
        color="blue"
        size="md"
        position={{ bottom: "25%", left: "0" }}
        speed={-30}
        opacity={0.3}
        className="animate-float"
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
            <span className="w-2 h-2 rounded-full bg-forma-sage animate-pulse" />
            <span className="text-sm font-medium text-forma-bone/80">
              Powerful Features
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Everything You Need to
            <br />
            <span className="gradient-text-warm">Master Your Files</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            Forma combines rule-based automation with intuitive controls,
            giving you the power to organize without the overhead.
          </motion.p>
        </div>

        {/* Feature Grid */}
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-16">
          {features.map((feature, index) => (
            <FeatureCard key={feature.title} feature={feature} index={index} />
          ))}
        </div>

        {/* Secondary Features Bar */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="glass-card-strong rounded-2xl p-8 relative overflow-hidden"
        >
          {/* Background shimmer */}
          <div className="absolute inset-0 animate-shimmer opacity-50" />

          <div className="grid md:grid-cols-2 gap-8 relative z-10">
            {secondaryFeatures.map((feature, index) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, x: index === 0 ? -20 : 20 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ delay: 0.2 + index * 0.15, duration: 0.5 }}
                whileHover={{ scale: 1.02 }}
                className="flex items-start gap-4 group cursor-default"
              >
                <motion.div
                  className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center shrink-0 group-hover:bg-white/10 transition-colors"
                  whileHover={{ rotate: [0, -10, 10, 0] }}
                  transition={{ duration: 0.5 }}
                >
                  <feature.icon className="w-5 h-5 text-forma-bone/70 group-hover:text-forma-steel-blue transition-colors" />
                </motion.div>
                <div>
                  <h4 className="font-display font-semibold text-forma-bone mb-1 group-hover:text-forma-steel-blue transition-colors">
                    {feature.title}
                  </h4>
                  <p className="text-sm text-forma-bone/50">
                    {feature.description}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  );
}
