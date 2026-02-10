"use client";
import { useRef } from "react";
import * as THREE from "three";
import { Text } from "@react-three/drei";

interface FileCardProps {
  filename: string;
  fileType: "document" | "image" | "code" | "video";
  position: [number, number, number];
  rotation?: [number, number, number];
}

const typeColors: Record<string, string> = {
  document: "#5B7C99", // steel-blue
  image: "#C17E4A", // warm-orange
  code: "#7A9D7E", // sage
  video: "#6A8FAA", // muted-blue
};

export function FileCard({
  filename,
  fileType,
  position,
  rotation = [0, 0, 0],
}: FileCardProps) {
  const meshRef = useRef<THREE.Mesh>(null);
  const color = typeColors[fileType];
  const displayName =
    filename.length > 22 ? filename.slice(0, 22) + "..." : filename;

  return (
    <group position={position} rotation={rotation}>
      <mesh ref={meshRef}>
        <boxGeometry args={[1.6, 1.1, 0.04]} />
        <meshStandardMaterial
          color="#1C1C1E"
          emissive={color}
          emissiveIntensity={0.15}
          roughness={0.5}
          metalness={0.1}
          transparent
          opacity={0.95}
        />
      </mesh>
      {/* File type indicator dot */}
      <mesh position={[-0.55, 0.35, 0.025]}>
        <circleGeometry args={[0.06, 16]} />
        <meshBasicMaterial color={color} />
      </mesh>
      {/* Filename text */}
      <Text
        position={[-0.35, 0.35, 0.025]}
        fontSize={0.08}
        color="#A0A0A4"
        anchorX="left"
        anchorY="middle"
        maxWidth={1.2}
      >
        {displayName}
      </Text>
      {/* File content placeholder lines */}
      {[0, 1, 2].map((i) => (
        <mesh key={i} position={[0, 0.1 - i * 0.18, 0.025]}>
          <planeGeometry args={[1.2, 0.06]} />
          <meshBasicMaterial color="#ffffff" opacity={0.04} transparent />
        </mesh>
      ))}
      {/* Border outline */}
      <lineSegments>
        <edgesGeometry args={[new THREE.BoxGeometry(1.6, 1.1, 0.04)]} />
        <lineBasicMaterial color={color} opacity={0.2} transparent />
      </lineSegments>
    </group>
  );
}
