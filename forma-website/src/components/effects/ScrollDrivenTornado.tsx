'use client';
import { useRef, Suspense } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Object3D, DoubleSide, BoxGeometry, MathUtils, Quaternion, Euler, InstancedMesh, Group } from 'three';
import { Environment, PerspectiveCamera, useTexture } from '@react-three/drei';
import { useGSAP } from '@gsap/react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

// Global proxy object to hold strictly bound GSAP scroll progress
export const tornadoScrollState = { progress: 0 };

const TEXTURE_PATHS = [
  '/file-icons/audio.png',
  '/file-icons/design.png',
  '/file-icons/doc.png',
  '/file-icons/folder.png',
  '/file-icons/image.png',
  '/file-icons/pdf.png',
  '/file-icons/slides.png',
  '/file-icons/spreadsheet.png',
  '/file-icons/txt.png',
  '/file-icons/video.png',
  '/file-icons/zip.png'
];

const PARTICLES_PER_TEXTURE = 35; // Total ~385 particles
const TORNADO_HEIGHT = 45;
const TORNADO_SPEED = 1.2;

type ScrollParticle = {
  tY: number;
  angle: number;
  speed: number;
  radiusOffset: number;
  tRx: number;
  tRy: number;
  tRz: number;
  tRs: number;
  oX: number;
  oY: number;
  oZ: number;
  oRx: number;
  oRy: number;
  oRz: number;
};

function centeredRandom(scale: number) {
  return (Math.random() - 0.5) * scale;
}

function createScrollParticles(textureIndex: number): ScrollParticle[] {
  const particles: ScrollParticle[] = [];
  const stackX = (textureIndex - 5) * 3.2;
  const stackZ = 5;

  for (let i = 0; i < PARTICLES_PER_TEXTURE; i++) {
    particles.push({
      tY: centeredRandom(TORNADO_HEIGHT),
      angle: Math.random() * Math.PI * 2,
      speed: (Math.random() * 0.4 + 0.8) * TORNADO_SPEED,
      radiusOffset: centeredRandom(2.5),
      tRx: Math.random() * Math.PI,
      tRy: Math.random() * Math.PI,
      tRz: Math.random() * Math.PI,
      tRs: centeredRandom(4),
      oX: stackX + centeredRandom(0.15),
      oY: -14 + i * 0.045,
      oZ: stackZ + centeredRandom(0.15),
      oRx: -Math.PI / 2,
      oRy: centeredRandom(0.35),
      oRz: centeredRandom(0.1),
    });
  }

  return particles;
}

const SCROLL_PARTICLES_BY_TEXTURE = TEXTURE_PATHS.map((_, index) =>
  createScrollParticles(index)
);

// Shared Curved Geometry for memory efficiency
const curvedCardGeometry = new BoxGeometry(2.5, 2.5, 0.04, 12, 12, 1);
const pos = curvedCardGeometry.attributes.position;
for (let i = 0; i < pos.count; i++) {
  const x = pos.getX(i);
  const z = pos.getZ(i) + 0.15 * (x * x); 
  pos.setZ(i, z);
}
curvedCardGeometry.computeVertexNormals();

// Renders one specific icon type as a swarm of instances
function TexturedSwarm({ texturePath, textureIndex }: { texturePath: string, textureIndex: number }) {
  const texture = useTexture(texturePath);
  const meshRef = useRef<InstancedMesh>(null);
  const dummyRef = useRef<Object3D | null>(null);

  if (dummyRef.current === null) {
    dummyRef.current = new Object3D();
  }

  const dummy = dummyRef.current;
  const particles = SCROLL_PARTICLES_BY_TEXTURE[textureIndex] ?? [];

  useFrame((state) => {
    if (!meshRef.current) return;
    const time = state.clock.getElapsedTime();
    const progress = tornadoScrollState.progress;
    
    // Safety check: if out of view completely (progress > 1.2), we could skip math to save CPU
    
    particles.forEach((particle, i) => {
      // 1. Calculate ideal Tornado Position & Rotation (always evolving via time)
      const currentAngle = particle.angle + time * particle.speed;
      const heightPercent = (particle.tY + TORNADO_HEIGHT / 2) / TORNADO_HEIGHT;
      const radius = 1.5 + Math.pow(heightPercent, 2) * 12 + particle.radiusOffset;
      const tX = Math.cos(currentAngle) * radius;
      const tZ = Math.sin(currentAngle) * radius;
      const bobbing = Math.sin(time * 1.5 + particle.angle) * 0.5;
      const rawY = particle.tY + (time * 0.5) % TORNADO_HEIGHT;
      const tY = ((rawY + TORNADO_HEIGHT / 2) % TORNADO_HEIGHT) - TORNADO_HEIGHT / 2 + bobbing;
      
      const tRx = particle.tRx + time * particle.tRs;
      const tRy = particle.tRy + time * particle.tRs * 0.4;
      const tRz = particle.tRz + time * particle.tRs * 0.1;

      // 2. Mathematically evaluate position strictly across global scroll progress
      // progress = 0.0 (chaos), 1.0 (organized)
      const currentX = MathUtils.lerp(tX, particle.oX, progress);
      const currentY = MathUtils.lerp(tY, particle.oY, progress);
      const currentZ = MathUtils.lerp(tZ, particle.oZ, progress);
      dummy.position.set(currentX, currentY, currentZ);

      // 3. Interpolate Rotation via Quaternion Slerp strictly across global scroll progress
      const chaosEuler = new Euler(tRx, tRy, tRz);
      const chaosQ = new Quaternion().setFromEuler(chaosEuler);
      
      const orderEuler = new Euler(particle.oRx, particle.oRy, particle.oRz);
      const orderQ = new Quaternion().setFromEuler(orderEuler);
      
      const currentQ = chaosQ.slerp(orderQ, progress);
      dummy.setRotationFromQuaternion(currentQ);
      
      dummy.updateMatrix();
      meshRef.current!.setMatrixAt(i, dummy.matrix);
    });

    meshRef.current.instanceMatrix.needsUpdate = true;
  });

  return (
    <instancedMesh 
        ref={meshRef} 
        args={[undefined, undefined, PARTICLES_PER_TEXTURE]}
        geometry={curvedCardGeometry}
    >
      <meshPhysicalMaterial 
        map={texture}
        transparent={true}
        alphaTest={0.01}
        roughness={0.4}
        metalness={0.2}
        clearcoat={0.3}
        transmission={0.0}
        side={DoubleSide}
      />
    </instancedMesh>
  );
}

function TornadoTextureGroups() {
  return (
    <>
      {TEXTURE_PATHS.map((path, index) => (
         <TexturedSwarm key={path} texturePath={path} textureIndex={index} />
      ))}
    </>
  );
}

// Wraps the tornado in a group that tilts dynamically based on the user's cursor position.
function ParallaxGroup({ children }: { children: React.ReactNode }) {
  const groupRef = useRef<Group>(null);
  
  useFrame((state) => {
    if (!groupRef.current) return;
    // Map cursor (-1 to 1) vectors to a soft 5 degree rotation (Math.PI / 35 max tilt)
    const targetX = (state.pointer.x * Math.PI) / 35;
    const targetY = (state.pointer.y * Math.PI) / 35;
    
    groupRef.current.rotation.y = MathUtils.lerp(groupRef.current.rotation.y, targetX, 0.05);
    groupRef.current.rotation.x = MathUtils.lerp(groupRef.current.rotation.x, -targetY, 0.05);
  });

  return <group ref={groupRef}>{children}</group>;
}

export default function ScrollDrivenTornado() {
  const containerRef = useRef<HTMLDivElement>(null);

  useGSAP(() => {
    // We bind the scrollState mathematically to the user's scroll depth across the hero section
    const tween = gsap.to(tornadoScrollState, {
      progress: 1,
      ease: "none",
      scrollTrigger: {
        trigger: "#top", // Start transitioning when scrolling the hero section
        start: "top top",
        end: "bottom top", // Become perfectly organized just as the hero section leaves the viewport
        scrub: 1.2, // 1.2 seconds of GSAP lag creates a heavier, extremely fluid physical animation
      }
    });

    const handleManualTrigger = () => {
      // 1. Kill the scrollTrigger so it stops forcing progress to the scrollbar
      if (tween.scrollTrigger) tween.scrollTrigger.kill();
      // 2. Animate the progress smoothly to 1.0 yourself
      gsap.to(tornadoScrollState, {
        progress: 1,
        duration: 2.5, // Satisfyingly slow physical transition
        ease: "power2.inOut"
      });
    };

    window.addEventListener('forma-organize-click', handleManualTrigger);
    return () => window.removeEventListener('forma-organize-click', handleManualTrigger);
  }); // Global triggers like #pricing can be found because scope was removed

  return (
    <div ref={containerRef} className="absolute inset-0 z-0 pointer-events-none w-full h-full opacity-40 md:opacity-35">
      {/* gl={{ alpha: true }} allows the white background of the page below to shine through the tornado */}
      <Canvas shadows dpr={[1, 1.5]} gl={{ antialias: true, alpha: true }}>
        <fog attach="fog" args={['#FDFCFB', 15, 38]} />
        <PerspectiveCamera makeDefault position={[0, -2, 28]} fov={50} />
        
        <ambientLight intensity={0.6} />
        <directionalLight position={[10, 20, 10]} intensity={1.5} />
        <directionalLight position={[-10, 10, -10]} intensity={0.8} color="#FFD1A9" />
        <pointLight position={[0, 0, 5]} intensity={0.5} color="#ffffff" distance={20} />
        
        <Suspense fallback={null}>
          <ParallaxGroup>
            <TornadoTextureGroups />
          </ParallaxGroup>
        </Suspense>
        
        <Environment preset="city" />
      </Canvas>
    </div>
  );
}
