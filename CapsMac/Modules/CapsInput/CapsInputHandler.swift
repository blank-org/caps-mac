import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Captures Caps Lock / Right Command as the Caps layer modifier via a CGEvent tap,
/// and remaps navigation, selection, and delete keys while the layer is active.
final class CapsInputHandler {
    private struct HeldStroke: Hashable {
        let keyCode: CGKeyCode
        let flags: CGEventFlags.RawValue
    }

    var onStateChange: ((CapsModifierState) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var releasePollTimer: Timer?
    private var holdTimer: Timer?
    private let keyMap = KeyMap()
    private var heldRemaps: [HeldStroke: Int] = [:]

    private var state = CapsModifierState()
    private var capsIsHeld = false
    private var pendingCapsTap = false
    private var rightCommandIsHeld = false
    private var capsPollSawPhysicalDown = false

    private static let capsLockKeyCode = CGKeyCode(kVK_CapsLock)
    private static let rightCommandKeyCode = CGKeyCode(kVK_RightCommand)
    private static let holdThreshold: TimeInterval = 0.18
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
        releaseHeldRemaps()
        stopHoldTimer()
        stopReleasePoller()
        capsIsHeld = false
        pendingCapsTap = false
        rightCommandIsHeld = false
        state.isLayerHeld = false
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
        syncCapsLockEngaged()
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

        if capsIsHeld && !state.isLayerHeld && !state.isSuspended {
            activateLayerFromHold()
        }

        if state.isLayerActive {
            return handleLayerKey(type: type, event: event, keyCode: keyCode)
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

    private func handleLayerKey(type: CGEventType, event: CGEvent, keyCode: CGKeyCode) -> Unmanaged<CGEvent>? {
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let action = keyMap.action(forVirtualKey: keyCode)
        if action.remapping == nil {
            return handleOneShot(action: action, type: type, event: event)
        }

        guard var stroke = action.remapping else {
            return Unmanaged.passUnretained(event)
        }

        if action == .deleteForward, event.flags.contains(.maskControl) || event.flags.contains(.maskCommand) {
            stroke = RemappedStroke(keyCode: CGKeyCode(kVK_ForwardDelete), addedFlags: .maskAlternate)
        }

        var flags = event.flags
        flags.remove(.maskCommand)
        flags.remove(.maskControl)
        flags.remove(.maskAlphaShift)
        flags.insert(stroke.addedFlags)

        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(stroke.keyCode))
        event.flags = flags

        let held = HeldStroke(keyCode: stroke.keyCode, flags: flags.rawValue)
        if type == .keyDown {
            heldRemaps[held, default: 0] += 1
        } else if let count = heldRemaps[held] {
            if count <= 1 {
                heldRemaps.removeValue(forKey: held)
            } else {
                heldRemaps[held] = count - 1
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleOneShot(action: ShortcutAction, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        switch action {
        case .volumeDown, .volumeUp:
            if type == .keyDown {
                performMedia(action)
            }
            return nil
        case .volumeMute, .playPause, .previousTrack, .nextTrack:
            if type == .keyDown && !isRepeat {
                performMedia(action)
            }
            return nil
        case .sleepDisplay:
            if type == .keyDown && !isRepeat {
                SystemIntegration.sleepSystem()
            }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func performMedia(_ action: ShortcutAction) {
        switch action {
        case .volumeDown: SystemIntegration.volumeDown()
        case .volumeUp: SystemIntegration.volumeUp()
        case .volumeMute: SystemIntegration.volumeMute()
        case .playPause: SystemIntegration.playPause()
        case .previousTrack: SystemIntegration.previousTrack()
        case .nextTrack: SystemIntegration.nextTrack()
        default: break
        }
    }

    private func releaseHeldRemaps() {
        let held = heldRemaps
        heldRemaps.removeAll()
        for (stroke, _) in held {
            postInjectedKey(stroke.keyCode, keyDown: false, flags: CGEventFlags(rawValue: stroke.flags))
        }
    }

    private func postInjectedKey(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = Self.injectedUserData
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { return }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.injectedUserData)
        event.post(tap: .cgSessionEventTap)
    }

    private func capsDown() {
        if capsIsHeld { return }
        capsIsHeld = true
        pendingCapsTap = true
        capsPollSawPhysicalDown = false
        startHoldTimer()
        startReleasePoller()
        publish()
    }

    private func capsUp() {
        guard capsIsHeld else { return }
        capsIsHeld = false
        stopHoldTimer()
        stopReleasePoller()

        let shouldToggleCaps = pendingCapsTap
        pendingCapsTap = false

        if state.isLayerHeld && !rightCommandIsHeld {
            state.isLayerHeld = false
            releaseHeldRemaps()
        }

        if shouldToggleCaps {
            toggleHardwareCapsLock()
        }
        syncCapsLockEngaged()
        publish()
    }

    private func activateLayerFromHold() {
        guard capsIsHeld else { return }
        pendingCapsTap = false
        stopHoldTimer()
        guard !state.isLayerHeld else { return }
        state.isLayerHeld = true
        publish()
    }

    private func startHoldTimer() {
        stopHoldTimer()
        let timer = Timer(timeInterval: Self.holdThreshold, repeats: false) { [weak self] _ in
            self?.activateLayerFromHold()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func stopHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func setRightCommandHeld(_ down: Bool) {
        if down {
            guard !rightCommandIsHeld else { return }
            rightCommandIsHeld = true
            pendingCapsTap = false
            stopHoldTimer()
            state.isLayerHeld = true
            publish()
        } else {
            guard rightCommandIsHeld else { return }
            rightCommandIsHeld = false
            if !capsIsHeld {
                state.isLayerHeld = false
                releaseHeldRemaps()
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

    private func toggleHardwareCapsLock() {
        let currentlyOn = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        postInjectedCapsLockPulse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.alignHardwareCapsLock(enabled: !currentlyOn, remainingTries: 6)
        }
    }

    private func syncCapsLockEngaged() {
        state.isCapsLockEngaged = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
    }

    private func alignHardwareCapsLock(enabled: Bool, remainingTries: Int) {
        let currentlyOn = CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        state.isCapsLockEngaged = currentlyOn
        guard currentlyOn != enabled else {
            publish()
            return
        }
        guard remainingTries > 0 else {
            publish()
            return
        }
        postInjectedCapsLockPulse()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            self?.alignHardwareCapsLock(enabled: enabled, remainingTries: remainingTries - 1)
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
