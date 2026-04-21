import { describe, expect, it } from "vitest";
import { shouldAnimateScribe } from "../src/components/animation/ScribeLine";

describe("shouldAnimateScribe", () => {
  it("returns false when the user prefers reduced motion", () => {
    expect(shouldAnimateScribe({ reducedMotion: true })).toBe(false);
  });

  it("returns true otherwise", () => {
    expect(shouldAnimateScribe({ reducedMotion: false })).toBe(true);
  });
});
