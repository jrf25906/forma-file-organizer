#!/usr/bin/env bash
set -euo pipefail

# Captures an App Store-ready screenshot set (Light + Dark) using UI tests.
#
# Output:
#   Docs/Marketing/Screenshots/AppStore/Light/*.png
#   Docs/Marketing/Screenshots/AppStore/Dark/*.png

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

OUT_DIR="$ROOT_DIR/Docs/Marketing/Screenshots/AppStore"
DERIVED_DATA="$ROOT_DIR/DerivedDataAppStoreScreenshots"

mkdir -p "$OUT_DIR/Light" "$OUT_DIR/Dark"

xcodebuild test \
  -project "Forma File Organizing.xcodeproj" \
  -scheme "Forma File Organizing" \
  -testPlan "Forma File Organizing - UI" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  -only-testing:"Forma File OrganizingUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots" \
  | tail -n 60

XCRESULT_PATH="$(ls -td "$DERIVED_DATA/Logs/Test/"*.xcresult 2>/dev/null | head -n 1 || true)"
if [[ -z "${XCRESULT_PATH}" ]]; then
  echo "No .xcresult found in: $DERIVED_DATA/Logs/Test"
  exit 1
fi

TMP_EXPORT_DIR="$(mktemp -d "/tmp/forma-appstore-shots.XXXXXX")"
trap 'rm -rf "${TMP_EXPORT_DIR}"' EXIT
export TMP_EXPORT_DIR OUT_DIR

xcrun xcresulttool export attachments \
  --path "$XCRESULT_PATH" \
  --output-path "$TMP_EXPORT_DIR" >/dev/null

python3 - <<'PY'
import json
import os
import re
from pathlib import Path

export_dir = Path(os.environ["TMP_EXPORT_DIR"])
out_dir = Path(os.environ["OUT_DIR"])

manifest = export_dir / "manifest.json"
data = json.loads(manifest.read_text())

appearance_re = re.compile(r"\s+\((light|dark)\)$", re.IGNORECASE)

def normalize_base(suggested: str) -> tuple[str, str] | None:
    # Example:
    #   "forma-02-all-files-list (dark)_0_<UUID>.png"
    # → base "forma-02-all-files-list", appearance "dark"
    stem = suggested
    if stem.lower().endswith(".png"):
        stem = stem[:-4]
    stem = stem.split("_0_", 1)[0]
    m = appearance_re.search(stem)
    if not m:
        return None
    appearance = m.group(1).lower()
    base = appearance_re.sub("", stem)
    return base, appearance

seen = set()
for suite in data:
    for att in suite.get("attachments", []):
        exported = export_dir / att["exportedFileName"]
        suggested = att.get("suggestedHumanReadableName", exported.name)
        normalized = normalize_base(suggested)
        if not normalized:
            continue
        base, appearance = normalized
        dest_dir = out_dir / ("Light" if appearance == "light" else "Dark")
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{base}.png"
        if dest in seen:
            continue
        dest.write_bytes(exported.read_bytes())
        seen.add(dest)

print(f"Wrote {len(seen)} screenshots to: {out_dir}")
PY

UPLOAD_DIR="$OUT_DIR/Upload"
mkdir -p "$UPLOAD_DIR/Light" "$UPLOAD_DIR/Dark"

# Create Mac App Store upload-ready images at an accepted size (2880×1800).
# Strategy:
# 1) Downscale to fit within 2880px max dimension (preserve aspect ratio)
# 2) Pad to exactly 2880×1800 with a neutral background
for mode in Light Dark; do
  for src in "$OUT_DIR/$mode/"*.png; do
    [[ -f "$src" ]] || continue
    tmp_resized="$TMP_EXPORT_DIR/resized.png"
    dst="$UPLOAD_DIR/$mode/$(basename "$src")"
    sips -Z 2880 "$src" --out "$tmp_resized" >/dev/null 2>&1
    sips -p 1800 2880 --padColor FAFAF8 "$tmp_resized" --out "$dst" >/dev/null 2>&1
  done
done

echo "Wrote screenshots to: $OUT_DIR"
echo "Wrote upload-ready (2880×1800) screenshots to: $UPLOAD_DIR"
