# Tmux Monitor

Local-first macOS menu bar app with a WidgetKit extension for monitoring tmux sessions on the current machine.

## What It Does

- monitors all local tmux sessions from the menu bar
- shows a compact desktop widget summary
- supports quick actions for `attach`, `create session`, and `kill session`
- caches the latest snapshot into an App Group so the widget can render without running tmux itself

## Project Layout

- `Shared/Core/`: tmux snapshot models, command runner, aggregation service, shared snapshot cache
- `TmuxMonitorApp/`: SwiftUI menu bar app and quick actions
- `TmuxMonitorWidget/TmuxMonitorWidgetExtension/`: WidgetKit extension
- `Tests/TmuxMonitorCoreHarness.swift`: direct core verification harness used on machines where SwiftPM is unavailable

## Requirements

- macOS 14+
- complete Xcode installation
- local `tmux` binary

The current machine only has Command Line Tools active, not full Xcode, so `.app + widget` builds were prepared structurally but not executed end-to-end here.

## Open The Project

1. Install full Xcode and switch the active developer directory if needed:

   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

2. Open the project:

   ```bash
   open /Users/susiwen8/Documents/apps/tmux-monitor/TmuxMonitor.xcodeproj
   ```

3. In Xcode, set a signing team for both targets.
4. Keep the App Group capability aligned with `group.local.tmuxmonitor` in both targets.
5. Build and run `TmuxMonitorApp`.
6. Add the widget from the desktop or Notification Center once the app has written its first snapshot.

## Verification Commands

Core harness:

```bash
swiftc Shared/Core/*.swift Tests/TmuxMonitorCoreHarness.swift -o /tmp/tmux-monitor-core-harness && /tmp/tmux-monitor-core-harness
```

App source typecheck:

```bash
swiftc -typecheck -target arm64-apple-macos14.0 -framework SwiftUI -framework WidgetKit Shared/Core/*.swift TmuxMonitorApp/*.swift TmuxMonitorApp/Views/*.swift TmuxMonitorApp/Support/*.swift
```

Widget source typecheck:

```bash
swiftc -typecheck -target arm64-apple-macos14.0 -framework SwiftUI -framework WidgetKit Shared/Core/*.swift TmuxMonitorWidget/TmuxMonitorWidgetExtension/*.swift
```

Repository verification:

```bash
./scripts/verify.sh
```

Release packaging:

```bash
./scripts/package_release.sh
```

## CI And Release

- `CI`: `.github/workflows/ci.yml`
  Runs on every push to `main` and on pull requests.
  It executes the core harness and an unsigned `xcodebuild` verification build on `macos-14`.

- `Release`: `.github/workflows/release.yml`
  Runs when a tag like `v0.1.0` is pushed, or manually through `workflow_dispatch`.
  It verifies the repo, builds an unsigned Release app, zips `Tmux Monitor.app`, generates a SHA-256 checksum, uploads workflow artifacts, and creates a GitHub Release.

### Release Checklist

1. Update `VERSION`
2. Add a matching section to `CHANGELOG.md`
3. Commit the release changes
4. Tag the commit:

   ```bash
   git tag v$(tr -d '[:space:]' < VERSION)
   git push origin main --tags
   ```

The release workflow expects the git tag to match `VERSION` exactly.

## Notes

- The app is configured for local use, not Mac App Store distribution.
- `Terminal` and `iTerm` attach flows use Apple Events via `osascript`.
- If the widget stays empty, verify signing, App Group entitlement alignment, and that the app has refreshed at least once.
