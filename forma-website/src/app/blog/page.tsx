import type { Metadata } from "next";
import Link from "next/link";
import { getAllBlogPosts } from "@/lib/content";
import { SITE_URL } from "@/lib/site";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";

export const metadata: Metadata = {
  title: "Blog",
  description:
    "Guides for organizing Mac files, cleaning up desktop clutter, and building practical file workflows.",
  alternates: {
    canonical: `${SITE_URL}/blog`,
  },
  openGraph: {
    title: "Forma Blog",
    description:
      "Practical guides for Mac file organization and desktop cleanup workflows.",
    url: `${SITE_URL}/blog`,
    type: "website",
  },
};

export default async function BlogIndexPage() {
  const posts = await getAllBlogPosts();

  return (
    <main id="main-content" className="relative py-20 md:py-24">
      <div className="site-container mx-auto max-w-4xl">
        <header className="mb-10 border-b border-[var(--border-subtle)] pb-8">
          <p className="mb-3 text-xs uppercase tracking-[0.14em] text-[var(--text-muted)]">
            Forma Guides
          </p>
          <h1 className="font-display text-4xl text-[var(--text-primary)] md:text-5xl">
            File Organization Blog
          </h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-[var(--text-secondary)]">
            Practical, no-fluff workflows for organizing files on macOS.
          </p>
        </header>

        <section className="space-y-4" aria-label="Blog posts">
          {posts.map((post) => (
            <article
              key={post.slug}
              className="rounded-2xl border border-[var(--border-subtle)] bg-[var(--bg-secondary)] p-6 transition-colors hover:border-[var(--border-medium)]"
            >
              <p className="text-xs text-[var(--text-muted)]">
                {post.publishedAt} · {post.readingTimeMinutes} min read
              </p>
              <h2 className="mt-2 font-display text-2xl text-[var(--text-primary)]">
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
          <h2 className="font-display text-2xl text-[var(--text-primary)]">
            Ready to apply this on your Mac?
          </h2>
          <p className="mt-3 max-w-xl text-[15px] leading-relaxed text-[var(--text-secondary)]">
            Use previews before applying moves, then keep full undo history for
            safe cleanup.
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

