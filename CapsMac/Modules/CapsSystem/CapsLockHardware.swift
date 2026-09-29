import CoreGraphics
import Foundation
import IOKit

/// Reads and sets the HID system's Caps Lock latch.
///
/// A session `CGEvent` tap can swallow Caps key events, but macOS still toggles the
/// driver-level Caps Lock modifier before those events reach the tap. Injected Caps
/// key events are not a reliable way to undo that latch.
enum CapsLockHardware {
    private static let capsLockModifier = Int32(kIOHIDCapsLockState)

    static func isModifierLockEngaged() -> Bool {
        guard let connect = openHIDParamConnect() else {
            return CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        }
        defer { IOServiceClose(connect) }
        var state = false
        let result = IOHIDGetModifierLockState(connect, capsLockModifier, &state)
        guard result == KERN_SUCCESS else {
            return CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
        }
        return state
    }

    @discardableResult
    static func setModifierLockEngaged(_ engaged: Bool) -> Bool {
        guard let connect = openHIDParamConnect() else { return false }
        defer { IOServiceClose(connect) }
        return IOHIDSetModifierLockState(connect, capsLockModifier, engaged) == KERN_SUCCESS
    }

    private static func openHIDParamConnect() -> io_connect_t? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connect: io_connect_t = 0
        let open = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
        guard open == KERN_SUCCESS else { return nil }
        return connect
    }
}
