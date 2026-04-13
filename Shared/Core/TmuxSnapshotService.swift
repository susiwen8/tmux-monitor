import Foundation

struct TmuxSnapshotService {
    private let commandRunner: TmuxCommandRunning

    init(commandRunner: TmuxCommandRunning = ProcessTmuxCommandRunner()) {
        self.commandRunner = commandRunner
    }

    func loadSnapshot(now: Date = Date()) throws -> TmuxSnapshot {
        do {
            let sessionsResult = try commandRunner.run(arguments: [
                "list-sessions",
                "-F",
                "#{session_id}\t#{session_name}\t#{session_windows}\t#{session_attached}\t#{session_created}\t#{session_activity}",
            ])

            guard sessionsResult.exitCode == 0 else {
                if Self.isNoServer(stderr: sessionsResult.stderr) {
                    return .empty(status: .noServer, generatedAt: now)
                }

                return .empty(
                    status: .failed,
                    generatedAt: now,
                    errorMessage: sessionsResult.stderr.nonEmptyTrimmed
                )
            }

            let panesResult = try commandRunner.run(arguments: [
                "list-panes",
                "-a",
                "-F",
                "#{session_id}\t#{session_name}\t#{pane_id}\t#{pane_current_command}\t#{pane_active}",
            ])

            let clientsResult = try commandRunner.run(arguments: [
                "list-clients",
                "-F",
                "#{session_id}\t#{session_name}\t#{client_name}",
            ])

            guard panesResult.exitCode == 0, clientsResult.exitCode == 0 else {
                let messages = [
                    panesResult.stderr.nonEmptyTrimmed,
                    clientsResult.stderr.nonEmptyTrimmed,
                ]
                .compactMap { $0 }
                .joined(separator: "\n")

                return .empty(
                    status: .failed,
                    generatedAt: now,
                    errorMessage: messages.isEmpty ? "tmux returned an unexpected error." : messages
                )
            }

            let paneRows = Self.parseRows(panesResult.stdout)
            let clientRows = Self.parseRows(clientsResult.stdout)

            let sessions = Self.parseRows(sessionsResult.stdout)
                .compactMap { row -> TmuxSessionSummary? in
                    guard row.count >= 6 else {
                        return nil
                    }

                    let sessionID = row[0]
                    let name = row[1]
                    let windowCount = Int(row[2]) ?? 0
                    let createdAt = Self.date(fromEpochString: row[4])
                    let lastActivityAt = Self.date(fromEpochString: row[5])
                    let matchingPanes = paneRows.filter { $0.first == sessionID }
                    let matchingClients = clientRows.filter { $0.first == sessionID }
                    let commands = Self.uniqueCommands(from: matchingPanes)

                    return TmuxSessionSummary(
                        id: sessionID,
                        name: name,
                        windowCount: windowCount,
                        paneCount: matchingPanes.count,
                        attachedClientCount: matchingClients.count,
                        createdAt: createdAt,
                        lastActivityAt: lastActivityAt,
                        commands: commands
                    )
                }
                .sorted(by: Self.sortSessions)

            let resolvedSessions: [TmuxSessionSummary]
            if sessions.isEmpty, sessionsResult.stdout.nonEmptyTrimmed != nil {
                resolvedSessions = Self.fallbackSessions(from: sessionsResult.stdout)
            } else {
                resolvedSessions = sessions
            }

            return TmuxSnapshot(
                generatedAt: now,
                status: .ready,
                sessions: resolvedSessions,
                errorMessage: nil
            )
        } catch is TmuxCommandLaunchError {
            return .empty(
                status: .unavailable,
                generatedAt: now,
                errorMessage: "tmux command could not be launched."
            )
        }
    }

    private static func parseRows(_ output: String) -> [[String]] {
        output
            .split(whereSeparator: \.isNewline)
            .map { line in
                line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            }
    }

    private static func uniqueCommands(from paneRows: [[String]]) -> [String] {
        var commands: [String] = []

        for row in paneRows where row.count >= 4 {
            let command = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty, !commands.contains(command) else {
                continue
            }
            commands.append(command)
        }

        return commands
    }

    private static func date(fromEpochString value: String) -> Date? {
        guard let seconds = TimeInterval(value) else {
            return nil
        }

        return Date(timeIntervalSince1970: seconds)
    }

    private static func isNoServer(stderr: String) -> Bool {
        let lowered = stderr.lowercased()
        return lowered.contains("no server running") || lowered.contains("failed to connect to server")
    }

    private static func sortSessions(_ lhs: TmuxSessionSummary, _ rhs: TmuxSessionSummary) -> Bool {
        if lhs.isAttached != rhs.isAttached {
            return lhs.isAttached && !rhs.isAttached
        }

        let lhsActivity = lhs.lastActivityAt ?? .distantPast
        let rhsActivity = rhs.lastActivityAt ?? .distantPast
        if lhsActivity != rhsActivity {
            return lhsActivity > rhsActivity
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func fallbackSessions(from output: String) -> [TmuxSessionSummary] {
        output
            .components(separatedBy: .newlines)
            .compactMap { line -> TmuxSessionSummary? in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else {
                    return nil
                }

                let fields = trimmedLine
                    .replacingOccurrences(of: "\r", with: "")
                    .components(separatedBy: "\t")

                guard fields.count >= 6 else {
                    return nil
                }

                return TmuxSessionSummary(
                    id: fields[0],
                    name: fields[1],
                    windowCount: Int(fields[2]) ?? 0,
                    paneCount: 0,
                    attachedClientCount: Int(fields[3]) ?? 0,
                    createdAt: date(fromEpochString: fields[4]),
                    lastActivityAt: date(fromEpochString: fields[5]),
                    commands: []
                )
            }
            .sorted(by: sortSessions)
    }
}

private extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
