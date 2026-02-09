const PLACEHOLDER_MAC_APP_STORE_URL = "https://apps.apple.com/app/forma/id0000000000";

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

export const MAC_APP_STORE_LINK_PROPS =
  MAC_APP_STORE_URL.startsWith("http")
    ? ({ target: "_blank", rel: "noopener noreferrer" } as const)
    : ({} as const);
