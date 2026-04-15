#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_DIR="${RUNNER_TEMP:-/tmp}/tmux-monitor-derived-data"
SWIFT_VERSION_OVERRIDE="${SWIFT_VERSION_OVERRIDE:-5.0}"

cd "$ROOT_DIR"

echo "==> Running core harness"
swiftc Shared/Core/*.swift Tests/TmuxMonitorCoreHarness.swift -o /tmp/tmux-monitor-core-harness
/tmp/tmux-monitor-core-harness

echo "==> Running app harness"
swiftc -framework WidgetKit \
  Shared/Core/*.swift \
  TmuxMonitorApp/AppState.swift \
  TmuxMonitorApp/Support/TerminalLauncher.swift \
  Tests/TmuxMonitorAppHarness.swift \
  -o /tmp/tmux-monitor-app-harness
/tmp/tmux-monitor-app-harness

echo "==> Building app with xcodebuild"
rm -rf "$DERIVED_DATA_DIR"
xcodebuild \
  -project "$ROOT_DIR/TmuxMonitor.xcodeproj" \
  -scheme TmuxMonitorApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  SWIFT_VERSION="$SWIFT_VERSION_OVERRIDE" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Verification complete"
