"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import Lottie, { LottieRefCurrentProps } from "lottie-react";

export interface LottieAnimationProps {
  /** Path to the JSON animation file in /public/animations/ (e.g., "hero-animation.json") */
  animationPath: string;
  /** Whether the animation should autoplay (default: true) */
  autoplay?: boolean;
  /** Whether the animation should loop (default: true) */
  loop?: boolean;
  /** Additional CSS classes */
  className?: string;
  /** Callback fired when animation completes (only fires if loop is false) */
  onComplete?: () => void;
  /** Start paused and play on hover (default: false) */
  playOnHover?: boolean;
  /** Start paused and play when in viewport (default: false) */
  playOnView?: boolean;
  /** IntersectionObserver threshold for playOnView (default: 0.5) */
  viewThreshold?: number;
  /** Animation speed (default: 1) */
  speed?: number;
  /** Aria label for accessibility */
  ariaLabel?: string;
}

/**
 * LottieAnimation Component
 *
 * A reusable Lottie animation component that supports:
 * - Dynamic loading of animation JSON files
 * - Autoplay and loop controls
 * - Hover-triggered playback
 * - Viewport-triggered playback (using IntersectionObserver)
 * - Animation completion callbacks
 *
 * @example
 * // Basic usage
 * <LottieAnimation animationPath="hero-animation.json" />
 *
 * @example
 * // Play on hover
 * <LottieAnimation
 *   animationPath="icon-animation.json"
 *   playOnHover
 *   loop={false}
 * />
 *
 * @example
 * // Play when scrolled into view
 * <LottieAnimation
 *   animationPath="scroll-animation.json"
 *   playOnView
 *   viewThreshold={0.3}
 * />
 */
export function LottieAnimation({
  animationPath,
  autoplay = true,
  loop = true,
  className,
  onComplete,
  playOnHover = false,
  playOnView = false,
  viewThreshold = 0.5,
  speed = 1,
  ariaLabel,
}: LottieAnimationProps) {
  const [animationData, setAnimationData] = useState<object | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isInView, setIsInView] = useState(false);
  const [isHovering, setIsHovering] = useState(false);

  const lottieRef = useRef<LottieRefCurrentProps>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  // Determine if animation should play based on props
  const shouldAutoplay = autoplay && !playOnHover && !playOnView;
  const shouldPlay = shouldAutoplay || (playOnHover && isHovering) || (playOnView && isInView);

  // Load animation data dynamically
  useEffect(() => {
    let isMounted = true;

    const loadAnimation = async () => {
      try {
        setIsLoading(true);
        setError(null);

        // Fetch animation JSON from public/animations/
        const response = await fetch(`/animations/${animationPath}`);

        if (!response.ok) {
          throw new Error(`Failed to load animation: ${response.statusText}`);
        }

        const data = await response.json();

        if (isMounted) {
          setAnimationData(data);
          setIsLoading(false);
        }
      } catch (err) {
        if (isMounted) {
          setError(err instanceof Error ? err.message : "Failed to load animation");
          setIsLoading(false);
        }
      }
    };

    loadAnimation();

    return () => {
      isMounted = false;
    };
  }, [animationPath]);

  // Set animation speed when lottie ref is available
  useEffect(() => {
    if (lottieRef.current && speed !== 1) {
      lottieRef.current.setSpeed(speed);
    }
  }, [speed, animationData]);

  // IntersectionObserver for playOnView
  useEffect(() => {
    if (!playOnView || !containerRef.current) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          setIsInView(entry.isIntersecting);
        });
      },
      {
        threshold: viewThreshold,
        rootMargin: "0px",
      }
    );

    observer.observe(containerRef.current);

    return () => {
      observer.disconnect();
    };
  }, [playOnView, viewThreshold]);

  // Control playback based on shouldPlay state
  useEffect(() => {
    if (!lottieRef.current || !animationData) return;

    if (shouldPlay) {
      lottieRef.current.play();
    } else {
      lottieRef.current.pause();
      // Reset to first frame when not playing (for hover interactions)
      if (playOnHover && !isHovering) {
        lottieRef.current.goToAndStop(0, true);
      }
    }
  }, [shouldPlay, animationData, playOnHover, isHovering]);

  // Handle animation complete
  const handleComplete = useCallback(() => {
    onComplete?.();
  }, [onComplete]);

  // Hover handlers
  const handleMouseEnter = useCallback(() => {
    if (playOnHover) {
      setIsHovering(true);
    }
  }, [playOnHover]);

  const handleMouseLeave = useCallback(() => {
    if (playOnHover) {
      setIsHovering(false);
    }
  }, [playOnHover]);

  // Loading state
  if (isLoading) {
    return (
      <div
        ref={containerRef}
        className={className}
        aria-label={ariaLabel || "Loading animation"}
        role="img"
      >
        {/* Optional: Add a skeleton/placeholder here */}
      </div>
    );
  }

  // Error state
  if (error || !animationData) {
    // Fail silently in production - just render nothing
    if (process.env.NODE_ENV === "development" && error) {
      console.warn(`LottieAnimation: ${error} (${animationPath})`);
    }
    return null;
  }

  return (
    <div
      ref={containerRef}
      className={className}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      role="img"
      aria-label={ariaLabel || "Animation"}
    >
      <Lottie
        lottieRef={lottieRef}
        animationData={animationData}
        loop={loop}
        autoplay={shouldAutoplay}
        onComplete={handleComplete}
        style={{ width: "100%", height: "100%" }}
      />
    </div>
  );
}

export default LottieAnimation;
