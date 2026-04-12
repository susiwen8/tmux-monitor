#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-${RUNNER_TEMP:-/tmp}/tmux-monitor-release-derived-data}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
CONFIGURATION="${CONFIGURATION:-Release}"
SWIFT_VERSION_OVERRIDE="${SWIFT_VERSION_OVERRIDE:-5.0}"
APP_NAME="Tmux Monitor.app"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME"
ZIP_PATH="$OUTPUT_DIR/tmux-monitor-${VERSION}.zip"
CHECKSUM_PATH="$OUTPUT_DIR/tmux-monitor-${VERSION}-sha256.txt"

cd "$ROOT_DIR"

rm -rf "$DERIVED_DATA_DIR" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "==> Building $APP_NAME ($CONFIGURATION)"
xcodebuild \
  -project "$ROOT_DIR/TmuxMonitor.xcodeproj" \
  -scheme TmuxMonitorApp \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  SWIFT_VERSION="$SWIFT_VERSION_OVERRIDE" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Packaging release artifact"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$CHECKSUM_PATH"

echo "Artifact: $ZIP_PATH"
echo "Checksum: $CHECKSUM_PATH"
