import { describe, expect, it } from "vitest"

import { shouldRevealFAQSectionImmediately } from "../src/components/sections/FAQSection"

describe("shouldRevealFAQSectionImmediately", () => {
  it("reveals immediately when reduced motion is enabled", () => {
    expect(
      shouldRevealFAQSectionImmediately({
        reducedMotion: true,
        triggerTop: 1200,
        viewportHeight: 900,
      })
    ).toBe(true)
  })

  it("reveals immediately when the section is already near the viewport", () => {
    expect(
      shouldRevealFAQSectionImmediately({
        reducedMotion: false,
        triggerTop: 600,
        viewportHeight: 900,
      })
    ).toBe(true)
  })

  it("keeps the entrance animation when the section is still below the viewport threshold", () => {
    expect(
      shouldRevealFAQSectionImmediately({
        reducedMotion: false,
        triggerTop: 900,
        viewportHeight: 900,
      })
    ).toBe(false)
  })
})
