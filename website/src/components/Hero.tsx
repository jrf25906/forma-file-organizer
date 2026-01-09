"use client";

export default function Hero() {
  return (
    <section className="min-h-screen flex items-center justify-center px-6 py-24">
      <div className="max-w-2xl mx-auto text-center">
        {/* Headline */}
        <h1 className="font-display text-4xl md:text-5xl lg:text-6xl leading-tight mb-8 text-forma-bone">
          A file organizer for people who gave up on file organizers.
        </h1>

        {/* Subhead */}
        <p className="text-xl md:text-2xl text-forma-bone/70 mb-8 leading-relaxed">
          Your desktop is a dumping ground. Your Downloads folder is worse. You've tried to fix it before.
        </p>

        {/* Body */}
        <p className="text-lg text-forma-bone/60 mb-12 leading-relaxed max-w-xl mx-auto">
          You make rules. Forma follows them. Screenshots go here, PDFs go there.
          You preview what's about to happen, approve it, and it's done.
          If you don't like it, undo it. That's the whole thing.
        </p>

        {/* CTA */}
        <a
          href="#download"
          className="inline-flex items-center gap-3 px-8 py-4 bg-forma-bone text-forma-obsidian font-medium rounded-lg hover:bg-forma-bone/90 transition-colors"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
          </svg>
          Download for Mac
        </a>
      </div>
    </section>
  );
}
