// @vitest-environment jsdom

import { act } from "react"
import { createRoot } from "react-dom/client"
import { afterEach, describe, expect, it } from "vitest"

describe("NewsletterSignupForm DOM behavior", () => {
  let container: HTMLDivElement | null = null
  let root: ReturnType<typeof createRoot> | null = null

  afterEach(async () => {
    if (root && container) {
      await act(async () => {
        root?.unmount()
      })
    }

    container?.remove()
    root = null
    container = null
  })

  it("moves focus to the live success message when the form enters success state", async () => {
    Object.defineProperty(window, "matchMedia", {
      writable: true,
      value: () => ({
        matches: false,
        media: "",
        onchange: null,
        addListener: () => {},
        removeListener: () => {},
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => false,
      }),
    })

    const { NewsletterSignupForm } = await import(
      "../src/components/sections/NewsletterSection"
    )

    container = document.createElement("div")
    document.body.appendChild(container)
    root = createRoot(container)

    await act(async () => {
      root?.render(
        <NewsletterSignupForm
          email="person@example.com"
          formState="idle"
          errorKind="none"
          errorMessage=""
          onEmailChange={() => {}}
          onSubmit={() => {}}
        />
      )
    })

    await act(async () => {
      root?.render(
        <NewsletterSignupForm
          email=""
          formState="success"
          errorKind="none"
          errorMessage=""
          onEmailChange={() => {}}
          onSubmit={() => {}}
        />
      )
    })

    const status = container.querySelector('[role="status"]')

    expect(status).not.toBeNull()
    expect(document.activeElement).toBe(status)
    expect(status?.textContent).toContain("You're in.")
  })
})
