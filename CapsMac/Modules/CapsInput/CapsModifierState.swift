import Foundation

/// Tracks Caps Lock layer modifier state (hold vs tap lock, suspend).
struct CapsModifierState: Equatable {
    var isLayerHeld = false
    var isCapsLockEngaged = false
    var isSuspended = false

    var isLayerActive: Bool {
        isLayerHeld && !isSuspended
    }

    var layerDescription: String {
        if isSuspended { return "Suspended" }
        if isLayerHeld { return "Held" }
        if isCapsLockEngaged { return "Caps Lock" }
        return "Idle"
    }
}
