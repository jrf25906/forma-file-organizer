/**
 * Analytics Event Infrastructure
 *
 * Provides a lightweight event firing system for analytics tracking.
 * Designed to be SDK-agnostic — fires custom events that can be picked up
 * by any analytics provider (GA4, Mixpanel, Amplitude, etc.).
 *
 * @example Integration with GA4:
 * ```ts
 * window.addEventListener('forma_analytics', (e) => {
 *   const { name, data, timestamp } = e.detail;
 *   gtag('event', name, data);
 * });
 * ```
 *
 * @example Integration with Mixpanel:
 * ```ts
 * window.addEventListener('forma_analytics', (e) => {
 *   mixpanel.track(e.detail.name, e.detail.data);
 * });
 * ```
 */

// ═══════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════

export interface AnalyticsEventData {
  [key: string]: string | number | boolean | undefined;
}

export interface AnalyticsEventDetail {
  name: string;
  data: AnalyticsEventData;
  timestamp: number;
}

export interface FormaAnalyticsEvent extends CustomEvent<AnalyticsEventDetail> {
  type: "forma_analytics";
}

// Predefined event names for type safety
export type AnalyticsEventName =
  | "hero_scroll_milestone"
  | "hero_beat_viewed"
  | "hero_cta_visible"
  | "hero_interaction"
  | "page_view"
  | "cta_click"
  | "feature_view"
  | "scroll_depth";

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════

const ANALYTICS_CONFIG = {
  /** Custom event name dispatched on window */
  eventName: "forma_analytics" as const,
  /** Enable console logging in development */
  debugMode: process.env.NODE_ENV === "development",
  /** Prefix for console logs */
  logPrefix: "[Forma Analytics]",
} as const;

// ═══════════════════════════════════════════════════════════════════════════
// CORE FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Track an analytics event.
 *
 * Fires a custom event on the window object that can be intercepted
 * by any analytics SDK. Also logs to console in development mode.
 *
 * @param name - The event name (use predefined AnalyticsEventName for type safety)
 * @param data - Event payload with key-value pairs
 *
 * @example
 * ```ts
 * trackEvent('hero_scroll_milestone', { milestone: 50, section: 'hero' });
 * ```
 */
export function trackEvent(
  name: AnalyticsEventName | string,
  data: AnalyticsEventData = {}
): void {
  const timestamp = Date.now();
  const eventDetail: AnalyticsEventDetail = {
    name,
    data,
    timestamp,
  };

  // Development logging
  if (ANALYTICS_CONFIG.debugMode) {
    console.log(
      `%c${ANALYTICS_CONFIG.logPrefix}`,
      "color: #4a7c59; font-weight: bold;",
      name,
      data
    );
  }

  // Fire custom event for SDK integration
  if (typeof window !== "undefined") {
    const event = new CustomEvent(ANALYTICS_CONFIG.eventName, {
      detail: eventDetail,
      bubbles: true,
      cancelable: false,
    });
    window.dispatchEvent(event);
  }
}

/**
 * Track a page view event.
 *
 * @param pageName - Name/path of the page
 * @param additionalData - Optional extra data to include
 */
export function trackPageView(
  pageName: string,
  additionalData?: AnalyticsEventData
): void {
  trackEvent("page_view", {
    page: pageName,
    referrer: typeof document !== "undefined" ? document.referrer : undefined,
    ...additionalData,
  });
}

/**
 * Track a CTA click event.
 *
 * @param ctaId - Identifier for the CTA
 * @param ctaText - Text content of the CTA
 * @param location - Where on the page the CTA is located
 */
export function trackCTAClick(
  ctaId: string,
  ctaText: string,
  location: string
): void {
  trackEvent("cta_click", {
    cta_id: ctaId,
    cta_text: ctaText,
    location,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Subscribe to analytics events.
 *
 * Useful for integrating with analytics SDKs or debugging.
 *
 * @param callback - Function called when an analytics event fires
 * @returns Cleanup function to remove the listener
 *
 * @example
 * ```ts
 * const unsubscribe = onAnalyticsEvent((detail) => {
 *   console.log('Event fired:', detail.name, detail.data);
 * });
 *
 * // Later: unsubscribe();
 * ```
 */
export function onAnalyticsEvent(
  callback: (detail: AnalyticsEventDetail) => void
): () => void {
  if (typeof window === "undefined") {
    return () => {};
  }

  const handler = (event: Event) => {
    const customEvent = event as FormaAnalyticsEvent;
    callback(customEvent.detail);
  };

  window.addEventListener(ANALYTICS_CONFIG.eventName, handler);

  return () => {
    window.removeEventListener(ANALYTICS_CONFIG.eventName, handler);
  };
}

/**
 * Create a data attribute object for analytics tracking.
 *
 * These attributes can be used by analytics SDKs for automatic tracking
 * or for debugging purposes.
 *
 * @param trackingId - Unique identifier for the element
 * @param eventName - Event to fire when interacted with
 * @returns Object with data-analytics-* attributes
 *
 * @example
 * ```tsx
 * <button {...analyticsAttributes('hero-cta', 'cta_click')}>
 *   Join Beta
 * </button>
 * ```
 */
export function analyticsAttributes(
  trackingId: string,
  eventName?: AnalyticsEventName | string
): Record<string, string> {
  return {
    "data-analytics-id": trackingId,
    ...(eventName && { "data-analytics-event": eventName }),
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// TYPE AUGMENTATION FOR WINDOW
// ═══════════════════════════════════════════════════════════════════════════

declare global {
  interface WindowEventMap {
    forma_analytics: FormaAnalyticsEvent;
  }
}
