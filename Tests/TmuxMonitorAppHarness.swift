import Foundation

@main
enum TmuxMonitorAppHarness {
    static func main() throws {
        try attachedSessionUsesDetachPrimaryAction()
        try idleSessionUsesAttachPrimaryAction()
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

    private static func detachedStatusMessageIsPreserved() throws {
        try expect(
            AppState.shouldPreserveActionStatusMessage("Detached clients from alpha."),
            "Detach confirmation should survive the next refresh."
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
