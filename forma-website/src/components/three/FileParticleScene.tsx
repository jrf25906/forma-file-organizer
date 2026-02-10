"use client";
import { Suspense, useMemo, useRef } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import * as THREE from "three";
import { FileCard } from "./FileCard";
import { FolderTarget } from "./FolderTarget";
import { SceneEnvironment } from "./SceneEnvironment";

// File data
const files = [
  { name: "Screenshot 2024-01-15.png", type: "image" as const, folder: 0 },
  { name: "IMG_4829.HEIC", type: "image" as const, folder: 0 },
  { name: "hero-banner.jpg", type: "image" as const, folder: 0 },
  { name: "app-icon.svg", type: "image" as const, folder: 0 },
  { name: "DSC_0042.RAW", type: "image" as const, folder: 0 },
  { name: "profile-photo.png", type: "image" as const, folder: 0 },
  { name: "Document (3).pdf", type: "document" as const, folder: 1 },
  { name: "final_v2_FINAL.docx", type: "document" as const, folder: 1 },
  { name: "report-Q4.pdf", type: "document" as const, folder: 1 },
  { name: "meeting-notes.md", type: "document" as const, folder: 1 },
  { name: "invoice_march.pdf", type: "document" as const, folder: 1 },
  { name: "resume-2024.pdf", type: "document" as const, folder: 1 },
  { name: "app.tsx", type: "code" as const, folder: 2 },
  { name: "styles.css", type: "code" as const, folder: 2 },
  { name: "utils.ts", type: "code" as const, folder: 2 },
  { name: "config.json", type: "code" as const, folder: 2 },
  { name: "index.html", type: "code" as const, folder: 2 },
  { name: "package.json", type: "code" as const, folder: 2 },
  { name: "recording.mov", type: "video" as const, folder: 3 },
  { name: "tutorial.mp4", type: "video" as const, folder: 3 },
  { name: "screen-capture.mov", type: "video" as const, folder: 3 },
  { name: "demo-reel.mp4", type: "video" as const, folder: 3 },
  { name: "backup.zip", type: "document" as const, folder: 1 },
  { name: "Untitled.txt", type: "document" as const, folder: 1 },
  { name: "screenshot-2.png", type: "image" as const, folder: 0 },
  { name: "test-runner.ts", type: "code" as const, folder: 2 },
  { name: "clip-001.mov", type: "video" as const, folder: 3 },
  { name: "readme.md", type: "document" as const, folder: 1 },
  { name: "photo-edit.psd", type: "image" as const, folder: 0 },
  { name: "db-schema.sql", type: "code" as const, folder: 2 },
];

const folders = [
  { label: "Images", color: "#C17E4A" }, // warm-orange
  { label: "Documents", color: "#5B7C99" }, // steel-blue
  { label: "Code", color: "#7A9D7E" }, // sage
  { label: "Videos", color: "#6A8FAA" }, // muted-blue
];

// Seeded random for deterministic chaos positions
function seededRandom(seed: number) {
  const x = Math.sin(seed * 9301 + 49297) * 233280;
  return x - Math.floor(x);
}

function easeInOutCubic(t: number) {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

interface FileParticleSceneInnerProps {
  progress: number;
}

function FileParticleSceneInner({ progress }: FileParticleSceneInnerProps) {
  const groupRef = useRef<THREE.Group>(null);

  // Pre-compute chaos and organized positions
  const { chaosPositions, organizedPositions } = useMemo(() => {
    const chaos: {
      x: number;
      y: number;
      z: number;
      rx: number;
      ry: number;
      rz: number;
    }[] = [];
    const organized: { x: number; y: number; z: number }[] = [];

    // Chaos: scatter in a sphere-ish volume
    files.forEach((_, i) => {
      const r1 = seededRandom(i * 7 + 1);
      const r2 = seededRandom(i * 7 + 2);
      const r3 = seededRandom(i * 7 + 3);
      chaos.push({
        x: (r1 - 0.5) * 10,
        y: (r2 - 0.5) * 7,
        z: (r3 - 0.5) * 4 - 2,
        rx: (seededRandom(i * 7 + 4) - 0.5) * 0.3,
        ry: (seededRandom(i * 7 + 5) - 0.5) * 0.3,
        rz: (seededRandom(i * 7 + 6) - 0.5) * 0.2,
      });
    });

    // Organized: grid per folder
    const folderCounts = [0, 0, 0, 0];
    files.forEach((file) => {
      const fi = file.folder;
      const col = folderCounts[fi];
      const row = fi;
      organized.push({
        x: -3.5 + (col % 5) * 1.8,
        y: 2.5 - row * 2.2,
        z: 0,
      });
      folderCounts[fi]++;
    });

    return { chaosPositions: chaos, organizedPositions: organized };
  }, []);

  // Orbital drift time offset for chaos state
  const timeRef = useRef(0);

  useFrame((_, delta) => {
    if (!groupRef.current) return;
    timeRef.current += delta;

    const sortProgress = Math.max(
      0,
      Math.min(1, (progress - 0.25) / 0.45),
    );
    const easedSort = easeInOutCubic(sortProgress);

    groupRef.current.children.forEach((child, i) => {
      if (i >= files.length) return; // skip folder targets

      const chaos = chaosPositions[i];
      const org = organizedPositions[i];

      // Orbital drift in chaos state
      const driftScale = 1 - easedSort;
      const drift = {
        x: Math.sin(timeRef.current * 0.3 + i * 1.7) * 0.3 * driftScale,
        y: Math.cos(timeRef.current * 0.25 + i * 2.1) * 0.2 * driftScale,
        z:
          Math.sin(timeRef.current * 0.2 + i * 0.9) * 0.15 * driftScale,
      };

      // Per-card stagger: cards don't all move at once
      const staggerOffset = (i / files.length) * 0.15;
      const cardSort = Math.max(
        0,
        Math.min(1, (sortProgress - staggerOffset) / (1 - staggerOffset)),
      );
      const easedCardSort = easeInOutCubic(cardSort);

      child.position.x =
        chaos.x + (org.x - chaos.x) * easedCardSort + drift.x;
      child.position.y =
        chaos.y + (org.y - chaos.y) * easedCardSort + drift.y;
      child.position.z =
        chaos.z + (org.z - chaos.z) * easedCardSort + drift.z;

      child.rotation.x = chaos.rx * (1 - easedCardSort);
      child.rotation.y = chaos.ry * (1 - easedCardSort);
      child.rotation.z = chaos.rz * (1 - easedCardSort);
    });
  });

  // Folder target opacity
  const folderOpacity = Math.max(
    0,
    Math.min(1, (progress - 0.55) / 0.2),
  );

  return (
    <group ref={groupRef}>
      {files.map((file, i) => (
        <FileCard
          key={i}
          filename={file.name}
          fileType={file.type}
          position={[
            chaosPositions[i].x,
            chaosPositions[i].y,
            chaosPositions[i].z,
          ]}
          rotation={[
            chaosPositions[i].rx,
            chaosPositions[i].ry,
            chaosPositions[i].rz,
          ]}
        />
      ))}
      {folders.map((folder, i) => (
        <FolderTarget
          key={folder.label}
          label={folder.label}
          position={[-0.5, 2.5 - i * 2.2, -0.2]}
          color={folder.color}
          opacity={folderOpacity}
        />
      ))}
    </group>
  );
}

interface FileParticleSceneProps {
  progress: number;
}

export default function FileParticleScene({
  progress,
}: FileParticleSceneProps) {
  return (
    <Canvas
      camera={{ position: [0, 1, 12], fov: 45 }}
      dpr={[1, 1.5]}
      frameloop="always"
      gl={{ antialias: true, alpha: true, powerPreference: "high-performance" }}
      style={{ background: "transparent" }}
    >
      <SceneEnvironment />
      <Suspense fallback={null}>
        <FileParticleSceneInner progress={progress} />
      </Suspense>
    </Canvas>
  );
}
