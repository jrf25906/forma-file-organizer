# Forma Marketing Plan

**Created:** February 9, 2026
**Target App Store Submission:** February 16, 2026
**Status:** Pre-launch

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Competitive Landscape](#2-competitive-landscape)
3. [Positioning & Messaging](#3-positioning--messaging)
4. [Website Fixes (Ship-Blocking)](#4-website-fixes-ship-blocking)
5. [Social Proof Strategy](#5-social-proof-strategy)
6. [Launch Sequence](#6-launch-sequence)
7. [App Store Optimization (ASO)](#7-app-store-optimization-aso)
8. [Content Marketing & SEO](#8-content-marketing--seo)
9. [Press & Media Outreach](#9-press--media-outreach)
10. [Community Building](#10-community-building)
11. [Pricing Strategy](#11-pricing-strategy)
12. [Post-Launch Optimization](#12-post-launch-optimization)
13. [Existing Assets Inventory](#13-existing-assets-inventory)
14. [Gaps & Next Steps](#14-gaps--next-steps)

---

## 1. Current State Assessment

### What Forma Is

Forma is a premium macOS application for intelligent file organization. It helps users organize files from Desktop, Downloads, and other folders using rule-based automation combined with AI/ML learning capabilities.

**Core value proposition:** "You make rules. Forma follows them. Preview what happens, approve it, undo anything."

### Key Differentiators

1. **Preview-first workflow** — nothing moves without explicit approval
2. **Full undo history** — every action is reversible
3. **Rules that read like sentences** — describe rules as readable conditions, no scripting
4. **AI pattern learning** — learns from user behavior, suggests destinations
5. **Personality-based onboarding** — adapts to how users naturally think about organization
6. **7 organization templates** — PARA, Johnny Decimal, Creative Professional, Minimal, Academic, Chronological, Student
7. **100% local processing** — no cloud, no data leaves the Mac
8. **Native macOS** — fast and lightweight, built natively for macOS

### Target Audience

| Segment | Template Match | Key Pain Point |
|---------|---------------|----------------|
| Knowledge workers | PARA Method | Digital clutter reducing productivity |
| Creative professionals | Creative Professional | Client/project file chaos |
| Students | Student | Assignment/class file organization |
| Academics & researchers | Academic & Research | Literature/research file management |
| Power users | Advanced rules + automation | Want Hazel-like power with modern UI |
| Casual users | Minimal | Just want Desktop/Downloads cleaned up |

### App Status

- **Version:** 1.0 (build 1)
- **Platform:** macOS 15.0+
- **Pricing (current plan):** $29 one-time purchase
- **Website:** formafiles.com (Next.js 16, live in production)
- **Marketing docs:** Comprehensive foundation already exists (see Section 13)

---

## 2. Competitive Landscape

### Direct Competitors

| App | Type | Price | Strengths | Weaknesses |
|-----|------|-------|-----------|------------|
| **Hazel** (Noodlesoft) | Rule-based automation | $42 one-time | 15+ year track record, deep rule system, huge community, podcast/blog presence | Learning curve, no AI, dated UI |
| **Sparkle** | AI-powered organizer | $99-179 one-time | Zero-config AI, GPT-4 powered | Expensive, no custom rules, sends filenames to cloud, no user override |
| **Neatify** | Rule-based automation | ~$10-20 | Lightweight, privacy-focused | Smaller community, less powerful |
| **Declutter** | Auto desktop cleaner | Paid | Simple, focused | Limited scope |

### Adjacent Competitors (Finder Replacements)

Commander One, ForkLift, Path Finder, Marta — dual-pane file managers, not automated organizers, but they compete for "better file management" search terms.

### Market Gap

The market has a clear gap that Forma fills:
- **Hazel** = powerful but complex, no AI, dated interface
- **Sparkle** = AI but expensive, no user control, cloud-dependent
- **Nobody** combines rule-based automation + AI intelligence + local processing + modern UI

### How Hazel Markets (The Gold Standard)

Hazel's strategy is entirely product-led growth:
- Exceptional product quality drives word-of-mouth
- Podcast appearances (Mac Power Users, Automators)
- Consistent presence in "essential Mac apps" lists
- Community forums for support and rule sharing
- Organic press coverage (no aggressive marketing)
- Founder Paul Kim: "I've always tried to focus on making a good product."

---

## 3. Positioning & Messaging

### Core Positioning

> "Forma is the intelligent file organizer that combines the power of rules with the ease of AI — all running locally on your Mac."

This directly addresses:
- Hazel users who want AI help without complexity
- Sparkle users who want control and privacy
- Non-technical users who want automation without scripting

### Headline Options (Tested)

| Headline | Angle |
|----------|-------|
| "A file organizer for people who gave up on file organizers." | Empathy / retry |
| "A file organizer that actually sticks." | Website tagline *(brand tagline "Give your files form" used in-app)* |
| "$29. Once. Forever." | Anti-subscription |
| "See before you move. Undo anything. Stay in control." | Safety / trust |

### Key Copy Moments

- "No subscription. No account. No 'premium tiers.'" (anti-SaaS positioning)
- "Fast and lightweight — built natively for macOS" (credibility; use "No Electron" for technical audiences only)
- "Everything runs locally on your Mac" (privacy)
- "Built by someone who got tired of seeing `Screenshot 2024-01-15 at 3.42.17 PM.png` fifty times on their desktop" (founder voice)

### Competitive Framing (Implicit, Not Combative)

- vs. Hazel: "More approachable, with AI assistance"
- vs. Sparkle: "More transparent, more affordable, fully local"
- vs. macOS Automator: "No scripting required"
- vs. doing nothing: "Preview and undo make it safe to experiment"

---

## 4. Website Fixes (Ship-Blocking)

The website (formafiles.com) is built and builds cleanly, but has several issues to fix before launch.

### Critical (Must Fix)

| Issue | Description | Fix |
|-------|-------------|-----|
| **CTA fallback** | If `NEXT_PUBLIC_MAC_APP_STORE_URL` is missing, CTA links should route to a dedicated download/waitlist page instead of support docs | Keep fallback on `/get-forma`, then set production `NEXT_PUBLIC_MAC_APP_STORE_URL` and verify all CTA targets in build preview |
| **No social proof** | Zero testimonials, reviews, press mentions, or user quotes anywhere on the page | Add 2-3 beta tester testimonials (see Section 5) |

### High Priority (Should Fix)

| Issue | Description | Fix |
|-------|-------------|-----|
| **Mobile CTA invisible** | No download button visible after scrolling past hero on mobile (5+ viewports until pricing) | Add compact "Download" button in sticky header on mobile, or floating action button |
| **Animations disabled** | All GSAP scroll animations are built but `enableScrollAnimations = false` across all sections | Enable selectively on Features, Pricing, FAQ sections |
| **Price not in hero** | Visitors don't see the price until deep scroll to Pricing section | Add "$29 once, forever" badge near hero CTA |
| **Only one screenshot** | 6 screenshots exist in `/public/screenshots/` but only hero is used | Add 1-2 more in Features or Pricing sections |
| **No mid-page CTA** | No call-to-action between Features and Pricing sections | Add "Ready to get organized?" prompt between BeforeAfter and Pricing |

### Medium Priority (Nice to Have)

- Move Before/After section before Features to hit empathy earlier
- Add visual differentiation to feature cards (left border stripes or tinted backgrounds)
- Strengthen "See how it works" secondary CTA (currently too subtle)
- Add visual weight to newsletter section
- Fix dark mode CSS (currently disabled; dead CSS could cause issues if toggled)

---

## 5. Social Proof Strategy

This is identified as the **single highest-impact gap** across the entire marketing effort.

### What to Collect

1. **Beta tester quotes** (3-5 minimum for launch)
   - Ask about: fear of file loss → confidence after using preview/undo
   - Ask about: previous tools tried and why Forma was better
   - Ask about: specific time saved or organizational wins

2. **Founder story** (expand beyond footer bio)
   - The footer line "Built by someone who got tired of seeing `Screenshot 2024-01-15 at 3.42.17 PM.png` fifty times on their desktop" is charming — expand into a visible section

3. **App Store ratings** (post-launch)
   - Implement smart in-app review prompts after positive moments (e.g., after first successful organize, after using undo successfully)
   - Target 4.5+ star rating for optimal conversion

### Where to Display

- Website: Testimonials section between Features and Pricing
- App Store: Include 2-3 quotes in description under "WHAT USERS SAY"
- Press kit: Include in `PRESS-KIT.md`

### Example Testimonial Prompts for Beta Testers

- "What were you using before Forma? What made you switch?"
- "What's the one feature that surprised you most?"
- "Would you describe Forma to a friend? How?"

---

## 6. Launch Sequence

### Pre-Launch (Now → Feb 16)

- [x] Capture live App Store listing URL (`id6759181510`) and wire website default CTA target.
- [ ] Set production `NEXT_PUBLIC_MAC_APP_STORE_URL`
- [ ] Collect 3-5 beta tester testimonials
- [ ] Add testimonials to website and App Store description
- [ ] Enable website scroll animations
- [ ] Record demo video (20-30s for App Store, 60-90s for YouTube/website)
- [ ] Finalize App Store screenshots (review current 12, select final 8)
- [ ] Verify formafiles.com/privacy and /terms are live
- [ ] Set up privacy-first analytics dashboard and Search Console reporting
- [ ] Start "build in public" posts on Twitter/X (3-5 per week)
- [ ] Begin engaging in r/macapps, r/macOS, and Hacker News communities
- [ ] Build Product Hunt page (followers before launch day)
- [ ] Prepare email to press contacts with promo codes

### Launch Week Sequence

| Day | Channel | Action |
|-----|---------|--------|
| **Day 1** (Tue/Wed) | **Product Hunt** | Launch with detailed maker comment. Have 20-30 supporters ready to engage organically. Weekend launches need fewer upvotes (~366 vs ~633) if you prefer less competition. |
| **Day 2** | **Hacker News** | `Show HN: Forma – File organizer with preview-first workflow`. Link to app directly (not landing page). Write personal first comment about the "why". Post 9am-12pm Pacific. |
| **Day 3-4** | **Reddit** | Post to r/macapps first, then r/macOS the next day. Use "I built X because..." format. Include screenshot or GIF. Respond to every comment. |
| **Same week** | **Press** | Email pitch to 9to5Mac Indie App Spotlight, MacStories, MacRumors. Include promo codes. |
| **Same week** | **Twitter/X** | Post launch thread (6 tweets, already written in LAUNCH-COPY.md). |
| **Same week** | **LinkedIn** | Post announcement (already written in LAUNCH-COPY.md). |
| **Same week** | **Email** | Send to newsletter/waitlist subscribers. |

### Platform-Specific Tips

**Product Hunt:**
- You get one shot — same product can't be reposted for 6 months
- Build followers on the product page weeks before launch
- Write a detailed maker comment with backstory and technical details
- Engage with every comment throughout the day

**Hacker News:**
- Drop ALL marketing language — factual, direct descriptions only
- Use personal account, not a brand account
- Never ask for upvotes (vote ring detection is excellent)
- If post underperforms, email hn@ycombinator.com for the "second-chance pool"
- Comments are a stronger ranking signal than upvotes — spark discussion

**Reddit:**
- Include a visual (screenshot or video demo) — top-performing posts always have one
- Post one subreddit at a time; iterate based on feedback before posting the next
- Be ready for pricing criticism — Reddit has strong opinions about utility app pricing
- Own your issues publicly; add "Edit:" sections addressing feedback
- If you listen and fix issues, Reddit users will buy and advocate

---

## 7. App Store Optimization (ASO)

### Key Facts

- 70% of App Store visitors use search to find apps
- 65% of downloads happen immediately after a search
- Metadata changes take 8-12 weeks for significant ranking movement
- Start ASO at launch; don't wait

### Current ASO Status

| Field | Limit | Current | Status |
|-------|-------|---------|--------|
| App Name | 30 chars | "Forma: File Organizer" (22) | Done |
| Subtitle | 30 chars | "Give your files form." (21) | Done |
| Description | 4000 chars | ~1800 | Done (3 A/B variants) |
| Keywords | 100 chars | 94 chars | Done |
| Promotional Text | 170 chars | 166 chars | Done |

### Optimization Opportunities

**Keywords** (current: `file organizer,desktop cleaner,macos utility,productivity,automation,declutter,files,organize,finder`):
- Consider adding: `rules`, `sort`, `tidy`, `rename`, `batch`, `cleanup`
- Research Hazel, Neatify, and Sparkle keywords to find gaps
- Revisit quarterly based on search trends

**Screenshots:**
- Current set covers 6 screens (light + dark)
- Consider adding captions/overlay text highlighting benefits
- Tell a visual story: problem (messy desktop) → solution (organized folders)
- Use Apple's Custom Product Pages to A/B test different screenshot sets

**2026 ASO Opportunities:**
- Apple's In-App Events feature for time-limited promotional events
- Custom Product Pages for different audience segments
- Product Page Optimization for A/B testing variants
- Voice search optimization with natural-language keyword phrases
- Generative Engine Optimization (GEO) — make content citable by AI search tools

**Ratings Strategy:**
- Prompt for review after positive moments (successful organize, undo used)
- Respond to every App Store review in App Store Connect
- Target 4.5+ stars

---

## 8. Content Marketing & SEO

### Blog Strategy (formafiles.com/blog)

Blog now exists at `formafiles.com/blog`. Recommended content pillars:

**Pillar 1: File Organization Guides (Top of Funnel)**
- "How to Organize Your Mac Desktop in 2026"
- "The Ultimate Guide to Folder Structures for Creatives, Developers, and Students"
- "10 Signs Your Digital Files Are Out of Control"
- "PARA Method for File Organization on Mac"
- "Johnny Decimal System: A Practical Guide for Mac Users"

**Pillar 2: macOS Productivity (Middle of Funnel)**
- "Hazel vs Forma: Which File Organizer is Right for You?" (comparison content ranks well)
- "How to Automate File Management on macOS Without Scripting"
- "Best macOS Productivity Apps in 2026"

**Pillar 3: Product & Technical (Bottom of Funnel)**
- "How Forma's AI Understands Your Filing Habits"
- "Setting Up Your First Forma Rules in 5 Minutes"
- "How We Built Forma: Local AI on macOS" (also good for Hacker News)

### SEO Priorities

- Target high-intent keywords: "file organizer mac", "organize downloads folder mac", "hazel alternative", "desktop cleanup mac"
- Structure content with clear headings and FAQ sections for AI search tools (GEO)
- Include structured data (JSON-LD) on blog posts
- Author posts as the founder (E-E-A-T: real experience matters)
- Update content regularly — refreshing an article can boost organic traffic 70%+

### Video Content

- **App Store preview:** 20-30s, 1920x1080, H.264 (specs in `PreviewVideo/README.md`)
- **YouTube demo:** 60-90s problem→solution→transformation narrative
- **Tutorial series:** "Setting up rules for screenshots, invoices, and downloads"
- Invest in good audio quality — 94% of customers say video builds purchase confidence

### 2026 Content Trends

- **Original research gets 10x more AI search traffic.** Consider publishing a "State of Digital File Organization" survey.
- **Google still owns 90% of search.** Traditional SEO is the foundation; AI search optimization is additive.
- **E-E-A-T matters more than ever.** Google rewards content from people with real experience.
- **Content freshness drives results.** Keep comparison and guide articles current.

---

## 9. Press & Media Outreach

### Priority Publications

**Tier 1 (Highest Impact — Pitch First)**

| Publication | Why | Angle |
|-------------|-----|-------|
| **9to5Mac** | Runs dedicated "Indie App Spotlight" series for indie devs | Pitch the preview-first workflow as a novel approach |
| **MacStories** | Deep, thoughtful app reviews; annual "MacStories Selects" awards | Pitch the AI + rules combination, personality-based onboarding |
| **MacRumors** | Publishes "10 Mac Apps Worth Trying" roundups with long-lasting SEO value | Pitch for inclusion in next roundup |

**Tier 2 (Strong Reach)**

| Publication | Why |
|-------------|-----|
| **Macworld** | Has reviewed Hazel; publishes in-depth macOS app reviews |
| **The Verge** | Covers notable Mac software with unique technical angles |
| **Ars Technica** | Reaches technically sophisticated macOS users |

**Tier 3 (Niche but Valuable)**

| Publication/Person | Why |
|-------------------|-----|
| **Asian Efficiency** | Productivity blog; Hazel is in their "Top 10 Essential Apps" annually |
| **MacSparky** (David Sparks) | Influential productivity blogger and podcaster |
| **Mac Power Users** (podcast) | Regularly features macOS utility apps |
| **Club MacStories** | Premium newsletter with dedicated app discovery |

**Aggregators:**
- **MacHash** — aggregates from all major Apple publications; getting covered by any Tier 1 source means automatic syndication

### How to Pitch

1. **Personalize every pitch** — reference the journalist's recent coverage
2. **Lead with the story, not the product** — "The messy digital desktop costs knowledge workers hours per week" is more compelling than "Forma is a file organizer"
3. **Include promo codes** — make it frictionless to try the app
4. **Offer exclusive angles** — give one publication an early look or exclusive interview
5. **Follow up once** — if no response after a week, one polite follow-up
6. **Timing** — pitch around Apple events (WWDC) or during "new year productivity" season (January)

### Press Kit Location

`Docs/Marketing/PRESS-KIT.md` — includes quick facts, elevator pitch, press release format, key messages, feature highlights, pricing, asset references, and founder bio template.

---

## 10. Community Building

### Channels

**Twitter/X "Build in Public" (Start Immediately)**
- Share design decisions and mockups
- Share file organization pain points and tips
- Post behind-the-scenes development content
- Engage in conversations about macOS productivity
- Replies and conversations get algorithmic boosts
- Target: 3-5 posts per week

**Newsletter (via formafiles.com)**
- Newsletter signup exists on the website (Supabase backend)
- Monthly "Forma Update" with new features, tips, file organization insights
- Consider a broader "Mac Productivity" newsletter to build audience beyond Forma users

**Reddit (Ongoing Presence)**
- r/macapps, r/macOS, r/productivity
- Answer questions about file management (without being promotional)
- Share tips and engage authentically

**Indie Hackers**
- Share revenue milestones, challenges, strategies
- Community values transparency and reciprocity

**Discord/Forum (Post-Launch, 100+ Users)**
- Feature requests and voting
- User-to-user support and rule sharing
- Beta testing coordination

### Conferences & Events

- **Deep Dish Swift** (Chicago, April 12-14, 2026) — indie-focused Swift conference
- **WWDC** (June 2026) — Apple developer conference; press coverage peaks around this time

### Distribution Partnerships

**Setapp** — 250+ curated premium Mac apps, subscription model ($9.99-14.99/mo):
- Handles payments, taxes, refunds
- Exposes Forma to Mac power users already paying for quality software
- Apply once 1.0 is stable and has initial reviews

---

## 11. Pricing Strategy

### Current Plan

Current website and marketing positioning uses a one-time $29 purchase model. Keep pricing copy synchronized across all channels whenever monetization changes.

### Market Context

| App | Model | Price |
|-----|-------|-------|
| Hazel | One-time | $42 |
| Sparkle | One-time | $99-179 |
| CleanMyMac | Subscription | $39.95/yr |
| Setapp | Subscription bundle | $9.99-14.99/mo |

### Industry Data

- Subscription models dominate modern app monetization
- Annual renewals in Utilities exceed 85% retention
- Subscription fatigue is real — users report their "slots are full"
- Hybrid models (subscription + one-time) see 30% higher revenue growth

### Options to Consider

**Option A: One-Time Purchase (Anti-Subscription Positioning)**
- $29-39 one-time
- Paid major version upgrades ($19-25 for Forma 2.0)
- Strongest for Product Hunt, Reddit, and HN audiences (subscription-hostile)
- Simpler, but limits recurring revenue

**Option B: Freemium + Subscription**
- Free tier: 3 folders, basic rules, limited AI
- Pro: $4.99/mo or $39.99/yr
- Lifetime: $99 one-time (captures subscription-fatigued users)
- Free tier creates viral loop and reduces friction for trying the app

**Option C: Hybrid (Recommended for Consideration)**
- Free tier with limited functionality
- $29 one-time unlock for current version
- Or $3.99/mo for ongoing updates + AI features
- Launch discount: 50% off first year for first 1,000 users

**Key Decision:** If pricing experiments are introduced later, ship copy updates for website, App Store, and launch collateral in a single coordinated release.

---

## 12. Post-Launch Optimization

### Week 1-2

- [ ] Monitor App Store reviews and respond to all
- [ ] Track which launch channels drive actual downloads
- [ ] Fix any bugs reported by early users
- [ ] Publish "lessons learned from launching Forma" blog post (great for SEO + HN + Indie Hackers)
- [ ] Follow up with press who didn't respond initially

### Month 1

- [ ] A/B test App Store description variants (3 written variants exist)
- [ ] Apply for MacStories Selects consideration
- [ ] Apply to Setapp for inclusion
- [ ] Submit to 9to5Mac Indie App Spotlight if not already covered
- [ ] Start publishing SEO blog content (1-2 posts)

### Month 2-3

- [ ] Analyze download/conversion data
- [ ] Optimize App Store keywords based on search data
- [ ] Expand to additional press outlets (Tier 2-3)
- [ ] Begin YouTube tutorial series
- [ ] Consider localization into top 5-10 languages (keywords especially)

### Ongoing

- [ ] Monthly newsletter to subscribers
- [ ] Weekly Twitter/X content
- [ ] Quarterly keyword/ASO review
- [ ] Update blog content for freshness
- [ ] Engage consistently in communities (Reddit, Indie Hackers)

---

## 13. Existing Assets Inventory

### Marketing Hub: `Docs/Marketing/`

| File | Content | Status |
|------|---------|--------|
| `APP-STORE-DESCRIPTION-V2.md` | App Store metadata (name, subtitle, keywords, description, 3 A/B variants) | Done |
| `LAUNCH-COPY.md` | Twitter thread (6 tweets), LinkedIn post, HN Show HN, launch announcements | Done |
| `PRESS-KIT.md` | Quick facts, elevator pitch, press release, key messages, founder bio | Done |
| `PRELAUNCH-TODO.md` | Pre-launch checklist with acceptance criteria | Active |
| `COMPETITOR-COMPARISON.md` | Competitive positioning | Done |
| `FEATURE-HIGHLIGHTS.md` | Feature marketing angles | Done |
| `Screenshots/AppStore/Light/` | 6 light mode screenshots | Done |
| `Screenshots/AppStore/Dark/` | 6 dark mode screenshots | Done |
| `Screenshots/AppStore/Upload/` | Upload-ready 2880x1800 versions | Done |
| `PreviewVideo/README.md` | Video specs and placement instructions | Placeholder |

### Brand Documentation: `Docs/Design/`

| File | Content | Status |
|------|---------|--------|
| `Forma-Brand-Guidelines.md` | Complete brand bible (2,135 lines) | Done |
| `FORMA-BRAND-TODO.md` | Brand task tracker | Active |

### Website: `forma-website/`

| File | Content | Status |
|------|---------|--------|
| Full Next.js 16 site | Landing page, privacy, terms, support, newsletter API | Built |
| `REVIEW_UX.md` | Comprehensive UX audit (455 lines) | Done |
| `REVIEW_VISUAL.md` | Visual design audit (205 lines) | Done |
| `VERIFICATION_REPORT.md` | QA verification (build passes, ready to ship) | Done |

### Tools: `Scripts/`

| File | Purpose |
|------|---------|
| `capture_app_store_screenshots.sh` | Automated screenshot capture via UI tests |
| `generate_app_icons.swift` | App icon generation from source artwork |

---

## 14. Gaps & Next Steps

### Still Missing (Priority Order)

1. **Social proof / testimonials** — highest conversion impact
2. **Demo video** — planned but not produced
3. **Pricing experiment framework** — define when and how to test alternative monetization without messaging drift
4. **Website deployment** — DNS not yet pointed to formafiles.com
5. **Email marketing plan** — templates, sequences, nurture flows
6. **Product Hunt launch preparation** — page setup, follower building
7. **Content calendar** — blog posts, social media posting schedule
8. **Analytics setup** — privacy-first tracking, conversion funnels, KPI targets
9. **Media contact list** — specific journalist names and emails for pitching
10. **Influencer/partnership outreach list** — Mac productivity space contacts
11. **A/B testing roadmap** — website copy and App Store variants
12. **Post-launch monitoring plan** — what to track, how to respond

### Immediate Actions (This Week)

- [ ] Collect beta tester testimonials (3-5 quotes)
- [ ] Verify production `NEXT_PUBLIC_MAC_APP_STORE_URL` is configured
- [ ] Define pricing experiment hypotheses (if any)
- [ ] Start Twitter/X "build in public" posts
- [ ] Set up Product Hunt page
- [ ] Begin recording demo video

---

*This document consolidates research from codebase analysis, marketing website audit, competitive landscape research, and industry best practices for macOS app marketing in 2026.*
