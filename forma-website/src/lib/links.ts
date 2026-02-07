const PLACEHOLDER_MAC_APP_STORE_URL = "https://apps.apple.com/app/forma/id0000000000";

const configuredMacAppStoreUrl = process.env.NEXT_PUBLIC_MAC_APP_STORE_URL?.trim();

export const MAC_APP_STORE_URL =
  configuredMacAppStoreUrl &&
  configuredMacAppStoreUrl !== PLACEHOLDER_MAC_APP_STORE_URL
    ? configuredMacAppStoreUrl
    : "/support";

export const MAC_APP_STORE_LINK_PROPS =
  MAC_APP_STORE_URL.startsWith("http")
    ? ({ target: "_blank", rel: "noopener noreferrer" } as const)
    : ({} as const);
