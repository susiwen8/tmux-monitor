import Foundation

@main
enum TmuxMonitorAppHarness {
    static func main() throws {
        try attachedSessionUsesDetachPrimaryAction()
        try idleSessionUsesAttachPrimaryAction()
        try defaultsToGhosttyForAttach()
        try terminalAppsPreferGhosttyThenITermThenTerminal()
        try terminalFallbackChainsStayStable()
        try sessionRenameCommandTargetsStableSessionID()
        try emptySessionRenameIsRejected()
        try unchangedSessionRenameIsRejected()
        try detachedStatusMessageIsPreserved()
        print("TmuxMonitor app checks passed.")
    }

    private static func attachedSessionUsesDetachPrimaryAction() throws {
        let session = TmuxSessionSummary(
            id: "$1",
            name: "alpha",
            windowCount: 1,
            paneCount: 1,
            attachedClientCount: 1,
            createdAt: nil,
            lastActivityAt: nil,
            commands: ["zsh"]
        )

        let action = SessionPrimaryAction(session: session)

        try expect(action == .detach, "Attached sessions should use the detach action.")
        try expect(action.buttonTitle == "Detach", "Detach action should expose the correct label.")
        try expect(
            action.tmuxArguments(for: session.name) == ["detach-client", "-s", "alpha"],
            "Detach action should target the session with detach-client."
        )
    }

    private static func idleSessionUsesAttachPrimaryAction() throws {
        let session = TmuxSessionSummary(
            id: "$2",
            name: "beta",
            windowCount: 1,
            paneCount: 1,
            attachedClientCount: 0,
            createdAt: nil,
            lastActivityAt: nil,
            commands: ["node"]
        )

        let action = SessionPrimaryAction(session: session)

        try expect(action == .attach, "Idle sessions should keep the attach action.")
        try expect(action.buttonTitle == "Attach", "Attach action should keep the existing label.")
        try expect(action.tmuxArguments(for: session.name) == nil, "Attach should not run a direct tmux command.")
    }

    @MainActor
    private static func defaultsToGhosttyForAttach() throws {
        let suiteName = "TmuxMonitorAppHarness-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let state = AppState(userDefaults: defaults)

        try expect(
            state.terminalApp.rawValue == "ghostty",
            "New installs should default attach to Ghostty."
        )
    }

    private static func terminalAppsPreferGhosttyThenITermThenTerminal() throws {
        try expect(
            TerminalApp.allCases.map(\.rawValue) == ["ghostty", "iTerm", "terminal"],
            "Attach preference order should be Ghostty, then iTerm, then Terminal."
        )
    }

    private static func terminalFallbackChainsStayStable() throws {
        try expect(
            TerminalApp.ghostty.fallbackOrder == [.ghostty, .iTerm, .terminal],
            "Ghostty should fall back to iTerm2 and then Terminal."
        )
        try expect(
            TerminalApp.iTerm.fallbackOrder == [.iTerm, .terminal],
            "iTerm2 should fall back to Terminal."
        )
        try expect(
            TerminalApp.terminal.fallbackOrder == [.terminal],
            "Terminal should remain the final fallback with no extra hops."
        )
    }

    private static func sessionRenameCommandTargetsStableSessionID() throws {
        let session = TmuxSessionSummary(
            id: "$9",
            name: "old-name",
            windowCount: 1,
            paneCount: 1,
            attachedClientCount: 0,
            createdAt: nil,
            lastActivityAt: nil,
            commands: []
        )

        let command = try SessionRenameCommand.build(
            session: session,
            proposedName: "  new-name  "
        ).get()

        try expect(
            command.arguments == ["rename-session", "-t", "$9", "new-name"],
            "Rename should target the stable tmux session id and trim the new name."
        )
        try expect(
            command.successMessage == "Renamed old-name to new-name.",
            "Rename should expose a status message that identifies both names."
        )
    }

    private static func emptySessionRenameIsRejected() throws {
        let session = TmuxSessionSummary(
            id: "$9",
            name: "old-name",
            windowCount: 1,
            paneCount: 1,
            attachedClientCount: 0,
            createdAt: nil,
            lastActivityAt: nil,
            commands: []
        )

        let result = SessionRenameCommand.build(session: session, proposedName: "   ")

        try expect(
            result == .failure(.empty),
            "Empty session names should be rejected before calling tmux."
        )
    }

    private static func unchangedSessionRenameIsRejected() throws {
        let session = TmuxSessionSummary(
            id: "$9",
            name: "old-name",
            windowCount: 1,
            paneCount: 1,
            attachedClientCount: 0,
            createdAt: nil,
            lastActivityAt: nil,
            commands: []
        )

        let result = SessionRenameCommand.build(session: session, proposedName: "old-name")

        try expect(
            result == .failure(.unchanged),
            "Unchanged session names should not call tmux."
        )
    }

    private static func detachedStatusMessageIsPreserved() throws {
        try expect(
            AppState.shouldPreserveActionStatusMessage("Detached clients from alpha."),
            "Detach confirmation should survive the next refresh."
        )
        try expect(
            AppState.shouldPreserveActionStatusMessage("Renamed alpha to beta."),
            "Rename confirmation should survive the next refresh."
        )
        try expect(
            !AppState.shouldPreserveActionStatusMessage("Opening alpha in Terminal."),
            "Non-action status messages should still clear on refresh."
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw HarnessFailure(message: message)
        }
    }
}

private struct HarnessFailure: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
