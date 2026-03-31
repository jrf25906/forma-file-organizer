import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import Header from "../src/components/Header"

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

describe("Header", () => {
  it("uses the floating shell contract for the header surface", () => {
    const html = renderToStaticMarkup(<Header />)
    const header = headerHtml(html)
    const headerTag = headerOpenTag(header)
    const headerClasses = classTokens(headerTag)
    const shellHostClasses = classTokens(firstInnerDiv(header))

    expect(headerTag).toContain('data-header-shell="floating"')
    expect(headerClasses).toContain("pointer-events-none")
    expect(shellHostClasses).toContain("pointer-events-auto")
    expect(headerClasses).not.toContain("border-b")
    expect(headerClasses).not.toContain("bg-[var(--bg-primary)]")
  })
})
