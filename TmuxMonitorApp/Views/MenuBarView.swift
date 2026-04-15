import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            killConfirmationPanel
            content
            Divider()
            footer
        }
        .padding(10)
        .frame(width: 440)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tmux Monitor")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    if showsHeaderSubtitle {
                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    appState.refresh()
                } label: {
                    Label(
                        appState.isRefreshing ? "Refreshing" : "Refresh",
                        systemImage: appState.isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Refresh snapshot")
            }

            if appState.snapshot.status == .ready {
                HStack(spacing: 6) {
                    CompactMetricChip(value: "\(appState.snapshot.sessionCount)", title: "Sessions")
                    CompactMetricChip(value: "\(appState.snapshot.attachedSessionCount)", title: "Attached")
                    CompactMetricChip(value: "\(appState.snapshot.totalPaneCount)", title: "Panes")
                    Spacer(minLength: 0)
                }
            }

            if let statusMessage = appState.statusMessage {
                StatusMessageView(
                    message: statusMessage,
                    color: statusColor,
                    iconName: statusIconName
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    @ViewBuilder
    private var killConfirmationPanel: some View {
        if let session = appState.sessionPendingKill {
            VStack(alignment: .leading, spacing: 8) {
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
            .padding(10)
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LIVE SESSIONS")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(summaryLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(appState.snapshot.sessions) { session in
                            SessionCardView(
                                session: session,
                                primaryActionTitle: appState.primaryAction(for: session).buttonTitle,
                                onPrimaryAction: { appState.triggerPrimaryAction(for: session) },
                                onKill: { appState.sessionPendingKill = session }
                            )
                        }
                    }
                }
                .frame(maxHeight: 460)
            }
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
        HStack(spacing: 10) {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            if let lastRefreshAt = appState.lastRefreshAt {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(lastRefreshAt, style: .time)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Quit")
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
            return .accentColor
        case .noServer:
            return .orange
        case .unavailable, .failed:
            return .red
        }
    }

    private var headerSubtitle: String {
        switch appState.snapshot.status {
        case .ready:
            return appState.snapshot.sessions.isEmpty ? "tmux is reachable and waiting for sessions." : "Monitor live tmux sessions and jump in quickly."
        case .noServer:
            return "No tmux server is running on this machine."
        case .unavailable:
            return "The configured tmux binary could not be found."
        case .failed:
            return "The latest tmux refresh returned an error."
        }
    }

    private var statusIconName: String {
        switch appState.snapshot.status {
        case .ready:
            return "checkmark.circle.fill"
        case .noServer:
            return "moon.zzz.fill"
        case .unavailable, .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var showsHeaderSubtitle: Bool {
        appState.snapshot.status != .ready || appState.snapshot.sessions.isEmpty
    }
}

private struct SessionCardView: View {
    let session: TmuxSessionSummary
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void
    let onKill: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(session.name)
                        .font(.headline)
                        .lineLimit(1)
                    StatusBadge(title: session.isAttached ? "Attached" : "Idle", isActive: session.isAttached)
                }
                .layoutPriority(1)

                Text(metadataLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let lastActivityAt = session.lastActivityAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text("Last active")
                        Text(lastActivityAt, style: .relative)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .help(detailLine)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Button(primaryActionTitle, action: onPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button(role: .destructive, action: onKill) {
                    Image(systemName: "trash")
                }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Kill session")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cardFillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(cardStrokeColor)
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

        if let primaryCommand = session.commands.first {
            parts.append(primaryCommand)
        }

        if session.commands.count > 1 {
            parts.append("+\(session.commands.count - 1)")
        }

        return parts.joined(separator: " • ")
    }

    private var detailLine: String {
        var parts = [metadataLine]

        if session.commands.count > 1 {
            parts.append(session.commands.joined(separator: ", "))
        }

        return parts.joined(separator: "\n")
    }

    private var cardFillColor: Color {
        session.isAttached ? Color.green.opacity(0.08) : Color(nsColor: .controlBackgroundColor)
    }

    private var cardStrokeColor: Color {
        session.isAttached ? Color.green.opacity(0.18) : Color.primary.opacity(0.08)
    }
}

private struct StatusBadge: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(isActive ? Color.green.opacity(0.15) : Color.gray.opacity(0.12))
            .foregroundStyle(isActive ? Color.green : Color.secondary)
            .clipShape(Capsule())
    }
}

private struct CompactMetricChip: View {
    let value: String
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct StatusMessageView: View {
    let message: String
    let color: Color
    let iconName: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(color)
            Text(message)
                .font(.caption)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.10))
        )
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
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
