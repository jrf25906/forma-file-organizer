import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import Home from "../src/app/page"

describe("Home", () => {
  it("keeps the hero bespoke while the pricing section uses shell surfaces", () => {
    const html = renderToStaticMarkup(<Home />)

    expect(html).toContain('<h1 data-hero="headline"')
    expect(html).toContain("A file organizer for people who gave up on file organizers.")
    expect(html).toMatch(/id="top"[^>]*bg-transparent/)
    expect(html).toMatch(
      /id="pricing"[^>]*border-y border-\[var\(--shell-border\)\] bg-\[var\(--bg-secondary\)\]/
    )
    expect(html).toMatch(
      /rounded-\[2\.25rem\] border border-\[var\(--shell-border\)\] bg-\[var\(--shell-surface\)\][^"]*shadow-\[var\(--shell-shadow\)\]/
    )
  })
})
