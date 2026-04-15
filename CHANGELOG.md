# Changelog

## 0.1.3 - 2026-04-15

### Fixes
- Keep live tmux sessions actionable by switching attached rows from `Attach` to `Detach`.
- Preserve detach confirmations after refresh so session actions do not disappear immediately.

### UI
- Compress the menu header and return more vertical space to the live session list.
- Rework session rows so status, activity, and primary actions stay readable without horizontal crowding.

### Tooling
- Add an app-level harness to verify attach/detach button behavior and include it in `scripts/verify.sh`.

## 0.1.2 - 2026-04-13

### Fixes
- Prevent relaunching the menu bar app from collapsing live tmux sessions into an empty snapshot.

### UI
- Tighten the menu bar session rows so more session data fits in a single line.

## 0.1.1 - 2026-04-12

### Tooling
- Fixed the GitHub Actions release workflow to use GitHub-supported shells on hosted runners.

## 0.1.0 - 2026-04-12

### Features
- Initial public release of the macOS menu bar tmux monitor.
- Added a WidgetKit extension backed by the shared snapshot store.
- Added menu bar quick actions for attach and session termination.

### Tooling
- Added reusable local verification and release packaging scripts.
- Added GitHub Actions CI for core verification and unsigned Xcode builds.
- Added tag-driven GitHub Release automation with packaged macOS artifacts.
