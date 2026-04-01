# Forma — Brand Positioning

**Version:** 1.1
**Last Updated:** February 2026
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
2. **Undo the recent batch when needed.** — Recent move history for when something was wrong
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

### Primary Audience: The Perpetually Messy

The biggest audience is people who accumulate files faster than any system can contain — often those with ADHD or executive function challenges. They know their desktop is a mess, they feel guilty about it, they've tried solutions that were too complex or required too much upkeep. They need something that works without constant maintenance.

### The Unifying Thread

The unifying thread is not profession or diagnosis, but *overwhelm*: people whose files outpace their ability to organize, who want a tool that works with their brain instead of demanding a brain they don't have.

### Example Personas (behavior-based)

- People with ADHD whose desktop has 400 screenshots and growing
- People whose Downloads folder decides their productivity
- Founders with 14 pitch decks and no canonical version
- Researchers buried in PDFs, screenshots, and exports
- Anyone who's ever named a file `Final_v2_edit_FINAL_FOR-REAL.mov`
- Anyone who periodically rage-cleans their desktop, then repeats the cycle

### ADHD/Executive Function Discoverability

ADHD-related language appears in discovery layers (meta keywords, structured data, llms.txt, product API) but not in visible page copy. The reasoning: "for the perpetually messy" resonates with the ADHD experience without labeling or being reductive. Someone searching "adhd file organizer mac" finds Forma; someone landing on the homepage feels seen without being categorized.

**Discovery keywords:** adhd file organization, adhd desktop clutter, file organizer for adhd, adhd productivity mac, executive function file management

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
| **Mac-native** | Fast and lightweight — built natively for macOS. *(Use "No Electron" only for technical audiences.)* |
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

## Website Messaging Decisions (February 2026)

These decisions apply to `forma-website` marketing copy. They represent deliberate departures from generic brand language for conversion purposes.

### Tagline Split
- **Brand tagline** ("Give your files form") remains for in-app, packaging, and existing-user contexts.
- **Website tagline** ("A file organizer that actually sticks") targets cold traffic who need the value proposition upfront.
- **OG/social headline** ("A file organizer for people who gave up on file organizers") targets the highest-intent audience segment.

### "Rules That Read Like Sentences" (not "Natural Language Rules")
The website feature was renamed from "Natural Language Rules" to "Rules That Read Like Sentences." Rationale: Forma uses condition-based rules (if filename contains X, move to Y), not natural language processing or AI. "Natural Language Rules" overpromises and triggers the same AI skepticism the brand positioning explicitly avoids. The new name is honest — the rules *read* like sentences, but they're structured conditions.

### Competitive Positioning Angle
Features intro now leads with: "Most file organizers run in the background and hope for the best. Forma shows you what it's about to do." This positions Forma's preview-first workflow as the key differentiator against the competitive field, rather than listing features in isolation.

### "Built natively for macOS" (not "No Electron")
"Not another Electron wrapper" and "Native Swift app" were replaced with user-facing benefit language. "No Electron" is meaningless to most users and reads as developer in-group signaling. Reserve "No Electron" for technical audiences (Hacker News, developer press). General audiences get: "Fast and lightweight — built natively for macOS 15+."

### Website Voice Direction (March 2026)
Website copy was rewritten for a unified voice: **warm, self-aware, lightly funny**. The humor comes from recognition — the reader sees themselves in the copy — not from jokes or puns. Key principles:
- Each section advances one argument (no repeating "preview before action" across sections)
- Copy talks *to* the user, not *about* the product ("Your desktop has 400 screenshots on it right now")
- Self-aware humor normalizes the mess rather than shaming it ("past-you was wrong", "Don't look. Just write a rule.")
- The tornado background visual is echoed by the hero subheadline ("Your files are already out of control") — the visual shows the problem, the words name the resolution

### Hero Eyebrow: "For the perpetually messy"
Replaced "Forma — Preview-first organization" (which read like a category name, not an identity statement). The new eyebrow sets audience identity before the headline confirms it — one-two punch. Echoed in the product API tagline for agent discoverability.

### ADHD/Executive Function SEO Strategy
ADHD-related keywords added to meta keywords, llms.txt, product API tagline, and schema markup. These are discovery-layer only — not in visible copy. The goal: someone asking ChatGPT "what app helps with ADHD file organization" or searching Google for "adhd desktop clutter mac" finds Forma. The visible copy uses language that resonates with the ADHD experience ("perpetually messy", "change your mind", "out of control") without labeling.

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

CTAs are differentiated by context — each location communicates different information:

| Context | Primary CTA | Rationale |
|---------|-------------|-----------|
| Header | Get Forma | Compact, fits nav without competing with page content |
| Hero | Get Forma for Mac | Primary CTA, platform-clear for organic traffic |
| Pricing | Get Forma — $29 | Includes price at the decision point |
| In-app | Organize now | Action-oriented for existing users |

> **Note (Mar 2026):** "Download for Mac" was replaced across all website CTAs. "Get Forma" is ownership-framed rather than action-framed, and differentiating CTAs by context avoids the generic feel of the same button text repeated everywhere.

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
