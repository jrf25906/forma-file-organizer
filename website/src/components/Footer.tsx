"use client";

export default function Footer() {
  return (
    <footer className="py-16 px-6 border-t border-forma-bone/10">
      <div className="max-w-2xl mx-auto text-center">
        <p className="text-forma-bone/50 mb-4">
          Built by someone who got tired of seeing<br />
          <span className="font-mono text-forma-bone/40">Screenshot 2024-01-15 at 3.42.17 PM.png</span><br />
          fifty times on their desktop.
        </p>

        <div className="flex items-center justify-center gap-6 text-sm text-forma-bone/40">
          <a
            href="mailto:hello@forma.app"
            className="hover:text-forma-bone/60 transition-colors"
          >
            Contact
          </a>
          <span>·</span>
          <a
            href="#"
            className="hover:text-forma-bone/60 transition-colors"
          >
            Privacy
          </a>
          <span>·</span>
          <a
            href="#"
            className="hover:text-forma-bone/60 transition-colors"
          >
            Terms
          </a>
        </div>
      </div>
    </footer>
  );
}
