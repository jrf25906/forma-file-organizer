"use client";

import { motion } from "framer-motion";
import { useRef } from "react";
import { useInView } from "framer-motion";
import { ArrowRight, Sparkle } from "@phosphor-icons/react";

export default function DownloadCTA() {
  const ref = useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });

  return (
    <section id="download" className="relative py-32 overflow-hidden">
      {/* Background Gradient */}
      <div className="absolute inset-0">
        <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-steel-blue/10 to-forma-obsidian" />
        <div className="orb orb-blue w-[600px] h-[600px] top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 opacity-20" />
        <div className="orb orb-sage w-96 h-96 top-0 left-1/4 animate-float-slower opacity-20" />
        <div className="orb orb-orange w-64 h-64 bottom-0 right-1/4 animate-float opacity-20" />
      </div>

      <div ref={ref} className="relative z-10 max-w-5xl mx-auto px-6">
        <motion.div
          initial={{ opacity: 0, y: 60 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.8 }}
          className="text-center"
        >
          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={isInView ? { opacity: 1, scale: 1 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-8"
          >
            <Sparkle className="w-4 h-4 text-forma-sage" />
            <span className="text-sm font-medium text-forma-bone/80">
              Free to Get Started
            </span>
          </motion.div>

          {/* Headline */}
          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.3 }}
            className="font-display font-bold text-4xl md:text-6xl lg:text-7xl text-forma-bone mb-6"
          >
            Ready to Bring
            <br />
            <span className="gradient-text">Order to Chaos?</span>
          </motion.h2>

          {/* Subheadline */}
          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.4 }}
            className="text-lg md:text-xl text-forma-bone/60 max-w-2xl mx-auto mb-12"
          >
            Download Forma today and experience the satisfaction of a perfectly
            organized digital life. Your future self will thank you.
          </motion.p>

          {/* CTA Buttons */}
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={isInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.5 }}
            className="flex flex-col sm:flex-row gap-4 justify-center items-center"
          >
            <motion.a
              href="#"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.98 }}
              className="group relative overflow-hidden"
            >
              <div className="btn-primary text-forma-bone flex items-center gap-3 text-lg px-8 py-4">
                {/* Apple Logo */}
                <svg className="w-6 h-6" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                </svg>
                <div className="text-left">
                  <div className="text-xs opacity-80">Download for</div>
                  <div className="font-semibold -mt-0.5">macOS</div>
                </div>
                <ArrowRight className="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" />
              </div>
            </motion.a>

            <motion.a
              href="#pricing"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.98 }}
              className="btn-secondary text-forma-bone px-8 py-4"
            >
              View Pricing
            </motion.a>
          </motion.div>

          {/* Requirements */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={isInView ? { opacity: 1 } : {}}
            transition={{ duration: 0.6, delay: 0.7 }}
            className="mt-8 text-sm text-forma-bone/40"
          >
            Requires macOS 13 Ventura or later • Apple Silicon & Intel supported
          </motion.div>

          {/* App Icon Visual */}
          <motion.div
            initial={{ opacity: 0, y: 40, scale: 0.9 }}
            animate={isInView ? { opacity: 1, y: 0, scale: 1 } : {}}
            transition={{ duration: 0.8, delay: 0.6, type: "spring", stiffness: 100 }}
            className="mt-16 flex justify-center"
          >
            <motion.div
              className="relative"
              whileHover={{ scale: 1.05 }}
              transition={{ type: "spring", stiffness: 300 }}
            >
              {/* Pulsing glow ring */}
              <motion.div
                className="absolute inset-0 rounded-[2rem] bg-gradient-to-br from-forma-steel-blue via-forma-sage to-forma-warm-orange"
                animate={{
                  scale: [1, 1.1, 1],
                  opacity: [0.3, 0.5, 0.3],
                }}
                transition={{
                  repeat: Infinity,
                  duration: 3,
                  ease: "easeInOut",
                }}
                style={{ filter: "blur(20px)" }}
              />

              <motion.div
                className="w-32 h-32 rounded-[2rem] bg-gradient-to-br from-forma-steel-blue via-forma-sage to-forma-warm-orange p-[2px] shadow-glass-xl relative"
                animate={{
                  rotate: [0, 2, -2, 0],
                }}
                transition={{
                  repeat: Infinity,
                  duration: 6,
                  ease: "easeInOut",
                }}
              >
                <div className="w-full h-full rounded-[2rem] bg-forma-obsidian flex items-center justify-center">
                  <motion.svg
                    viewBox="0 0 24 24"
                    fill="none"
                    className="w-16 h-16"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    animate={{ scale: [1, 1.05, 1] }}
                    transition={{ repeat: Infinity, duration: 2, ease: "easeInOut" }}
                  >
                    <path
                      d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
                      className="fill-forma-steel-blue/20 stroke-forma-bone"
                    />
                    <motion.path
                      d="M9 14l2 2 4-4"
                      className="stroke-forma-sage"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      initial={{ pathLength: 0 }}
                      animate={isInView ? { pathLength: 1 } : {}}
                      transition={{ duration: 0.8, delay: 1 }}
                    />
                  </motion.svg>
                </div>
              </motion.div>

              {/* Floating sparkles */}
              <motion.div
                animate={{
                  y: [0, -15, 0],
                  x: [0, 5, 0],
                  opacity: [0.5, 1, 0.5],
                  rotate: [0, 15, 0],
                }}
                transition={{
                  repeat: Infinity,
                  duration: 2,
                  ease: "easeInOut",
                }}
                className="absolute -top-4 -right-4"
              >
                <Sparkle className="w-6 h-6 text-forma-sage" />
              </motion.div>

              <motion.div
                animate={{
                  y: [0, -8, 0],
                  x: [0, -3, 0],
                  opacity: [0.3, 0.8, 0.3],
                  rotate: [0, -10, 0],
                }}
                transition={{
                  repeat: Infinity,
                  duration: 2.5,
                  ease: "easeInOut",
                  delay: 0.5,
                }}
                className="absolute -bottom-2 -left-6"
              >
                <Sparkle className="w-5 h-5 text-forma-warm-orange" />
              </motion.div>

              <motion.div
                animate={{
                  y: [0, 10, 0],
                  x: [0, -5, 0],
                  opacity: [0.4, 0.9, 0.4],
                }}
                transition={{
                  repeat: Infinity,
                  duration: 3,
                  ease: "easeInOut",
                  delay: 1,
                }}
                className="absolute top-1/2 -right-8"
              >
                <Sparkle className="w-4 h-4 text-forma-steel-blue" />
              </motion.div>
            </motion.div>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
