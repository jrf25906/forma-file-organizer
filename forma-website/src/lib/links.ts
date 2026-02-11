const PLACEHOLDER_MAC_APP_STORE_URL = "https://apps.apple.com/app/forma/id0000000000";

export type AppStoreLinkLocation =
  | "header_mobile"
  | "header_desktop"
  | "header_menu"
  | "hero_primary"
  | "pricing_primary"
  | "blog_inline";

const configuredMacAppStoreUrl = process.env.NEXT_PUBLIC_MAC_APP_STORE_URL?.trim();

const resolvedMacAppStoreUrl =
  configuredMacAppStoreUrl &&
  configuredMacAppStoreUrl !== PLACEHOLDER_MAC_APP_STORE_URL
    ? configuredMacAppStoreUrl
    : "/support";

if (resolvedMacAppStoreUrl === "/support") {
  console.warn(
    "[Forma] NEXT_PUBLIC_MAC_APP_STORE_URL is not configured. CTA buttons will link to /support."
  );
}

export const MAC_APP_STORE_URL = resolvedMacAppStoreUrl;
export const IS_APP_STORE_URL_CONFIGURED = MAC_APP_STORE_URL.startsWith("http");

export function getMacAppStoreUrl(location: AppStoreLinkLocation) {
  if (!IS_APP_STORE_URL_CONFIGURED) {
    return MAC_APP_STORE_URL;
  }

  const url = new URL(MAC_APP_STORE_URL);
  url.searchParams.set("utm_source", "formafiles.com");
  url.searchParams.set("utm_medium", "website");
  url.searchParams.set("utm_campaign", "signup_optimization_2026q1");
  url.searchParams.set("utm_content", location);
  return url.toString();
}

export function getMacAppStoreLinkProps(href: string) {
  return href.startsWith("http")
    ? ({ target: "_blank", rel: "noopener noreferrer" } as const)
    : ({} as const);
}
