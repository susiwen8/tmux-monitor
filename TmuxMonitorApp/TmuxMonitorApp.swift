import SwiftUI

@main
struct TmuxMonitorApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        state.start()
        _appState = StateObject(wrappedValue: state)
    }

    var body: some Scene {
        MenuBarExtra(appState.menuBarTitle, systemImage: appState.menuBarSymbolName) {
            MenuBarView(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
                .frame(width: 420)
        }
    }
}
