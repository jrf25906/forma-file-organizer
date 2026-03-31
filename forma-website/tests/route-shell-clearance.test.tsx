import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it, vi } from "vitest"

vi.mock("server-only", () => ({}))

import BlogIndexPage from "../src/app/blog/page"
import BlogPostPage from "../src/app/blog/[slug]/page"
import ForAgentsPage from "../src/app/for-agents/page"
import GetFormaPage from "../src/app/get-forma/page"
import SupportPage from "../src/app/support/page"
import LegalPageShell from "../src/components/legal/LegalPageShell"
import { getAllBlogSlugs } from "../src/lib/content"
import { HEADER_SHELL_LAYOUT } from "../src/lib/header-shell-layout"

function mainOpenTag(html: string) {
  const match = html.match(/<main\b[^>]*>/)

  if (!match) {
    throw new Error("Missing main opening tag")
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

describe("Non-home route shells", () => {
  it("apply the shared header clearance contract to every top-level route shell", async () => {
    const clearanceClasses = HEADER_SHELL_LAYOUT.routeClearanceClassName.split(/\s+/).filter(Boolean)
    const [blogSlug] = await getAllBlogSlugs()

    if (!blogSlug) {
      throw new Error("Expected at least one blog slug for route shell clearance coverage")
    }

    const renderedPages = [
      await BlogIndexPage(),
      await BlogPostPage({ params: Promise.resolve({ slug: blogSlug }) }),
      <GetFormaPage key="get-forma" />,
      <SupportPage key="support" />,
      <ForAgentsPage key="for-agents" />,
      (
        <LegalPageShell
          key="legal-shell"
          eyebrow="Legal"
          title="Terms"
          description="Terms description"
          lastUpdated="March 31, 2026"
          contactLocation="legal_test"
          summaryChips={["Test"]}
          plainLanguageTitle="Plain language summary"
          plainLanguagePoints={["Point one"]}
          sections={[{ paragraphs: ["Section body"] }]}
          relatedLinks={[
            {
              href: "/privacy",
              label: "Privacy",
              description: "Privacy policy",
            },
          ]}
        />
      ),
    ]

    renderedPages.forEach((page) => {
      const mainClasses = classTokens(mainOpenTag(renderToStaticMarkup(page)))

      clearanceClasses.forEach((className) => {
        expect(mainClasses).toContain(className)
      })
    })
  })
})
