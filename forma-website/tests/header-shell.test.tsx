import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

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

describe("Header", () => {
  it("uses the floating shell contract for the header surface", () => {
    const html = renderToStaticMarkup(<Header />)
    const header = headerHtml(html)
    const headerTag = headerOpenTag(header)
    const headerClasses = classTokens(headerTag)
    const shellHostClasses = classTokens(firstInnerDiv(header))
    const floatingShellClasses = classTokens(firstFloatingShell(header))

    expect(headerTag).toContain('data-header-shell="floating"')
    expect(headerClasses).toContain("pointer-events-none")
    expect(shellHostClasses).toContain("pointer-events-auto")
    expect(floatingShellClasses).toContain("backdrop-blur-xl")
    expect(floatingShellClasses).toContain("bg-[var(--header-shell-surface)]")
    expect(floatingShellClasses).toContain("border-[var(--header-shell-border)]")
    expect(floatingShellClasses).toContain("shadow-[var(--header-shell-shadow)]")
    expect(headerClasses).not.toContain("border-b")
    expect(headerClasses).not.toContain("bg-[var(--bg-primary)]")
  })

  it("keeps the header shell compact enough to clear the hero copy", () => {
    expect(HEADER_SHELL_LAYOUT.topInsetClassName).toBe("pt-3 md:pt-4")
    expect(HEADER_SHELL_LAYOUT.cardHeightClassName).toBe("h-[64px] md:h-[68px]")
    expect(HEADER_SHELL_LAYOUT.heroClearanceClassName).toBe(
      "pt-36 pb-12 md:pt-40 md:pb-16 lg:pt-44 lg:pb-24"
    )
  })
})
