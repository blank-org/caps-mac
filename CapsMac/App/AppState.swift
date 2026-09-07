import AppKit
import Combine
import Foundation

/// Shared UI/runtime state for the menu bar shell.
final class AppState: ObservableObject {
    @Published var isSuspended = false
    @Published var modifierState = CapsModifierState()
    @Published var isAccessibilityGranted = AccessibilityPermission.isGranted
    @Published var isEventTapRunning = false

    private let inputHandler = CapsInputHandler()
    private var permissionPollTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    var accessibilityStatusDescription: String {
        isAccessibilityGranted ? "Granted" : "Required — not granted"
    }

    init() {
        SingleInstance.terminateStaleCopies()
        inputHandler.onStateChange = { [weak self] state in
            guard let self else { return }
            self.modifierState = state
            self.isEventTapRunning = self.inputHandler.isTapEnabled
        }
        startPermissionMonitoring()
        refreshAccessibilityStatus()
        syncInputHandler()
    }

    deinit {
        permissionPollTimer?.invalidate()
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        inputHandler.stop()
    }

    func toggleSuspended() {
        isSuspended.toggle()
        modifierState.isSuspended = isSuspended
        inputHandler.setSuspended(isSuspended)
    }

    func refreshAccessibilityStatus() {
        let granted = AccessibilityPermission.isGranted
        let changed = granted != isAccessibilityGranted
        isAccessibilityGranted = granted
        if changed || (granted && !inputHandler.isTapEnabled) {
            syncInputHandler()
        }
        isEventTapRunning = inputHandler.isTapEnabled
    }

    func requestAccessibilityAccess() {
        AccessibilityPermission.requestAccess()
        startPermissionPolling(untilGrantedOrSeconds: 10)
    }

    func startSettingsPermissionPolling() {
        startPermissionPolling(untilGrantedOrSeconds: nil)
    }

    func stopSettingsPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
    }

    private func syncInputHandler() {
        if isAccessibilityGranted {
            inputHandler.setSuspended(isSuspended)
            inputHandler.start()
        } else {
            inputHandler.stop()
        }
        isEventTapRunning = inputHandler.isTapEnabled
    }

    private func startPermissionMonitoring() {
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshAccessibilityStatus()
            }
        )
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.inputHandler.stop()
            }
        )
        workspaceObservers.append(
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.inputHandler.resetTransientState()
                self?.refreshAccessibilityStatus()
            }
        )
        distributedObservers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name("com.apple.accessibility.api"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.refreshAccessibilityStatus()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self?.refreshAccessibilityStatus()
                }
            }
        )
    }

    private func startPermissionPolling(untilGrantedOrSeconds limit: TimeInterval?) {
        permissionPollTimer?.invalidate()
        let startedAt = Date()
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.refreshAccessibilityStatus()
            if self.isAccessibilityGranted {
                timer.invalidate()
                self.permissionPollTimer = nil
                return
            }
            if let limit, Date().timeIntervalSince(startedAt) > limit {
                timer.invalidate()
                self.permissionPollTimer = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionPollTimer = timer
    }
}
