#!/bin/bash
# export_paper_screenshots.sh
#
# Documents and validates the Paper screenshot export process.
#
# Paper screenshots must be exported manually from Paper's UI since the
# MCP tool returns image data inline rather than writing files to disk.
#
# MANUAL EXPORT STEPS:
# ===================
# 1. Open "Forma App Store Screenshots" in Paper
# 2. For each artboard, export at 2x scale as PNG:
#
#    Artboard                         -> Filename
#    ─────────────────────────────────────────────────────────────
#    Screenshot 1 – Hero     (1-0)   -> forma-paper-01-hero.png
#    Screenshot 2 – Rules    (6K-0)  -> forma-paper-02-rules.png
#    Screenshot 3 – Preview  (7S-0)  -> forma-paper-03-preview.png
#    Screenshot 4 – Before/After (9W-0) -> forma-paper-04-before-after.png
#
# 3. Save all exports to:
#    Docs/Marketing/Screenshots/AppStore/Upload/Dark/
#
# 4. Run this script to validate dimensions and format.
#
# Each exported image must be 2880x1800 pixels (1440x900 artboard at 2x).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCREENSHOT_DIR="$PROJECT_ROOT/Docs/Marketing/Screenshots/AppStore/Upload/Dark"

EXPECTED_WIDTH=2880
EXPECTED_HEIGHT=1800

PAPER_SCREENSHOTS=(
    "forma-paper-01-hero.png"
    "forma-paper-02-rules.png"
    "forma-paper-03-preview.png"
    "forma-paper-04-before-after.png"
)

echo "Validating Paper screenshot exports..."
echo "Directory: $SCREENSHOT_DIR"
echo "Expected dimensions: ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT}"
echo ""

PASS=0
FAIL=0

for filename in "${PAPER_SCREENSHOTS[@]}"; do
    filepath="$SCREENSHOT_DIR/$filename"

    if [ ! -f "$filepath" ]; then
        echo "  MISSING  $filename"
        echo "           Export from Paper at 2x scale and save here."
        FAIL=$((FAIL + 1))
        continue
    fi

    width=$(sips -g pixelWidth "$filepath" 2>/dev/null | tail -1 | awk '{print $2}')
    height=$(sips -g pixelHeight "$filepath" 2>/dev/null | tail -1 | awk '{print $2}')
    size=$(stat -f%z "$filepath" 2>/dev/null || echo "?")
    size_kb=$((size / 1024))

    if [ "$width" = "$EXPECTED_WIDTH" ] && [ "$height" = "$EXPECTED_HEIGHT" ]; then
        echo "  PASS  $filename (${width}x${height}, ${size_kb} KB)"
        PASS=$((PASS + 1))
    else
        echo "  FAIL  $filename — ${width}x${height} (expected ${EXPECTED_WIDTH}x${EXPECTED_HEIGHT})"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed out of ${#PAPER_SCREENSHOTS[@]} screenshots."

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Fix the issues above, then run:"
    echo "  bash Scripts/prepare_fastlane_screenshots.sh"
    echo "  fastlane mac screenshots"
    exit 1
else
    echo ""
    echo "All Paper screenshots validated. Ready for:"
    echo "  bash Scripts/prepare_fastlane_screenshots.sh"
    echo "  fastlane mac screenshots"
fi
