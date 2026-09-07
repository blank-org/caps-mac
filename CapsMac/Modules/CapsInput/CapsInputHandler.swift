import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Captures Caps Lock / Right Command as the Caps layer modifier via a CGEvent tap.
///
/// Key remapping is still ahead; this handler owns the layer key, swallows native
/// Caps Lock toggling, and drives `CapsModifierState` (hold, double-tap lock, suspend).
final class CapsInputHandler {
    var onStateChange: ((CapsModifierState) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var releasePollTimer: Timer?

    private var state = CapsModifierState()
    private var capsIsHeld = false
    private var rightCommandIsHeld = false
    private var lastCapsLockTime: TimeInterval = 0
    private var capsPollSawPhysicalDown = false
    private var desiredCapsLockLED = false

    private static let capsLockKeyCode = CGKeyCode(kVK_CapsLock)
    private static let rightCommandKeyCode = CGKeyCode(kVK_RightCommand)
    private static let doubleTapInterval: TimeInterval = 0.3
    private static let injectedUserData: Int64 = 0x4341_5053 // 'CAPS'
    private static let rightCommandDeviceFlag = CGEventFlags(rawValue: 0x0000_0010)

    var isTapEnabled: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() {
        guard !isTapEnabled else {
            publish()
            return
        }
        stopTap()
        guard AccessibilityPermission.isGranted else {
            publish()
            return
        }
        installTap()
    }

    func stop() {
        resetTransientState(publishAfter: false)
        stopTap()
        publish()
    }

    func setSuspended(_ suspended: Bool) {
        state.isSuspended = suspended
        if suspended {
            resetTransientState(publishAfter: false)
        }
        publish()
    }

    func resetTransientState(publishAfter: Bool = true) {
        stopReleasePoller()
        capsIsHeld = false
        rightCommandIsHeld = false
        state.isLayerHeld = false
        lastCapsLockTime = 0
        if publishAfter {
            publish()
        }
    }

    private func stopTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
    }

    private func installTap() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let handler = Unmanaged<CapsInputHandler>.fromOpaque(refcon).takeUnretainedValue()
                return handler.handleEvent(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            fputs("CapsMac: failed to create event tap. Grant Accessibility and reopen Settings.\n", stderr)
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        publish()
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            publish()
            return Unmanaged.passUnretained(event)
        }

        if isInjected(event) {
            return Unmanaged.passUnretained(event)
        }

        if state.isSuspended {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        if keyCode == Self.capsLockKeyCode {
            return handleCapsLock(type: type, event: event)
        }
        if keyCode == Self.rightCommandKeyCode {
            return handleRightCommand(type: type, event: event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func isInjected(_ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == Self.injectedUserData {
            return true
        }
        let sourcePID = event.getIntegerValueField(.eventSourceUnixProcessID)
        return sourcePID != 0 && sourcePID == Int64(ProcessInfo.processInfo.processIdentifier)
    }

    private func handleCapsLock(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            if !capsIsHeld {
                capsDown()
            }
            return nil
        case .keyUp:
            capsUp()
            return nil
        case .flagsChanged:
            if capsIsHeld {
                if !CGEventSource.keyState(.hidSystemState, key: Self.capsLockKeyCode) {
                    capsUp()
                }
            } else {
                capsDown()
            }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleRightCommand(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let down: Bool
        switch type {
        case .keyDown:
            down = true
        case .keyUp:
            down = false
        case .flagsChanged:
            if event.flags.contains(Self.rightCommandDeviceFlag) {
                down = true
            } else if rightCommandIsHeld {
                down = false
            } else {
                down = event.flags.contains(.maskCommand)
            }
        default:
            return Unmanaged.passUnretained(event)
        }

        setRightCommandHeld(down)
        return nil
    }

    private func capsDown() {
        if capsIsHeld { return }
        capsIsHeld = true
        capsPollSawPhysicalDown = false
        startReleasePoller()

        if state.isCapsLockEngaged {
            state.isCapsLockEngaged = false
            state.isLayerHeld = false
            setHardwareCapsLock(enabled: false)
            publish()
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if now - lastCapsLockTime < Self.doubleTapInterval && lastCapsLockTime > 0 {
            state.isCapsLockEngaged = true
            state.isLayerHeld = false
            setHardwareCapsLock(enabled: true)
        } else {
            state.isLayerHeld = true
            setHardwareCapsLock(enabled: false)
        }
        lastCapsLockTime = now
        publish()
    }

    private func capsUp() {
        guard capsIsHeld else { return }
        capsIsHeld = false
        stopReleasePoller()
        if !state.isCapsLockEngaged && !rightCommandIsHeld {
            state.isLayerHeld = false
        }
        publish()
    }

    private func setRightCommandHeld(_ down: Bool) {
        if down {
            guard !rightCommandIsHeld else { return }
            rightCommandIsHeld = true
            if !state.isCapsLockEngaged {
                state.isLayerHeld = true
            }
            publish()
        } else {
            guard rightCommandIsHeld else { return }
            rightCommandIsHeld = false
            if !capsIsHeld && !state.isCapsLockEngaged {
                state.isLayerHeld = false
            }
            publish()
        }
    }

    private func startReleasePoller() {
        stopReleasePoller()
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.pollCapsLockRelease()
        }
        RunLoop.main.add(timer, forMode: .common)
        releasePollTimer = timer
    }

    private func stopReleasePoller() {
        releasePollTimer?.invalidate()
        releasePollTimer = nil
        capsPollSawPhysicalDown = false
    }

    private func pollCapsLockRelease() {
        guard capsIsHeld else {
            stopReleasePoller()
            return
        }
        let physical = CGEventSource.keyState(.hidSystemState, key: Self.capsLockKeyCode)
        if physical {
            capsPollSawPhysicalDown = true
        } else if capsPollSawPhysicalDown {
            capsUp()
        }
    }

    private func setHardwareCapsLock(enabled: Bool) {
        desiredCapsLockLED = enabled
        DispatchQueue.main.async { [weak self] in
            self?.alignHardwareCapsLock(remainingTries: 6)
        }
    }

    private func alignHardwareCapsLock(remainingTries: Int) {
        let currentlyOn = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        guard currentlyOn != desiredCapsLockLED else { return }
        guard remainingTries > 0 else { return }
        postInjectedCapsLockPulse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.alignHardwareCapsLock(remainingTries: remainingTries - 1)
        }
    }

    private func postInjectedCapsLockPulse() {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = Self.injectedUserData
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: Self.capsLockKeyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: Self.capsLockKeyCode, keyDown: false)
        else { return }
        down.setIntegerValueField(.eventSourceUserData, value: Self.injectedUserData)
        up.setIntegerValueField(.eventSourceUserData, value: Self.injectedUserData)
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func publish() {
        let snapshot = state
        if Thread.isMainThread {
            onStateChange?(snapshot)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onStateChange?(snapshot)
            }
        }
    }
}
