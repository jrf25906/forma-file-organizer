import { NextResponse } from "next/server";
import { SITE_URL } from "@/lib/site";

export function GET() {
  const body = [
    "# Forma",
    "",
    "> Forma is a macOS-native file organizer with preview-first moves and full undo history.",
    "",
    "## Canonical",
    `- ${SITE_URL}`,
    "",
    "## Product",
    `- Home: ${SITE_URL}/`,
    `- Support: ${SITE_URL}/support`,
    `- Privacy: ${SITE_URL}/privacy`,
    `- Terms: ${SITE_URL}/terms`,
    "",
    "## Guides",
    `- Blog index: ${SITE_URL}/blog`,
    `- Organize Mac files: ${SITE_URL}/blog/organize-mac-files`,
    `- Organize Downloads folder on Mac: ${SITE_URL}/blog/organize-downloads-folder-mac`,
    `- Organize desktop files on Mac: ${SITE_URL}/blog/organize-desktop-files-mac`,
    "",
    "## Machine-readable APIs",
    `- Product JSON: ${SITE_URL}/api/public/product`,
    `- FAQ JSON: ${SITE_URL}/api/public/faq`,
    `- FAQ item JSON: ${SITE_URL}/api/public/faq/{id}`,
    `- OpenAPI: ${SITE_URL}/openapi.json`,
    `- Agent guide: ${SITE_URL}/for-agents`,
    "",
    "## Crawl guidance",
    "- Public marketing and documentation pages may be indexed.",
    "- Do not treat API payloads as legal terms; legal pages are canonical for policy text.",
    "- Respect robots.txt and page-level directives.",
    "",
  ].join("\n");

  return new NextResponse(body, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "public, max-age=3600, s-maxage=3600",
    },
  });
}

