"use client";
import { useThree } from "@react-three/fiber";
import { useEffect } from "react";

export function SceneEnvironment() {
  const { camera } = useThree();

  useEffect(() => {
    camera.position.set(0, 2, 12);
    camera.lookAt(0, 0, 0);
  }, [camera]);

  return (
    <>
      <ambientLight intensity={0.3} />
      <pointLight position={[-5, 5, 5]} color="#5B7C99" intensity={1.2} />
      <pointLight position={[5, -3, 3]} color="#7A9D7E" intensity={0.8} />
      <fog attach="fog" args={["#0A0A0B", 10, 25]} />
    </>
  );
}
