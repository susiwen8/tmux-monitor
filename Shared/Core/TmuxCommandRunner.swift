import Foundation

struct TmuxCommandResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol TmuxCommandRunning {
    func run(arguments: [String]) throws -> TmuxCommandResult
}

struct TmuxCommandLaunchError: Error, Equatable {}

struct ProcessTmuxCommandRunner: TmuxCommandRunning {
    let tmuxPath: String

    init(tmuxPath: String = AppConstants.defaultTmuxPath) {
        let trimmed = tmuxPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "tmux" {
            self.tmuxPath = AppConstants.defaultTmuxPath
        } else {
            self.tmuxPath = trimmed
        }
    }

    func run(arguments: [String]) throws -> TmuxCommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = executableArguments(for: arguments)
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw TmuxCommandLaunchError()
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return TmuxCommandResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private var executableURL: URL {
        if tmuxPath.contains("/") {
            return URL(fileURLWithPath: tmuxPath)
        }

        return URL(fileURLWithPath: "/usr/bin/env")
    }

    private func executableArguments(for arguments: [String]) -> [String] {
        if tmuxPath.contains("/") {
            return arguments
        }

        return [tmuxPath] + arguments
    }
}
