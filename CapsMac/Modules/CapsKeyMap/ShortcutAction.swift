import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// A single remapped action triggered while the Caps layer is active.
enum ShortcutAction: String, CaseIterable, Codable {
    case moveUp
    case moveDown
    case moveLeft
    case moveRight
    case home
    case end
    case pageUp
    case pageDown
    case volumeDown
    case volumeUp
    case volumeMute
    case playPause
    case previousTrack
    case nextTrack
    case mouseLeftClick
    case mouseMiddleClick
    case mouseRightClick
    case openTerminal
    case openEditor
    case toggleDarkMode
    case showKeyboardMap
    case sleepDisplay
    case pasteType
    case unmapped

    var displayName: String {
        switch self {
        case .moveUp: return "Move Up"
        case .moveDown: return "Move Down"
        case .moveLeft: return "Move Left"
        case .moveRight: return "Move Right"
        case .home: return "Home"
        case .end: return "End"
        case .pageUp: return "Page Up"
        case .pageDown: return "Page Down"
        case .volumeDown: return "Volume Down"
        case .volumeUp: return "Volume Up"
        case .volumeMute: return "Volume Mute"
        case .playPause: return "Play/Pause"
        case .previousTrack: return "Previous Track"
        case .nextTrack: return "Next Track"
        case .mouseLeftClick: return "Mouse Left Click"
        case .mouseMiddleClick: return "Mouse Middle Click"
        case .mouseRightClick: return "Mouse Right Click"
        case .openTerminal: return "Open Terminal"
        case .openEditor: return "Open Editor"
        case .toggleDarkMode: return "Toggle Dark Mode"
        case .showKeyboardMap: return "Show Keyboard Map"
        case .sleepDisplay: return "Sleep Display"
        case .pasteType: return "Paste Type"
        case .unmapped: return "Unmapped"
        }
    }

    /// Virtual key to emit while the Caps layer is held. `nil` means not a keyboard remap yet.
    var navigationKeyCode: CGKeyCode? {
        switch self {
        case .moveUp: return CGKeyCode(kVK_UpArrow)
        case .moveDown: return CGKeyCode(kVK_DownArrow)
        case .moveLeft: return CGKeyCode(kVK_LeftArrow)
        case .moveRight: return CGKeyCode(kVK_RightArrow)
        case .home: return CGKeyCode(kVK_Home)
        case .end: return CGKeyCode(kVK_End)
        case .pageUp: return CGKeyCode(kVK_PageUp)
        case .pageDown: return CGKeyCode(kVK_PageDown)
        default: return nil
        }
    }
}
