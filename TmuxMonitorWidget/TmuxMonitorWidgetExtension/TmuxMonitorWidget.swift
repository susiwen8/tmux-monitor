import SwiftUI
import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: TmuxSnapshot
}

struct SnapshotProvider: TimelineProvider {
    private static let staleFailureInterval: TimeInterval = 120

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(
            SnapshotEntry(
                date: .now,
                snapshot: currentSnapshot()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = currentSnapshot()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 1, to: .now) ?? .now.addingTimeInterval(60)
        let timeline = Timeline(
            entries: [SnapshotEntry(date: snapshot.generatedAt, snapshot: snapshot)],
            policy: .after(nextRefresh)
        )
        completion(timeline)
    }

    private func currentSnapshot() -> TmuxSnapshot {
        do {
            guard let snapshot = try SharedSnapshotStore().load() else {
                return .empty(
                    status: .failed,
                    errorMessage: "Waiting for the app to publish the first snapshot."
                )
            }

            if snapshot.status != .ready, Date().timeIntervalSince(snapshot.generatedAt) > Self.staleFailureInterval {
                return TmuxSnapshot(
                    generatedAt: snapshot.generatedAt,
                    status: .failed,
                    sessions: snapshot.sessions,
                    errorMessage: "Snapshot is stale. Open the menu bar app to refresh."
                )
            }

            return snapshot
        } catch SharedSnapshotStoreError.suiteUnavailable {
            return .empty(
                status: .failed,
                errorMessage: "Shared App Group is unavailable."
            )
        } catch {
            return .empty(
                status: .failed,
                errorMessage: "Failed to read shared snapshot."
            )
        }
    }
}

struct TmuxMonitorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKind, provider: SnapshotProvider()) { entry in
            TmuxMonitorWidgetView(entry: entry)
                .widgetURL(AppConstants.appOpenURL)
        }
        .configurationDisplayName("Tmux Sessions")
        .description("Shows a compact summary of local tmux sessions.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TmuxMonitorWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            switch entry.snapshot.status {
            case .ready:
                Text("\(entry.snapshot.sessionCount)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("\(entry.snapshot.attachedSessionCount) attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let leadSession = entry.snapshot.sessions.first {
                    Text(leadSession.name)
                        .font(.caption)
                        .lineLimit(1)
                }
            case .noServer:
                Text("No tmux server")
                    .font(.headline)
                Text("Start tmux in Terminal to begin tracking.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .unavailable, .failed:
                Text("Needs attention")
                    .font(.headline)
                Text(entry.snapshot.errorMessage ?? "Refresh the app.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            Spacer()
            footer
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow

            switch entry.snapshot.status {
            case .ready:
                HStack(spacing: 14) {
                    metric(title: "Sessions", value: "\(entry.snapshot.sessionCount)")
                    metric(title: "Attached", value: "\(entry.snapshot.attachedSessionCount)")
                    metric(title: "Panes", value: "\(entry.snapshot.totalPaneCount)")
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(entry.snapshot.sessions.prefix(3)) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(session.windowCount)w • \(session.paneCount)p")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(session.isAttached ? "Attached" : "Idle")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(session.isAttached ? .green : .secondary)
                        }
                    }
                }
            case .noServer:
                widgetMessage(
                    title: "No tmux server",
                    detail: "Start tmux in Terminal to begin tracking."
                )
            case .unavailable, .failed:
                widgetMessage(
                    title: "Snapshot unavailable",
                    detail: entry.snapshot.errorMessage ?? "Open the app to inspect the tmux path and refresh state."
                )
            }

            Spacer()
            footer
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var titleRow: some View {
        HStack {
            Text("tmux")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Spacer()
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
        }
    }

    private var footer: some View {
        Text(entry.date, style: .time)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func widgetMessage(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
    }

    private var iconName: String {
        switch entry.snapshot.status {
        case .ready:
            return entry.snapshot.attachedSessionCount > 0 ? "terminal.fill" : "terminal"
        case .noServer:
            return "moon.zzz"
        case .unavailable:
            return "questionmark.app"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch entry.snapshot.status {
        case .ready:
            return entry.snapshot.attachedSessionCount > 0 ? .green : .primary
        case .noServer:
            return .orange
        case .unavailable, .failed:
            return .red
        }
    }
}
