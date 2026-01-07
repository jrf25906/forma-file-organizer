"use client";

// GSAP core and plugins
export { gsap, ScrollTrigger, useGSAP } from "./gsap-config";

// Lenis + GSAP integration
export {
  LenisGSAPProvider,
  useLenisScroll,
  scrollTo,
  Lenis,
} from "./scroll-context";

// Forma brand easing curves
export {
  formaSnap,
  formaReveal,
  formaSettle,
  formaMagnetic,
  formaExit,
  formaStagger,
  formaDuration,
  formaPresets,
} from "./ease-curves";
