// @vitest-environment jsdom

import { act } from "react"
import { createRoot } from "react-dom/client"
import { afterEach, describe, expect, it } from "vitest"

describe("Header DOM behavior", () => {
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

  it("switches from top mode to scrolled mode after the shell threshold", async () => {
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

    Object.defineProperty(window, "scrollY", {
      configurable: true,
      value: 0,
      writable: true,
    })

    const { Header } = await import("../src/components/Header")

    container = document.createElement("div")
    document.body.appendChild(container)
    root = createRoot(container)

    await act(async () => {
      root?.render(<Header />)
    })

    const header = container.querySelector('[data-header-shell="floating"]')

    expect(header?.getAttribute("data-header-shell-mode")).toBe("top")

    await act(async () => {
      Object.defineProperty(window, "scrollY", {
        configurable: true,
        value: 48,
        writable: true,
      })
      window.dispatchEvent(new Event("scroll"))
    })

    expect(header?.getAttribute("data-header-shell-mode")).toBe("scrolled")
  })
})
