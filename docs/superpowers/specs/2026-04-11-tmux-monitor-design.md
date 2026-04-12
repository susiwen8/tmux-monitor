# Tmux Monitor Design

**Date:** 2026-04-11
**Status:** approved in chat, implemented directly after approval

## Goal

Build a local-first macOS utility for monitoring all tmux sessions on the current machine, with:

- a menu bar primary surface
- a desktop/Notification Center widget summary
- lightweight quick actions: attach, create session, kill session

The app is for personal local use, not Mac App Store distribution. It can call local `tmux` directly.

## Product Shape

### Primary surfaces

- `MenuBarExtra` is the main UI.
- The widget is a compact summary surface, not the primary control plane.
- A minimal settings window configures polling interval, tmux path, terminal app, and app group notes.

### MVP actions

- Attach to a session by launching the user's terminal app with `tmux attach -t <session>`.
- Create a new session from the menu bar.
- Kill a session with explicit confirmation.

## Architecture

The app is split into three layers:

1. `Shared/Core`
   Reads tmux state, normalizes it into snapshot models, and stores the latest snapshot in shared storage.
2. `TmuxMonitorApp`
   Runs the polling loop, renders the menu bar interface, and performs tmux actions.
3. `TmuxMonitorWidgetExtension`
   Reads the last shared snapshot and renders small/medium widgets.

## Data Flow

1. The app polls tmux via formatted commands.
2. Command output is converted into a `TmuxSnapshot`.
3. The latest snapshot is encoded and written to shared storage.
4. The widget reads the shared snapshot and renders a compact summary.
5. After create / kill / attach actions, the app forces a refresh and reloads widget timelines.

## tmux Integration Strategy

Use lightweight command polling rather than hooks or a background daemon.

Commands:

- `tmux list-sessions`
- `tmux list-panes -a`
- `tmux list-clients`

Polling is sufficient for MVP because:

- it minimizes setup complexity
- it is easy to reason about and test
- it works well for a personal menu bar utility

## Widget Strategy

The widget reads shared cached state instead of running tmux itself. This keeps the extension simple and avoids making widget execution depend on shell access.

Supported families:

- small
- medium

The widget shows:

- total sessions
- attached session count
- last refresh time
- top sessions in priority order

## Error Handling

The snapshot distinguishes:

- `ready`
- `noServer`
- `unavailable` (tmux binary missing or cannot launch)
- `failed`

The UI must not collapse these into a blank state.

## Testing Strategy

Use TDD for the shared core:

- parse and aggregate tmux command output into session summaries
- treat "no server running" as an empty-but-valid state
- treat launch failures as `unavailable`
- verify snapshot store round-trips through shared defaults

UI is verified with compilation-oriented validation and manual structure review because the current machine only has Command Line Tools active and cannot run a full Xcode widget build yet.

## Risks

- Full `.app + widget` builds require complete Xcode, not only Command Line Tools.
- Widget shared storage usually requires an App Group capability configured in Xcode signing.
- Terminal attach flows depend on Apple Events permission for Terminal/iTerm.
