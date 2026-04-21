import { describe, expect, it } from "vitest";
import { formatFolioRevision } from "../src/lib/folio";

describe("formatFolioRevision", () => {
  it("formats an ISO date as MM·DD", () => {
    expect(formatFolioRevision("2026-04-20T00:00:00Z")).toBe("04·20");
  });

  it("zero-pads single-digit months and days", () => {
    expect(formatFolioRevision("2026-01-05T00:00:00Z")).toBe("01·05");
  });

  it("falls back to a stable placeholder on invalid input", () => {
    expect(formatFolioRevision("not-a-date")).toBe("—·—");
  });
});
