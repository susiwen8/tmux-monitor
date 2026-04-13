import Foundation
import WidgetKit

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var snapshot: TmuxSnapshot
    @Published var pollIntervalSeconds: Double {
        didSet {
            userDefaults.set(pollIntervalSeconds, forKey: DefaultsKeys.pollInterval)
            if started {
                scheduleTimer()
            }
        }
    }
    @Published var tmuxPath: String {
        didSet {
            userDefaults.set(tmuxPath, forKey: DefaultsKeys.tmuxPath)
            if started {
                refresh()
            }
        }
    }
    @Published var terminalApp: TerminalApp {
        didSet {
            userDefaults.set(terminalApp.rawValue, forKey: DefaultsKeys.terminalApp)
        }
    }
    @Published var sessionPendingKill: TmuxSessionSummary?
    @Published private(set) var statusMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshAt: Date?

    private enum DefaultsKeys {
        static let pollInterval = "pollIntervalSeconds"
        static let tmuxPath = "tmuxPath"
        static let terminalApp = "terminalApp"
    }

    private struct CommandOutcome: Sendable {
        let message: String
        let succeeded: Bool
    }

    private let userDefaults: UserDefaults
    private var pollingTask: Task<Void, Never>?
    private var started = false

    init(
        userDefaults: UserDefaults = .standard
    ) {
        self.userDefaults = userDefaults
        self.pollIntervalSeconds = userDefaults.object(forKey: DefaultsKeys.pollInterval) as? Double ?? 5

        let storedTmuxPath = userDefaults.string(forKey: DefaultsKeys.tmuxPath)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedStoredTmuxPath: String
        if let storedTmuxPath, !storedTmuxPath.isEmpty, storedTmuxPath != "tmux" {
            resolvedStoredTmuxPath = storedTmuxPath
        } else {
            resolvedStoredTmuxPath = AppConstants.defaultTmuxPath
            userDefaults.set(resolvedStoredTmuxPath, forKey: DefaultsKeys.tmuxPath)
        }
        self.tmuxPath = resolvedStoredTmuxPath

        if
            let savedTerminal = userDefaults.string(forKey: DefaultsKeys.terminalApp),
            let terminal = TerminalApp(rawValue: savedTerminal)
        {
            self.terminalApp = terminal
        } else {
            self.terminalApp = .terminal
        }

        self.snapshot = (try? SharedSnapshotStore().load()) ?? .empty(status: .noServer)
        self.lastRefreshAt = self.snapshot.generatedAt
    }

    deinit {
        pollingTask?.cancel()
    }

    var menuBarTitle: String {
        switch snapshot.status {
        case .ready:
            return snapshot.sessionCount == 0 ? "tmux" : "tmux \(snapshot.sessionCount)"
        case .noServer:
            return "tmux off"
        case .unavailable:
            return "tmux ?"
        case .failed:
            return "tmux !"
        }
    }

    var menuBarSymbolName: String {
        switch snapshot.status {
        case .ready:
            return snapshot.attachedSessionCount > 0 ? "terminal.fill" : "terminal"
        case .noServer:
            return "moon.zzz"
        case .unavailable:
            return "questionmark.app"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    func start() {
        guard !started else {
            return
        }

        started = true
        refresh()
        scheduleTimer()
    }

    func refresh() {
        isRefreshing = true

        let currentTmuxPath = resolvedTmuxPath()
        Task {
            let snapshot = await Task.detached(priority: .userInitiated) {
                let runner = ProcessTmuxCommandRunner(tmuxPath: currentTmuxPath)
                let service = TmuxSnapshotService(commandRunner: runner)
                let primarySnapshot = (try? service.loadSnapshot()) ?? .empty(
                    status: .failed,
                    errorMessage: "Failed to read tmux snapshot."
                )
                let snapshot: TmuxSnapshot
                if primarySnapshot.status == .ready, primarySnapshot.sessions.isEmpty {
                    Self.writeEmptySnapshotDiagnostic(
                        using: runner,
                        tmuxPath: currentTmuxPath
                    )
                    snapshot = Self.recoverSnapshot(using: runner) ?? primarySnapshot
                } else {
                    snapshot = primarySnapshot
                }
                try? SharedSnapshotStore().save(snapshot)
                return snapshot
            }
            .value

            WidgetCenter.shared.reloadAllTimelines()

            self.snapshot = snapshot
            self.lastRefreshAt = snapshot.generatedAt
            self.isRefreshing = false

            if let errorMessage = snapshot.errorMessage {
                self.statusMessage = errorMessage
            } else if snapshot.status == .noServer {
                self.statusMessage = "tmux server is not running."
            } else if self.statusMessage?.hasPrefix("Created ") == true || self.statusMessage?.hasPrefix("Killed ") == true {
                // Preserve the latest action confirmation.
            } else {
                self.statusMessage = nil
            }
        }
    }

    func confirmKill() {
        guard let session = sessionPendingKill else {
            return
        }

        sessionPendingKill = nil
        runTmuxCommand(
            ["kill-session", "-t", session.name],
            successMessage: "Killed \(session.name)."
        )
    }

    func cancelKill() {
        sessionPendingKill = nil
    }

    func attach(to session: TmuxSessionSummary) {
        do {
            try TerminalLauncher(
                terminalApp: terminalApp,
                tmuxPath: resolvedTmuxPath()
            )
            .attach(to: session.name)

            statusMessage = "Opening \(session.name) in \(terminalApp.displayName)."
            refresh()
        } catch {
            statusMessage = Self.message(for: error)
        }
    }

    private func scheduleTimer() {
        pollingTask?.cancel()
        let interval = max(3, pollIntervalSeconds)
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else {
                    return
                }
                self.refresh()
            }
        }
    }

    private func runTmuxCommand(
        _ arguments: [String],
        successMessage: String,
        afterSuccess: (@MainActor @Sendable () -> Void)? = nil
    ) {
        let tmuxPath = resolvedTmuxPath()

        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                let runner = ProcessTmuxCommandRunner(tmuxPath: tmuxPath)

                do {
                    let result = try runner.run(arguments: arguments)
                    if result.exitCode == 0 {
                        return CommandOutcome(message: successMessage, succeeded: true)
                    }

                    let trimmed = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    return CommandOutcome(
                        message: trimmed.isEmpty ? "tmux command failed." : trimmed,
                        succeeded: false
                    )
                } catch {
                    return CommandOutcome(
                        message: Self.message(for: error),
                        succeeded: false
                    )
                }
            }
            .value

            self.statusMessage = outcome.message
            if outcome.succeeded {
                afterSuccess?()
                self.refresh()
            }
        }
    }

    private func resolvedTmuxPath() -> String {
        let trimmed = tmuxPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppConstants.defaultTmuxPath : trimmed
    }

    nonisolated private static func writeEmptySnapshotDiagnostic(
        using runner: ProcessTmuxCommandRunner,
        tmuxPath: String
    ) {
        let logURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/TmuxMonitor-empty-snapshot.log")
        let format = "#{session_id}\t#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}\t#{session_activity}"
        let rawResult: TmuxCommandResult
        do {
            rawResult = try runner.run(arguments: ["list-sessions", "-F", format])
        } catch {
            rawResult = TmuxCommandResult(exitCode: -1, stdout: "", stderr: "launch error: \(error)")
        }

        let payload = """
        time=\(ISO8601DateFormatter().string(from: Date()))
        tmuxPath=\(tmuxPath)
        exitCode=\(rawResult.exitCode)
        stdout=\(rawResult.stdout.replacingOccurrences(of: "\n", with: "\\n"))
        stderr=\(rawResult.stderr.replacingOccurrences(of: "\n", with: "\\n"))

        """

        if let data = payload.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path),
               let handle = try? FileHandle(forWritingTo: logURL) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: logURL, options: .atomic)
            }
        }
    }

    nonisolated private static func recoverSnapshot(
        using runner: TmuxCommandRunning
    ) -> TmuxSnapshot? {
        let now = Date()
        let sessionsFormat = "#{session_id}|#{session_name}|#{session_windows}|#{session_attached}|#{session_created}|#{session_activity}"
        let panesFormat = "#{session_id}|#{session_name}|#{pane_id}|#{pane_current_command}|#{pane_active}"
        let clientsFormat = "#{session_id}|#{session_name}|#{client_name}"

        guard
            let sessionsResult = try? runner.run(arguments: ["list-sessions", "-F", sessionsFormat]),
            sessionsResult.exitCode == 0
        else {
            return nil
        }

        let paneRows: [[String]]
        if
            let panesResult = try? runner.run(arguments: ["list-panes", "-a", "-F", panesFormat]),
            panesResult.exitCode == 0
        {
            paneRows = parseFallbackRows(panesResult.stdout)
        } else {
            paneRows = []
        }

        let clientRows: [[String]]
        if
            let clientsResult = try? runner.run(arguments: ["list-clients", "-F", clientsFormat]),
            clientsResult.exitCode == 0
        {
            clientRows = parseFallbackRows(clientsResult.stdout)
        } else {
            clientRows = []
        }

        let sessions = parseFallbackRows(sessionsResult.stdout)
            .compactMap { row -> TmuxSessionSummary? in
                guard row.count >= 6 else {
                    return nil
                }

                let sessionID = row[0]
                let matchingPanes = paneRows.filter { $0.first == sessionID }
                let matchingClients = clientRows.filter { $0.first == sessionID }
                let commands = Array(
                    NSOrderedSet(array: matchingPanes.compactMap { $0.count >= 4 ? $0[3] : nil })
                ) as? [String] ?? []

                return TmuxSessionSummary(
                    id: sessionID,
                    name: row[1],
                    windowCount: Int(row[2]) ?? 0,
                    paneCount: matchingPanes.count,
                    attachedClientCount: matchingClients.count,
                    createdAt: date(fromEpochString: row[4]),
                    lastActivityAt: date(fromEpochString: row[5]),
                    commands: commands.filter { !$0.isEmpty }
                )
            }
            .sorted(by: { lhs, rhs in
                if lhs.isAttached != rhs.isAttached {
                    return lhs.isAttached && !rhs.isAttached
                }
                let lhsActivity = lhs.lastActivityAt ?? .distantPast
                let rhsActivity = rhs.lastActivityAt ?? .distantPast
                if lhsActivity != rhsActivity {
                    return lhsActivity > rhsActivity
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            })

        guard !sessions.isEmpty else {
            return nil
        }

        return TmuxSnapshot(
            generatedAt: now,
            status: .ready,
            sessions: sessions,
            errorMessage: nil
        )
    }

    nonisolated private static func parseFallbackRows(_ output: String) -> [[String]] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> [String]? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return nil
                }
                return trimmed.components(separatedBy: "|")
            }
    }

    nonisolated private static func date(fromEpochString value: String) -> Date? {
        guard let seconds = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    nonisolated private static func message(for error: Error) -> String {
        if error is TmuxCommandLaunchError {
            return "tmux command could not be launched."
        }

        return error.localizedDescription
    }
}
