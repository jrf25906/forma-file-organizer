import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import SupportPage from "../src/app/support/page"
import { SUPPORT_EMAIL } from "../src/lib/site"

describe("SupportPage", () => {
  it("keeps a single page-level h1 while using shell cards for the support sections", () => {
    const html = renderToStaticMarkup(<SupportPage />)
    const shellCardMatches = html.match(
      /rounded-2xl border border-\[var\(--shell-border\)\] bg-\[var\(--shell-surface\)\] text-\[var\(--text-primary\)\] shadow-\[var\(--shell-shadow\)\] ring-0/g
    )

    expect(html).toContain('<h1 class="sr-only">Support without a ticket maze</h1>')
    expect(html.match(/<h1\b/g)).toHaveLength(1)
    expect(shellCardMatches).toHaveLength(3)
    expect(html).toContain(`mailto:${SUPPORT_EMAIL}`)
    expect(html).toContain('href="/blog/organize-mac-files"')
  })
})
