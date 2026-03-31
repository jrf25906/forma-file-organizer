import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import Header from "../src/components/Header"

describe("Header", () => {
  it("uses the floating shell contract for the header surface", () => {
    const html = renderToStaticMarkup(<Header />)

    expect(html).toContain('data-header-shell="floating"')
    expect(html).toContain("pointer-events-none")
    expect(html).toContain("pointer-events-auto")
    expect(html).not.toContain(
      "border-b border-[var(--shell-border)] bg-[var(--bg-primary)]"
    )
  })
})
