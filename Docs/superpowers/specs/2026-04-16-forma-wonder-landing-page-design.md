# Forma Wonder Landing Page Design

**Date:** 2026-04-16

## Goal

Design a full landing page in Wonder for Forma that optimizes for direct Mac App Store download.

The page should be aimed at overwhelmed, skeptical Mac users who have already been burned by file organizers or automation they could not see or reverse.

The finished artboard should:

- make the target user feel understood within the first screen
- present Forma as trustworthy before presenting it as powerful
- show concrete relief from file clutter rather than generic software polish
- drive one clear action: download Forma from the Mac App Store

## Context

- Forma's core differentiator is trust, not raw automation or AI novelty.
- The brand voice explicitly avoids vague productivity language and leads with empathy, specificity, and reversibility.
- The existing marketing site already uses the strongest core positioning line:
  `A file organizer for people who gave up on file organizers.`
- The user requested that this work be done as a Wonder design/artboard rather than in the `forma-website/` codebase.
- The user explicitly asked to use the taste skill, which means the page should avoid generic startup landing-page patterns and lean into a deliberate, high-signal visual system.

Relevant references:

- `BRAND_VOICE.md`
- `forma-website/src/app/page.tsx`
- `forma-website/src/app/globals.css`
- `forma-website/REVIEW_UX.md`

## Problem Statement

The landing page cannot behave like a generic SaaS page.

That would fail for two reasons:

1. Forma's audience is skeptical. Generic "productivity" or "smart automation" framing lowers trust instead of raising it.
2. Forma's value is emotional before it is technical. Users need to feel that the product understands their anxiety around file clutter and opaque automation before they will care about feature depth.

The design problem is therefore not "make a polished homepage."

It is:

- acknowledge the user's mess without patronizing them
- show visible relief quickly
- explain the trust model with minimal cognitive load
- make the download CTA feel calm and credible rather than salesy

## Approved Direction

The approved direction is:

- visual concept: `C. Empathy Split`
- page scope: `Full`
- structure: `Problem -> Proof -> Process -> Features -> FAQ -> CTA`

This is the chosen direction because it best fits the brand voice and gives the Wonder artboard a clear persuasion arc for skeptical users:

1. recognize the user's reality
2. show the transformation from mess to order
3. explain why the workflow is safe
4. support the claim with concrete feature proof
5. answer anxious objections
6. close with a clear Mac App Store download action

## Considered Approaches

### 1. Problem -> Proof -> Process -> Features -> FAQ -> CTA

Lead with the user's pain, immediately visualize the before/after transformation, then explain the trust model.

Why this is chosen:

- strongest match for the target user's mindset
- creates an emotional hook before the product explanation
- gives the page a clear non-generic narrative shape
- supports direct conversion without needing aggressive sales language

### 2. Product -> Trust -> Transformation -> Features -> FAQ -> CTA

Lead with the product window more aggressively, then explain trust and show transformation later.

Why not:

- visually cleaner, but less emotionally sharp
- risks feeling more product-led than user-led
- weaker fit for users who already distrust file organizers

### 3. Story-scroll editorial sequence

Turn the page into a more sequential storytelling composition with stronger scroll-based pacing.

Why not:

- stronger stylistic risk with less scanability
- over-relies on pacing rather than clear section utility
- introduces more complexity than needed for a trust-first download page

## Artboard Scope

This design is for one full landing page artboard in Wonder.

It should include:

- a hero with product window
- a before/after transformation section
- a three-step trust flow
- feature proof blocks
- FAQ / objection handling
- a closing App Store CTA section

It should not include:

- blog content
- waitlist capture
- newsletter signup
- pricing comparisons
- multi-page navigation concepts
- alternative funnel variants in the same artboard

## Page Architecture

### 1. Hero

Purpose:
Make the user feel seen immediately, establish the product promise, and present the primary download CTA.

Required content:

- eyebrow: `For the perpetually messy`
- headline: `A file organizer for people who gave up on file organizers.`
- subcopy focused on:
  - plain-English rules
  - preview before anything moves
  - undo if something was wrong
- primary CTA: `Get Forma for Mac`
- price note directly associated with the CTA:
  `$29 once. No subscription. No account. Just a Mac app.`

Hero layout rules:

- left-aligned copy, not centered
- product window as the dominant visual object on the right
- one primary CTA style only
- no secondary CTA that competes with download

### 2. Proof: Mess to Order

Purpose:
Show relief visually, not abstractly.

The section should depict messy file reality on one side and a clean, categorized after-state on the other.

Design rules:

- use realistic messy-file cues
- make the transformation readable at a glance
- avoid abstract "workflow diagram" energy
- prioritize emotional recognition over technical explanation

This section exists to say:
`Yes, this page understands the exact kind of mess you are dealing with.`

### 3. Process: Trust Flow

Purpose:
Explain why Forma feels safer than other file organizers.

This section uses the approved three-step model:

1. `Write a rule`
2. `Preview the batch`
3. `Undo the batch`

Each step should have one short explanatory sentence.

The section should feel instructional without becoming manual-like.

Trust signals should be integrated nearby, such as:

- everything stays on your Mac
- no account required
- no silent background surprises

### 4. Feature Proof

Purpose:
Support the trust model with concrete capability blocks.

Approved feature themes:

- `Tell it what to do in plain English`
- `See every move before it happens`
- `Undo the recent batch if something was wrong`
- `Everything stays on your Mac`

Section rules:

- keep examples concrete, not abstract
- avoid "smart" prefixes and AI-magic framing
- show the product as understandable and inspectable
- present the features as proof of trust, not as a feature checklist

### 5. FAQ

Purpose:
Answer the user's anxious objections directly.

Approved question direction:

- `Will it delete my files?`
- `Does anything leave my Mac?`
- `Do I need to keep it running in the background?`
- `Why would I trust this over other file organizers?`

Tone rules:

- direct, short, calm
- no evasive legalese
- no defensive over-explanation

### 6. Closing CTA

Purpose:
Close the page calmly with one final download decision point.

Suggested supporting line:
`Your files are not going to organize themselves. Forma can help.`

Required behavior:

- repeat the Mac App Store action clearly
- keep the one-time pricing visible
- do not add extra asks, forms, or distractions

## Visual System

### Chosen Mood

The page should feel like a warm editorial utility page.

It should be:

- light, calm, and premium
- grounded and trustworthy
- emotionally direct
- intentionally designed rather than flashy

It should not feel:

- like a dark startup SaaS page
- like a futuristic AI product launch
- like a playful consumer app
- like a sterile enterprise page

### Color Direction

Use a warm light base rather than a dark glass-heavy shell.

Recommended palette behavior:

- warm bone / paper-toned background
- obsidian or deep ink text
- restrained steel-blue and sage accents
- warm orange only as a supporting accent, not a dominant brand field

Color rules:

- one coherent palette across the artboard
- no purple bias
- no neon glows
- no shifting between multiple visual temperatures

### Typography

Typography should be assertive and editorial, but still software-adjacent.

Rules:

- strong left-aligned hierarchy
- large, tight headline setting
- compact supporting copy
- uppercase eyebrow and trust labels used sparingly
- no serif treatment for the core product story

### Surface Language

Surfaces should feel refined but not precious.

Use:

- rounded large containers
- subtle border definition
- soft depth
- layered panels where hierarchy matters

Avoid:

- card spam
- heavy boxed sections everywhere
- loud shadows
- frosted-glass-overload

### Motion and Interaction

This is a Wonder artboard, so the visual design should imply restrained motion rather than depend on complex animation.

Design as if the page could support:

- soft reveals
- slight stagger between sections
- minimal CTA polish

Do not design around:

- dramatic parallax
- scroll gimmicks
- elaborate 3D movement
- hyperactive product-demo choreography

## Copy System

### Voice Rules

The page copy must follow these rules:

- empathetic before promotional
- specific before aspirational
- blunt before clever
- trust-first before capability-first

Avoid:

- `streamline`
- `boost productivity`
- `smart rules`
- `powerful automation`
- `AI magic`
- generic lifestyle claims

### Hero Copy Direction

The hero should preserve the existing strongest positioning line and keep the supporting copy tightly tied to the three-step trust model.

The hero's job is not to explain everything.

Its job is to say:

- this is for your kind of mess
- it works in plain language
- you stay in control
- here is the download button

### Proof and Feature Copy Direction

The supporting sections should use recognizable examples and grounded outcomes.

Good:

- examples involving screenshots, invoices, downloads, and familiar clutter
- language that admits the user has tried before
- phrasing that makes preview and undo feel central

Bad:

- abstract promises about organization
- corporate feature naming
- overly technical rule-engine language

### Closing Tone

The close should be calm and slightly wry, not hyped.

The user should feel nudged, not pushed.

## Wonder Execution Notes

The Wonder artboard should be built as one composed landing-page design, not as disconnected blocks.

Execution priorities:

1. get the hero and proof sections visually right first
2. keep the trust flow legible and compact
3. make the CTA hierarchy unambiguous
4. preserve enough whitespace so the page does not feel like a feature wall

Wonder-specific composition expectations:

- maintain a strong top-of-page composition with headline on the left and product visual on the right
- keep section transitions visually related through spacing and shared palette
- use the proof section as the emotional hinge of the page
- keep the closing CTA distinct from the hero while staying in the same visual family

## Non-Goals

This pass does not:

- redesign the live `forma-website/` implementation
- create responsive production code
- define animation engineering details
- produce multiple variant artboards
- introduce a waitlist or alternate conversion funnel

## Validation

The Wonder artboard should be considered successful if it meets these checks:

- the first screen immediately communicates who Forma is for
- the download CTA is visually dominant and unmistakable
- the page clearly explains why Forma is safer than other file organizers
- the design feels specific to Forma rather than interchangeable with another SaaS brand
- the copy stays aligned with the approved brand voice
- the full page supports scanning without losing emotional clarity

## Approved Decisions Summary

The following decisions were explicitly approved during brainstorming:

- surface: Wonder design/artboard
- conversion goal: direct Mac App Store download
- audience: overwhelmed, skeptical Mac users burned by prior file organizers
- visual direction: `C. Empathy Split`
- scope: `Full`
- structure: `Problem -> Proof -> Process -> Features -> FAQ -> CTA`
- visual system: warm light, left-aligned, trust-first, concrete product proof
- content direction: blunt, empathetic, trust-forward, no generic productivity language
