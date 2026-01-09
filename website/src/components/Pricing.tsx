"use client";

import { motion, useInView } from "framer-motion";
import { useRef } from "react";
import { Check, Sparkle } from "@phosphor-icons/react";
import ParallaxOrb from "./ParallaxOrb";

const plans = [
  {
    name: "Free",
    price: "$0",
    period: "forever",
    description: "Perfect for getting started with file organization",
    features: [
      "Organize up to 100 files/month",
      "5 custom rules",
      "Basic pattern detection",
      "Desktop & Downloads scanning",
      "Manual organization",
    ],
    cta: "Download Free",
    highlighted: false,
  },
  {
    name: "Pro",
    price: "$9",
    period: "/month",
    description: "For power users who want full automation",
    features: [
      "Unlimited file organization",
      "Unlimited custom rules",
      "Advanced AI pattern detection",
      "All folder locations",
      "Automatic organization",
      "Duplicate file detection",
      "Storage analytics & reports",
      "Priority support",
    ],
    cta: "Start Free Trial",
    highlighted: true,
    badge: "Most Popular",
  },
  {
    name: "Lifetime",
    price: "$149",
    period: "one-time",
    description: "Pay once, organize forever",
    features: [
      "Everything in Pro",
      "Lifetime updates",
      "Early access to new features",
      "Priority feature requests",
      "Direct developer support",
    ],
    cta: "Get Lifetime Access",
    highlighted: false,
  },
];

function PricingCard({
  plan,
  index,
}: {
  plan: (typeof plans)[0];
  index: number;
}) {
  const cardRef = useRef(null);
  const isInView = useInView(cardRef, { once: true, margin: "-50px" });

  // Stagger animation variants for features
  const featureVariants = {
    hidden: { opacity: 0, x: -20 },
    visible: (i: number) => ({
      opacity: 1,
      x: 0,
      transition: {
        delay: 0.3 + i * 0.08, // Start after card entrance, stagger each feature
        duration: 0.4,
        ease: [0.25, 0.46, 0.45, 0.94],
      },
    }),
  };

  // Check icon scale animation
  const checkVariants = {
    hidden: { scale: 0, opacity: 0 },
    visible: (i: number) => ({
      scale: 1,
      opacity: 1,
      transition: {
        delay: 0.4 + i * 0.08,
        duration: 0.3,
        type: "spring",
        stiffness: 400,
        damping: 15,
      },
    }),
  };

  return (
    <motion.div
      ref={cardRef}
      initial={{ opacity: 0, y: 40 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6, delay: index * 0.1 }}
      className={`relative ${plan.highlighted ? "lg:-mt-4 lg:mb-4" : ""}`}
    >
      {/* Badge */}
      {plan.badge && (
        <motion.div
          initial={{ opacity: 0, y: -10, scale: 0.9 }}
          animate={isInView ? { opacity: 1, y: 0, scale: 1 } : {}}
          transition={{ delay: 0.2, duration: 0.4, type: "spring" }}
          className="absolute -top-4 left-1/2 -translate-x-1/2 z-10"
        >
          <div className="px-4 py-1.5 rounded-full bg-gradient-to-r from-forma-steel-blue to-forma-sage text-sm font-medium text-forma-bone shadow-glow-blue">
            {plan.badge}
          </div>
        </motion.div>
      )}

      <div
        className={`h-full rounded-2xl p-8 transition-all duration-500 ${
          plan.highlighted
            ? "glass-card-strong border-forma-steel-blue/30 shadow-glow-blue"
            : "glass-card hover:shadow-glass-lg hover:-translate-y-2"
        }`}
      >
        {/* Header */}
        <div className="mb-8">
          <motion.h3
            initial={{ opacity: 0 }}
            animate={isInView ? { opacity: 1 } : {}}
            transition={{ delay: 0.1 }}
            className="font-display font-bold text-2xl text-forma-bone mb-2"
          >
            {plan.name}
          </motion.h3>
          <motion.p
            initial={{ opacity: 0 }}
            animate={isInView ? { opacity: 1 } : {}}
            transition={{ delay: 0.15 }}
            className="text-forma-bone/50 text-sm mb-4"
          >
            {plan.description}
          </motion.p>
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={isInView ? { opacity: 1, scale: 1 } : {}}
            transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
            className="flex items-baseline gap-1"
          >
            <span className="font-display font-bold text-5xl text-forma-bone">
              {plan.price}
            </span>
            <span className="text-forma-bone/50">{plan.period}</span>
          </motion.div>
        </div>

        {/* Features */}
        <ul className="space-y-4 mb-8">
          {plan.features.map((feature, featureIndex) => (
            <motion.li
              key={feature}
              custom={featureIndex}
              variants={featureVariants}
              initial="hidden"
              animate={isInView ? "visible" : "hidden"}
              className="flex items-start gap-3"
            >
              <motion.div
                custom={featureIndex}
                variants={checkVariants}
                initial="hidden"
                animate={isInView ? "visible" : "hidden"}
                className={`w-5 h-5 rounded-full flex items-center justify-center shrink-0 mt-0.5 ${
                  plan.highlighted
                    ? "bg-forma-steel-blue/20"
                    : "bg-forma-sage/20"
                }`}
              >
                <Check
                  className={`w-3 h-3 ${
                    plan.highlighted ? "text-forma-steel-blue" : "text-forma-sage"
                  }`}
                />
              </motion.div>
              <span className="text-forma-bone/70">{feature}</span>
            </motion.li>
          ))}
        </ul>

        {/* CTA */}
        <motion.button
          initial={{ opacity: 0, y: 10 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ delay: 0.5 + plan.features.length * 0.05 }}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className={`w-full py-3 px-6 rounded-xl font-display font-medium transition-all duration-300 ${
            plan.highlighted
              ? "btn-primary text-forma-bone"
              : "btn-secondary text-forma-bone"
          }`}
        >
          {plan.cta}
        </motion.button>
      </div>
    </motion.div>
  );
}

export default function Pricing() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });

  return (
    <section id="pricing" className="relative py-32 overflow-hidden">
      {/* Background with Parallax */}
      <ParallaxOrb
        color="sage"
        size="xl"
        position={{ top: "-12%", right: "25%" }}
        speed={-70}
        opacity={0.3}
        className="animate-float-slower"
      />
      <ParallaxOrb
        color="blue"
        size="md"
        position={{ bottom: "0", left: "25%" }}
        speed={-25}
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
            <Sparkle className="w-4 h-4 text-forma-warm-orange" />
            <span className="text-sm font-medium text-forma-bone/80">
              Simple Pricing
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Choose Your Path to
            <br />
            <span className="gradient-text-warm">Digital Clarity</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            Start free and upgrade when you need more power. No hidden fees, no
            surprises.
          </motion.p>
        </div>

        {/* Pricing Cards */}
        <div className="grid md:grid-cols-3 gap-6 lg:gap-8 max-w-5xl mx-auto">
          {plans.map((plan, index) => (
            <PricingCard key={plan.name} plan={plan} index={index} />
          ))}
        </div>

        {/* Trust Badge */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.5 }}
          className="text-center mt-12"
        >
          <p className="text-sm text-forma-bone/40">
            💳 Secure payment via Stripe • 30-day money-back guarantee • Cancel
            anytime
          </p>
        </motion.div>
      </div>
    </section>
  );
}
