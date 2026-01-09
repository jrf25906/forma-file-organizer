"use client";

import { motion } from "framer-motion";
import { useRef, useState } from "react";
import { useInView } from "framer-motion";
import { Quotes, CaretLeft, CaretRight, Star, Clock, HardDrive, FolderOpen, Lightning } from "@phosphor-icons/react";
import TypewriterText from "./TypewriterText";
import ParallaxOrb from "./ParallaxOrb";

const testimonials = [
  {
    quote:
      "Forma completely changed how I manage my downloads folder. What used to be a chaotic mess is now perfectly organized—automatically. I didn't realize how much mental energy I was wasting on file management.",
    author: "Sarah Chen",
    role: "UX Designer",
    company: "Figma",
    avatar: "SC",
    rating: 5,
    stat: { value: "12,847", label: "files organized", icon: FolderOpen },
    highlight: "in first month",
  },
  {
    quote:
      "As a photographer, I deal with thousands of images. Forma's pattern detection figured out my naming conventions and now sorts everything into the right folders. It's like having a digital assistant.",
    author: "Marcus Rivera",
    role: "Photographer",
    company: "Freelance",
    avatar: "MR",
    rating: 5,
    stat: { value: "6.2 hrs", label: "saved weekly", icon: Clock },
    highlight: "on file management",
  },
  {
    quote:
      "The rule builder is incredibly powerful yet simple to use. I set up my entire organization system in 10 minutes. Now I spend zero time filing documents.",
    author: "Emily Watson",
    role: "Product Manager",
    company: "Stripe",
    avatar: "EW",
    rating: 5,
    stat: { value: "127", label: "rules created", icon: Lightning },
    highlight: "and counting",
  },
  {
    quote:
      "I was skeptical about another productivity app, but Forma delivers. The duplicate detection alone saved me 40GB of storage. Clean, fast, and actually useful.",
    author: "James Park",
    role: "Software Engineer",
    company: "Vercel",
    avatar: "JP",
    rating: 5,
    stat: { value: "47 GB", label: "storage recovered", icon: HardDrive },
    highlight: "from duplicates",
  },
  {
    quote:
      "Finally, a file organizer that respects my workflow. The natural language rules are genius—I just type what I want and Forma handles the rest.",
    author: "Alex Thompson",
    role: "Content Creator",
    company: "YouTube",
    avatar: "AT",
    rating: 5,
    stat: { value: "3,200+", label: "files per project", icon: FolderOpen },
    highlight: "auto-sorted",
  },
];

// Aggregate stats for the section
const aggregateStats = [
  { value: "2M+", label: "Files Organized" },
  { value: "4.2 hrs", label: "Avg. Saved/Week" },
  { value: "98%", label: "Keep Using After Trial" },
];

export default function Testimonials() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });
  const [activeIndex, setActiveIndex] = useState(0);

  const nextTestimonial = () => {
    setActiveIndex((prev) => (prev + 1) % testimonials.length);
  };

  const prevTestimonial = () => {
    setActiveIndex((prev) => (prev - 1 + testimonials.length) % testimonials.length);
  };

  const activeTestimonial = testimonials[activeIndex];

  return (
    <section className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="absolute inset-0 bg-gradient-to-b from-transparent via-forma-sage/5 to-transparent" />
      <ParallaxOrb
        color="orange"
        size="lg"
        position={{ top: "25%", right: "-9%" }}
        speed={-45}
        opacity={0.3}
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
            <span className="w-2 h-2 rounded-full bg-forma-warm-orange animate-pulse" />
            <span className="text-sm font-medium text-forma-bone/80">
              Loved by Mac Users
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Real Results From
            <br />
            <span className="gradient-text">Real Users</span>
          </motion.h2>

          {/* Aggregate Stats Bar */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="flex flex-wrap justify-center gap-8 mt-8"
          >
            {aggregateStats.map((stat, index) => (
              <div key={stat.label} className="text-center">
                <div className="font-display font-bold text-3xl text-forma-steel-blue">
                  {stat.value}
                </div>
                <div className="text-sm text-forma-bone/50">{stat.label}</div>
              </div>
            ))}
          </motion.div>
        </div>

        {/* Featured Testimonial */}
        <div className="max-w-4xl mx-auto mb-12">
          <motion.div
            key={activeIndex}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
            transition={{ duration: 0.4 }}
            className="glass-card-strong rounded-3xl p-8 md:p-12 relative"
          >
            {/* Quote Icon */}
            <div className="absolute top-8 right-8 opacity-10">
              <Quotes className="w-24 h-24 text-forma-steel-blue" />
            </div>

            {/* Rating */}
            <div className="flex gap-1 mb-6">
              {[...Array(activeTestimonial.rating)].map((_, i) => (
                <Star
                  key={i}
                  className="w-5 h-5 fill-forma-warm-orange text-forma-warm-orange"
                />
              ))}
            </div>

            {/* Quote */}
            <blockquote className="text-xl md:text-2xl text-forma-bone/90 leading-relaxed mb-8 relative z-10 min-h-[120px]">
              &ldquo;
              <TypewriterText
                text={activeTestimonial.quote}
                speed={18}
                delay={300}
                triggerKey={activeIndex}
              />
              &rdquo;
            </blockquote>

            {/* Author + Stat Row */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-6">
              {/* Author */}
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-full bg-gradient-to-br from-forma-steel-blue to-forma-sage flex items-center justify-center font-display font-bold text-lg text-forma-bone">
                  {activeTestimonial.avatar}
                </div>
                <div>
                  <div className="font-display font-semibold text-forma-bone">
                    {activeTestimonial.author}
                  </div>
                  <div className="text-sm text-forma-bone/50">
                    {activeTestimonial.role} at {activeTestimonial.company}
                  </div>
                </div>
              </div>

              {/* Quantified Stat */}
              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.2 }}
                className="glass-card rounded-xl px-5 py-3 flex items-center gap-4"
              >
                <div className="w-10 h-10 rounded-lg bg-forma-sage/20 flex items-center justify-center">
                  <activeTestimonial.stat.icon className="w-5 h-5 text-forma-sage" />
                </div>
                <div>
                  <div className="font-display font-bold text-xl text-forma-bone">
                    {activeTestimonial.stat.value}
                  </div>
                  <div className="text-xs text-forma-bone/50">
                    {activeTestimonial.stat.label}{" "}
                    <span className="text-forma-sage">{activeTestimonial.highlight}</span>
                  </div>
                </div>
              </motion.div>
            </div>
          </motion.div>
        </div>

        {/* Navigation */}
        <div className="flex items-center justify-center gap-4">
          <motion.button
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.95 }}
            onClick={prevTestimonial}
            className="w-12 h-12 rounded-full glass-card flex items-center justify-center text-forma-bone/60 hover:text-forma-bone transition-colors"
          >
            <CaretLeft className="w-5 h-5" />
          </motion.button>

          {/* Dots */}
          <div className="flex gap-2">
            {testimonials.map((_, index) => (
              <button
                key={index}
                onClick={() => setActiveIndex(index)}
                className={`w-2 h-2 rounded-full transition-all duration-300 ${
                  index === activeIndex
                    ? "w-8 bg-forma-steel-blue"
                    : "bg-forma-bone/20 hover:bg-forma-bone/40"
                }`}
              />
            ))}
          </div>

          <motion.button
            whileHover={{ scale: 1.1 }}
            whileTap={{ scale: 0.95 }}
            onClick={nextTestimonial}
            className="w-12 h-12 rounded-full glass-card flex items-center justify-center text-forma-bone/60 hover:text-forma-bone transition-colors"
          >
            <CaretRight className="w-5 h-5" />
          </motion.button>
        </div>

        {/* Mini Testimonials Grid with Stats */}
        <div className="grid md:grid-cols-3 gap-4 mt-16">
          {testimonials.slice(0, 3).map((testimonial, index) => (
            <motion.div
              key={testimonial.author}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1 }}
              className="glass-card rounded-xl p-6"
            >
              {/* Stat Badge */}
              <div className="flex items-center justify-between mb-4">
                <div className="flex gap-1">
                  {[...Array(5)].map((_, i) => (
                    <Star
                      key={i}
                      className="w-3 h-3 fill-forma-warm-orange text-forma-warm-orange"
                    />
                  ))}
                </div>
                <div className="flex items-center gap-1.5 px-2 py-1 rounded-full bg-forma-sage/10">
                  <testimonial.stat.icon className="w-3 h-3 text-forma-sage" />
                  <span className="text-xs font-medium text-forma-sage">
                    {testimonial.stat.value}
                  </span>
                </div>
              </div>

              <p className="text-sm text-forma-bone/70 line-clamp-3 mb-4">
                &ldquo;{testimonial.quote}&rdquo;
              </p>
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-forma-steel-blue/50 to-forma-sage/50 flex items-center justify-center text-xs font-medium">
                  {testimonial.avatar}
                </div>
                <div className="text-sm">
                  <div className="font-medium text-forma-bone">
                    {testimonial.author}
                  </div>
                  <div className="text-forma-bone/40 text-xs">
                    {testimonial.company}
                  </div>
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
