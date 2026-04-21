import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import {
  getAllBlogSlugs,
  getBlogPostBySlug,
  getRelatedBlogPosts,
} from "@/lib/content";
import GuideProductBridge from "@/components/blog/GuideProductBridge";
import { HEADER_SHELL_LAYOUT } from "@/lib/header-shell-layout";
import { SITE_NAME, SITE_URL } from "@/lib/site";
import { TrackedAppStoreLink } from "@/components/TrackedAppStoreLink";

type BlogPostPageProps = {
  params: Promise<{
    slug: string;
  }>;
};

function formatDate(dateString: string) {
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  }).format(new Date(dateString));
}

export async function generateStaticParams() {
  const slugs = await getAllBlogSlugs();
  return slugs.map((slug) => ({ slug }));
}

export async function generateMetadata({
  params,
}: BlogPostPageProps): Promise<Metadata> {
  const { slug } = await params;
  const post = await getBlogPostBySlug(slug);

  if (!post) {
    return {
      title: "Post not found",
      robots: {
        index: false,
        follow: false,
      },
    };
  }

  return {
    title: post.title,
    description: post.description,
    alternates: {
      canonical: post.canonical,
    },
    openGraph: {
      title: post.title,
      description: post.description,
      type: "article",
      url: post.canonical,
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt,
      authors: [post.author],
      tags: post.tags,
    },
    twitter: {
      card: "summary_large_image",
      title: post.title,
      description: post.description,
    },
  };
}

export default async function BlogPostPage({ params }: BlogPostPageProps) {
  const { slug } = await params;
  const post = await getBlogPostBySlug(slug);

  if (!post) {
    notFound();
  }

  const relatedPosts = await getRelatedBlogPosts(post.slug, 2);

  const articleJsonLd = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: post.title,
    description: post.description,
    datePublished: post.publishedAt,
    dateModified: post.updatedAt,
    author: {
      "@type": "Person",
      name: post.author,
    },
    publisher: {
      "@type": "Organization",
      name: SITE_NAME,
      url: SITE_URL,
    },
    mainEntityOfPage: post.canonical,
    keywords: post.tags.join(", "),
  };

  const faqJsonLd =
    post.faqPairs && post.faqPairs.length > 0
      ? {
          "@context": "https://schema.org",
          "@type": "FAQPage",
          mainEntity: post.faqPairs.map((faqPair) => ({
            "@type": "Question",
            name: faqPair.question,
            acceptedAnswer: {
              "@type": "Answer",
              text: faqPair.answer,
            },
          })),
        }
      : null;

  return (
    <main id="main-content" className={`relative ${HEADER_SHELL_LAYOUT.routeClearanceClassName}`}>
      <div className="site-container mx-auto max-w-3xl">
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(articleJsonLd) }}
        />
        {faqJsonLd ? (
          <script
            type="application/ld+json"
            dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
          />
        ) : null}

        <Link
          href="/blog"
          className="inline-flex text-sm text-[var(--ink-secondary)] hover:text-[var(--ink-primary)]"
        >
          &larr; Back to guides
        </Link>

        <article className="mt-6">
          <header className="border-b border-[var(--rule-faint)] pb-8">
            <p className="text-xs text-[var(--ink-faint)]">
              {formatDate(post.publishedAt)} · Updated {formatDate(post.updatedAt)}{" "}
              · {post.readingTimeMinutes} min read
            </p>
            <h1 className="display-lg mt-3 text-[var(--ink-primary)]">
              {post.title}
            </h1>
            <p className="prose-editorial mt-4">
              {post.description}
            </p>
            <p className="mt-3 text-sm text-[var(--ink-faint)]">
              By {post.author}
            </p>
          </header>

          <GuideProductBridge
            eyebrow="Run this guide inside Forma"
            title="This cleanup has a preview-first path."
            body="Keep the article open while you build one plain-language rule, review the proposed file moves, and run only the batch you trust."
            eventLocation="blog_post_top"
            slug={post.slug}
            className="mt-8"
          />

          <article className="mt-8 max-w-[68ch]">
            <div className="blog-content">{post.content}</div>
          </article>
        </article>

        <section className="mt-12 rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-7">
          <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
            Apply this workflow with Forma
          </h2>
          <p className="mt-3 text-[15px] leading-relaxed text-[var(--ink-secondary)]">
            Set rules in plain language, preview every change, and undo the recent batch if something was wrong.
          </p>
          <div className="mt-5">
            <TrackedAppStoreLink
              location="blog_inline"
              extraEvents={[
                {
                  name: "blog_cta_click",
                  props: { location: "blog_post", slug: post.slug },
                },
              ]}
              className="inline-flex items-center rounded-xl bg-[var(--cta-bg)] px-5 py-3 text-sm font-semibold text-[var(--cta-text)] transition-colors hover:bg-[var(--cta-bg-hover)]"
            >
              Download Forma for Mac
            </TrackedAppStoreLink>
          </div>
        </section>

        {relatedPosts.length > 0 ? (
          <section className="mt-10 rounded-2xl border border-[var(--rule-faint)] bg-[var(--canvas-bone)] p-7">
            <h2 className="font-display text-[1.5rem] font-medium tracking-[-0.01em] text-[var(--ink-primary)]">
              Related guides
            </h2>
            <ul className="mt-4 space-y-3">
              {relatedPosts.map((relatedPost) => (
                <li key={relatedPost.slug}>
                  <Link
                    href={`/blog/${relatedPost.slug}`}
                    className="inline-flex text-[15px] text-forma-steel-blue hover:underline"
                  >
                    {relatedPost.title}
                  </Link>
                </li>
              ))}
            </ul>
          </section>
        ) : null}
      </div>
    </main>
  );
}
