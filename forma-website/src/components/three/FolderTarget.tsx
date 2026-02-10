"use client";
import * as THREE from "three";
import { Text } from "@react-three/drei";

interface FolderTargetProps {
  label: string;
  position: [number, number, number];
  color: string;
  opacity: number;
}

export function FolderTarget({
  label,
  position,
  color,
  opacity,
}: FolderTargetProps) {
  return (
    <group position={position}>
      {/* Wireframe box outline */}
      <lineSegments>
        <edgesGeometry args={[new THREE.BoxGeometry(5.5, 1.8, 0.1)]} />
        <lineBasicMaterial color={color} opacity={opacity * 0.4} transparent />
      </lineSegments>
      {/* Label above folder */}
      <Text
        position={[-2.5, 1.15, 0]}
        fontSize={0.16}
        color={color}
        anchorX="left"
        anchorY="middle"
        fillOpacity={opacity}
      >
        {label}
      </Text>
      {/* Subtle glow plane */}
      <mesh>
        <planeGeometry args={[5.5, 1.8]} />
        <meshBasicMaterial color={color} opacity={opacity * 0.03} transparent />
      </mesh>
    </group>
  );
}
