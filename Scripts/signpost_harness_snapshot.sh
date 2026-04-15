#!/usr/bin/env bash
set -euo pipefail

PROJECT="Forma File Organizing.xcodeproj"
SCHEME="Forma File Organizing"
CONFIGURATION="Debug"
APP_TARGET=""
APP_EXECUTABLE=""
WARMUP=3
ITERATIONS=60
TIME_LIMIT_SECONDS=75
OUTPUT_PREFIX="/tmp/forma-signpost-harness"
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: Scripts/signpost_harness_snapshot.sh [options]

Runs the debug signpost harness, exports xctrace data, and computes summary stats.

Options:
  --project <path>          Xcode project path (default: "Forma File Organizing.xcodeproj")
  --scheme <name>           Scheme name (default: "Forma File Organizing")
  --configuration <name>    Build configuration (default: Debug)
  --target <name>           App target name (default: same as scheme)
  --app <executable_path>   Explicit app executable path (.../App.app/Contents/MacOS/<name>)
  --warmup <n>              Warm-up iterations (default: 3)
  --iterations <n>          Sample iterations (default: 60)
  --time-limit <seconds>    xctrace record time limit (default: 75)
  --output-prefix <path>    Prefix for trace/export files (default: /tmp/forma-signpost-harness)
  --skip-build              Skip xcodebuild step when --app is provided
  -h, --help                Show this help

Example:
  Scripts/signpost_harness_snapshot.sh --iterations 60 --warmup 3 --time-limit 75 \
    --output-prefix /tmp/forma-signpost-harness-60
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --target)
      APP_TARGET="$2"
      shift 2
      ;;
    --app)
      APP_EXECUTABLE="$2"
      shift 2
      ;;
    --warmup)
      WARMUP="$2"
      shift 2
      ;;
    --iterations)
      ITERATIONS="$2"
      shift 2
      ;;
    --time-limit)
      TIME_LIMIT_SECONDS="$2"
      shift 2
      ;;
    --output-prefix)
      OUTPUT_PREFIX="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required but not found." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is required but not found." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found." >&2
  exit 1
fi

if [[ -z "$APP_TARGET" ]]; then
  APP_TARGET="$SCHEME"
fi

if [[ -z "$APP_EXECUTABLE" ]]; then
  if [[ "$SKIP_BUILD" -eq 0 ]]; then
    echo "Building app: $SCHEME ($CONFIGURATION)"
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" build >/tmp/forma-signpost-build.log
  fi

  BUILD_SETTINGS=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" -showBuildSettings)
  TARGET_SETTINGS=$(printf '%s\n' "$BUILD_SETTINGS" | awk -v target="$APP_TARGET" '
    {
      normalized=$0
      gsub(/"/, "", normalized)
    }
    normalized ~ "Build settings for action build and target " target ":" {capture=1; next}
    normalized ~ /^Build settings for action build and target / && capture {capture=0}
    capture {print}
  ')

  SETTINGS_SOURCE="$TARGET_SETTINGS"
  if [[ -z "$SETTINGS_SOURCE" ]]; then
    SETTINGS_SOURCE="$BUILD_SETTINGS"
  fi

  BUILT_PRODUCTS_DIR=$(printf '%s\n' "$SETTINGS_SOURCE" | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / {print $2; exit}')
  FULL_PRODUCT_NAME=$(printf '%s\n' "$SETTINGS_SOURCE" | awk -F' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / {print $2; exit}')
  EXECUTABLE_NAME=$(printf '%s\n' "$SETTINGS_SOURCE" | awk -F' = ' '/^[[:space:]]*EXECUTABLE_NAME = / {print $2; exit}')

  if [[ -z "$BUILT_PRODUCTS_DIR" || -z "$FULL_PRODUCT_NAME" || -z "$EXECUTABLE_NAME" ]]; then
    echo "Failed to resolve app build settings for target '$APP_TARGET'." >&2
    exit 1
  fi

  APP_EXECUTABLE="$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME/Contents/MacOS/$EXECUTABLE_NAME"
fi

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  echo "App executable not found or not executable: $APP_EXECUTABLE" >&2
  exit 1
fi

APP_BUNDLE="$(cd "$(dirname "$APP_EXECUTABLE")/../.." && pwd)"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"
if [[ ! -f "$INFO_PLIST" ]]; then
  echo "Info.plist not found for app bundle: $APP_BUNDLE" >&2
  exit 1
fi

BUNDLE_IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST" 2>/dev/null || true)
if [[ -z "$BUNDLE_IDENTIFIER" ]]; then
  echo "Failed to resolve CFBundleIdentifier from: $INFO_PLIST" >&2
  exit 1
fi

TRACE_OUTPUT="${OUTPUT_PREFIX}.trace"
TOC_XML="${OUTPUT_PREFIX}-toc.xml"
INTERVALS_XML="${OUTPUT_PREFIX}-intervals.xml"
SIGNPOSTS_XML="${OUTPUT_PREFIX}-signposts.xml"
EVENTS_JSONL="${OUTPUT_PREFIX}-events.jsonl"
APP_EVENTS_DIR="$HOME/Library/Containers/$BUNDLE_IDENTIFIER/Data/tmp"
APP_EVENTS_JSONL="$APP_EVENTS_DIR/$(basename "$EVENTS_JSONL")"
SUMMARY_JSON="${OUTPUT_PREFIX}-summary.json"
SUMMARY_MD="${OUTPUT_PREFIX}-summary.md"

mkdir -p "$(dirname "$OUTPUT_PREFIX")"
mkdir -p "$APP_EVENTS_DIR"

rm -rf "$TRACE_OUTPUT" "$TOC_XML" "$INTERVALS_XML" "$SIGNPOSTS_XML" "$EVENTS_JSONL" "$APP_EVENTS_JSONL" "$SUMMARY_JSON" "$SUMMARY_MD"

echo "Recording signpost trace..."
set +e
xcrun xctrace record \
  --template 'Logging' \
  --output "$TRACE_OUTPUT" \
  --time-limit "${TIME_LIMIT_SECONDS}s" \
  --no-prompt \
  --launch \
  -- /bin/bash -lc 'exec "$0" --perf-harness-warmup "$1" --perf-harness-iterations "$2" --perf-harness-events-file "$3" --perf-signpost-harness' \
  "$APP_EXECUTABLE" \
  "$WARMUP" \
  "$ITERATIONS" \
  "$APP_EVENTS_JSONL"
RECORD_EXIT=$?
set -e

if [[ "$RECORD_EXIT" -ne 0 && "$RECORD_EXIT" -ne 54 ]]; then
  echo "xctrace record failed with exit code $RECORD_EXIT" >&2
  exit "$RECORD_EXIT"
fi

if [[ -f "$APP_EVENTS_JSONL" ]]; then
  cp "$APP_EVENTS_JSONL" "$EVENTS_JSONL"
fi

echo "Exporting trace metadata..."
xcrun xctrace export --input "$TRACE_OUTPUT" --toc >"$TOC_XML"

read -r INTERVAL_TABLE_INDEX SIGNPOST_TABLE_INDEX < <(
  python3 - "$TOC_XML" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
tables = root.findall("./run/data/table")
interval_index = -1
signpost_index = -1

for idx, table in enumerate(tables, start=1):
    schema = table.attrib.get("schema", "")
    if schema == "os-signpost-interval" and interval_index == -1:
        interval_index = idx
    if schema == "os-signpost" and signpost_index == -1:
        signpost_index = idx

print(interval_index, signpost_index)
PY
)

if [[ "$INTERVAL_TABLE_INDEX" -le 0 ]]; then
  printf '<trace-data />\n' >"$INTERVALS_XML"
else
  echo "Exporting intervals (table ${INTERVAL_TABLE_INDEX})..."
  xcrun xctrace export \
    --input "$TRACE_OUTPUT" \
    --output "$INTERVALS_XML" \
    --xpath "//trace-toc[1]/run[1]/data[1]/table[${INTERVAL_TABLE_INDEX}]"
fi

if [[ "$SIGNPOST_TABLE_INDEX" -gt 0 ]]; then
  echo "Exporting signposts (table ${SIGNPOST_TABLE_INDEX})..."
  xcrun xctrace export \
    --input "$TRACE_OUTPUT" \
    --output "$SIGNPOSTS_XML" \
    --xpath "//trace-toc[1]/run[1]/data[1]/table[${SIGNPOST_TABLE_INDEX}]"
fi

echo "Computing summary stats..."
python3 - "$INTERVALS_XML" "$SUMMARY_JSON" "$SUMMARY_MD" "$WARMUP" "$ITERATIONS" "$EVENTS_JSONL" <<'PY'
import json
import re
import statistics
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

intervals_xml = Path(sys.argv[1])
summary_json = Path(sys.argv[2])
summary_md = Path(sys.argv[3])
requested_warmup = int(sys.argv[4])
requested_iterations = int(sys.argv[5])
events_jsonl = Path(sys.argv[6])

records = []

if events_jsonl.exists() and events_jsonl.stat().st_size > 0:
    for line in events_jsonl.read_text().splitlines():
        if not line.strip():
            continue
        record = json.loads(line)
        records.append({
            "event": record["event"],
            "kind": record["kind"],
            "index": int(record["index"]),
            "start_ns": int(record["startedAtNs"]),
            "duration_ms": float(record["durationMs"])
        })
else:
    root = ET.parse(intervals_xml).getroot()
    for node in root.findall("node"):
        id_fmt = {}
        for elem in node.iter():
            elem_id = elem.attrib.get("id")
            elem_fmt = elem.attrib.get("fmt")
            if elem_id is not None and elem_fmt is not None:
                id_fmt[elem_id] = elem_fmt

        for row in node.findall("row"):
            duration_elem = row.find("duration")
            start_elem = row.find("start-time")
            meta_elem = row.find("os-log-metadata")
            if duration_elem is None or start_elem is None or meta_elem is None:
                continue
            if duration_elem.text is None or start_elem.text is None:
                continue

            try:
                duration_ms = int(duration_elem.text) / 1_000_000
                start_ns = int(start_elem.text)
            except ValueError:
                continue

            start_message = meta_elem.attrib.get("fmt")
            if start_message is None:
                ref = meta_elem.attrib.get("ref")
                if ref is not None:
                    start_message = id_fmt.get(ref)
            if not start_message:
                continue

            event_match = re.search(r"\[\s*(DashboardScanRefresh|DefaultPanelInsightRefresh)\s*\]", start_message)
            kind_match = re.search(r"harness\s+(warmup|sample)\s+(\d+)", start_message)
            if not event_match or not kind_match:
                continue

            records.append({
                "event": event_match.group(1),
                "kind": kind_match.group(1),
                "index": int(kind_match.group(2)),
                "start_ns": start_ns,
                "duration_ms": duration_ms
            })

# Keep earliest row for each logical harness index.
deduped = {}
for record in sorted(records, key=lambda item: item["start_ns"]):
    key = (record["event"], record["kind"], record["index"])
    if key not in deduped:
        deduped[key] = record

def percentile_nearest(values, percentile):
    sorted_values = sorted(values)
    if not sorted_values:
        return None
    rank = int((percentile * len(sorted_values)) + 0.9999999999)
    rank = max(1, min(rank, len(sorted_values)))
    return sorted_values[rank - 1]

def summarize(values):
    if not values:
        return None
    sorted_values = sorted(values)
    return {
        "count": len(sorted_values),
        "min_ms": sorted_values[0],
        "p50_ms": percentile_nearest(sorted_values, 0.50),
        "p95_ms": percentile_nearest(sorted_values, 0.95),
        "p99_ms": percentile_nearest(sorted_values, 0.99),
        "mean_ms": statistics.fmean(sorted_values),
        "max_ms": sorted_values[-1]
    }

events = ["DashboardScanRefresh", "DefaultPanelInsightRefresh"]
summary = {
    "requested": {
        "warmup_iterations": requested_warmup,
        "sample_iterations": requested_iterations
    },
    "events": {}
}

for event_name in events:
    warmup_values = [
        item["duration_ms"]
        for key, item in deduped.items()
        if key[0] == event_name and key[1] == "warmup"
    ]
    sample_values = [
        item["duration_ms"]
        for key, item in deduped.items()
        if key[0] == event_name and key[1] == "sample"
    ]
    combined_values = warmup_values + sample_values

    event_summary = {
        "warmup": summarize(warmup_values),
        "sample": summarize(sample_values),
        "combined": summarize(combined_values)
    }
    if event_summary["combined"] and event_summary["sample"]:
        event_summary["p95_delta_ms"] = (
            event_summary["sample"]["p95_ms"] - event_summary["combined"]["p95_ms"]
        )
    summary["events"][event_name] = event_summary

summary_json.write_text(json.dumps(summary, indent=2))

def fmt(value):
    if value is None:
        return "n/a"
    return f"{value:.3f}"

lines = []
lines.append("# Signpost Harness Summary")
lines.append("")
lines.append(f"- Requested warmup iterations: `{requested_warmup}`")
lines.append(f"- Requested sample iterations: `{requested_iterations}`")
lines.append("")
lines.append("| Operation | Sample Count | Min (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Mean (ms) | Max (ms) |")
lines.append("|-----------|--------------|----------|----------|----------|----------|-----------|----------|")
for event_name in events:
    sample_summary = summary["events"][event_name]["sample"]
    if sample_summary is None:
        lines.append(f"| `{event_name}` | 0 | n/a | n/a | n/a | n/a | n/a | n/a |")
        continue
    lines.append(
        f"| `{event_name}` | {sample_summary['count']} | {fmt(sample_summary['min_ms'])} | "
        f"{fmt(sample_summary['p50_ms'])} | {fmt(sample_summary['p95_ms'])} | {fmt(sample_summary['p99_ms'])} | "
        f"{fmt(sample_summary['mean_ms'])} | {fmt(sample_summary['max_ms'])} |"
    )

lines.append("")
lines.append("| Operation | P95 (warmup+sample) | P95 (sample-only) | Delta (ms) |")
lines.append("|-----------|----------------------|-------------------|------------|")
for event_name in events:
    event_summary = summary["events"][event_name]
    combined = event_summary["combined"]
    sample = event_summary["sample"]
    delta = event_summary.get("p95_delta_ms")
    lines.append(
        f"| `{event_name}` | {fmt(combined['p95_ms']) if combined else 'n/a'} | "
        f"{fmt(sample['p95_ms']) if sample else 'n/a'} | {fmt(delta)} |"
    )

summary_md.write_text("\n".join(lines) + "\n")

print("\n".join(lines))
PY

echo ""
echo "Outputs:"
echo "  Trace:        $TRACE_OUTPUT"
echo "  TOC XML:      $TOC_XML"
echo "  Intervals:    $INTERVALS_XML"
if [[ -f "$SIGNPOSTS_XML" ]]; then
  echo "  Signposts:    $SIGNPOSTS_XML"
fi
if [[ -f "$EVENTS_JSONL" ]]; then
  echo "  Events JSONL: $EVENTS_JSONL"
fi
echo "  Summary JSON: $SUMMARY_JSON"
echo "  Summary MD:   $SUMMARY_MD"
