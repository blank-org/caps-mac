import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// macOS-specific integrations (media keys, display sleep, app launchers).
enum SystemIntegration {
    /// Matches `CapsInputHandler` injected events so the tap does not re-handle them.
    private static let injectedUserData: Int64 = 0x4341_5053 // 'CAPS'

    private static let pasteTypeWaitIterations = 25
    private static let pasteTypePollInterval: TimeInterval = 0.1
    private static let pasteTypeInterKeyDelay: TimeInterval = 0.02
    private static let spaceKeyCode = CGKeyCode(kVK_Space)
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

    static func sleepSystem() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]
        do {
            try process.run()
        } catch {
            fputs("CapsMac: failed to sleep: \(error)\n", stderr)
        }
    }

    static func showKeyboardMap() {
        DispatchQueue.main.async {
            KeyboardMapWindowController.shared.showMap()
        }
    }

    static func sleepDisplay() {
        // Stub: IOKit display sleep (Windows Caps+Z) will live here.
    }

    static func setDarkMode(enabled: Bool) {
        // Stub: AppleInterfaceStyle toggling will live here.
        _ = enabled
    }

    /// Types the clipboard as raw keystrokes (Windows Caps+B / paste-type).
    ///
    /// Waits up to ~2.5s; Space ends the wait early and is not typed. Empty clipboard is a no-op.
    static func pasteType() {
        DispatchQueue.global(qos: .userInitiated).async {
            waitForPasteTypeTriggerEnd()
            guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
                return
            }
            typeRawKeystrokes(text)
        }
    }

    private static func waitForPasteTypeTriggerEnd() {
        for _ in 0 ..< pasteTypeWaitIterations {
            if CGEventSource.keyState(.hidSystemState, key: spaceKeyCode) {
                break
            }
            Thread.sleep(forTimeInterval: pasteTypePollInterval)
        }
    }

    private static func typeRawKeystrokes(_ text: String) {
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\r" {
                let next = text.index(after: index)
                if next < text.endIndex, text[next] == "\n" {
                    index = next
                }
                postVirtualKey(CGKeyCode(kVK_Return))
            } else if character == "\n" {
                postVirtualKey(CGKeyCode(kVK_Return))
            } else if character == "\t" {
                postVirtualKey(CGKeyCode(kVK_Tab))
            } else {
                postUnicodeScalar(character)
            }
            index = text.index(after: index)
            Thread.sleep(forTimeInterval: pasteTypeInterKeyDelay)
        }
    }

    private static func postVirtualKey(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = injectedUserData
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.setIntegerValueField(.eventSourceUserData, value: injectedUserData)
        up.setIntegerValueField(.eventSourceUserData, value: injectedUserData)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private static func postUnicodeScalar(_ character: Character) {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = injectedUserData
        var codeUnits = Array(String(character).utf16)
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        down.keyboardSetUnicodeString(stringLength: codeUnits.count, unicodeString: &codeUnits)
        down.setIntegerValueField(.eventSourceUserData, value: injectedUserData)
        up.setIntegerValueField(.eventSourceUserData, value: injectedUserData)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
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
