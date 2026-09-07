import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// A key plus modifiers to emit while the Caps layer is active.
struct RemappedStroke: Hashable {
    let keyCode: CGKeyCode
    let addedFlags: CGEventFlags

    func hash(into hasher: inout Hasher) {
        hasher.combine(keyCode)
        hasher.combine(addedFlags.rawValue)
    }

    static func == (lhs: RemappedStroke, rhs: RemappedStroke) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.addedFlags == rhs.addedFlags
    }
}

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
    case selectUp
    case selectDown
    case selectWordLeft
    case selectWordRight
    case wordLeft
    case wordRight
    case historyBack
    case historyForward
    case browserBack
    case browserForward
    case deleteForward
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
        case .selectUp: return "Select Up"
        case .selectDown: return "Select Down"
        case .selectWordLeft: return "Select Word Left"
        case .selectWordRight: return "Select Word Right"
        case .wordLeft: return "Word Left"
        case .wordRight: return "Word Right"
        case .historyBack: return "History Back"
        case .historyForward: return "History Forward"
        case .browserBack: return "Browser Back"
        case .browserForward: return "Browser Forward"
        case .deleteForward: return "Delete Forward"
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

    /// Keyboard remap for this action. `nil` means a non-key action (media, mouse, apps).
    var remapping: RemappedStroke? {
        switch self {
        case .moveUp:
            return RemappedStroke(keyCode: CGKeyCode(kVK_UpArrow), addedFlags: [])
        case .moveDown:
            return RemappedStroke(keyCode: CGKeyCode(kVK_DownArrow), addedFlags: [])
        case .moveLeft:
            return RemappedStroke(keyCode: CGKeyCode(kVK_LeftArrow), addedFlags: [])
        case .moveRight:
            return RemappedStroke(keyCode: CGKeyCode(kVK_RightArrow), addedFlags: [])
        case .home:
            return RemappedStroke(keyCode: CGKeyCode(kVK_Home), addedFlags: [])
        case .end:
            return RemappedStroke(keyCode: CGKeyCode(kVK_End), addedFlags: [])
        case .pageUp:
            return RemappedStroke(keyCode: CGKeyCode(kVK_PageUp), addedFlags: [])
        case .pageDown:
            return RemappedStroke(keyCode: CGKeyCode(kVK_PageDown), addedFlags: [])
        case .selectUp:
            return RemappedStroke(keyCode: CGKeyCode(kVK_UpArrow), addedFlags: .maskShift)
        case .selectDown:
            return RemappedStroke(keyCode: CGKeyCode(kVK_DownArrow), addedFlags: .maskShift)
        case .selectWordLeft:
            return RemappedStroke(keyCode: CGKeyCode(kVK_LeftArrow), addedFlags: [.maskShift, .maskAlternate])
        case .selectWordRight:
            return RemappedStroke(keyCode: CGKeyCode(kVK_RightArrow), addedFlags: [.maskShift, .maskAlternate])
        case .wordLeft:
            return RemappedStroke(keyCode: CGKeyCode(kVK_LeftArrow), addedFlags: .maskAlternate)
        case .wordRight:
            return RemappedStroke(keyCode: CGKeyCode(kVK_RightArrow), addedFlags: .maskAlternate)
        case .historyBack:
            return RemappedStroke(keyCode: CGKeyCode(kVK_LeftArrow), addedFlags: .maskCommand)
        case .historyForward:
            return RemappedStroke(keyCode: CGKeyCode(kVK_RightArrow), addedFlags: .maskCommand)
        case .browserBack:
            return RemappedStroke(keyCode: CGKeyCode(kVK_ANSI_LeftBracket), addedFlags: .maskCommand)
        case .browserForward:
            return RemappedStroke(keyCode: CGKeyCode(kVK_ANSI_RightBracket), addedFlags: .maskCommand)
        case .deleteForward:
            return RemappedStroke(keyCode: CGKeyCode(kVK_ForwardDelete), addedFlags: [])
        default:
            return nil
        }
    }
}
