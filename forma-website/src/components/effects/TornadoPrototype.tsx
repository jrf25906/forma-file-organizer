'use client';
import { useRef, useMemo, Suspense, useState } from 'react';
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
  const dummy = useMemo(() => new Object3D(), []);
  
  // Store physics data for each particle
  const particles = useMemo(() => {
    const temp = [];
    for (let i = 0; i < PARTICLES_PER_TEXTURE; i++) {
      // Organized Stack Parameters (where they belong when neat)
      // 11 texture types mapped from -15 to +15 on X axis
      const stackX = (textureIndex - 5) * 3.2;
      const stackZ = 5; // bringing them slightly forward for the camera
      
      temp.push({
        // TORNADO CONSTANTS
        tY: (Math.random() - 0.5) * TORNADO_HEIGHT,
        angle: Math.random() * Math.PI * 2,
        speed: (Math.random() * 0.4 + 0.8) * TORNADO_SPEED,
        radiusOffset: Math.random() * 2.5 - 1.25,
        tRx: Math.random() * Math.PI,
        tRy: Math.random() * Math.PI,
        tRz: Math.random() * Math.PI,
        tRs: (Math.random() - 0.5) * 4,
        
        // ORGANIZED CONSTANTS
        oX: stackX + (Math.random() - 0.5) * 0.15, // slight sloppy stack
        oY: -8 + i * 0.045, // Stack up vertically from base
        oZ: stackZ + (Math.random() - 0.5) * 0.15,
        oRx: -Math.PI / 2, // lay flat on the ground
        oRy: 0,
        oRz: (Math.random() - 0.5) * 0.2, // slight rotational twist
        
        // CURRENT PHYSICS STATE
        x: (Math.random() - 0.5) * 20,
        y: (Math.random() - 0.5) * 20,
        z: (Math.random() - 0.5) * 20,
        q: new Quaternion().random()
      });
    }
    return temp;
  }, [textureIndex]);

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
