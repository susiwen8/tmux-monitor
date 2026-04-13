import SwiftUI

@main
struct TmuxMonitorApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        Task { @MainActor in
            state.start()
        }
    }

    var body: some Scene {
        MenuBarExtra(appState.menuBarTitle, systemImage: appState.menuBarSymbolName) {
            MenuBarView(appState: appState)
                .onAppear {
                    appState.start()
                    appState.refresh()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
                .frame(width: 420)
        }
    }
}
