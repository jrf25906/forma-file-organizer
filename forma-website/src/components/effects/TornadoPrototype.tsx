'use client';
import { useRef, Suspense, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { Object3D, DoubleSide, BoxGeometry, MathUtils, Quaternion, Euler, InstancedMesh } from 'three';
import { Environment, PerspectiveCamera, OrbitControls, useTexture } from '@react-three/drei';

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

type PrototypeParticleSeed = {
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
  x: number;
  y: number;
  z: number;
  qx: number;
  qy: number;
  qz: number;
  qw: number;
};

type PrototypeParticleState = Omit<PrototypeParticleSeed, 'qx' | 'qy' | 'qz' | 'qw'> & {
  q: Quaternion;
};

function centeredRandom(scale: number) {
  return (Math.random() - 0.5) * scale;
}

function createPrototypeParticleSeeds(textureIndex: number): PrototypeParticleSeed[] {
  const particles: PrototypeParticleSeed[] = [];
  const stackX = (textureIndex - 5) * 3.2;
  const stackZ = 5;

  for (let i = 0; i < PARTICLES_PER_TEXTURE; i++) {
    const orientation = new Quaternion().random();

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
      oY: -8 + i * 0.045,
      oZ: stackZ + centeredRandom(0.15),
      oRx: -Math.PI / 2,
      oRy: 0,
      oRz: centeredRandom(0.2),
      x: centeredRandom(20),
      y: centeredRandom(20),
      z: centeredRandom(20),
      qx: orientation.x,
      qy: orientation.y,
      qz: orientation.z,
      qw: orientation.w,
    });
  }

  return particles;
}

function clonePrototypeParticles(seeds: PrototypeParticleSeed[]): PrototypeParticleState[] {
  return seeds.map(({ qx, qy, qz, qw, ...particle }) => ({
    ...particle,
    q: new Quaternion(qx, qy, qz, qw),
  }));
}

const PROTOTYPE_PARTICLES_BY_TEXTURE = TEXTURE_PATHS.map((_, index) =>
  createPrototypeParticleSeeds(index)
);

// Shared Curved Geometry
const curvedCardGeometry = new BoxGeometry(2.5, 2.5, 0.04, 12, 12, 1);
const pos = curvedCardGeometry.attributes.position;
for (let i = 0; i < pos.count; i++) {
  const x = pos.getX(i);
  const z = pos.getZ(i) + 0.15 * (x * x); 
  pos.setZ(i, z);
}
curvedCardGeometry.computeVertexNormals();

// Renders one specific icon type as a swarm of instances
function TexturedSwarm({ texturePath, textureIndex, isOrganized }: { texturePath: string, textureIndex: number, isOrganized: boolean }) {
  const texture = useTexture(texturePath);
  const meshRef = useRef<InstancedMesh>(null);
  const dummyRef = useRef<Object3D | null>(null);
  const particlesRef = useRef<PrototypeParticleState[] | null>(null);

  if (dummyRef.current === null) {
    dummyRef.current = new Object3D();
  }

  if (particlesRef.current === null) {
    particlesRef.current = clonePrototypeParticles(
      PROTOTYPE_PARTICLES_BY_TEXTURE[textureIndex] ?? []
    );
  }

  const dummy = dummyRef.current;
  const particles = particlesRef.current;

  useFrame((state) => {
    if (!meshRef.current) return;
    const time = state.clock.getElapsedTime();
    const targetEuler = new Euler();
    const targetQ = new Quaternion();
    const lerpSpeed = isOrganized ? 0.05 : 0.03; // snappier when organizing, more floaty when unleashing

    particles.forEach((particle, i) => {
      // 1. Calculate ideal Tornado Position & Rotation
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

      // 2. Select Target Position based on state
      const targetX = isOrganized ? particle.oX : tX;
      const targetY = isOrganized ? particle.oY : tY;
      const targetZ = isOrganized ? particle.oZ : tZ;
      
      // 3. Interpolate Position
      particle.x = MathUtils.lerp(particle.x, targetX, lerpSpeed);
      particle.y = MathUtils.lerp(particle.y, targetY, lerpSpeed);
      particle.z = MathUtils.lerp(particle.z, targetZ, lerpSpeed);
      dummy.position.set(particle.x, particle.y, particle.z);

      // 4. Interpolate Rotation (Quaternion Slerp)
      if (isOrganized) {
        targetEuler.set(particle.oRx, particle.oRy, particle.oRz);
      } else {
        targetEuler.set(tRx, tRy, tRz);
      }
      targetQ.setFromEuler(targetEuler);
      particle.q.slerp(targetQ, lerpSpeed);
      dummy.setRotationFromQuaternion(particle.q);
      
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
        castShadow
        receiveShadow
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

function TornadoTextureGroups({ isOrganized }: { isOrganized: boolean }) {
  return (
    <>
      {TEXTURE_PATHS.map((path, index) => (
         <TexturedSwarm key={path} texturePath={path} textureIndex={index} isOrganized={isOrganized} />
      ))}
    </>
  );
}

export default function TornadoPrototype() {
  const [isOrganized, setIsOrganized] = useState(false);

  return (
    <div className="w-full h-screen bg-[#FDFCFB] overflow-hidden relative font-sans">
      <div className="absolute inset-0 z-10 pointer-events-none flex flex-col items-center justify-center">
         <h1 className="text-6xl md:text-8xl font-bold tracking-tighter mix-blend-difference text-white/90 drop-shadow-lg transition-all duration-1000 ease-in-out">
            {isOrganized ? "Order, Restored." : "Chaos, Untangled."}
         </h1>
         <p className="text-black/60 font-medium text-lg max-w-lg text-center mt-6 backdrop-blur-sm bg-white/30 py-2 px-6 rounded-full border border-white/40 shadow-sm mix-blend-multiply">
            Forma Interactive Prototype
         </p>
         
         <button 
           className="mt-12 pointer-events-auto px-8 py-4 bg-[#FF6A39] hover:bg-[#E55B33] text-white rounded-full font-bold text-lg transition-transform hover:scale-105 active:scale-95 shadow-xl"
           onClick={() => setIsOrganized(!isOrganized)}
         >
           {isOrganized ? "Unleash Chaos" : "Organize Files"}
         </button>
      </div>
      
      <Canvas shadows dpr={[1, 2]} gl={{ antialias: true }}>
        <PerspectiveCamera makeDefault position={[0, -2, 28]} fov={50} />
        {/* The user can click and drag to orbit around the tornado */}
        <OrbitControls enableZoom={true} enablePan={false} autoRotate autoRotateSpeed={0.3} maxPolarAngle={Math.PI / 1.5} />
        
        <ambientLight intensity={0.6} />
        <directionalLight position={[10, 20, 10]} intensity={1.5} castShadow shadow-mapSize={[1024, 1024]} />
        <directionalLight position={[-10, 10, -10]} intensity={0.8} color="#FFD1A9" />
        <pointLight position={[0, 0, 5]} intensity={0.5} color="#ffffff" distance={20} />
        
        <Suspense fallback={null}>
            <TornadoTextureGroups isOrganized={isOrganized} />
        </Suspense>
        
        <Environment preset="city" />
      </Canvas>
    </div>
  );
}
