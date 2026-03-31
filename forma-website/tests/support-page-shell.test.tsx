import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import SupportPage from "../src/app/support/page"

describe("SupportPage", () => {
  it("uses shell surfaces for the support cards", () => {
    const html = renderToStaticMarkup(<SupportPage />)

    expect(html).toContain("Support without a ticket maze")
    expect(html).toContain("border-[var(--shell-border)]")
    expect(html).toContain("bg-[var(--shell-surface)]")
    expect(html).toContain("shadow-[var(--shell-shadow)]")
  })
})
