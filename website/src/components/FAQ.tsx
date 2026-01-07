"use client";

import { motion, AnimatePresence } from "framer-motion";
import { useRef, useState } from "react";
import { useInView } from "framer-motion";
import { Plus, Minus, HelpCircle } from "lucide-react";

const faqs = [
  {
    question: "Is Forma safe to use? Will it delete my files?",
    answer:
      "Absolutely safe. Forma never deletes files without your explicit permission. All file movements are logged and can be reversed. We only move files to locations you've approved—nothing happens automatically until you review and confirm.",
  },
  {
    question: "What macOS versions does Forma support?",
    answer:
      "Forma supports macOS 13 (Ventura) and later, including macOS 14 (Sonoma) and macOS 15 (Sequoia). For the best experience with liquid glass effects, we recommend macOS 15 or later.",
  },
  {
    question: "How does the AI pattern detection work?",
    answer:
      "Forma analyzes your file naming conventions, folder structures, and organization history to identify patterns. For example, if you consistently move screenshots to a specific folder, Forma will suggest creating a rule for that. All analysis happens locally on your Mac—your files are never uploaded to any server.",
  },
  {
    question: "Can I use Forma on multiple Macs?",
    answer:
      "Yes! Pro and Lifetime plans support up to 3 Macs per account. Your rules and preferences sync across devices via iCloud, so your organization setup follows you everywhere.",
  },
  {
    question: "What's the difference between Free and Pro?",
    answer:
      "The Free tier lets you organize up to 100 files per month with 5 custom rules—perfect for light users. Pro unlocks unlimited files, unlimited rules, AI pattern detection, duplicate finding, analytics, and automatic organization. See the pricing section for full details.",
  },
  {
    question: "How do I cancel my subscription?",
    answer:
      "You can cancel anytime from your account settings or by emailing support@forma.app. If you cancel, you'll retain Pro features until the end of your billing period, then automatically downgrade to the Free tier. Your files and rules are never deleted.",
  },
  {
    question: "Does Forma work with iCloud Drive, Dropbox, or external drives?",
    answer:
      "Yes! Forma can organize files across any mounted volume, including iCloud Drive, Dropbox, Google Drive, and external hard drives. Just add them as watched locations in settings.",
  },
  {
    question: "Is my data private?",
    answer:
      "100%. Forma processes everything locally on your Mac. We don't upload your files, file names, or folder structures to any server. The only data we collect is anonymous usage analytics (which you can opt out of) to help improve the app.",
  },
];

function FAQItem({
  faq,
  isOpen,
  onToggle,
  index,
}: {
  faq: (typeof faqs)[0];
  isOpen: boolean;
  onToggle: () => void;
  index: number;
}) {
  const headingId = `faq-heading-${index}`;
  const panelId = `faq-panel-${index}`;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay: index * 0.05 }}
      className="border-b border-white/10 last:border-0"
    >
      <h3>
        <button
          id={headingId}
          onClick={onToggle}
          aria-expanded={isOpen}
          aria-controls={panelId}
          className="w-full py-6 flex items-start justify-between gap-4 text-left group"
        >
          <span className="font-display font-medium text-lg text-forma-bone group-hover:text-forma-steel-blue transition-colors">
            {faq.question}
          </span>
          <div
            className={`w-8 h-8 rounded-full glass-card flex items-center justify-center shrink-0 transition-all duration-300 ${
              isOpen ? "bg-forma-steel-blue/20 rotate-180" : ""
            }`}
            aria-hidden="true"
          >
            {isOpen ? (
              <Minus className="w-4 h-4 text-forma-steel-blue" />
            ) : (
              <Plus className="w-4 h-4 text-forma-bone/60" />
            )}
          </div>
        </button>
      </h3>

      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            id={panelId}
            role="region"
            aria-labelledby={headingId}
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
            className="overflow-hidden"
          >
            <p className="pb-6 text-forma-bone/60 leading-relaxed pr-12">
              {faq.answer}
            </p>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

export default function FAQ() {
  const headerRef = useRef(null);
  const isHeaderInView = useInView(headerRef, { once: true, margin: "-100px" });
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <section id="faq" className="relative py-32 overflow-hidden">
      {/* Background */}
      <div className="orb orb-blue w-80 h-80 -bottom-40 -left-40 animate-float-slow opacity-30" />

      <div className="relative z-10 max-w-4xl mx-auto px-6">
        {/* Section Header */}
        <div ref={headerRef} className="text-center max-w-3xl mx-auto mb-16">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-full glass-card mb-6"
          >
            <HelpCircle className="w-4 h-4 text-forma-muted-blue" />
            <span className="text-sm font-medium text-forma-bone/80">
              Got Questions?
            </span>
          </motion.div>

          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="font-display font-bold text-4xl md:text-5xl text-forma-bone mb-6"
          >
            Frequently Asked
            <br />
            <span className="gradient-text">Questions</span>
          </motion.h2>

          <motion.p
            initial={{ opacity: 0, y: 30 }}
            animate={isHeaderInView ? { opacity: 1, y: 0 } : {}}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="text-lg text-forma-bone/60"
          >
            Everything you need to know about Forma. Can&apos;t find what you&apos;re
            looking for? Reach out to our support team.
          </motion.p>
        </div>

        {/* FAQ List */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="glass-card-strong rounded-2xl p-8 md:p-10"
        >
          {faqs.map((faq, index) => (
            <FAQItem
              key={index}
              faq={faq}
              index={index}
              isOpen={openIndex === index}
              onToggle={() => setOpenIndex(openIndex === index ? null : index)}
            />
          ))}
        </motion.div>

        {/* Contact CTA */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.3 }}
          className="text-center mt-12"
        >
          <p className="text-forma-bone/50 mb-4">Still have questions?</p>
          <a
            href="mailto:support@forma.app"
            className="btn-secondary text-forma-bone inline-flex items-center gap-2"
          >
            Contact Support
          </a>
        </motion.div>
      </div>
    </section>
  );
}
