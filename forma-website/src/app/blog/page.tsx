import type { Metadata } from "next";
import Link from "next/link";
import { getAllBlogPosts } from "@/lib/content";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { SITE_URL } from "@/lib/site";
import GuideProductBridge from "@/components/blog/GuideProductBridge";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";

export const metadata: Metadata = {
  title: "Blog",
  description:
    "Practical guides for organizing Mac files with clear, repeatable workflows.",
  alternates: {
    canonical: `${SITE_URL}/blog`,
  },
  openGraph: {
    title: "Forma Blog",
    description:
      "Practical guides for organizing Mac files with clear, repeatable workflows.",
    url: `${SITE_URL}/blog`,
    type: "website",
  },
};

export default async function BlogIndexPage() {
  const posts = await getAllBlogPosts();

  return (
    <main id="main-content" className={`relative ${HEADER_SHELL_LAYOUT.routeClearanceClassName}`}>
      <section className="mx-auto w-full max-w-[1100px] px-6">
        <header className="mb-12 border-b border-[var(--rule-faint)] pb-10">
          <p className="eyebrow">Guides</p>
          <h1 className="display-lg mt-5 text-[var(--ink-primary)]">
            Practical guides for organizing Mac files
          </h1>
          <p className="prose-editorial mt-5">
            Step-by-step workflows you can apply right away, without adding more complexity.
          </p>
        </header>

        <GuideProductBridge
          eyebrow="Guides that map to the product"
          title="Read the workflow. Then run it in Forma."
          body="These guides are built around the same preview-first system Forma uses in the app: write the rule, review the batch, and approve only what belongs."
          eventLocation="blog_index_top"
          className="mb-12"
        />

        <ul className="space-y-4" aria-label="Blog posts">
          {posts.map((post) => (
            <li key={post.slug}>
              <article className="rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-8 transition-colors hover:border-[var(--rule-strong)]">
                <p className="text-xs text-[var(--ink-faint)]">
                  {post.publishedAt} · {post.readingTimeMinutes} min read
                </p>
                <h2 className="mt-3 font-display text-[1.625rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
                  <Link href={`/blog/${post.slug}`} className="hover:underline">
                    {post.title}
                  </Link>
                </h2>
                <p className="mt-3 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
                  {post.description}
                </p>
                <div className="mt-5 flex flex-wrap gap-2">
                  {post.tags.slice(0, 3).map((tag) => (
                    <span
                      key={tag}
                      className="rounded-full border border-[var(--rule-faint)] px-2.5 py-1 text-xs text-[var(--ink-faint)]"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </article>
            </li>
          ))}
        </ul>

        <section className="mt-16 rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-8">
          <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
            Put this into practice on your Mac
          </h2>
          <p className="mt-3 max-w-xl text-[15px] leading-relaxed text-[var(--ink-secondary)]">
            Build preview-first rules, review every move, and undo when needed.
          </p>
          <div className="mt-6">
            <TrackedAppStoreLink
              location="blog_inline"
              extraEvents={[
                {
                  name: "blog_cta_click",
                  props: { location: "blog_index" },
                },
              ]}
              className="inline-flex items-center rounded-xl bg-[var(--cta-bg)] px-5 py-3 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
            >
              Download Forma for Mac
            </TrackedAppStoreLink>
          </div>
        </section>
      </section>
    </main>
  );
}
