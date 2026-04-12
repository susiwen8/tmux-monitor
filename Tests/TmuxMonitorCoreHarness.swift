import Foundation

@main
enum TmuxMonitorCoreHarness {
    static func main() throws {
        try snapshotAggregatesPaneAndClientStatePerSession()
        try noServerRunningBecomesEmptySnapshot()
        try launchFailureBecomesUnavailableSnapshot()
        try snapshotStoreRoundTripsLatestSnapshot()
        print("TmuxMonitor core checks passed.")
    }

    private static func snapshotAggregatesPaneAndClientStatePerSession() throws {
        let runner = FakeCommandRunner(
            responses: [
                .success(
                    command: ["list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}\t#{session_activity}"],
                    stdout: """
                    $1\talpha\t2\t1\t1711000000\t1711000050
                    $2\tbeta\t1\t0\t1711000100\t1711000200
                    """
                ),
                .success(
                    command: ["list-panes", "-a", "-F", "#{session_id}\t#{session_name}\t#{pane_id}\t#{pane_current_command}\t#{pane_active}"],
                    stdout: """
                    $1\talpha\t%1\tvim\t1
                    $1\talpha\t%2\tzsh\t0
                    $2\tbeta\t%3\tnode\t1
                    """
                ),
                .success(
                    command: ["list-clients", "-F", "#{session_id}\t#{session_name}\t#{client_name}"],
                    stdout: "$1\talpha\t/dev/ttys001"
                ),
            ]
        )

        let snapshot = try TmuxSnapshotService(commandRunner: runner).loadSnapshot(
            now: Date(timeIntervalSince1970: 1_711_000_200)
        )

        try expect(snapshot.status == .ready, "Expected ready snapshot.")
        try expect(snapshot.sessionCount == 2, "Expected 2 sessions.")
        try expect(snapshot.attachedSessionCount == 1, "Expected 1 attached session.")
        try expect(snapshot.totalPaneCount == 3, "Expected 3 panes.")
        try expect(snapshot.sessions.map(\.name) == ["alpha", "beta"], "Unexpected session order.")
        try expect(snapshot.sessions.first?.commands == ["vim", "zsh"], "Unexpected command aggregation.")
    }

    private static func noServerRunningBecomesEmptySnapshot() throws {
        let runner = FakeCommandRunner(
            responses: [
                .exitFailure(
                    command: ["list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}\t#{session_activity}"],
                    stderr: "no server running on /private/tmp/tmux-501/default"
                ),
            ]
        )

        let snapshot = try TmuxSnapshotService(commandRunner: runner).loadSnapshot()

        try expect(snapshot.status == .noServer, "Expected noServer snapshot.")
        try expect(snapshot.sessions.isEmpty, "Expected empty sessions for no server.")
    }

    private static func launchFailureBecomesUnavailableSnapshot() throws {
        let runner = FakeCommandRunner(
            responses: [
                .launchFailure(
                    command: ["list-sessions", "-F", "#{session_id}\t#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}\t#{session_activity}"]
                ),
            ]
        )

        let snapshot = try TmuxSnapshotService(commandRunner: runner).loadSnapshot()

        try expect(snapshot.status == .unavailable, "Expected unavailable snapshot.")
        try expect(snapshot.errorMessage == "tmux command could not be launched.", "Unexpected unavailable error.")
    }

    private static func snapshotStoreRoundTripsLatestSnapshot() throws {
        let suiteName = "TmuxMonitorTests.\(UUID().uuidString)"
        let store = SharedSnapshotStore(suiteName: suiteName)
        let snapshot = TmuxSnapshot.placeholder

        try store.save(snapshot)
        let restored = try store.load()

        try expect(restored == snapshot, "Snapshot store should round-trip placeholder data.")
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

private final class FakeCommandRunner: TmuxCommandRunning {
    enum Response {
        case success(command: [String], stdout: String, stderr: String = "")
        case exitFailure(command: [String], stdout: String = "", stderr: String)
        case launchFailure(command: [String])
    }

    private let responses: [Response]
    private var index = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    func run(arguments: [String]) throws -> TmuxCommandResult {
        guard index < responses.count else {
            throw HarnessFailure(message: "Missing fake response for \(arguments)")
        }

        let response = responses[index]
        index += 1

        guard response.command == arguments else {
            throw HarnessFailure(
                message: "Expected command \(response.command), got \(arguments)"
            )
        }

        switch response {
        case let .success(_, stdout, stderr):
            return TmuxCommandResult(exitCode: 0, stdout: stdout, stderr: stderr)
        case let .exitFailure(_, stdout, stderr):
            return TmuxCommandResult(exitCode: 1, stdout: stdout, stderr: stderr)
        case .launchFailure:
            throw TmuxCommandLaunchError()
        }
    }
}

private extension FakeCommandRunner.Response {
    var command: [String] {
        switch self {
        case let .success(command, _, _):
            return command
        case let .exitFailure(command, _, _):
            return command
        case let .launchFailure(command):
            return command
        }
    }
}
