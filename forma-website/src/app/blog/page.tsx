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
      <div className="site-container mx-auto max-w-4xl">
        <header className="mb-10 border-b border-[var(--border-subtle)] pb-8">
          <p className="mb-3 text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
            Guides
          </p>
          <h1 className="text-4xl font-semibold tracking-[-0.02em] text-[var(--text-primary)] md:text-5xl">
            Practical guides for organizing Mac files
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-[var(--text-secondary)]">
            Step-by-step workflows you can apply right away, without adding more complexity.
          </p>
        </header>

        <GuideProductBridge
          eyebrow="Guides that map to the product"
          title="Read the workflow. Then run it in Forma."
          body="These guides are built around the same preview-first system Forma uses in the app: write the rule, review the batch, and approve only what belongs."
          eventLocation="blog_index_top"
          className="mb-10"
        />

        <section className="space-y-4" aria-label="Blog posts">
          {posts.map((post) => (
            <article
              key={post.slug}
              className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 transition-colors hover:border-[var(--border-medium)]"
            >
              <p className="text-xs text-[var(--text-muted)]">
                {post.publishedAt} · {post.readingTimeMinutes} min read
              </p>
              <h2 className="mt-2 text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
                <Link href={`/blog/${post.slug}`} className="hover:underline">
                  {post.title}
                </Link>
              </h2>
              <p className="mt-3 text-[15px] leading-relaxed text-[var(--text-secondary)]">
                {post.description}
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                {post.tags.slice(0, 3).map((tag) => (
                  <span
                    key={tag}
                    className="rounded-full border border-[var(--border-medium)] px-2.5 py-1 text-xs text-[var(--text-muted)]"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </article>
          ))}
        </section>

        <section className="mt-12 rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-7">
          <h2 className="text-2xl font-semibold tracking-[-0.02em] text-[var(--text-primary)]">
            Put this into practice on your Mac
          </h2>
          <p className="mt-3 max-w-xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
            Build preview-first rules, review every move, and undo when needed.
          </p>
          <div className="mt-5">
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
      </div>
    </main>
  );
}
