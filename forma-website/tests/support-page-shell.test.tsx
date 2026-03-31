import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import SupportPage from "../src/app/support/page"
import { SUPPORT_EMAIL } from "../src/lib/site"

describe("SupportPage", () => {
  it("keeps a single page-level h1 while using shell cards for the support sections", () => {
    const html = renderToStaticMarkup(<SupportPage />)

    expect(html).toContain("<h1")
    expect(html).toContain("Support without a ticket maze")
    expect(html.match(/<h1\b/g)).toHaveLength(1)
    expect(html).toContain("border-[var(--shell-border)]")
    expect(html).toContain("bg-[var(--shell-surface-muted)]")
    expect(html).toContain("shadow-[var(--shell-shadow-soft)]")
    expect(html).toContain(`mailto:${SUPPORT_EMAIL}`)
    expect(html).toContain('href="/blog/organize-mac-files"')
  })
})
