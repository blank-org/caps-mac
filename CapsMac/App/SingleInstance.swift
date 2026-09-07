import AppKit

/// Ensures only one Caps process owns the keyboard hook.
///
/// Matches Windows `#SingleInstance Force` / `Caps_CloseStaleInstances`: a newly
/// launched copy closes any other running instance with the same bundle ID.
enum SingleInstance {
    static func terminateStaleCopies() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let selfPID = ProcessInfo.processInfo.processIdentifier

        func others() -> [NSRunningApplication] {
            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != selfPID }
        }

        var remaining = others()
        guard !remaining.isEmpty else { return }

        remaining.forEach { $0.terminate() }
        waitUntilEmpty(timeout: 1.5)

        remaining = others()
        remaining.forEach { $0.forceTerminate() }
        waitUntilEmpty(timeout: 0.5)
    }

    private static func waitUntilEmpty(timeout: TimeInterval) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let remaining = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != selfPID }
            if remaining.isEmpty { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
