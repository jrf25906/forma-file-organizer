"use client";

import { useRef, useState, useEffect } from "react";
import { Shield, EyeOff, Lock } from "lucide-react";
import { gsap, useGSAP } from "@/lib/animation/gsap-config";
import {
  formaSettle,
  formaDuration,
  formaSnap,
  formaReveal,
} from "@/lib/animation/ease-curves";
import { ScrollReveal } from "@/components/animation/ScrollReveal";

/* ═══════════════════════════════════════════════════════════════════════════
   macOS FILE ICON (reusable base shape)
   ═══════════════════════════════════════════════════════════════════════════ */

function MacFileIcon({
  children,
  badgeText,
  badgeColor,
  className,
  style,
}: {
  children?: React.ReactNode;
  badgeText?: string;
  badgeColor?: string;
  className?: string;
  style?: React.CSSProperties;
}) {
  return (
    <svg
      viewBox="0 0 48 58"
      fill="none"
      aria-hidden="true"
      className={className}
      style={style}
    >
      <path
        d="M0 5C0 2.239 2.239 0 5 0H30L48 17V53C48 55.761 45.761 58 43 58H5C2.239 58 0 55.761 0 53V5Z"
        fill="white"
        stroke="#DDD9D5"
        strokeWidth="0.75"
      />
      <path
        d="M30 0L48 17H35C32.239 17 30 14.761 30 12V0Z"
        fill="#F0EFED"
        stroke="#DDD9D5"
        strokeWidth="0.75"
      />
      {children}
      {badgeText && (
        <g>
          <rect x="7" y="44" width="34" height="12" rx="2.5" fill={badgeColor} />
          <text
            x="24"
            y="52.5"
            textAnchor="middle"
            fill="white"
            fontSize="7"
            fontWeight="700"
            fontFamily="Inter, system-ui, sans-serif"
          >
            {badgeText}
          </text>
        </g>
      )}
    </svg>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: SCREENSHOTS — scattered files → folder with sparkles
   ═══════════════════════════════════════════════════════════════════════════ */

const scatteredFiles = [
  {
    top: 12, left: 16, rotate: -15,
    driftX: -4, driftY: -3,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#EDE7F6" opacity="0.6" />
        <rect x="14" y="26" width="9" height="9" rx="1.5" fill="#9575CD" opacity="0.4" />
        <rect x="26" y="26" width="9" height="9" rx="1.5" fill="#B39DDB" opacity="0.3" />
      </>
    ),
  },
  {
    top: 8, left: 80, rotate: 8,
    driftX: 5, driftY: -4,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#E8F5E9" opacity="0.6" />
        <path d="M14 34L20 27L25 31L31 25L38 34Z" fill="#7A9D7E" opacity="0.35" />
      </>
    ),
  },
  {
    top: 52, left: 52, rotate: -5,
    driftX: -3, driftY: 3,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#FFF8E1" opacity="0.6" />
        <path d="M14 34L21 28L28 32L38 34Z" fill="#C9A84C" opacity="0.35" />
      </>
    ),
  },
  {
    top: 16, left: 140, rotate: 12,
    driftX: 4, driftY: -3,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#E8F5E9" opacity="0.6" />
        <path d="M15 34L22 26L28 30L36 24" stroke="#7A9D7E" strokeWidth="1.5" fill="none" opacity="0.4" strokeLinecap="round" />
      </>
    ),
  },
  {
    top: 100, left: 8, rotate: -10,
    driftX: -5, driftY: 4,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#E3F2FD" opacity="0.6" />
        <circle cx="24" cy="30" r="6" fill="#64B5F6" opacity="0.35" />
      </>
    ),
  },
  {
    top: 120, left: 72, rotate: -8,
    driftX: -3, driftY: -4,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#F3E5F5" opacity="0.6" />
        <rect x="13" y="25" width="22" height="2.5" rx="1" fill="#9E9E9E" opacity="0.25" />
        <rect x="13" y="29.5" width="15" height="2.5" rx="1" fill="#9E9E9E" opacity="0.2" />
      </>
    ),
  },
  {
    top: 140, left: 130, rotate: 5,
    driftX: 4, driftY: 3,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#E8F5E9" opacity="0.6" />
        <circle cx="20" cy="29" r="4.5" fill="#66BB6A" opacity="0.3" />
        <circle cx="30" cy="31" r="3" fill="#81C784" opacity="0.25" />
      </>
    ),
  },
  {
    top: 60, left: 120, rotate: -3,
    driftX: 3, driftY: -3,
    content: (
      <>
        <rect x="10" y="22" width="28" height="16" rx="3" fill="#E8F5E9" opacity="0.6" />
        <path d="M14 34L20 27L25 31L31 25L38 34Z" fill="#5B7C99" opacity="0.25" />
      </>
    ),
  },
];

function ScreenshotsScene({ isHovered }: { isHovered: boolean }) {
  const sceneRef = useRef<HTMLDivElement>(null);
  const tlRef = useRef<gsap.core.Timeline | undefined>(undefined);

  useGSAP(
    () => {
      const el = sceneRef.current;
      if (!el) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;
      if (prefersReducedMotion) return;

      const files = el.querySelectorAll<HTMLElement>("[data-scatter]");
      const folder = el.querySelector("[data-folder]");
      const sparkles = el.querySelectorAll("[data-sparkle]");
      const arrow = el.querySelector("[data-arrow]");

      tlRef.current = gsap
        .timeline({
          paused: true,
          defaults: { ease: formaSettle, duration: formaDuration.fast },
        })
        // Scattered files drift outward
        .to(files, {
          x: (_i: number, target: HTMLElement) => Number(target.dataset.driftX) || 0,
          y: (_i: number, target: HTMLElement) => Number(target.dataset.driftY) || 0,
          stagger: 0.02,
        })
        // Folder scales up
        .to(folder, { scale: 1.08 }, 0)
        // Arrow pulses
        .to(arrow, { scale: 1.15, duration: formaDuration.fast * 0.6 }, 0)
        .to(arrow, { scale: 1, duration: formaDuration.fast * 0.4 }, formaDuration.fast * 0.6)
        // Sparkles twinkle
        .to(
          sparkles,
          {
            scale: 1.2,
            rotate: (_i: number) => [12, -10, 15, -8][_i % 4],
            opacity: (_i: number, target: SVGElement) =>
              Math.min(1, parseFloat(target.getAttribute("opacity") || "0.3") + 0.25),
            stagger: 0.04,
            transformOrigin: "center center",
          },
          0
        );
    },
    { scope: sceneRef }
  );

  useEffect(() => {
    if (isHovered) tlRef.current?.play();
    else tlRef.current?.reverse();
  }, [isHovered]);

  return (
    <div
      ref={sceneRef}
      className="relative h-[220px] overflow-hidden rounded-t-2xl bg-[var(--bg-tertiary)]"
    >
      {/* Scattered files (left half) */}
      {scatteredFiles.map((file, i) => (
        <div
          key={i}
          data-scatter
          data-drift-x={file.driftX}
          data-drift-y={file.driftY}
          className="absolute w-[48px] h-[58px]"
          style={{
            top: file.top,
            left: file.left,
            transform: `rotate(${file.rotate}deg)`,
            opacity: 0.55,
          }}
        >
          <MacFileIcon>{file.content}</MacFileIcon>
        </div>
      ))}

      {/* Center divider */}
      <div
        className="absolute left-1/2 w-px"
        style={{ top: 24, bottom: 24, backgroundColor: "var(--border-medium)" }}
      />

      {/* Arrow circle at divider center */}
      <div
        data-arrow
        className="absolute left-1/2 top-1/2 z-10 flex h-7 w-7 -translate-x-1/2 -translate-y-1/2 items-center justify-center rounded-full border border-[var(--border-medium)] bg-[var(--bg-tertiary)]"
      >
        <svg
          width="12"
          height="12"
          viewBox="0 0 24 24"
          fill="none"
          stroke="var(--text-muted)"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="M5 12h14M12 5l7 7-7 7" />
        </svg>
      </div>

      {/* Folder icon (right half, centered) */}
      <div
        data-folder
        className="absolute top-1/2 right-[72px] w-[80px] h-[68px] -translate-y-1/2"
      >
        <svg
          width="80"
          height="68"
          viewBox="0 0 80 68"
          fill="none"
          aria-hidden="true"
        >
          <path
            d="M4 8C4 4.686 6.686 2 10 2H28L34 10H70C73.314 10 76 12.686 76 16V58C76 61.314 73.314 64 70 64H10C6.686 64 4 61.314 4 58V8Z"
            fill="#5B7C99"
            opacity="0.18"
          />
          <path
            d="M2 16C2 12.686 4.686 10 8 10H26C27.3 10 28.5 10.6 29.3 11.6L33.7 17.4C34.5 18.4 35.7 19 37 19H72C75.314 19 78 21.686 78 25V60C78 63.314 75.314 66 72 66H8C4.686 66 2 63.314 2 60V16Z"
            fill="#5B7C99"
            opacity="0.3"
          />
        </svg>
      </div>

      {/* Sparkles around folder */}
      <svg
        className="pointer-events-none absolute top-1/2 right-[52px] h-[100px] w-[120px] -translate-y-1/2"
        viewBox="-20 -16 120 100"
        fill="none"
        aria-hidden="true"
      >
        <path data-sparkle d="M85 4L87 10L93 12L87 14L85 20L83 14L77 12L83 10Z" fill="#5B7C99" opacity="0.45" />
        <path data-sparkle d="M8 0L9.5 4L13.5 5.5L9.5 7L8 11L6.5 7L2.5 5.5L6.5 4Z" fill="#5B7C99" opacity="0.25" />
        <path data-sparkle d="M95 40L97 46L103 48L97 50L95 56L93 50L87 48L93 46Z" fill="#7A9D7E" opacity="0.35" />
        <path data-sparkle d="M-5 65L-3 69L1 71L-3 73L-5 77L-7 73L-11 71L-7 69Z" fill="#5B7C99" opacity="0.2" />
        <circle data-sparkle cx="72" cy="-2" r="2" fill="#5B7C99" opacity="0.3" />
        <circle data-sparkle cx="100" cy="28" r="1.5" fill="#7A9D7E" opacity="0.3" />
        <circle data-sparkle cx="-8" cy="20" r="1.5" fill="#5B7C99" opacity="0.2" />
        <circle data-sparkle cx="90" cy="62" r="1.5" fill="#C97E66" opacity="0.2" />
      </svg>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: PDFs — three document icons with type badges + filenames
   ═══════════════════════════════════════════════════════════════════════════ */

const pdfDocs = [
  {
    badge: "PDF",
    badgeColor: "#C0392B",
    label: "Invoice.pdf",
    lines: (
      <>
        <rect x="9" y="22" width="30" height="2.5" rx="1" fill="#C8C4BF" opacity="0.5" />
        <rect x="9" y="27" width="30" height="2.5" rx="1" fill="#C8C4BF" opacity="0.4" />
        <rect x="9" y="32" width="22" height="2.5" rx="1" fill="#C8C4BF" opacity="0.3" />
      </>
    ),
  },
  {
    badge: "XLSX",
    badgeColor: "#27AE60",
    label: "Tax_2025.xlsx",
    lines: (
      <>
        <rect x="9" y="22" width="14" height="6" rx="1" fill="#C8C4BF" opacity="0.35" />
        <rect x="25" y="22" width="14" height="6" rx="1" fill="#C8C4BF" opacity="0.35" />
        <rect x="9" y="30" width="14" height="6" rx="1" fill="#C8C4BF" opacity="0.25" />
        <rect x="25" y="30" width="14" height="6" rx="1" fill="#C8C4BF" opacity="0.25" />
      </>
    ),
  },
  {
    badge: "PDF",
    badgeColor: "#C0392B",
    label: "Statement.pdf",
    lines: (
      <>
        <rect x="9" y="22" width="30" height="2.5" rx="1" fill="#C8C4BF" opacity="0.5" />
        <rect x="9" y="27" width="30" height="2.5" rx="1" fill="#C8C4BF" opacity="0.4" />
        <rect x="9" y="32" width="18" height="2.5" rx="1" fill="#C8C4BF" opacity="0.3" />
      </>
    ),
  },
];

function PDFsScene({ isHovered }: { isHovered: boolean }) {
  const sceneRef = useRef<HTMLDivElement>(null);
  const tlRef = useRef<gsap.core.Timeline | undefined>(undefined);

  useGSAP(
    () => {
      const el = sceneRef.current;
      if (!el) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;
      if (prefersReducedMotion) return;

      const docs = el.querySelectorAll("[data-doc]");

      tlRef.current = gsap
        .timeline({
          paused: true,
          defaults: { ease: formaSnap, duration: formaDuration.fast },
        })
        // Documents shuffle up with stagger
        .to(docs, {
          y: -6,
          rotate: (_i: number) => [-1.5, 1, -1][_i],
          stagger: 0.06,
        })
        // Settle back slightly
        .to(
          docs,
          {
            y: -3,
            rotate: 0,
            ease: formaReveal,
            duration: formaDuration.fast * 0.6,
          },
          ">"
        );
    },
    { scope: sceneRef }
  );

  useEffect(() => {
    if (isHovered) tlRef.current?.play();
    else tlRef.current?.reverse();
  }, [isHovered]);

  return (
    <div
      ref={sceneRef}
      className="flex h-[220px] flex-col items-center justify-center gap-2 rounded-t-2xl bg-[var(--bg-tertiary)]"
    >
      <div className="flex items-end gap-8">
        {pdfDocs.map((doc) => (
          <div
            key={doc.label}
            data-doc
            className="flex flex-col items-center gap-2"
          >
            <MacFileIcon
              className="w-[64px] h-[78px]"
              badgeText={doc.badge}
              badgeColor={doc.badgeColor}
            >
              {doc.lines}
            </MacFileIcon>
            <span className="text-[12px] text-[var(--text-muted)]">
              {doc.label}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   SCENE: PROJECTS — mixed file types in a grid + category pills
   ═══════════════════════════════════════════════════════════════════════════ */

const projectFiles = [
  {
    badge: "PNG",
    badgeColor: "#27AE60",
    content: (
      <>
        <rect x="8" y="20" width="32" height="18" rx="2" fill="#E8F5E9" opacity="0.6" />
        <path d="M12 34L18 27L23 31L29 25L36 34Z" fill="#7A9D7E" opacity="0.4" />
      </>
    ),
  },
  {
    badge: "MOV",
    badgeColor: "#E67E22",
    content: (
      <>
        <rect x="8" y="20" width="32" height="18" rx="2" fill="#FFF3E0" opacity="0.5" />
        <path d="M20 25L30 30L20 35Z" fill="#E67E22" opacity="0.4" />
      </>
    ),
  },
  {
    badge: "SKETCH",
    badgeColor: "#F1C40F",
    content: (
      <>
        <rect x="8" y="20" width="32" height="18" rx="2" fill="#FFFDE7" opacity="0.5" />
        <rect x="13" y="23" width="22" height="2.5" rx="1" fill="#C8C4BF" opacity="0.4" />
        <rect x="13" y="28" width="22" height="2.5" rx="1" fill="#C8C4BF" opacity="0.3" />
        <rect x="13" y="33" width="14" height="2.5" rx="1" fill="#C8C4BF" opacity="0.25" />
      </>
    ),
  },
  {
    badge: "PSD",
    badgeColor: "#3498DB",
    content: (
      <>
        <rect x="8" y="20" width="32" height="18" rx="2" fill="#E3F2FD" opacity="0.5" />
        <circle cx="24" cy="29" r="6" fill="#3498DB" opacity="0.3" />
      </>
    ),
  },
  {
    badge: "MP4",
    badgeColor: "#2C3E50",
    content: (
      <>
        <rect x="8" y="20" width="32" height="18" rx="2" fill="#ECEFF1" opacity="0.5" />
        <path d="M20 25L30 30L20 35Z" fill="#2C3E50" opacity="0.35" />
      </>
    ),
  },
  {
    badge: "FIG",
    badgeColor: "#9B59B6",
    content: (
      <>
        <rect x="8" y="20" width="32" height="18" rx="2" fill="#F3E5F5" opacity="0.5" />
        <rect x="13" y="23" width="9" height="9" rx="1" fill="#9B59B6" opacity="0.25" />
        <rect x="25" y="23" width="9" height="9" rx="1" fill="#9B59B6" opacity="0.2" />
      </>
    ),
  },
];

const categoryPills = ["Exports", "Renders", "Drafts"];

function ProjectsScene({ isHovered }: { isHovered: boolean }) {
  const sceneRef = useRef<HTMLDivElement>(null);
  const tlRef = useRef<gsap.core.Timeline | undefined>(undefined);

  useGSAP(
    () => {
      const el = sceneRef.current;
      if (!el) return;

      const prefersReducedMotion = window.matchMedia(
        "(prefers-reduced-motion: reduce)"
      ).matches;
      if (prefersReducedMotion) return;

      const files = el.querySelectorAll("[data-file]");
      const pills = el.querySelectorAll("[data-pill]");

      tlRef.current = gsap
        .timeline({
          paused: true,
          defaults: { ease: formaReveal, duration: formaDuration.fast },
        })
        // File icons ripple wave
        .to(files, {
          scale: 1.06,
          y: -2,
          stagger: { each: 0.04, from: "start" },
        })
        // Settle
        .to(
          files,
          {
            scale: 1.02,
            y: -1,
            duration: formaDuration.fast * 0.5,
          },
          ">"
        )
        // Pills slide up
        .to(
          pills,
          {
            y: -2,
            stagger: 0.04,
            duration: formaDuration.fast * 0.8,
          },
          0
        );
    },
    { scope: sceneRef }
  );

  useEffect(() => {
    if (isHovered) tlRef.current?.play();
    else tlRef.current?.reverse();
  }, [isHovered]);

  return (
    <div
      ref={sceneRef}
      className="relative flex h-[220px] flex-col items-center justify-center gap-3 overflow-hidden rounded-t-2xl bg-[var(--bg-tertiary)]"
    >
      {/* Peeking DOCX file in top-right corner */}
      <div className="absolute -top-1 -right-1 w-[48px] h-[58px] opacity-60">
        <MacFileIcon badgeText="DOCX" badgeColor="#2B579A">
          <rect x="10" y="22" width="28" height="2.5" rx="1" fill="#C8C4BF" opacity="0.4" />
          <rect x="10" y="27" width="28" height="2.5" rx="1" fill="#C8C4BF" opacity="0.3" />
        </MacFileIcon>
      </div>

      {/* 2×3 file grid */}
      <div className="grid grid-cols-3 gap-x-6 gap-y-2">
        {projectFiles.map((file) => (
          <div key={file.badge} data-file>
            <MacFileIcon
              className="w-[52px] h-[63px]"
              badgeText={file.badge}
              badgeColor={file.badgeColor}
            >
              {file.content}
            </MacFileIcon>
          </div>
        ))}
      </div>

      {/* Category pills */}
      <div className="flex gap-2">
        {categoryPills.map((pill) => (
          <span
            key={pill}
            data-pill
            className="rounded-full border border-[var(--border-medium)] bg-[var(--bg-secondary)] px-3 py-1 text-[12px] font-medium text-[var(--text-secondary)]"
          >
            {pill}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   BENTO CARD WRAPPER (manages hover state, passes to scene)
   ═══════════════════════════════════════════════════════════════════════════ */

function BentoCard({
  children,
  title,
  description,
}: {
  children: (isHovered: boolean) => React.ReactNode;
  title: string;
  description: string;
}) {
  const [isHovered, setIsHovered] = useState(false);

  return (
    <article
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      className="group overflow-hidden rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] transition-all duration-300 hover:-translate-y-1 hover:border-[var(--border-medium)] hover:shadow-[0_8px_30px_rgba(0,0,0,0.06)]"
    >
      {children(isHovered)}
      <div className="border-t border-[var(--border-subtle)] px-6 py-5">
        <h3 className="text-[16px] font-semibold text-[var(--text-primary)]">
          {title}
        </h3>
        <p className="mt-2 text-[14px] leading-relaxed text-[var(--text-secondary)]">
          {description}
        </p>
      </div>
    </article>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   TRUST SIGNALS
   ═══════════════════════════════════════════════════════════════════════════ */

const trustSignals = [
  {
    icon: Shield,
    title: "Local-only privacy",
    body: "Your files never leave your Mac. No account, no uploads, no \u2018we take privacy seriously\u2019 blog post.",
    color: "text-forma-sage",
    bgTint: "bg-[rgba(122,157,126,0.14)]",
    borderTint: "border-[rgba(122,157,126,0.22)]",
    animationClass: "",
  },
  {
    icon: EyeOff,
    title: "No background agent",
    body: "Forma runs when you ask, not behind your back. No daemon, no menu bar icon, no silent surprises.",
    color: "text-forma-steel-blue",
    bgTint: "bg-[rgba(91,124,153,0.14)]",
    borderTint: "border-[rgba(91,124,153,0.22)]",
    animationClass: "",
  },
  {
    icon: Lock,
    title: "Sandboxed",
    body: "App Store approved, no full-disk access. Forma only touches the folders you explicitly grant.",
    color: "text-forma-warm-orange",
    bgTint: "bg-[rgba(201,126,102,0.14)]",
    borderTint: "border-[rgba(201,126,102,0.22)]",
    animationClass: "",
  },
];

/* ═══════════════════════════════════════════════════════════════════════════
   SUBSECTION LABEL
   ═══════════════════════════════════════════════════════════════════════════ */

function SubsectionLabel({ children }: { children: React.ReactNode }) {
  return (
    <p className="mb-5 text-[12px] font-semibold uppercase tracking-[0.14em] text-[var(--text-muted)]">
      {children}
    </p>
  );
}

/* ═══════════════════════════════════════════════════════════════════════════
   EXPORTED SECTION
   ═══════════════════════════════════════════════════════════════════════════ */

export default function UseCasesBento() {
  return (
    <section
      aria-labelledby="use-cases-heading"
      className="relative z-10 bg-transparent py-20 md:py-28"
    >
      <div className="site-container">
        {/* Section header */}
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-[12px] font-semibold uppercase tracking-[0.12em] text-forma-steel-blue">
            Where it clicks
          </p>
          <h2
            id="use-cases-heading"
            className="mx-auto mt-5 max-w-2xl text-[1.875rem] font-semibold leading-[1.15] tracking-[-0.03em] text-[var(--text-primary)] md:text-[2.75rem] md:leading-[1.1]"
          >
            Start with the folder that bothers you most.
          </h2>
          <p className="mx-auto mt-5 max-w-lg text-base leading-relaxed text-[var(--text-secondary)] md:text-[1.125rem]">
            One rule, one folder, one visible payoff. Expand from there.
          </p>
        </div>

        {/* WHAT YOU ORGANIZE — bento cards */}
        <div className="mx-auto mt-14 max-w-5xl">
          <SubsectionLabel>What you organize</SubsectionLabel>
          <ScrollReveal
            direction="up"
            distance={24}
            stagger={0.08}
            className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3"
          >
            <BentoCard
              title="Screenshots and exports"
              description="Your desktop has 400 screenshots on it right now. Don&rsquo;t look. Just write a rule."
            >
              {(isHovered) => <ScreenshotsScene isHovered={isHovered} />}
            </BentoCard>
            <BentoCard
              title="PDFs and paperwork"
              description="Invoices, tax forms, bank statements. Rules you can still understand when tax season hits."
            >
              {(isHovered) => <PDFsScene isHovered={isHovered} />}
            </BentoCard>
            <BentoCard
              title="Project overflow"
              description="Exports, renders, drafts — the files that pile up mid-project. Move them without losing track."
            >
              {(isHovered) => <ProjectsScene isHovered={isHovered} />}
            </BentoCard>
          </ScrollReveal>
        </div>

        {/* HOW IT WORKS — trust signal cards */}
        <div className="mx-auto mt-14 max-w-5xl">
          <SubsectionLabel>How it works</SubsectionLabel>
          <ScrollReveal
            direction="up"
            distance={24}
            stagger={0.08}
            className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3"
          >
            {trustSignals.map((signal) => {
              const Icon = signal.icon;
              return (
                <article
                  key={signal.title}
                  className="group rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 transition-all duration-300 hover:-translate-y-1 hover:border-[var(--border-medium)] hover:shadow-[0_8px_30px_rgba(0,0,0,0.06)]"
                >
                  <div
                    className={`flex h-11 w-11 items-center justify-center rounded-xl border ${signal.borderTint} ${signal.bgTint}`}
                  >
                    <Icon
                      className={`h-5 w-5 ${signal.color} ${signal.animationClass}`}
                      strokeWidth={1.5}
                    />
                  </div>
                  <h3 className="mt-4 text-[16px] font-semibold text-[var(--text-primary)]">
                    {signal.title}
                  </h3>
                  <p className="mt-2 text-[14px] leading-relaxed text-[var(--text-secondary)]">
                    {signal.body}
                  </p>
                </article>
              );
            })}
          </ScrollReveal>
        </div>
      </div>
    </section>
  );
}
