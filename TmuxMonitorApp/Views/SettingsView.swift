import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("Runtime") {
                TextField("tmux path", text: $appState.tmuxPath)
                Picker("Attach with", selection: $appState.terminalApp) {
                    ForEach(TerminalApp.allCases) { terminal in
                        Text(terminal.displayName).tag(terminal)
                    }
                }
                Stepper(value: $appState.pollIntervalSeconds, in: 3...60, step: 1) {
                    Text("Refresh every \(Int(appState.pollIntervalSeconds)) seconds")
                }
                Button("Refresh Now") {
                    appState.refresh()
                }
            }

            Section("Widget") {
                LabeledContent("App Group", value: AppConstants.appGroupID)
                Text("Keep the Xcode capability and the entitlement files aligned with this App Group so the widget can read the latest snapshot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}
