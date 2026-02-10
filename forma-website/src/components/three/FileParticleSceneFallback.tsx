"use client";
import { useMemo, useEffect, useRef } from "react";
import { gsap } from "@/lib/animation/gsap-config";

const files = [
  { name: "Screenshot 2024-01-15.png", type: "image", folder: 0 },
  { name: "IMG_4829.HEIC", type: "image", folder: 0 },
  { name: "Document (3).pdf", type: "document", folder: 1 },
  { name: "final_v2_FINAL.docx", type: "document", folder: 1 },
  { name: "app.tsx", type: "code", folder: 2 },
  { name: "styles.css", type: "code", folder: 2 },
  { name: "recording.mov", type: "video", folder: 3 },
  { name: "tutorial.mp4", type: "video", folder: 3 },
];

const typeColors: Record<string, string> = {
  image: "bg-[#C17E4A]",
  document: "bg-[#5B7C99]",
  code: "bg-[#7A9D7E]",
  video: "bg-[#6A8FAA]",
};

function seededRandom(seed: number) {
  const x = Math.sin(seed * 9301 + 49297) * 233280;
  return x - Math.floor(x);
}

interface Props {
  progress: number;
}

export function FileParticleSceneFallback({ progress }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const fileRefs = useRef<(HTMLDivElement | null)[]>([]);

  const chaosPositions = useMemo(
    () =>
      files.map((_, i) => ({
        x: (seededRandom(i * 3 + 1) - 0.5) * 280,
        y: (seededRandom(i * 3 + 2) - 0.5) * 200,
        rotation: (seededRandom(i * 3 + 3) - 0.5) * 12,
      })),
    [],
  );

  const organizedPositions = useMemo(() => {
    const counts = [0, 0, 0, 0];
    return files.map((file) => {
      const col = counts[file.folder]++;
      return {
        x: -140 + col * 160,
        y: -90 + file.folder * 55,
        rotation: 0,
      };
    });
  }, []);

  useEffect(() => {
    const sortProgress = Math.max(
      0,
      Math.min(1, (progress - 0.25) / 0.45),
    );
    const eased =
      sortProgress < 0.5
        ? 4 * sortProgress ** 3
        : 1 - (-2 * sortProgress + 2) ** 3 / 2;

    fileRefs.current.forEach((el, i) => {
      if (!el) return;
      const c = chaosPositions[i];
      const o = organizedPositions[i];
      gsap.set(el, {
        x: c.x + (o.x - c.x) * eased,
        y: c.y + (o.y - c.y) * eased,
        rotation: c.rotation * (1 - eased),
      });
    });
  }, [progress, chaosPositions, organizedPositions]);

  return (
    <div
      ref={containerRef}
      className="relative w-full h-[400px] md:h-[500px]"
      aria-hidden="true"
    >
      {files.map((file, i) => (
        <div
          key={i}
          ref={(el) => {
            fileRefs.current[i] = el;
          }}
          className="absolute left-1/2 top-1/2 rounded-lg border border-white/[0.08] bg-white/[0.04] backdrop-blur-sm px-3 py-2 shadow-lg"
        >
          <div className="flex items-center gap-2">
            <span
              className={`w-2 h-2 rounded-full ${typeColors[file.type]}`}
            />
            <span className="font-mono text-[11px] text-[var(--text-secondary)] whitespace-nowrap">
              {file.name.length > 20
                ? file.name.slice(0, 20) + "..."
                : file.name}
            </span>
          </div>
        </div>
      ))}
    </div>
  );
}

export default FileParticleSceneFallback;
