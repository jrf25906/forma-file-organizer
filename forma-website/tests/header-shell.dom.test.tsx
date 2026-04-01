// @vitest-environment jsdom

import { act } from "react"
import { createRoot } from "react-dom/client"
import { afterEach, describe, expect, it } from "vitest"

import { HEADER_SHELL_LAYOUT } from "../src/lib/header-shell-layout"

const HEADER_SCROLL_THRESHOLD = 24

;(globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean })
  .IS_REACT_ACT_ENVIRONMENT = true

describe("Header DOM behavior", () => {
  let container: HTMLDivElement | null = null
  let root: ReturnType<typeof createRoot> | null = null
  let restoreMatchMedia = false
  let restoreScrollY = false

  afterEach(async () => {
    if (root && container) {
      await act(async () => {
        root?.unmount()
      })
    }

    container?.remove()
    root = null
    container = null

    if (restoreMatchMedia) {
      delete (window as typeof window & { matchMedia?: typeof window.matchMedia }).matchMedia
      restoreMatchMedia = false
    }

    if (restoreScrollY) {
      delete (window as typeof window & { scrollY?: number }).scrollY
      restoreScrollY = false
    }
  })

  it("uses the shared scroll threshold contract", () => {
    expect(HEADER_SHELL_LAYOUT.scrollThreshold).toBe(HEADER_SCROLL_THRESHOLD)
  })

  it("switches from top mode to scrolled mode after the shell threshold", async () => {
    restoreMatchMedia = true
    Object.defineProperty(window, "matchMedia", {
      configurable: true,
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

    restoreScrollY = true
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
    expect(header).not.toBeNull()
    expect(header?.getAttribute("data-header-shell-mode")).toBe("top")
    expect(
      container.querySelector('[data-shell-variant="floating"]')?.getAttribute("data-shell-mode")
    ).toBe("top")

    await act(async () => {
      Object.defineProperty(window, "scrollY", {
        configurable: true,
        value: HEADER_SCROLL_THRESHOLD + 1,
        writable: true,
      })
      window.dispatchEvent(new Event("scroll"))
    })

    expect(header?.getAttribute("data-header-shell-mode")).toBe("scrolled")
    expect(
      container.querySelector('[data-shell-variant="floating"]')?.getAttribute("data-shell-mode")
    ).toBe("scrolled")
  })
})
