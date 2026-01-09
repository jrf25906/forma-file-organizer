"use client";

import { motion } from "framer-motion";
import { useRef } from "react";
import { useInView } from "framer-motion";
import {
  Shield,
  Cpu,
  Lock,
  Eye,
  CloudSlash,
  Fingerprint,
  HardDrive,
  Database,
} from "@phosphor-icons/react";

const privacyFeatures = [
  {
    icon: Cpu,
    title: "On-Device AI",
    description:
      "All pattern detection and machine learning runs entirely on your Mac. Your files never leave your computer for processing.",
  },
  {
    icon: CloudSlash,
    title: "No Cloud Required",
    description:
      "Forma works completely offline. No internet connection needed for any feature—your organization stays local.",
  },
  {
    icon: Eye,
    title: "Zero Data Collection",
    description:
      "We don't see your file names, folder structures, or content. Anonymous usage analytics are optional and can be disabled.",
  },
  {
    icon: Lock,
    title: "Sandboxed & Secure",
    description:
      "Forma only accesses folders you explicitly grant permission to. macOS security ensures complete isolation.",
  },
];

const techDetails = [
  {
    icon: HardDrive,
    label: "Processing",
    value: "100% Local",
  },
  {
    icon: Database,
    label: "Data Uploaded",
    value: "Zero Bytes",
  },
  {
    icon: Fingerprint,
    label: "Tracking",
    value: "None",
  },
  {
    icon: Shield,
    label: "Encryption",
    value: "Apple Keychain",
  },
];

export default function Privacy() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });

  return (
    <section className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="orb orb-sage w-96 h-96 top-0 left-1/4 animate-float-slower opacity-20" />
      <div className="orb orb-blue w-72 h-72 bottom-1/4 right-0 animate-float opacity-20" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <div className="grid lg:grid-cols-2 gap-16 items-center">
          {/* Left Content */}
          <div>
            <div ref={headerRef}>
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.6 }}
                className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
              >
                <Shield className="w-4 h-4 text-forma-sage" />
                <span className="text-sm font-medium text-forma-bone/80">
                  Privacy First
                </span>
              </motion.div>

              <motion.h2
                initial={{ opacity: 0, y: 30 }}
                animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.6, delay: 0.1 }}
                className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
              >
                Your Files.
                <br />
                <span className="gradient-text">Your Mac.</span>
                <br />
                Your Privacy.
              </motion.h2>

              <motion.p
                initial={{ opacity: 0, y: 30 }}
                animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.6, delay: 0.2 }}
                className="text-lg text-forma-bone/60 mb-8"
              >
                Unlike cloud-based AI tools, Forma&apos;s intelligence runs entirely
                on your Mac. Your files, file names, and organization patterns
                never leave your device—ever.
              </motion.p>

              {/* Tech Stats */}
              <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
                transition={{ duration: 0.6, delay: 0.3 }}
                className="grid grid-cols-2 gap-4"
              >
                {techDetails.map((detail, index) => (
                  <div
                    key={detail.label}
                    className="glass-card rounded-xl p-4 flex items-center gap-3"
                  >
                    <div className="w-10 h-10 rounded-lg bg-forma-sage/20 flex items-center justify-center">
                      <detail.icon className="w-5 h-5 text-forma-sage" />
                    </div>
                    <div>
                      <div className="text-xs text-forma-bone/50">
                        {detail.label}
                      </div>
                      <div className="font-display font-semibold text-forma-bone">
                        {detail.value}
                      </div>
                    </div>
                  </div>
                ))}
              </motion.div>
            </div>
          </div>

          {/* Right Content - Feature Cards */}
          <div className="space-y-4">
            {privacyFeatures.map((feature, index) => (
              <motion.div
                key={feature.title}
                initial={{ opacity: 0, x: 40 }}
                whileInView={{ opacity: 1, x: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: index * 0.1 }}
                className="glass-card rounded-xl p-6 group hover:shadow-glass-lg hover:border-white/20 transition-all duration-300"
              >
                <div className="flex gap-4">
                  <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-forma-sage/20 to-forma-steel-blue/20 flex items-center justify-center shrink-0 group-hover:scale-110 transition-transform">
                    <feature.icon className="w-6 h-6 text-forma-sage" />
                  </div>
                  <div>
                    <h3 className="font-display font-semibold text-lg text-forma-bone mb-1">
                      {feature.title}
                    </h3>
                    <p className="text-forma-bone/60 text-sm leading-relaxed">
                      {feature.description}
                    </p>
                  </div>
                </div>
              </motion.div>
            ))}

            {/* Trust Badge */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.5 }}
              className="glass-card-strong rounded-xl p-6 border-forma-sage/30"
            >
              <div className="flex items-center gap-4">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-forma-sage to-forma-steel-blue p-[1px]">
                  <div className="w-full h-full rounded-2xl bg-forma-obsidian flex items-center justify-center">
                    <Shield className="w-7 h-7 text-forma-bone" />
                  </div>
                </div>
                <div>
                  <div className="font-display font-bold text-forma-bone mb-1">
                    Privacy Promise
                  </div>
                  <p className="text-sm text-forma-bone/60">
                    We will never sell, share, or upload your data. Period.
                    <br />
                    <span className="text-forma-sage">
                      Read our privacy policy →
                    </span>
                  </p>
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  );
}
