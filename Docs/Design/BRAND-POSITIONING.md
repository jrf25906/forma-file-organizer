# Forma — Brand Positioning

**Version:** 1.0
**Last Updated:** January 2025
**Status:** Strategic Foundation

This document defines Forma's core positioning and messaging strategy. All brand documents, marketing copy, and product communication should align with these principles.

---

## Core Positioning

### The Central Reframe: Structural, Not Smart

Forma is positioned as **structural**, not **intelligent**.

Users don't ask: "Is this smart?"
They ask: "Where does this sit in my system?"

**Forma is:**
- A **system layer** on top of Finder, not a replacement
- An **executor of intent**, not an autonomous actor
- A **bounded tool**, not a magical one

**Forma is NOT:**
- An AI that "understands" your files
- An autonomous organizer that acts on its own
- A replacement for your file system

---

## The Trust Model

Users treat their file system like a bank vault. Trust is the foundation.

### Winning Posture

> You give the orders. Forma executes them — and only after you approve.

### Trust Hierarchy (in messaging order)

1. **You approve. It executes.** — Nothing moves without your explicit approval
2. **Undo everything. Always.** — Full reversibility, complete action history
3. **Declarative rules.** — You define the logic in plain language
4. **Context awareness.** — Forma infers structure but never assumes

Lead with control. Follow with capability.

---

## Language Guidelines

### Avoid "Ghost of AI" Language

These phrases signal latency, chat interfaces, and probabilistic behavior:

| Avoid | Use Instead |
|-------|-------------|
| "Talk to it like a human" | "Declarative rules" or "Intent-based commands" |
| "AI-powered organization" | "Rule-based organization" |
| "Smart suggestions" | "Pattern-matched suggestions" |
| "Learns your preferences" | "Adapts to your corrections" |
| "Understands your files" | "Infers structure from patterns" |

### Make "Context" Legible

When describing how Forma understands file context, be specific:

> Forma infers structure using file extensions, naming patterns, dates, and sizes. You can correct a suggestion once — Forma adapts future suggestions based on your behavior.

Never imply opaque AI autonomy.

### Replace Absolutes with Capabilities

| Avoid | Use Instead |
|-------|-------------|
| "Never lose anything again" | "Full action history with one-click rollback" |
| "Zero files lost. Ever." | "Preview every change before it happens" |
| "Always organizes perfectly" | "Suggests destinations based on your rules" |

Specificity builds trust. Slogans don't.

---

## Architectural Clarity

The site and product must explicitly answer: **Is Forma a layer or a replacement?**

### The Answer (communicate visually and verbally)

```
┌─────────────────────────────────────┐
│           Your Intent               │
│    (Rules you define in plain       │
│         language)                   │
└─────────────────┬───────────────────┘
                  ▼
┌─────────────────────────────────────┐
│         Forma Layer                 │
│   • Proposes changes               │
│   • Shows preview                  │
│   • Waits for approval             │
│   • Maintains undo history         │
└─────────────────┬───────────────────┘
                  ▼
┌─────────────────────────────────────┐
│        macOS File System            │
│   (Native APIs, direct moves,       │
│    every action reversible)         │
└─────────────────────────────────────┘
```

Forma uses native macOS file APIs to organize your files directly — but only after you preview and approve each action. Every move is recorded and reversible.

---

## Persona Strategy

### Target Behavior, Not Job Titles

**Instead of:**
> Built for creative professionals who refuse chaos.

**Use:**
> Built for people whose files outgrow folders — where screenshots, documents, assets, and ideas pile up faster than folders can handle.

### The Unifying Thread

The unifying thread is not profession, but *care*: people who take their work seriously and expect their tools to do the same.

### Example Personas (behavior-based)

- People whose Downloads folder decides their productivity
- Founders with 14 pitch decks and no canonical version
- Researchers buried in PDFs, screenshots, and exports
- Anyone who's ever named a file `Final_v2_edit_FINAL_FOR-REAL.mov`

---

## Comparison Positioning

Position Forma in the "Goldilocks zone" without snark:

| Approach | Limitation |
|----------|------------|
| **Folders** | Manual, brittle, require constant maintenance |
| **Tags** | Powerful, but depend on perfect human discipline |
| **Hazel / Scripts** | Flexible, but fragile and intimidating |
| **Raycast** | Powerful launcher, but not persistent organization |
| **Forma** | Declarative rules, preview-first execution, full reversibility |

No dunking. Just clarity.

---

## Value Pillars (with specifics)

Be concrete, not sloganeering:

| Pillar | Proof |
|--------|-------|
| **Mac-native** | Uses native file APIs. No Electron. |
| **Private** | On-device processing. Files never leave your Mac. |
| **Fast** | Launches and previews in milliseconds on Apple Silicon. |
| **Reversible** | Full action history with one-click rollback. |
| **Transparent** | Preview every change before it happens. |

---

## Visual Hierarchy Guidance

For website and marketing materials:

### Needs More Visual Weight

1. **Undo / Reversibility** — Should interrupt the scroll
2. **Preview Queue / Approval State** — Treat as a control panel, not a feature callout
3. **Architecture Diagram** — Show the layer model prominently

### Needs Less Visual Weight

- Taglines and aspirational copy
- Repeated benefit cards
- Vanity stats

Safety is not a feature. It is the foundation. The visual system should reflect that.

---

## Show the Ugly Reality

Perfect files imply shallow value. Show Forma handling real messes:

**Example transformations:**
- `Final_v2_edit_FINAL_FOR-REAL.mov` → `ClientName_Deliverable_2024-03.mov`
- `Screenshot 2024-11-01 at 9.23.45 AM.png` → `Screenshots/2024-11/screen-capture-01.png`
- `IMG_4521.jpg` through `IMG_4589.jpg` → `Photos/2024-11-Trip/`

This is proof of necessity.

---

## Constrained Automation Philosophy

Forma explicitly embraces limits. These principles should be visible in product and marketing:

1. **Automation must be reversible** — Every action can be undone
2. **Intelligence must be inspectable** — Users can see why Forma suggests what it does
3. **Files remain yours** — Local processing, no cloud, no telemetry on file contents

Boundaries increase trust.

---

## Canonical Narrative

Use this as the foundation for all messaging:

> Forma is a system layer for macOS files.
>
> It builds a private, on-device index and lets you issue declarative commands.
> Nothing moves without preview.
> Everything can be undone.
>
> Forma does not organize your life.
> **It executes your intent — safely.**

---

## CTA Consistency

Use consistent CTAs throughout all materials:

| Context | Primary CTA | Secondary CTA |
|---------|-------------|---------------|
| Hero | Join the beta | Watch a 30-second demo |
| Mid-page | Join the beta | See how it works |
| Footer | Join the beta | — |
| In-app | Organize now | Review first |

---

## Document Hierarchy

This positioning document is the **source of truth** for messaging strategy. Other documents implement these principles:

| Document | Purpose |
|----------|---------|
| **BRAND-POSITIONING.md** (this) | Strategic messaging foundation |
| **BRAND-OVERVIEW.md** | Quick reference for developers/designers |
| **Forma-Brand-Guidelines.md** | Comprehensive implementation guide |
| **Forma-App-Store-Description.md** | App Store copy |
| **Forma-Onboarding-Flow.md** | In-app copy and flows |

When conflicts arise, defer to this document.

---

## Summary: The Shift

| From | To |
|------|-----|
| Intelligent | Structural |
| Smart | Precise |
| AI-powered | Rule-based |
| Autonomous | Executor of intent |
| Magic | Transparent |
| Absolutes | Specific capabilities |
| Job titles | Behavior patterns |
| Features first | Trust first |

Forma's opportunity is not louder marketing. It is **structural inevitability**.

When users understand exactly where Forma lives in their system, belief follows.
