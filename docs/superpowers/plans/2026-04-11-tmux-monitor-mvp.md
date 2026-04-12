# Tmux Monitor MVP Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local-first macOS menu bar app with a widget that summarizes tmux sessions and supports attach, create session, and kill session actions.

**Architecture:** A shared Swift core loads and caches tmux snapshots. The menu bar app owns polling and quick actions. The widget reads the cached snapshot from shared storage and renders a compact summary.

**Tech Stack:** Swift 6, SwiftUI, WidgetKit, Foundation, direct `swiftc` verification harness, Xcode project

---

## Chunk 1: Shared Core

### Task 1: Snapshot models and polling service

**Files:**
- Create: `Shared/Core/AppConstants.swift`
- Create: `Shared/Core/TmuxSnapshot.swift`
- Create: `Shared/Core/TmuxCommandRunner.swift`
- Create: `Shared/Core/TmuxSnapshotService.swift`
- Test: `Tests/TmuxMonitorCoreHarness.swift`

- [ ] Step 1: Write failing aggregation and error-state tests.
- [ ] Step 2: Run a direct `swiftc` harness compile and confirm the missing implementation fails.
- [ ] Step 3: Implement the minimal snapshot models and service to satisfy the tests.
- [ ] Step 4: Run the direct harness again and confirm all checks pass.

### Task 2: Shared snapshot cache

**Files:**
- Create: `Shared/Core/SharedSnapshotStore.swift`
- Modify: `Tests/TmuxMonitorCoreHarness.swift`

- [ ] Step 1: Add a failing round-trip cache test.
- [ ] Step 2: Run the direct harness and confirm the new test fails.
- [ ] Step 3: Implement the shared snapshot store.
- [ ] Step 4: Run the direct harness and confirm all tests pass.

## Chunk 2: Menu Bar App

### Task 3: App shell and menu bar state

**Files:**
- Create: `TmuxMonitorApp/TmuxMonitorApp.swift`
- Create: `TmuxMonitorApp/AppState.swift`
- Create: `TmuxMonitorApp/Views/MenuBarView.swift`
- Create: `TmuxMonitorApp/Views/SettingsView.swift`
- Create: `TmuxMonitorApp/Support/TerminalLauncher.swift`
- Create: `TmuxMonitorApp/Info.plist`
- Create: `TmuxMonitorApp/TmuxMonitorApp.entitlements`

- [ ] Step 1: Wire a menu bar app that polls shared core state.
- [ ] Step 2: Add create / attach / kill actions.
- [ ] Step 3: Write snapshots to shared storage and trigger widget reloads.
- [ ] Step 4: Review the UI for dense, tool-like clarity.

## Chunk 3: Widget

### Task 4: Widget summary extension

**Files:**
- Create: `TmuxMonitorWidget/TmuxMonitorWidgetExtension/TmuxMonitorWidgetBundle.swift`
- Create: `TmuxMonitorWidget/TmuxMonitorWidgetExtension/TmuxMonitorWidget.swift`
- Create: `TmuxMonitorWidget/TmuxMonitorWidgetExtension/Info.plist`
- Create: `TmuxMonitorWidget/TmuxMonitorWidgetExtension/TmuxMonitorWidget.entitlements`

- [ ] Step 1: Read the latest cached snapshot.
- [ ] Step 2: Render small and medium widget families.
- [ ] Step 3: Show meaningful empty/error states.

## Chunk 4: Project Scaffolding and Docs

### Task 5: Xcode project and setup notes

**Files:**
- Create: `TmuxMonitor.xcodeproj/project.pbxproj`
- Create: `README.md`

- [ ] Step 1: Add app and widget targets to an Xcode project.
- [ ] Step 2: Document Xcode/signing requirements and local run instructions.
- [ ] Step 3: Run source-level verification and record remaining build constraints.
