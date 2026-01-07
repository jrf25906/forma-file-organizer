# Accessibility Fixes - Implementation Guide

This document contains all specific code changes needed to achieve WCAG 2.1 AA compliance.

## 🔴 CRITICAL FIX #1: Color Contrast

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/app/globals.css`

#### Change 1: Update CSS Variables (Lines 25-26)

```css
/* CURRENT */
--text-primary: var(--forma-bone);
--text-muted: rgba(250, 250, 248, 0.6);

/* REPLACE WITH */
--text-primary: var(--forma-bone);
--text-muted: rgba(250, 250, 248, 0.75);
```

#### Change 2: Update Dark Mode Opacity Classes (Lines 112-142)

Replace all these lines:

```css
/* Line 128-130 - CURRENT */
[data-theme="light"] .text-forma-bone\/60 {
  color: rgba(26, 26, 26, 0.6);
}

/* REPLACE WITH */
[data-theme="light"] .text-forma-bone\/60 {
  color: rgba(26, 26, 26, 0.75);
}

/* Line 124-126 - CURRENT */
[data-theme="light"] .text-forma-bone\/50 {
  color: rgba(26, 26, 26, 0.5);
}

/* REPLACE WITH */
[data-theme="light"] .text-forma-bone\/50 {
  color: rgba(26, 26, 26, 0.70);
}

/* Line 120-122 - CURRENT */
[data-theme="light"] .text-forma-bone\/40 {
  color: rgba(26, 26, 26, 0.4);
}

/* REPLACE WITH (Use only for large text 18px+) */
[data-theme="light"] .text-forma-bone\/40 {
  color: rgba(26, 26, 26, 0.65);
}

/* Line 132-134 - CURRENT */
[data-theme="light"] .text-forma-bone\/70 {
  color: rgba(26, 26, 26, 0.7);
}

/* REPLACE WITH */
[data-theme="light"] .text-forma-bone\/70 {
  color: rgba(26, 26, 26, 0.80);
}
```

#### Change 3: Update Light Mode Variables (Lines 33-35)

```css
/* CURRENT */
[data-theme="light"] {
  --bg-primary: #F8F9FA;
  --text-primary: #1A1A1A;
  --text-muted: rgba(26, 26, 26, 0.6);
  /* ... */
}

/* REPLACE WITH */
[data-theme="light"] {
  --bg-primary: #F8F9FA;
  --text-primary: #1A1A1A;
  --text-muted: rgba(26, 26, 26, 0.75);
  /* ... */
}
```

---

## 🔴 CRITICAL FIX #2: Add Skip Link

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/app/layout.tsx`

#### Change: Update body element (Lines 40-42)

```tsx
/* CURRENT */
<body className="min-h-screen gradient-bg noise-overlay">
  <ThemeProvider>{children}</ThemeProvider>
</body>

/* REPLACE WITH */
<body className="min-h-screen gradient-bg noise-overlay">
  <a
    href="#main-content"
    className="skip-link"
  >
    Skip to main content
  </a>
  <ThemeProvider>{children}</ThemeProvider>
</body>
```

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/app/page.tsx`

#### Change: Add ID to main element (Line 19)

```tsx
/* CURRENT */
<main className="relative">

/* REPLACE WITH */
<main id="main-content" className="relative">
```

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/app/globals.css`

#### Change: Add skip link styles (After line 754)

```css
/* Add this new section */

/* ========================================
   ACCESSIBILITY: Skip Link
   ======================================== */

.skip-link {
  position: absolute;
  top: -100px;
  left: 0;
  z-index: 9999;
  padding: 1rem 1.5rem;
  background: var(--forma-steel-blue);
  color: var(--forma-bone);
  text-decoration: none;
  font-weight: 600;
  font-family: var(--font-display);
  border-radius: 0 0 0.5rem 0;
  transition: top 0.2s;
}

.skip-link:focus {
  top: 0;
  outline: 3px solid var(--forma-sage);
  outline-offset: 2px;
}

/* Light mode skip link */
[data-theme="light"] .skip-link {
  background: var(--forma-steel-blue);
  color: #FFFFFF;
}
```

---

## 🔴 CRITICAL FIX #3: ARIA Labels for Icon Buttons

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/components/Navigation.tsx`

#### Change 1: Mobile Menu Button (Lines 112-117)

```tsx
/* CURRENT */
<button
  onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
  className="md:hidden p-2 text-forma-bone"
>
  {mobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
</button>

/* REPLACE WITH */
<button
  onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
  className="md:hidden p-3 text-forma-bone"
  aria-label={mobileMenuOpen ? "Close menu" : "Open menu"}
  aria-expanded={mobileMenuOpen}
>
  {mobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
</button>
```

#### Change 2: Theme Toggle Button - Increase Touch Target (Line 87-105)

```tsx
/* CURRENT */
<motion.button
  onClick={toggleTheme}
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  className="p-2.5 rounded-xl glass-card text-forma-bone/70 hover:text-forma-bone transition-colors"
  aria-label="Toggle theme"
>

/* REPLACE WITH (change p-2.5 to p-3) */
<motion.button
  onClick={toggleTheme}
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.95 }}
  className="p-3 rounded-xl glass-card text-forma-bone/70 hover:text-forma-bone transition-colors"
  aria-label="Toggle theme"
>
```

#### Change 3: Logo Link with SVG (Lines 51-69)

```tsx
/* CURRENT */
<a href="#" className="flex items-center gap-3 group">
  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-forma-steel-blue to-forma-sage flex items-center justify-center shadow-lg group-hover:shadow-glow-blue transition-shadow duration-300">
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className="w-6 h-6"
      stroke="currentColor"
      strokeWidth="2"
    >
      <path
        d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
        className="fill-forma-bone/20"
      />
    </svg>
  </div>
  <span className="font-display font-bold text-xl text-forma-bone">
    Forma
  </span>
</a>

/* REPLACE WITH */
<a href="#" className="flex items-center gap-3 group" aria-label="Forma - Go to homepage">
  <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-forma-steel-blue to-forma-sage flex items-center justify-center shadow-lg group-hover:shadow-glow-blue transition-shadow duration-300">
    <svg
      viewBox="0 0 24 24"
      fill="none"
      className="w-6 h-6"
      stroke="currentColor"
      strokeWidth="2"
      role="img"
      aria-hidden="true"
    >
      <path
        d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
        className="fill-forma-bone/20"
      />
    </svg>
  </div>
  <span className="font-display font-bold text-xl text-forma-bone">
    Forma
  </span>
</a>
```

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/components/FAQ.tsx`

#### Change: FAQ Accordion Buttons (Line 70-88)

```tsx
/* CURRENT */
<button
  onClick={onToggle}
  className="w-full py-6 flex items-start justify-between gap-4 text-left group"
>
  <span className="font-display font-medium text-lg text-forma-bone group-hover:text-forma-steel-blue transition-colors">
    {faq.question}
  </span>
  <div
    className={`w-8 h-8 rounded-full glass-card flex items-center justify-center shrink-0 transition-all duration-300 ${
      isOpen ? "bg-forma-steel-blue/20 rotate-180" : ""
    }`}
  >
    {isOpen ? (
      <Minus className="w-4 h-4 text-forma-steel-blue" />
    ) : (
      <Plus className="w-4 h-4 text-forma-bone/60" />
    )}
  </div>
</button>

/* REPLACE WITH */
<button
  onClick={onToggle}
  className="w-full py-6 flex items-start justify-between gap-4 text-left group"
  aria-expanded={isOpen}
  aria-controls={`faq-answer-${index}`}
>
  <span className="font-display font-medium text-lg text-forma-bone group-hover:text-forma-steel-blue transition-colors">
    {faq.question}
  </span>
  <div
    className={`w-8 h-8 rounded-full glass-card flex items-center justify-center shrink-0 transition-all duration-300 ${
      isOpen ? "bg-forma-steel-blue/20 rotate-180" : ""
    }`}
    aria-hidden="true"
  >
    {isOpen ? (
      <Minus className="w-4 h-4 text-forma-steel-blue" />
    ) : (
      <Plus className="w-4 h-4 text-forma-bone/60" />
    )}
  </div>
</button>

/* Also update the AnimatePresence section (Lines 90-104) */
<AnimatePresence initial={false}>
  {isOpen && (
    <motion.div
      id={`faq-answer-${index}`}
      role="region"
      initial={{ height: 0, opacity: 0 }}
      animate={{ height: "auto", opacity: 1 }}
      exit={{ height: 0, opacity: 0 }}
      transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
      className="overflow-hidden"
    >
      <p className="pb-6 text-forma-bone/60 leading-relaxed pr-12">
        {faq.answer}
      </p>
    </motion.div>
  )}
</AnimatePresence>
```

---

## 🔴 CRITICAL FIX #4: Prefers-Reduced-Motion Support

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/app/globals.css`

#### Change: Add media query (After line 754)

```css
/* Add this new section */

/* ========================================
   ACCESSIBILITY: Reduced Motion Support
   ======================================== */

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }

  /* Disable decorative floating animations */
  .orb {
    animation: none !important;
    opacity: 0.2 !important;
  }

  .gradient-bg {
    animation: none !important;
    background-size: 100% 100%;
  }

  /* Disable all decorative movement animations */
  .animate-float,
  .animate-float-slow,
  .animate-float-slower,
  .animate-float-subtle,
  .animate-pulse-glow,
  .animate-shimmer,
  .animate-bounce-subtle,
  .animate-spin-slow,
  .animate-scale-pulse {
    animation: none !important;
  }

  /* Keep opacity transitions for UI feedback */
  button,
  a,
  input,
  [role="button"] {
    transition-property: opacity, background-color, color, border-color !important;
    transition-duration: 0.15s !important;
  }
}
```

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/components/Hero.tsx`

#### Change: Use reduced motion hook (Lines 1-6 and 28-58)

```tsx
/* Add import at top (after line 5) */
import { useReducedMotion } from "@/hooks/useReducedMotion";

/* Add inside Hero component (after line 30) */
const prefersReducedMotion = useReducedMotion();

/* Update useEffect for animation cycle (Lines 33-58) */
useEffect(() => {
  // If user prefers reduced motion, show final organized state
  if (prefersReducedMotion) {
    setAnimationPhase("organized");
    return;
  }

  const phases = [
    { phase: "scattered" as const, duration: 2000 },
    { phase: "scanning" as const, duration: 1500 },
    { phase: "organizing" as const, duration: 2000 },
    { phase: "organized" as const, duration: 3000 },
  ];

  let currentIndex = 0;
  let timeout: NodeJS.Timeout;

  const runPhase = () => {
    setAnimationPhase(phases[currentIndex].phase);
    timeout = setTimeout(() => {
      currentIndex = (currentIndex + 1) % phases.length;
      if (currentIndex === 0) {
        setCycleCount((c) => c + 1);
      }
      runPhase();
    }, phases[currentIndex].duration);
  };

  runPhase();

  return () => clearTimeout(timeout);
}, [prefersReducedMotion]);
```

---

## 🔴 CRITICAL FIX #5: Enhanced Focus Indicators

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/app/globals.css`

#### Change: Add focus styles (After line 754)

```css
/* Add this new section */

/* ========================================
   ACCESSIBILITY: Focus Indicators
   ======================================== */

/* Enhanced focus indicators for keyboard navigation */
*:focus-visible {
  outline: 2px solid var(--forma-steel-blue);
  outline-offset: 2px;
  transition: outline-offset 0.15s ease;
}

/* Light mode focus */
[data-theme="light"] *:focus-visible {
  outline-color: var(--forma-steel-blue);
}

/* Button focus styles */
.btn-primary:focus-visible {
  outline: 3px solid var(--forma-sage);
  outline-offset: 4px;
}

.btn-secondary:focus-visible {
  outline: 2px solid var(--forma-steel-blue);
  outline-offset: 4px;
  background: rgba(255, 255, 255, 0.15);
}

[data-theme="light"] .btn-secondary:focus-visible {
  background: rgba(0, 0, 0, 0.08);
}

/* Navigation link focus */
nav a:focus-visible {
  outline: 2px solid var(--forma-steel-blue);
  outline-offset: 4px;
  border-radius: 4px;
}

/* Glass card interactive elements */
.glass-card:focus-visible,
.glass-card-strong:focus-visible {
  outline: 2px solid var(--forma-steel-blue);
  outline-offset: 3px;
}

/* Remove default focus for mouse users, keep for keyboard */
*:focus:not(:focus-visible) {
  outline: none;
}

/* Input and form element focus */
input:focus-visible,
textarea:focus-visible,
select:focus-visible {
  outline: 2px solid var(--forma-steel-blue);
  outline-offset: 2px;
  border-color: var(--forma-steel-blue);
}
```

---

## ⚠️ HIGH PRIORITY FIX #6: Pricing Button Accessibility

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/components/Pricing.tsx`

#### Change: Add proper button semantics (Line 128-136)

```tsx
/* CURRENT */
<button
  className={`w-full py-3 px-6 rounded-xl font-display font-medium transition-all duration-300 ${
    plan.highlighted
      ? "btn-primary text-forma-bone"
      : "btn-secondary text-forma-bone"
  }`}
>
  {plan.cta}
</button>

/* REPLACE WITH */
<a
  href="#download"
  role="button"
  className={`w-full py-3 px-6 rounded-xl font-display font-medium transition-all duration-300 text-center inline-block ${
    plan.highlighted
      ? "btn-primary text-forma-bone"
      : "btn-secondary text-forma-bone"
  }`}
  aria-label={`${plan.cta} - ${plan.name} plan for ${plan.price}${plan.period}`}
>
  {plan.cta}
</a>
```

---

## ⚠️ HIGH PRIORITY FIX #7: Download CTA Buttons

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/components/DownloadCTA.tsx`

#### Change: Add descriptive labels (Lines 72-98)

```tsx
/* CURRENT download button (line 72) */
<motion.a
  href="#"
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.98 }}
  className="group relative overflow-hidden"
>

/* REPLACE WITH */
<motion.a
  href="#"
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.98 }}
  className="group relative overflow-hidden"
  aria-label="Download Forma for macOS - Free download"
>

/* CURRENT pricing button (line 91) */
<motion.a
  href="#pricing"
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.98 }}
  className="btn-secondary text-forma-bone px-8 py-4"
>
  View Pricing
</motion.a>

/* REPLACE WITH */
<motion.a
  href="#pricing"
  whileHover={{ scale: 1.05 }}
  whileTap={{ scale: 0.98 }}
  className="btn-secondary text-forma-bone px-8 py-4"
  aria-label="View pricing plans"
>
  View Pricing
</motion.a>
```

---

## 📋 MODERATE PRIORITY FIX #8: Footer SVG Icons

### File: `/Users/jamesfarmer/Application Prototype/Forma/website/src/components/Footer.tsx`

#### Change: Logo SVG (Lines 43-57)

```tsx
/* CURRENT */
<div className="w-10 h-10 rounded-xl bg-gradient-to-br from-forma-steel-blue to-forma-sage flex items-center justify-center">
  <svg
    viewBox="0 0 24 24"
    fill="none"
    className="w-6 h-6"
    stroke="currentColor"
    strokeWidth="2"
  >
    <path
      d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
      className="fill-forma-bone/20"
    />
  </svg>
</div>

/* REPLACE WITH */
<div className="w-10 h-10 rounded-xl bg-gradient-to-br from-forma-steel-blue to-forma-sage flex items-center justify-center">
  <svg
    viewBox="0 0 24 24"
    fill="none"
    className="w-6 h-6"
    stroke="currentColor"
    strokeWidth="2"
    role="img"
    aria-hidden="true"
  >
    <path
      d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z"
      className="fill-forma-bone/20"
    />
  </svg>
</div>
```

---

## ✅ VERIFICATION CHECKLIST

After implementing all fixes, verify:

- [ ] Color contrast: Use Chrome DevTools Accessibility panel
- [ ] Skip link: Press Tab on page load, verify link appears
- [ ] ARIA labels: Use screen reader to test all buttons
- [ ] Reduced motion: Enable in System Preferences, reload page
- [ ] Focus indicators: Tab through page, verify all elements show focus
- [ ] Touch targets: Use mobile device or responsive mode
- [ ] SVG titles: Use screen reader to verify icon descriptions
- [ ] Keyboard navigation: Navigate entire site without mouse
- [ ] Zoom to 200%: Verify no horizontal scroll
- [ ] Run axe DevTools: Should show 0 critical issues

---

## 🚀 DEPLOYMENT STEPS

1. Create feature branch: `git checkout -b accessibility-wcag-aa`
2. Apply all fixes from this document
3. Test locally with screen reader and keyboard
4. Run automated testing: `npm run test:a11y` (if configured)
5. Create pull request with accessibility checklist
6. Review with accessibility team member
7. Deploy to staging for final testing
8. Deploy to production

---

## 📚 ADDITIONAL FILES CREATED

1. `/Users/jamesfarmer/Application Prototype/Forma/website/src/hooks/useReducedMotion.ts` - Motion preference hook
2. This file: `ACCESSIBILITY_FIXES.md` - Implementation guide
3. `ACCESSIBILITY_AUDIT.md` - Full audit report

All files are ready to use and implement.
