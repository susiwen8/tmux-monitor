import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            killConfirmationPanel
            content
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tmux Monitor")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    appState.refresh()
                } label: {
                    Image(systemName: appState.isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh snapshot")
            }

            if let statusMessage = appState.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var killConfirmationPanel: some View {
        if let session = appState.sessionPendingKill {
            VStack(alignment: .leading, spacing: 10) {
                Text("Kill \(session.name)?")
                    .font(.headline)
                Text("This will terminate all panes inside the session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Cancel") {
                        appState.cancelKill()
                    }
                    .buttonStyle(.bordered)

                    Button("Kill", role: .destructive) {
                        appState.confirmKill()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.red.opacity(0.16))
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch appState.snapshot.status {
        case .ready where appState.snapshot.sessions.isEmpty:
            EmptyStateView(
                title: "No Sessions",
                message: "tmux is reachable, but there are no active sessions right now."
            )
        case .ready:
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(appState.snapshot.sessions) { session in
                        SessionCardView(
                            session: session,
                            onAttach: { appState.attach(to: session) },
                            onKill: { appState.sessionPendingKill = session }
                        )
                    }
                }
            }
            .frame(maxHeight: 420)
        case .noServer:
            EmptyStateView(
                title: "tmux Offline",
                message: "No tmux server is running. Start tmux in Terminal to begin tracking."
            )
        case .unavailable:
            EmptyStateView(
                title: "tmux Unavailable",
                message: "Check the tmux path in Settings and make sure the binary is installed."
            )
        case .failed:
            EmptyStateView(
                title: "Refresh Failed",
                message: appState.snapshot.errorMessage ?? "tmux returned an unexpected error."
            )
        }
    }

    private var footer: some View {
        HStack {
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.bordered)

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }

            Spacer()

            if let lastRefreshAt = appState.lastRefreshAt {
                Text(lastRefreshAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summaryLine: String {
        switch appState.snapshot.status {
        case .ready:
            return "\(appState.snapshot.sessionCount) sessions, \(appState.snapshot.attachedSessionCount) attached, \(appState.snapshot.totalPaneCount) panes"
        case .noServer:
            return "tmux server not running"
        case .unavailable:
            return "tmux binary unavailable"
        case .failed:
            return "snapshot error"
        }
    }

    private var statusColor: Color {
        switch appState.snapshot.status {
        case .ready:
            return .secondary
        case .noServer:
            return .orange
        case .unavailable, .failed:
            return .red
        }
    }
}

private struct SessionCardView: View {
    let session: TmuxSessionSummary
    let onAttach: () -> Void
    let onKill: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(metadataLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            Spacer(minLength: 8)

            if let lastActivityAt = session.lastActivityAt {
                Text(lastActivityAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 70, alignment: .trailing)
            }

            StatusBadge(title: session.isAttached ? "Attached" : "Idle", isActive: session.isAttached)

            HStack(spacing: 8) {
                Button("Attach", action: onAttach)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Kill", role: .destructive, action: onKill)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
    }

    private var metadataLine: String {
        var parts = [
            "\(session.windowCount)w",
            "\(session.paneCount)p",
        ]

        if session.attachedClientCount > 0 {
            parts.append("\(session.attachedClientCount)c")
        }

        parts.append(contentsOf: session.commands)
        return parts.joined(separator: " • ")
    }
}

private struct StatusBadge: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
            .foregroundStyle(isActive ? Color.green : Color.secondary)
            .clipShape(Capsule())
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
