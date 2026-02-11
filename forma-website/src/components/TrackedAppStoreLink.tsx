"use client";

import type { MouseEventHandler, ReactNode } from "react";
import {
  type AppStoreLinkLocation,
  getMacAppStoreLinkProps,
  getMacAppStoreUrl,
  IS_APP_STORE_URL_CONFIGURED,
} from "@/lib/links";
import { type AnalyticsEventName, trackEvent } from "@/lib/analytics";

type ExtraEvent = {
  name: AnalyticsEventName;
  props?: Record<string, string | number | boolean>;
};

type TrackedAppStoreLinkProps = {
  className?: string;
  location: AppStoreLinkLocation;
  children: ReactNode;
  onClick?: MouseEventHandler<HTMLAnchorElement>;
  extraEvents?: ExtraEvent[];
};

export function TrackedAppStoreLink({
  className,
  location,
  children,
  onClick,
  extraEvents,
}: TrackedAppStoreLinkProps) {
  const href = getMacAppStoreUrl(location);
  const linkProps = getMacAppStoreLinkProps(href);

  const handleClick: MouseEventHandler<HTMLAnchorElement> = (event) => {
    trackEvent("download_click", {
      location,
      destination: IS_APP_STORE_URL_CONFIGURED ? "app_store" : "get_forma_fallback",
    });

    extraEvents?.forEach((extra) => {
      trackEvent(extra.name, extra.props);
    });

    onClick?.(event);
  };

  return (
    <a href={href} className={className} onClick={handleClick} {...linkProps}>
      {children}
    </a>
  );
}
