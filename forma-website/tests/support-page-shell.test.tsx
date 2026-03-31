import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import SupportPage from "../src/app/support/page"
import { SUPPORT_EMAIL } from "../src/lib/site"

describe("SupportPage", () => {
  it("keeps a single page-level h1 while using shell cards for the support sections", () => {
    const html = renderToStaticMarkup(<SupportPage />)
    const cardShadowMatches = html.match(/shadow-\[var\(--shell-shadow\)\]/g)

    expect(html).toContain("<h1")
    expect(html).toContain(">Support without a ticket maze</h1>")
    expect(html.match(/<h1\b/g)).toHaveLength(1)
    expect(cardShadowMatches).toHaveLength(3)
    expect(html).toContain(">Contact</h2>")
    expect(html).toContain(">Quick fixes</h2>")
    expect(html).toContain(">Guides</h2>")
    expect(html).toContain(`mailto:${SUPPORT_EMAIL}`)
    expect(html).toContain('href="/blog/organize-mac-files"')
  })
})
