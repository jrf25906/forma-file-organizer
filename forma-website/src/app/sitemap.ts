import type { MetadataRoute } from "next";
import { getAllBlogPosts } from "@/lib/content";
import { SITE_URL, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

const PRIVACY_LAST_MODIFIED_ISO = "2026-02-04T00:00:00.000Z";
const TERMS_LAST_MODIFIED_ISO = "2026-02-04T00:00:00.000Z";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const blogPosts = await getAllBlogPosts();

  const sitemapEntries: MetadataRoute.Sitemap = [
    {
      url: SITE_URL,
      lastModified: new Date(WEBSITE_LAST_UPDATED_ISO),
      changeFrequency: "weekly",
      priority: 1,
    },
    {
      url: `${SITE_URL}/blog`,
      lastModified: new Date(WEBSITE_LAST_UPDATED_ISO),
      changeFrequency: "weekly",
      priority: 0.8,
    },
    {
      url: `${SITE_URL}/for-agents`,
      lastModified: new Date(WEBSITE_LAST_UPDATED_ISO),
      changeFrequency: "monthly",
      priority: 0.6,
    },
    {
      url: `${SITE_URL}/privacy`,
      lastModified: new Date(PRIVACY_LAST_MODIFIED_ISO),
      changeFrequency: "yearly",
      priority: 0.3,
    },
    {
      url: `${SITE_URL}/terms`,
      lastModified: new Date(TERMS_LAST_MODIFIED_ISO),
      changeFrequency: "yearly",
      priority: 0.3,
    },
    {
      url: `${SITE_URL}/support`,
      lastModified: new Date(WEBSITE_LAST_UPDATED_ISO),
      changeFrequency: "monthly",
      priority: 0.5,
    },
  ];

  const postEntries: MetadataRoute.Sitemap = blogPosts.map((post) => ({
    url: `${SITE_URL}/blog/${post.slug}`,
    lastModified: new Date(post.updatedAt),
    changeFrequency: "monthly",
    priority: 0.7,
  }));

  return [...sitemapEntries, ...postEntries];
}

