// @vitest-environment jsdom

import { act } from "react"
import { createRoot, hydrateRoot } from "react-dom/client"
import { renderToStaticMarkup } from "react-dom/server"
import { afterEach, describe, expect, it, vi } from "vitest"

const { mockUsePathname } = vi.hoisted(() => ({
  mockUsePathname: vi.fn(() => "/"),
}))

vi.mock("next/navigation", () => ({
  usePathname: mockUsePathname,
}))

import { HEADER_SHELL_LAYOUT } from "../src/lib/header-shell-layout"

const HEADER_SCROLL_THRESHOLD = 24

function classTokens(className: string) {
  return className.split(/\s+/).filter(Boolean)
}

;(globalThis as typeof globalThis & { IS_REACT_ACT_ENVIRONMENT?: boolean })
  .IS_REACT_ACT_ENVIRONMENT = true

describe("Header DOM behavior", () => {
  let container: HTMLDivElement | null = null
  let root: ReturnType<typeof createRoot> | null = null
  let hydrationRoot: ReturnType<typeof hydrateRoot> | null = null
  let restoreMatchMedia = false
  let restoreScrollY = false

  afterEach(async () => {
    if (root && container) {
      await act(async () => {
        root?.unmount()
      })
    }

    if (hydrationRoot && container) {
      await act(async () => {
        hydrationRoot?.unmount()
      })
    }

    container?.remove()
    root = null
    hydrationRoot = null
    container = null

    if (restoreMatchMedia) {
      delete (window as typeof window & { matchMedia?: typeof window.matchMedia }).matchMedia
      restoreMatchMedia = false
    }

    if (restoreScrollY) {
      delete (window as typeof window & { scrollY?: number }).scrollY
      restoreScrollY = false
    }

    mockUsePathname.mockReset()
    mockUsePathname.mockReturnValue("/")
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

    const topNav = container.querySelector('nav[aria-label="Main navigation"]')
    expect(topNav).not.toBeNull()
    const topNavClasses = classTokens(topNav?.className ?? "")
    expect(topNavClasses).toContain("opacity-0")
    expect(topNavClasses).toContain("pointer-events-none")
    expect(topNavClasses).toContain("translate-y-1")
    expect(topNavClasses).toContain("focus-within:opacity-100")
    expect(topNavClasses).toContain("focus-within:pointer-events-auto")

    await act(async () => {
      Object.defineProperty(window, "scrollY", {
        configurable: true,
        value: HEADER_SCROLL_THRESHOLD + 1,
        writable: true,
      })
      window.dispatchEvent(new Event("scroll"))
    })

    const scrolledHeader = container.querySelector('[data-header-shell="floating"]')
    expect(scrolledHeader?.getAttribute("data-header-shell-mode")).toBe("scrolled")
    expect(
      container.querySelector('[data-shell-variant="floating"]')?.getAttribute("data-shell-mode")
    ).toBe("scrolled")

    const scrolledNav = container.querySelector('nav[aria-label="Main navigation"]')
    expect(scrolledNav).not.toBeNull()
    const scrolledNavClasses = classTokens(scrolledNav?.className ?? "")
    expect(scrolledNavClasses).toContain("opacity-100")
    expect(scrolledNavClasses).toContain("translate-y-0")
    expect(scrolledNavClasses).not.toContain("opacity-0")
    expect(scrolledNavClasses).not.toContain("pointer-events-none")
  })

  it("keeps the home route hydration-safe before the post-mount scroll sync", async () => {
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
      value: HEADER_SCROLL_THRESHOLD + 1,
      writable: true,
    })

    const { Header } = await import("../src/components/Header")
    const serverHtml = renderToStaticMarkup(<Header />)

    container = document.createElement("div")
    container.innerHTML = serverHtml
    document.body.appendChild(container)
    expect(container.querySelector('[data-header-shell="floating"]')?.getAttribute("data-header-shell-mode")).toBe("top")

    const consoleErrors: string[] = []
    const consoleError = vi.spyOn(console, "error").mockImplementation((...args) => {
      consoleErrors.push(args.map(String).join(" "))
    })

    try {
      await act(async () => {
        hydrationRoot = hydrateRoot(container!, <Header />)
      })
    } finally {
      consoleError.mockRestore()
    }

    expect(
      consoleErrors.filter((message) =>
        /hydration|did not match|server rendered html/i.test(message)
      )
    ).toHaveLength(0)

    const scrolledHeader = container.querySelector('[data-header-shell="floating"]')
    expect(scrolledHeader?.getAttribute("data-header-shell-mode")).toBe("scrolled")
    expect(
      container.querySelector('[data-shell-variant="floating"]')?.getAttribute("data-shell-mode")
    ).toBe("scrolled")
  })
})
