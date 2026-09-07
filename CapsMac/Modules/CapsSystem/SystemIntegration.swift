import AppKit
import Foundation

/// macOS-specific integrations (media keys, display sleep, app launchers).
enum SystemIntegration {
    /// HID system-defined key types from `IOKit/hidsystem/ev_keymap.h`.
    private enum MediaKey: Int32 {
        case soundUp = 0
        case soundDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
        case play = 16
        case next = 17
        case previous = 18
    }

    static func volumeDown() { postMediaKey(.soundDown) }
    static func volumeUp() { postMediaKey(.soundUp) }
    static func volumeMute() { postMediaKey(.mute) }
    static func playPause() { postMediaKey(.play) }
    static func nextTrack() { postMediaKey(.next) }
    static func previousTrack() { postMediaKey(.previous) }

    static func openTerminal() {
        NSWorkspace.shared.launchApplication("Terminal")
    }

    static func openEditor() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func sleepDisplay() {
        // Stub: IOKit display sleep call will live here.
    }

    static func setDarkMode(enabled: Bool) {
        // Stub: AppleInterfaceStyle toggling will live here.
        _ = enabled
    }

    private static func postMediaKey(_ key: MediaKey) {
        postMediaKeyEvent(key, down: true)
        postMediaKeyEvent(key, down: false)
    }

    private static func postMediaKeyEvent(_ key: MediaKey, down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0x0A00 : 0x0B00)
        let data1 = Int((key.rawValue << 16) | Int32(down ? 0x0A00 : 0x0B00))
        guard
            let nsEvent = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ),
            let event = nsEvent.cgEvent
        else { return }
        event.post(tap: .cghidEventTap)
    }
}
