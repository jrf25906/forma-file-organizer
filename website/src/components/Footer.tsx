"use client";

import { motion } from "framer-motion";
import { Github, Twitter, Mail } from "lucide-react";

const footerLinks = {
  product: [
    { name: "Features", href: "#features" },
    { name: "Pricing", href: "#pricing" },
    { name: "FAQ", href: "#faq" },
    { name: "Changelog", href: "#" },
  ],
  resources: [
    { name: "Documentation", href: "#" },
    { name: "Support", href: "mailto:support@forma.app" },
    { name: "Blog", href: "#" },
    { name: "Press Kit", href: "#" },
  ],
  legal: [
    { name: "Privacy Policy", href: "#" },
    { name: "Terms of Service", href: "#" },
    { name: "License", href: "#" },
  ],
};

const socialLinks = [
  { icon: Twitter, href: "https://twitter.com/formaapp", label: "Twitter" },
  { icon: Github, href: "https://github.com/forma", label: "GitHub" },
  { icon: Mail, href: "mailto:hello@forma.app", label: "Email" },
];

export default function Footer() {
  return (
    <footer className="relative pt-20 pb-10 overflow-hidden border-t border-white/5">
      {/* Background */}
      <div className="absolute inset-0 bg-forma-obsidian" />

      <div className="relative z-10 max-w-7xl mx-auto px-6">
        <div className="grid md:grid-cols-2 lg:grid-cols-5 gap-12 mb-16">
          {/* Brand Column */}
          <div className="lg:col-span-2">
            {/* Logo */}
            <div className="flex items-center gap-3 mb-6">
              <img
                src="/logo-mark-light.svg"
                alt="Forma"
                className="w-8 h-8"
              />
              <span className="font-display font-bold text-xl text-forma-bone">
                Forma
              </span>
            </div>

            <p className="text-forma-bone/50 max-w-sm mb-6">
              Structural file organization for macOS. Transform digital chaos
              into clarity with rule-based organization.
            </p>

            {/* Social Links */}
            <div className="flex gap-3">
              {socialLinks.map((social) => (
                <motion.a
                  key={social.label}
                  href={social.href}
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.95 }}
                  className="w-10 h-10 rounded-xl glass-card flex items-center justify-center text-forma-bone/50 hover:text-forma-bone transition-colors"
                  aria-label={social.label}
                >
                  <social.icon className="w-5 h-5" />
                </motion.a>
              ))}
            </div>
          </div>

          {/* Product Links */}
          <div>
            <h4 className="font-display font-semibold text-forma-bone mb-4">
              Product
            </h4>
            <ul className="space-y-3">
              {footerLinks.product.map((link) => (
                <li key={link.name}>
                  <a
                    href={link.href}
                    className="text-forma-bone/50 hover:text-forma-bone transition-colors"
                  >
                    {link.name}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Resources Links */}
          <div>
            <h4 className="font-display font-semibold text-forma-bone mb-4">
              Resources
            </h4>
            <ul className="space-y-3">
              {footerLinks.resources.map((link) => (
                <li key={link.name}>
                  <a
                    href={link.href}
                    className="text-forma-bone/50 hover:text-forma-bone transition-colors"
                  >
                    {link.name}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal Links */}
          <div>
            <h4 className="font-display font-semibold text-forma-bone mb-4">
              Legal
            </h4>
            <ul className="space-y-3">
              {footerLinks.legal.map((link) => (
                <li key={link.name}>
                  <a
                    href={link.href}
                    className="text-forma-bone/50 hover:text-forma-bone transition-colors"
                  >
                    {link.name}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Divider */}
        <div className="border-t border-white/5 pt-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <p className="text-sm text-forma-bone/40">
              © {new Date().getFullYear()} Forma. All rights reserved.
            </p>
            <p className="text-sm text-forma-bone/40">
              Made with ❤️ for Mac users everywhere
            </p>
          </div>
        </div>
      </div>
    </footer>
  );
}
