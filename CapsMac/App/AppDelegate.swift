import AppKit

/// AppKit lifecycle hooks. Keyboard capture lives in `AppState` / `CapsInputHandler`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        SingleInstance.terminateStaleCopies()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {}

    func applicationWillTerminate(_ notification: Notification) {}
}
