"use client";

import { motion } from "framer-motion";

// Placeholder companies - replace with actual logos/press mentions when available
const trustedBy = [
  { name: "ProductHunt", type: "featured" },
  { name: "MacStories", type: "featured" },
  { name: "9to5Mac", type: "featured" },
  { name: "The Verge", type: "featured" },
  { name: "Cult of Mac", type: "featured" },
  { name: "Lifehacker", type: "featured" },
];

const usedBy = [
  "Stanford",
  "MIT",
  "Figma",
  "Notion",
  "Linear",
  "Vercel",
  "Stripe",
  "Airbnb",
];

export default function LogoMarquee() {
  // Double the arrays for seamless loop
  const featuredDouble = [...trustedBy, ...trustedBy];
  const usedByDouble = [...usedBy, ...usedBy];

  return (
    <section className="relative py-16 overflow-hidden border-y border-white/5">
      {/* Background gradient */}
      <div className="absolute inset-0 bg-gradient-to-r from-forma-obsidian via-transparent to-forma-obsidian z-10 pointer-events-none" />

      <div className="max-w-7xl mx-auto px-6 mb-8">
        <p className="text-center text-sm text-forma-bone/40 uppercase tracking-widest">
          Featured in & trusted by teams at
        </p>
      </div>

      {/* Marquee Container */}
      <div className="relative">
        {/* First Row - Press/Featured */}
        <div className="flex overflow-hidden mb-6">
          <motion.div
            animate={{ x: [0, -50 * trustedBy.length * 4] }}
            transition={{
              duration: 30,
              repeat: Infinity,
              ease: "linear",
            }}
            className="flex gap-12 items-center"
          >
            {featuredDouble.map((item, index) => (
              <div
                key={`${item.name}-${index}`}
                className="flex items-center gap-2 px-6 py-3 rounded-full glass-card shrink-0"
              >
                {item.type === "featured" && (
                  <span className="text-xs text-forma-sage uppercase tracking-wider">
                    Featured in
                  </span>
                )}
                <span className="font-display font-semibold text-forma-bone/70 whitespace-nowrap">
                  {item.name}
                </span>
              </div>
            ))}
          </motion.div>
        </div>

        {/* Second Row - Company Names (opposite direction) */}
        <div className="flex overflow-hidden">
          <motion.div
            animate={{ x: [-50 * usedBy.length * 4, 0] }}
            transition={{
              duration: 25,
              repeat: Infinity,
              ease: "linear",
            }}
            className="flex gap-16 items-center"
          >
            {usedByDouble.map((name, index) => (
              <div
                key={`${name}-${index}`}
                className="flex items-center gap-3 shrink-0 group"
              >
                {/* Placeholder logo circle */}
                <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-forma-bone/30 font-display font-bold text-sm group-hover:bg-white/10 transition-colors">
                  {name.charAt(0)}
                </div>
                <span className="font-medium text-forma-bone/40 whitespace-nowrap group-hover:text-forma-bone/60 transition-colors">
                  {name}
                </span>
              </div>
            ))}
          </motion.div>
        </div>
      </div>

      {/* Optional: "As seen on" badge */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        className="max-w-7xl mx-auto px-6 mt-10 text-center"
      >
        <div className="inline-flex items-center gap-3 glass-card rounded-full px-5 py-2">
          <div className="flex -space-x-1">
            {[...Array(5)].map((_, i) => (
              <div
                key={i}
                className="w-5 h-5 rounded-full bg-gradient-to-br from-yellow-400 to-yellow-600 border border-forma-obsidian flex items-center justify-center text-[10px]"
              >
                ★
              </div>
            ))}
          </div>
          <span className="text-sm text-forma-bone/60">
            <span className="text-forma-bone font-medium">4.9/5</span> from 200+ reviews
          </span>
        </div>
      </motion.div>
    </section>
  );
}
