export const SITE_NAME = "Forma";
export const SITE_URL = "https://formafiles.com";
export const SITE_TAGLINE = "A file organizer for people who gave up on file organizers.";
export const SUPPORT_EMAIL = "hello@formafiles.com";

export const WEBSITE_LAST_UPDATED_ISO = "2026-02-11T00:00:00.000Z";

export type SeoMeta = {
  title: string;
  description: string;
  canonical: string;
  ogImage?: string;
  noindex?: boolean;
};

export type PublicApiVersion = "v1";
export const PUBLIC_API_VERSION: PublicApiVersion = "v1";
