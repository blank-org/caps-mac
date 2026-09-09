import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Text("Caps layer: \(appState.modifierState.layerDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !appState.isAccessibilityGranted {
                Text("Accessibility: not granted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button(appState.isSuspended ? "Resume Hotkeys" : "Suspend Hotkeys") {
                appState.toggleSuspended()
            }

            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Settings…")
                }
            } else {
                Button("Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }

            Button("Keyboard Map") {
                SystemIntegration.showKeyboardMap()
            }

            Button("About Caps") {
                openWindow(id: "about")
            }

            Divider()

            Button("Quit Caps") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
