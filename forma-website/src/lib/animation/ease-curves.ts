"use client";

export const formaSnap = "elastic.out(1, 0.5)";
export const formaReveal = "power3.out";
export const formaSettle = "back.out(1.7)";
export const formaMagnetic = "power2.out";
export const formaExit = "power2.in";

export const formaStagger = {
  fast: 0.06,
  normal: 0.12,
  slow: 0.18,
  cascade: 0.1,
};

export const formaDuration = {
  instant: 0.2,
  fast: 0.4,
  normal: 0.85,
  slow: 1.1,
  reveal: 1.5,
};

export const formaPresets = {
  fadeUp: {
    from: { opacity: 0, y: 30 },
    to: { opacity: 1, y: 0, ease: formaReveal, duration: formaDuration.normal },
  },
  fadeIn: {
    from: { opacity: 0 },
    to: { opacity: 1, ease: formaReveal, duration: formaDuration.fast },
  },
  scaleIn: {
    from: { opacity: 0, scale: 0.9 },
    to: { opacity: 1, scale: 1, ease: formaSettle, duration: formaDuration.normal },
  },
  snapIn: {
    from: { opacity: 0, y: 50, scale: 0.95 },
    to: { opacity: 1, y: 0, scale: 1, ease: formaSnap, duration: formaDuration.slow },
  },
};
