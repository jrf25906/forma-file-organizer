import { MAC_APP_STORE_URL } from "@/lib/links";
import { faqs } from "@/lib/faq";
import { PUBLIC_API_VERSION, WEBSITE_LAST_UPDATED_ISO } from "@/lib/site";

export const publicProduct = {
  name: "Forma",
  tagline: "Give your files form",
  platform: "macOS 14+",
  price_usd: 29,
  purchase_url: MAC_APP_STORE_URL,
  last_updated: WEBSITE_LAST_UPDATED_ISO,
};

export const publicFaqItems = faqs.map((faq) => ({
  id: faq.id,
  question: faq.question,
  answer: faq.answer,
  category: faq.category,
  last_updated: faq.lastUpdated,
}));

export function createApiEnvelope<T>(data: T) {
  return {
    version: PUBLIC_API_VERSION,
    data,
  };
}

