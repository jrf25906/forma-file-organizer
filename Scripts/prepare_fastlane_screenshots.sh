#!/bin/bash
# prepare_fastlane_screenshots.sh
#
# Copies and renames App Store screenshots into the fastlane/screenshots/en-US/
# directory with ordering prefixes for App Store Connect upload.
#
# Screenshot order (Paper-designed marketing screenshots):
#   01 - Hero tagline
#   02 - Rules showcase
#   03 - Preview
#   04 - Before/After

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="$PROJECT_ROOT/Docs/Marketing/Screenshots/AppStore/Upload/Dark"
DEST_DIR="$PROJECT_ROOT/fastlane/screenshots/en-US"

# Verify source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

# Clean destination and recreate
rm -f "$DEST_DIR"/*.png
mkdir -p "$DEST_DIR"

echo "Preparing screenshots for fastlane deliver..."
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo ""

COPIED=0
MISSING=0

copy_screenshot() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ -f "$src" ]; then
        cp "$src" "$dest"
        # Verify dimensions
        local width
        width=$(sips -g pixelWidth "$dest" 2>/dev/null | tail -1 | awk '{print $2}')
        local height
        height=$(sips -g pixelHeight "$dest" 2>/dev/null | tail -1 | awk '{print $2}')

        if [ "$width" = "2880" ] && [ "$height" = "1800" ]; then
            echo "  OK  $label ($width x $height)"
            COPIED=$((COPIED + 1))
        else
            echo "  WARN $label — unexpected dimensions: ${width}x${height} (expected 2880x1800)"
            COPIED=$((COPIED + 1))
        fi
    else
        echo "  SKIP $label — source not found: $(basename "$src")"
        MISSING=$((MISSING + 1))
    fi
}

copy_screenshot \
    "$SOURCE_DIR/forma-paper-01-hero.png" \
    "$DEST_DIR/01_hero.png" \
    "01 Hero"

copy_screenshot \
    "$SOURCE_DIR/forma-paper-02-rules.png" \
    "$DEST_DIR/02_rules.png" \
    "02 Rules"

copy_screenshot \
    "$SOURCE_DIR/forma-paper-03-preview.png" \
    "$DEST_DIR/03_preview.png" \
    "03 Preview"

copy_screenshot \
    "$SOURCE_DIR/forma-paper-04-before-after.png" \
    "$DEST_DIR/04_before_after.png" \
    "04 Before/After"

echo ""
echo "Done. $COPIED screenshots copied, $MISSING skipped."

if [ "$MISSING" -gt 0 ]; then
    echo ""
    echo "Note: Some screenshots were not found. Paper screenshots must be"
    echo "exported manually from Paper at 2x scale before running this script."
    echo "See: Scripts/export_paper_screenshots.sh for instructions."
fi
