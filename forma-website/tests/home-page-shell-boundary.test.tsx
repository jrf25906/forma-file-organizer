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
    expect(heroSection).toContain("bg-transparent")
    clearanceClasses.forEach((className) => {
      expect(heroSection).toContain(className)
    })
    expect(heroSection).not.toContain("rounded-[2.25rem]")
    expect(heroSection).not.toContain("shadow-[var(--shell-shadow)]")

    expect(pricingSection).toContain("border-y border-[var(--shell-border)]")
    expect(pricingSection).toContain("bg-[var(--bg-secondary)]")
    expect(pricingSection).toContain("rounded-[2.25rem]")
    expect(pricingSection).toContain("bg-[var(--shell-surface)]")
    expect(pricingSection).toContain("shadow-[var(--shell-shadow)]")
  })
})
