import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var configuration = ConfigStore.shared.load()

    var body: some View {
        Form {
            Section("Layer") {
                LabeledContent("Status") {
                    Text(appState.isSuspended ? "Suspended" : appState.modifierState.layerDescription)
                }
            }

            Section("Configuration") {
                Toggle("Map right click to left click", isOn: $configuration.rightClickMapsToLeftClick)
                    .help(Text(verbatim: "Mirrors the Windows right_click_left option in config.ini."))
            }

            Section("Permissions") {
                LabeledContent("Accessibility") {
                    Text(appState.accessibilityStatusDescription)
                        .foregroundStyle(appState.isAccessibilityGranted ? Color.green : Color.orange)
                }
                LabeledContent("Keyboard hook") {
                    Text(keyboardHookDescription)
                        .foregroundStyle(appState.isEventTapRunning ? Color.green : Color.secondary)
                }
                if !appState.isAccessibilityGranted {
                    Text("Grant access in System Settings, then return here. Status updates automatically — no restart required once macOS reports the app as trusted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(appState.isAccessibilityGranted ? "Open Accessibility Settings" : "Grant Accessibility Access") {
                    appState.requestAccessibilityAccess()
                }
            }

            Section("Development") {
                Text("Hold Caps Lock (or Right Command) for the layer. WASD / IJKL are arrows; T/Y home/end; U/R page up/down. Media and app shortcuts are next.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            appState.refreshAccessibilityStatus()
            appState.startSettingsPermissionPolling()
        }
        .onDisappear {
            appState.stopSettingsPermissionPolling()
            ConfigStore.shared.save(configuration)
        }
    }

    private var keyboardHookDescription: String {
        if appState.isEventTapRunning {
            return "Running"
        }
        if appState.isAccessibilityGranted {
            return "Not running"
        }
        return "Waiting for Accessibility"
    }
}
