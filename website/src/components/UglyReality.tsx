"use client";

import { motion, useInView, AnimatePresence } from "framer-motion";
import { useRef, useState, useEffect } from "react";
import { ArrowRight, Folder, FileVideo, Image, Camera } from "@phosphor-icons/react";
import ParallaxOrb from "./ParallaxOrb";

interface Transformation {
  id: string;
  icon: React.ElementType;
  before: string | string[];
  after: string;
  category: string;
  description: string;
}

const transformations: Transformation[] = [
  {
    id: "final-hell",
    icon: FileVideo,
    before: "Final_v2_edit_FINAL_FOR-REAL.mov",
    after: "ClientName_Deliverable_2024-03.mov",
    category: "Video Files",
    description: "Version control chaos, solved.",
  },
  {
    id: "screenshot-mess",
    icon: Image,
    before: "Screenshot 2024-11-01 at 9.23.45 AM.png",
    after: "Screenshots/2024-11/screen-capture-01.png",
    category: "Screenshots",
    description: "Timestamps become structure.",
  },
  {
    id: "photo-dump",
    icon: Camera,
    before: ["IMG_4521.jpg", "IMG_4522.jpg", "IMG_4523.jpg", "...", "IMG_4589.jpg"],
    after: "Photos/2024-11-Trip/",
    category: "Photo Batches",
    description: "68 files, one destination.",
  },
];

function FileItem({
  filename,
  isBefore = true,
  isAnimating = false,
  index = 0,
}: {
  filename: string;
  isBefore?: boolean;
  isAnimating?: boolean;
  index?: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, x: isBefore ? -20 : 20 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: isBefore ? -20 : 20 }}
      transition={{ delay: index * 0.05, duration: 0.3 }}
      className={`
        px-3 py-2 rounded-lg font-mono text-sm
        ${isBefore
          ? "bg-forma-warm-orange/10 border border-forma-warm-orange/20 text-forma-bone/70"
          : "bg-forma-sage/10 border border-forma-sage/20 text-forma-bone/90"
        }
        ${isAnimating ? "animate-pulse" : ""}
      `}
    >
      {filename}
    </motion.div>
  );
}

function TransformationCard({
  transformation,
  isActive,
}: {
  transformation: Transformation;
  isActive: boolean;
}) {
  const [phase, setPhase] = useState<"before" | "animating" | "after">("before");
  const Icon = transformation.icon;

  useEffect(() => {
    if (!isActive) {
      setPhase("before");
      return;
    }

    // Cycle through phases when active
    const timer1 = setTimeout(() => setPhase("animating"), 800);
    const timer2 = setTimeout(() => setPhase("after"), 1800);

    return () => {
      clearTimeout(timer1);
      clearTimeout(timer2);
    };
  }, [isActive]);

  const beforeFiles = Array.isArray(transformation.before)
    ? transformation.before
    : [transformation.before];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: isActive ? 1 : 0.5, y: 0 }}
      className={`
        glass-card rounded-2xl p-6 transition-all duration-500
        ${isActive ? "ring-2 ring-forma-steel-blue/30 shadow-glow-blue" : ""}
      `}
    >
      {/* Header */}
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-forma-warm-orange/20 to-forma-sage/20 flex items-center justify-center">
          <Icon className="w-5 h-5 text-forma-bone/80" />
        </div>
        <div>
          <span className="text-xs uppercase tracking-wider text-forma-bone/40 font-medium">
            {transformation.category}
          </span>
          <p className="text-sm text-forma-bone/60">{transformation.description}</p>
        </div>
      </div>

      {/* Transformation Visual */}
      <div className="relative">
        {/* Before State */}
        <div className="mb-4">
          <span className="text-xs uppercase tracking-wider text-forma-warm-orange/70 font-medium mb-2 block">
            Before
          </span>
          <div className="space-y-1.5">
            <AnimatePresence mode="wait">
              {phase === "before" && (
                <>
                  {beforeFiles.map((file, idx) => (
                    <FileItem
                      key={file}
                      filename={file}
                      isBefore
                      index={idx}
                    />
                  ))}
                </>
              )}
            </AnimatePresence>

            {/* Animating state - files flying away */}
            {phase === "animating" && (
              <div className="space-y-1.5">
                {beforeFiles.map((file, idx) => (
                  <motion.div
                    key={file}
                    initial={{ opacity: 1, x: 0, scale: 1 }}
                    animate={{
                      opacity: 0,
                      x: 100,
                      scale: 0.8,
                      filter: "blur(4px)",
                    }}
                    transition={{
                      delay: idx * 0.08,
                      duration: 0.4,
                      ease: "easeIn",
                    }}
                    className="px-3 py-2 rounded-lg font-mono text-sm bg-forma-warm-orange/10 border border-forma-warm-orange/20 text-forma-bone/70"
                  >
                    {file}
                  </motion.div>
                ))}
              </div>
            )}

            {phase === "after" && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 0.3 }}
                className="h-10 flex items-center justify-center"
              >
                <span className="text-forma-bone/30 text-sm line-through">
                  {beforeFiles.length > 1 ? `${beforeFiles.length - 1} messy files` : beforeFiles[0]}
                </span>
              </motion.div>
            )}
          </div>
        </div>

        {/* Arrow Indicator */}
        <div className="flex justify-center my-3">
          <motion.div
            animate={{
              y: phase === "animating" ? [0, 5, 0] : 0,
              scale: phase === "animating" ? [1, 1.2, 1] : 1,
            }}
            transition={{ duration: 0.4 }}
            className={`
              w-8 h-8 rounded-full flex items-center justify-center
              ${phase === "after"
                ? "bg-forma-sage/20"
                : "bg-white/5"
              }
            `}
          >
            <ArrowRight
              className={`w-4 h-4 transition-colors duration-300 ${
                phase === "after" ? "text-forma-sage" : "text-forma-bone/40"
              }`}
            />
          </motion.div>
        </div>

        {/* After State */}
        <div>
          <span className="text-xs uppercase tracking-wider text-forma-sage/70 font-medium mb-2 block">
            After
          </span>
          <AnimatePresence mode="wait">
            {phase === "after" ? (
              <motion.div
                initial={{ opacity: 0, x: 20, scale: 0.95 }}
                animate={{ opacity: 1, x: 0, scale: 1 }}
                className="px-4 py-3 rounded-lg font-mono text-sm bg-forma-sage/15 border border-forma-sage/30 text-forma-bone flex items-center gap-2"
              >
                <Folder className="w-4 h-4 text-forma-sage" />
                {transformation.after}
              </motion.div>
            ) : (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 0.5 }}
                className="px-4 py-3 rounded-lg font-mono text-sm bg-white/5 border border-white/10 text-forma-bone/40"
              >
                <span className="opacity-50">{transformation.after}</span>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </div>
    </motion.div>
  );
}

export default function UglyReality() {
  const sectionRef = useRef(null);
  const isInView = useInView(sectionRef, { once: true, margin: "-100px" });
  const [activeIndex, setActiveIndex] = useState(0);

  // Cycle through transformations
  useEffect(() => {
    const interval = setInterval(() => {
      setActiveIndex((prev) => (prev + 1) % transformations.length);
    }, 4000);

    return () => clearInterval(interval);
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative py-24 md:py-32 overflow-hidden"
    >
      {/* Background Orbs */}
      <ParallaxOrb
        color="orange"
        size="lg"
        position={{ top: "10%", left: "5%" }}
        speed={-40}
        opacity={0.25}
        className="animate-float-slower"
      />
      <ParallaxOrb
        color="sage"
        size="md"
        position={{ bottom: "20%", right: "10%" }}
        speed={-25}
        opacity={0.2}
        className="animate-float"
      />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        {/* Section Header */}
        <div className="text-center max-w-3xl mx-auto mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
          >
            <span className="w-2 h-2 rounded-full bg-forma-warm-orange animate-pulse" />
            <span className="text-sm font-medium text-forma-bone/80">
              The Ugly Reality
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-3xl md:text-4xl lg:text-5xl text-forma-bone mb-6"
          >
            We Handle the{" "}
            <span className="gradient-text-warm">Real Messes</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            Anyone whose ever named a file{" "}
            <span className="font-mono text-forma-warm-orange/80 text-base">
              Final_v2_edit_FINAL_FOR-REAL.mov
            </span>{" "}
            knows the struggle. Forma turns chaos into structure.
          </motion.p>
        </div>

        {/* Transformation Cards Grid */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6, delay: 0.3 }}
          className="grid md:grid-cols-3 gap-6 mb-12"
        >
          {transformations.map((transformation, index) => (
            <TransformationCard
              key={transformation.id}
              transformation={transformation}
              isActive={index === activeIndex}
            />
          ))}
        </motion.div>

        {/* Progress Indicators */}
        <div className="flex justify-center gap-2">
          {transformations.map((_, index) => (
            <button
              key={index}
              onClick={() => setActiveIndex(index)}
              className={`
                h-1.5 rounded-full transition-all duration-300
                ${index === activeIndex
                  ? "w-8 bg-forma-steel-blue"
                  : "w-1.5 bg-white/20 hover:bg-white/30"
                }
              `}
              aria-label={`View transformation ${index + 1}`}
            />
          ))}
        </div>

        {/* Bottom Message */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={isInView ? { opacity: 1 } : {}}
          transition={{ duration: 0.6, delay: 0.5 }}
          className="mt-16 text-center"
        >
          <div className="glass-card-strong rounded-2xl p-6 md:p-8 max-w-2xl mx-auto">
            <p className="text-forma-bone/80 text-lg font-medium mb-2">
              Your files are messy. That is the point.
            </p>
            <p className="text-forma-bone/50 text-sm">
              Forma does not require perfect input. It infers structure from the chaos
              and proposes destinations based on your rules. You approve, it executes.
            </p>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
