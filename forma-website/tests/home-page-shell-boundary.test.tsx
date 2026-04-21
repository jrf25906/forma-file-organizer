import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import Home from "../src/app/page"
import { HEADER_SHELL_LAYOUT } from "../src/lib/header-shell-layout"

function sectionHtml(html: string, id: string) {
  const match = html.match(
    new RegExp(`<section\\b[^>]*id="${id}"[^>]*>[\\s\\S]*?<\\/section>`)
  )

  if (!match) {
    throw new Error(`Missing section: ${id}`)
  }

  return match[0]
}

describe("Home", () => {
  it("keeps the hero bespoke while preserving the header clearance contract", () => {
    const html = renderToStaticMarkup(<Home />)
    const heroSection = sectionHtml(html, "top")
    const pricingSection = sectionHtml(html, "pricing")
    const clearanceClasses = HEADER_SHELL_LAYOUT.heroClearanceClassName.split(/\s+/).filter(Boolean)

    expect(heroSection).toContain('data-hero-layout="header-overlay"')
    expect(heroSection).toContain('data-hero-clearance="floating-header-shell"')
    expect(heroSection).toContain('<h1 data-hero="headline"')
    expect(heroSection).toContain('data-hero="window"')
    // bg-transparent was removed in the canvas redesign; the hero now inherits
    // canvas-paper from the body via HeroCanvasBackground. Verify the layout
    // contract attributes that replaced it are still present instead.
    expect(heroSection).toContain('data-hero-layout=')
    clearanceClasses.forEach((className) => {
      expect(heroSection).toContain(className)
    })
    expect(heroSection).not.toContain("rounded-[2.25rem]")
    expect(heroSection).not.toContain("shadow-[var(--shell-shadow)]")

    // Canvas redesign: pricing section uses rule-faint border and canvas-paper surface.
    expect(pricingSection).toContain("border-y border-[var(--rule-faint)]")
    expect(pricingSection).toContain("bg-[var(--canvas-paper)]")
    // The pricing card uses an anchor-dark shell with its own bespoke shadow.
    expect(pricingSection).toContain("anchor-dark")
  })
})
