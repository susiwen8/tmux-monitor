import Foundation

enum AppConstants {
    static let appBundleID = "local.tmuxmonitor.app"
    static let widgetBundleID = "local.tmuxmonitor.app.widget"
    static let appGroupID = "group.local.tmuxmonitor"
    static let snapshotDefaultsKey = "latestSnapshot"
    static let snapshotFileName = "latest-snapshot.json"
    static let widgetKind = "TmuxMonitorWidget"
    static let appOpenURL = URL(string: "tmuxmonitor://open")!

    static var defaultTmuxPath: String {
        let fileManager = FileManager.default
        let knownPaths = [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ]

        return knownPaths.first(where: { fileManager.isExecutableFile(atPath: $0) }) ?? "tmux"
    }
}

enum TerminalApp: String, CaseIterable, Codable, Identifiable {
    case terminal
    case iTerm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .terminal:
            return "Terminal"
        case .iTerm:
            return "iTerm"
        }
    }
}
