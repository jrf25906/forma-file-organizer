import { renderToStaticMarkup } from "react-dom/server"
import { afterEach, describe, expect, it, vi } from "vitest"

const { mockUsePathname } = vi.hoisted(() => ({
  mockUsePathname: vi.fn(() => "/"),
}))

vi.mock("next/navigation", () => ({
  usePathname: mockUsePathname,
}))

import Header from "../src/components/Header"
import { HEADER_SHELL_LAYOUT } from "../src/lib/header-shell-layout"

function headerHtml(html: string) {
  const match = html.match(/<header\b[^>]*>[\s\S]*?<\/header>/)

  if (!match) {
    throw new Error("Missing header element")
  }

  return match[0]
}

function headerOpenTag(html: string) {
  const match = html.match(/^<header\b[^>]*>/)

  if (!match) {
    throw new Error("Missing header opening tag")
  }

  return match[0]
}

function classTokens(tagHtml: string) {
  const classMatch = tagHtml.match(/\bclass="([^"]*)"/)

  if (!classMatch) {
    return []
  }

  return classMatch[1].split(/\s+/).filter(Boolean)
}

function firstInnerDiv(html: string) {
  const match = html.match(/<header\b[^>]*>(\s*<div\b[^>]*>)/)

  if (!match) {
    throw new Error("Missing inner shell host container")
  }

  return match[1]
}

function firstFloatingShell(html: string) {
  const match = html.match(/<div\b[^>]*data-shell-variant="floating"[^>]*>/)

  if (!match) {
    throw new Error("Missing floating shell card")
  }

  return match[0]
}

function firstDesktopNav(html: string) {
  const match = html.match(/<nav\b[^>]*aria-label="Main navigation"[^>]*>/)

  if (!match) {
    throw new Error("Missing desktop navigation")
  }

  return match[0]
}

function firstDesktopNavLink(html: string) {
  const match = html.match(
    /<nav\b[^>]*aria-label="Main navigation"[^>]*>\s*<a\b[^>]*href="\/#how-it-works"[^>]*>/
  )

  if (!match) {
    throw new Error("Missing first desktop navigation link")
  }

  return match[0]
}

describe("Header", () => {
  afterEach(() => {
    mockUsePathname.mockReset()
    mockUsePathname.mockReturnValue("/")
  })

  it("uses the floating shell contract for the header surface", () => {
    const html = renderToStaticMarkup(<Header />)
    const header = headerHtml(html)
    const headerTag = headerOpenTag(header)
    const headerClasses = classTokens(headerTag)
    const shellHostClasses = classTokens(firstInnerDiv(header))
    const floatingShellClasses = classTokens(firstFloatingShell(header))
    const desktopNavClasses = classTokens(firstDesktopNav(header))

    expect(headerTag).toContain('data-header-shell="floating"')
    expect(headerTag).toContain('data-header-shell-mode="top"')
    expect(headerClasses).toContain("pointer-events-none")
    expect(shellHostClasses).toContain("pointer-events-auto")
    expect(desktopNavClasses).toContain("hidden")
    expect(firstDesktopNav(header)).not.toContain('aria-hidden="true"')
    expect(firstDesktopNavLink(header)).not.toContain("tabindex=")
    expect(firstFloatingShell(header)).toContain('data-shell-mode="top"')
    expect(floatingShellClasses).toContain("data-[shell-mode=top]:bg-[var(--header-shell-surface-top)]")
    expect(floatingShellClasses).toContain(
      "data-[shell-mode=scrolled]:bg-[var(--header-shell-surface-scrolled)]"
    )
    expect(floatingShellClasses).toContain("data-[shell-mode=top]:border-[var(--header-shell-surface-top-border)]")
    expect(floatingShellClasses).toContain(
      "data-[shell-mode=scrolled]:border-[var(--header-shell-surface-scrolled-border)]"
    )
    expect(floatingShellClasses).toContain("backdrop-blur-xl")
    expect(floatingShellClasses).toContain("shadow-[var(--header-shell-shadow)]")
    expect(headerClasses).not.toContain("border-b")
    expect(headerClasses).not.toContain("bg-[var(--bg-primary)]")
  })

  it("renders non-home routes in the scrolled desktop state", () => {
    mockUsePathname.mockReturnValue("/blog")

    const html = renderToStaticMarkup(<Header />)
    const header = headerHtml(html)
    const headerTag = headerOpenTag(header)
    const desktopNavClasses = classTokens(firstDesktopNav(header))

    expect(headerTag).toContain('data-header-shell-mode="scrolled"')
    expect(firstFloatingShell(header)).toContain('data-shell-mode="scrolled"')
    expect(desktopNavClasses).toContain("opacity-100")
    expect(desktopNavClasses).toContain("translate-y-0")
    expect(desktopNavClasses).not.toContain("pointer-events-none")
    expect(firstDesktopNav(header)).not.toContain('aria-hidden="true"')
    expect(firstDesktopNavLink(header)).not.toContain("tabindex=")
  })

  it("keeps the header shell compact enough to clear the hero copy", () => {
    expect(HEADER_SHELL_LAYOUT.topInsetClassName).toBe("pt-3 md:pt-4")
    expect(HEADER_SHELL_LAYOUT.cardHeightClassName).toBe("h-[64px] md:h-[68px]")
    expect(HEADER_SHELL_LAYOUT.heroClearanceClassName).toBe(
      "pt-36 pb-12 md:pt-40 md:pb-16 lg:pt-44 lg:pb-24"
    )
  })
})
