import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import Home from "../src/app/page"

function sectionHtml(html: string, id: string) {
  const start = html.indexOf(`<section id="${id}"`)
  if (start === -1) {
    throw new Error(`Missing section: ${id}`)
  }

  const end = html.indexOf("</section>", start)
  if (end === -1) {
    throw new Error(`Unclosed section: ${id}`)
  }

  return html.slice(start, end)
}

describe("Home", () => {
  it("keeps the hero bespoke while the pricing section uses shell surfaces", () => {
    const html = renderToStaticMarkup(<Home />)
    const heroSection = sectionHtml(html, "top")
    const pricingSection = sectionHtml(html, "pricing")

    expect(heroSection).toContain('<h1 data-hero="headline"')
    expect(heroSection).toContain('data-hero="window"')
    expect(heroSection).toContain("bg-transparent")
    expect(heroSection).not.toContain("var(--shell-surface)")

    expect(pricingSection).toContain("border-y border-[var(--shell-border)]")
    expect(pricingSection).toContain("bg-[var(--bg-secondary)]")
    expect(pricingSection).toContain("rounded-[2.25rem]")
    expect(pricingSection).toContain("bg-[var(--shell-surface)]")
    expect(pricingSection).toContain("shadow-[var(--shell-shadow)]")
  })
})
