import type { Metadata } from "next";

import { Footer } from "@/components/Footer";

export const metadata: Metadata = {
  title: "Support",
  description: "Get help with Forma, contact support, and find troubleshooting tips.",
};

export default function SupportPage() {
  return (
    <div className="relative min-h-screen">
      <main className="relative z-10 mb-[220px] shadow-2xl overflow-hidden">
        <section className="relative px-6 py-section-lg">
          <div className="max-w-3xl mx-auto">
            <div className="rounded-2xl border border-forma-bone/10 bg-forma-obsidian/70 backdrop-blur-md p-8 md:p-12">
              <h1 className="font-display text-4xl md:text-5xl text-forma-bone mb-4">
                Support
              </h1>
              <p className="text-forma-bone/70 leading-relaxed mb-10">
                Need help with Forma? Email us and include any details that might
                help (macOS version, what you expected to happen, and what
                happened).
              </p>

              <div className="space-y-10 text-forma-bone/70 leading-relaxed">
                <section className="space-y-3">
                  <h2 className="font-display text-xl text-forma-bone">
                    Contact
                  </h2>
                  <p>
                    <a
                      className="text-forma-steel-blue hover:opacity-80 transition-opacity"
                      href="mailto:hello@forma.app"
                    >
                      hello@forma.app
                    </a>
                  </p>
                </section>

                <section className="space-y-3">
                  <h2 className="font-display text-xl text-forma-bone">
                    Common issues
                  </h2>
                  <ul className="list-disc pl-5 space-y-2">
                    <li>
                      If a folder isn&apos;t scanning, re-grant access in Forma
                      and macOS settings.
                    </li>
                    <li>
                      If a move fails, check that the destination folder has
                      permission and enough free space.
                    </li>
                    <li>
                      If you want to reset permissions, remove the folder from
                      Forma and re-add it.
                    </li>
                  </ul>
                </section>
              </div>
            </div>
          </div>
        </section>
      </main>
      <Footer />
    </div>
  );
}

