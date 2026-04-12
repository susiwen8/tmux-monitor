import Foundation

enum TerminalLaunchError: LocalizedError {
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case let .scriptFailed(message):
            return message
        }
    }
}

struct TerminalLauncher {
    let terminalApp: TerminalApp
    let tmuxPath: String

    func attach(to sessionName: String) throws {
        let command = "\(shellQuoted(tmuxPath)) attach -t \(shellQuoted(sessionName))"
        let script = scriptLines(for: command)

        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = script.flatMap { ["-e", $0] }
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw TerminalLaunchError.scriptFailed("Failed to launch osascript.")
        }

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TerminalLaunchError.scriptFailed(
                message?.isEmpty == false ? message! : "The terminal app could not be controlled."
            )
        }
    }

    private func scriptLines(for command: String) -> [String] {
        let escapedCommand = appleScriptEscaped(command)

        switch terminalApp {
        case .terminal:
            return [
                "tell application \"Terminal\"",
                "activate",
                "do script \"\(escapedCommand)\"",
                "end tell",
            ]
        case .iTerm:
            return [
                "tell application id \"com.googlecode.iterm2\"",
                "activate",
                "create window with default profile command \"\(escapedCommand)\"",
                "end tell",
            ]
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
