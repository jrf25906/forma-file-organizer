#!/usr/bin/env bash
set -euo pipefail

if ! command -v periphery >/dev/null 2>&1; then
  echo "Periphery is not installed."
  echo "Install: brew install peripheryapp/periphery/periphery"
  exit 1
fi

periphery scan \
  --project "Forma File Organizing.xcodeproj" \
  --schemes "Forma File Organizing" \
  --targets "Forma File Organizing" \
  --retain-public
