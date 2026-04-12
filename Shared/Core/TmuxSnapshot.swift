import Foundation

enum TmuxSnapshotStatus: String, Codable, Sendable {
    case ready
    case noServer
    case unavailable
    case failed
}

struct TmuxSessionSummary: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let windowCount: Int
    let paneCount: Int
    let attachedClientCount: Int
    let createdAt: Date?
    let lastActivityAt: Date?
    let commands: [String]

    var isAttached: Bool {
        attachedClientCount > 0
    }
}

struct TmuxSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let status: TmuxSnapshotStatus
    let sessions: [TmuxSessionSummary]
    let errorMessage: String?

    var sessionCount: Int {
        sessions.count
    }

    var attachedSessionCount: Int {
        sessions.filter(\.isAttached).count
    }

    var totalPaneCount: Int {
        sessions.reduce(0) { $0 + $1.paneCount }
    }

    static func empty(
        status: TmuxSnapshotStatus,
        generatedAt: Date = Date(),
        errorMessage: String? = nil
    ) -> TmuxSnapshot {
        TmuxSnapshot(
            generatedAt: generatedAt,
            status: status,
            sessions: [],
            errorMessage: errorMessage
        )
    }

    static let placeholder = TmuxSnapshot(
        generatedAt: Date(timeIntervalSince1970: 1_711_000_000),
        status: .ready,
        sessions: [
            TmuxSessionSummary(
                id: "$1",
                name: "alpha",
                windowCount: 2,
                paneCount: 3,
                attachedClientCount: 1,
                createdAt: Date(timeIntervalSince1970: 1_711_000_000),
                lastActivityAt: Date(timeIntervalSince1970: 1_711_000_050),
                commands: ["vim", "zsh"]
            ),
            TmuxSessionSummary(
                id: "$2",
                name: "beta",
                windowCount: 1,
                paneCount: 1,
                attachedClientCount: 0,
                createdAt: Date(timeIntervalSince1970: 1_711_000_010),
                lastActivityAt: Date(timeIntervalSince1970: 1_711_000_100),
                commands: ["node"]
            ),
        ],
        errorMessage: nil
    )
}
