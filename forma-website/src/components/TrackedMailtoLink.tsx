"use client";

import type { ReactNode } from "react";
import { trackEvent } from "@/lib/analytics";

type TrackedMailtoLinkProps = {
  className?: string;
  email: string;
  location: string;
  children: ReactNode;
};

export function TrackedMailtoLink({
  className,
  email,
  location,
  children,
}: TrackedMailtoLinkProps) {
  return (
    <a
      className={className}
      href={`mailto:${email}`}
      onClick={() => trackEvent("support_contact_click", { location })}
    >
      {children}
    </a>
  );
}

