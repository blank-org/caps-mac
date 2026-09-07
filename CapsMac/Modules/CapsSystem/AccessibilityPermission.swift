import AppKit
import ApplicationServices

/// Accessibility permission helpers required for global key remapping.
enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static var statusDescription: String {
        isGranted ? "Granted" : "Required — not granted"
    }

    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        openSystemSettings()
    }

    static func openSystemSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
