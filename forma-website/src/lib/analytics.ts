export type AnalyticsEventName =
  | "download_click"
  | "newsletter_submit_success"
  | "support_contact_click"
  | "blog_cta_click";

type AnalyticsProps = Record<string, string | number | boolean>;

declare global {
  interface Window {
    plausible?: (eventName: string, options?: { props?: AnalyticsProps }) => void;
  }
}

export function trackEvent(
  eventName: AnalyticsEventName,
  props?: AnalyticsProps
) {
  if (typeof window === "undefined") return;
  if (typeof window.plausible !== "function") return;

  if (props && Object.keys(props).length > 0) {
    window.plausible(eventName, { props });
    return;
  }

  window.plausible(eventName);
}

