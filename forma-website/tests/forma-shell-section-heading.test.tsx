import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import { FormaShellSectionHeading } from "../src/components/ui/forma-shell-section-heading"

describe("FormaShellSectionHeading", () => {
  it("centers the description when aligned center", () => {
    const html = renderToStaticMarkup(
      <FormaShellSectionHeading
        align="center"
        title="Centered title"
        description="Centered description"
      />
    )

    expect(html).toContain("Centered description")
    expect(html).toMatch(
      /<p class="[^"]*mx-auto[^"]*"[^>]*>Centered description<\/p>/
    )
  })
})
