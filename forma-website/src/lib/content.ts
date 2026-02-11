import "server-only";

import fs from "node:fs/promises";
import path from "node:path";
import type { ReactNode } from "react";
import matter from "gray-matter";
import { compileMDX } from "next-mdx-remote/rsc";
import remarkGfm from "remark-gfm";
import { SITE_URL } from "@/lib/site";

const BLOG_CONTENT_DIR = path.join(process.cwd(), "src/content/blog");
const AVERAGE_WORDS_PER_MINUTE = 220;

type BlogFaqPair = {
  question: string;
  answer: string;
};

export type BlogFrontmatter = {
  slug: string;
  title: string;
  description: string;
  publishedAt: string;
  updatedAt: string;
  author: string;
  tags: string[];
  faqPairs?: BlogFaqPair[];
};

export type BlogPostSummary = BlogFrontmatter & {
  canonical: string;
  readingTimeMinutes: number;
};

export type BlogPost = BlogPostSummary & {
  content: ReactNode;
};

function toCanonical(slug: string) {
  return `${SITE_URL}/blog/${slug}`;
}

function estimateReadingTimeMinutes(markdownContent: string) {
  const plainText = markdownContent
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/`[^`]*`/g, " ")
    .replace(/[#>*_[\]()!-]/g, " ");
  const words = plainText.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.round(words / AVERAGE_WORDS_PER_MINUTE));
}

function normalizeFaqPairs(data: unknown): BlogFaqPair[] | undefined {
  if (!Array.isArray(data)) return undefined;

  const parsed = data
    .map((item) => {
      if (
        typeof item === "object" &&
        item !== null &&
        "question" in item &&
        "answer" in item &&
        typeof item.question === "string" &&
        typeof item.answer === "string"
      ) {
        return {
          question: item.question.trim(),
          answer: item.answer.trim(),
        };
      }
      return null;
    })
    .filter((item): item is BlogFaqPair => item !== null);

  return parsed.length > 0 ? parsed : undefined;
}

function normalizeFrontmatter(
  rawFrontmatter: Record<string, unknown>,
  filenameSlug: string
): BlogFrontmatter {
  const tags = Array.isArray(rawFrontmatter.tags)
    ? rawFrontmatter.tags
        .filter((tag): tag is string => typeof tag === "string")
        .map((tag) => tag.trim())
        .filter(Boolean)
    : [];

  const slug =
    typeof rawFrontmatter.slug === "string" && rawFrontmatter.slug.trim()
      ? rawFrontmatter.slug.trim()
      : filenameSlug;

  const title =
    typeof rawFrontmatter.title === "string" && rawFrontmatter.title.trim()
      ? rawFrontmatter.title.trim()
      : "Untitled guide";

  const description =
    typeof rawFrontmatter.description === "string" &&
    rawFrontmatter.description.trim()
      ? rawFrontmatter.description.trim()
      : "Forma guide";

  const publishedAt =
    typeof rawFrontmatter.publishedAt === "string"
      ? rawFrontmatter.publishedAt
      : "2026-02-11";

  const updatedAt =
    typeof rawFrontmatter.updatedAt === "string"
      ? rawFrontmatter.updatedAt
      : publishedAt;

  const author =
    typeof rawFrontmatter.author === "string" && rawFrontmatter.author.trim()
      ? rawFrontmatter.author.trim()
      : "Forma Team";

  return {
    slug,
    title,
    description,
    publishedAt,
    updatedAt,
    author,
    tags,
    faqPairs: normalizeFaqPairs(rawFrontmatter.faqPairs),
  };
}

async function readBlogFile(slug: string) {
  const filePath = path.join(BLOG_CONTENT_DIR, `${slug}.mdx`);
  const file = await fs.readFile(filePath, "utf8");
  const parsed = matter(file);
  const frontmatter = normalizeFrontmatter(
    parsed.data as Record<string, unknown>,
    slug
  );

  return {
    slug: frontmatter.slug,
    frontmatter,
    markdownContent: parsed.content,
  };
}

export async function getAllBlogSlugs() {
  const files = await fs.readdir(BLOG_CONTENT_DIR, { withFileTypes: true });
  return files
    .filter((file) => file.isFile() && file.name.endsWith(".mdx"))
    .map((file) => file.name.replace(/\.mdx$/, ""));
}

export async function getAllBlogPosts(): Promise<BlogPostSummary[]> {
  const slugs = await getAllBlogSlugs();

  const posts = await Promise.all(
    slugs.map(async (slug) => {
      const { frontmatter, markdownContent } = await readBlogFile(slug);
      return {
        ...frontmatter,
        canonical: toCanonical(frontmatter.slug),
        readingTimeMinutes: estimateReadingTimeMinutes(markdownContent),
      };
    })
  );

  return posts.sort(
    (a, b) =>
      new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime()
  );
}

export async function getBlogPostBySlug(slug: string): Promise<BlogPost | null> {
  try {
    const { frontmatter, markdownContent } = await readBlogFile(slug);
    const compiled = await compileMDX({
      source: markdownContent,
      options: {
        parseFrontmatter: false,
        mdxOptions: {
          remarkPlugins: [remarkGfm],
        },
      },
    });

    return {
      ...frontmatter,
      canonical: toCanonical(frontmatter.slug),
      readingTimeMinutes: estimateReadingTimeMinutes(markdownContent),
      content: compiled.content,
    };
  } catch {
    return null;
  }
}

export async function getRelatedBlogPosts(slug: string, limit = 2) {
  const allPosts = await getAllBlogPosts();
  const current = allPosts.find((post) => post.slug === slug);

  if (!current) {
    return allPosts.slice(0, limit);
  }

  const currentTags = new Set(current.tags);
  const ranked = allPosts
    .filter((post) => post.slug !== slug)
    .map((post) => ({
      post,
      score: post.tags.reduce(
        (sum, tag) => (currentTags.has(tag) ? sum + 1 : sum),
        0
      ),
    }))
    .sort((a, b) => b.score - a.score)
    .map((entry) => entry.post);

  return ranked.slice(0, limit);
}

