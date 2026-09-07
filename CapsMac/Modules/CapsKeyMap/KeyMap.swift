import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// Maps physical keys to Caps-layer actions.
///
/// Parity target: `resource/map_caps.csv` and the shortcut table in README.md.
struct KeyMap {
    private let bindings: [String: ShortcutAction]

    init(bindings: [String: ShortcutAction] = KeyMap.defaultBindings) {
        self.bindings = bindings
    }

    func action(forVirtualKey keyCode: CGKeyCode) -> ShortcutAction {
        Self.virtualKeyBindings[keyCode] ?? .unmapped
    }

    func action(forKeyLabel label: String) -> ShortcutAction {
        bindings[label.lowercased(), default: .unmapped]
    }

    /// Hardware key codes for the live event tap.
    static let virtualKeyBindings: [CGKeyCode: ShortcutAction] = [
        CGKeyCode(kVK_ANSI_W): .moveUp,
        CGKeyCode(kVK_ANSI_A): .moveLeft,
        CGKeyCode(kVK_ANSI_S): .moveDown,
        CGKeyCode(kVK_ANSI_D): .moveRight,
        CGKeyCode(kVK_ANSI_I): .moveUp,
        CGKeyCode(kVK_ANSI_J): .moveLeft,
        CGKeyCode(kVK_ANSI_K): .moveDown,
        CGKeyCode(kVK_ANSI_L): .moveRight,
        CGKeyCode(kVK_ANSI_T): .home,
        CGKeyCode(kVK_ANSI_Y): .end,
        CGKeyCode(kVK_ANSI_U): .pageUp,
        CGKeyCode(kVK_ANSI_R): .pageDown,
        CGKeyCode(kVK_ANSI_E): .selectUp,
        CGKeyCode(kVK_ANSI_F): .selectDown,
        CGKeyCode(kVK_ANSI_G): .selectWordLeft,
        CGKeyCode(kVK_ANSI_H): .selectWordRight,
        CGKeyCode(kVK_ANSI_V): .wordLeft,
        CGKeyCode(kVK_ANSI_N): .wordRight,
        CGKeyCode(kVK_ANSI_C): .historyBack,
        CGKeyCode(kVK_ANSI_M): .historyForward,
        CGKeyCode(kVK_ANSI_X): .browserBack,
        CGKeyCode(kVK_ANSI_Comma): .browserForward,
        CGKeyCode(kVK_Delete): .deleteForward,
        CGKeyCode(kVK_ANSI_O): .volumeDown,
        CGKeyCode(kVK_ANSI_LeftBracket): .volumeUp,
        CGKeyCode(kVK_ANSI_Semicolon): .volumeMute,
        CGKeyCode(kVK_ANSI_P): .playPause,
        CGKeyCode(kVK_ANSI_RightBracket): .previousTrack,
        CGKeyCode(kVK_ANSI_Backslash): .nextTrack,
    ]

    /// Label map for config/UI; expand toward Windows parity.
    static let defaultBindings: [String: ShortcutAction] = [
        "w": .moveUp,
        "a": .moveLeft,
        "s": .moveDown,
        "d": .moveRight,
        "i": .moveUp,
        "j": .moveLeft,
        "k": .moveDown,
        "l": .moveRight,
        "t": .home,
        "y": .end,
        "u": .pageUp,
        "r": .pageDown,
        "e": .selectUp,
        "f": .selectDown,
        "g": .selectWordLeft,
        "h": .selectWordRight,
        "v": .wordLeft,
        "n": .wordRight,
        "c": .historyBack,
        "m": .historyForward,
        "x": .browserBack,
        ",": .browserForward,
        "backspace": .deleteForward,
        "o": .volumeDown,
        "p": .playPause,
        "[": .volumeUp,
        "]": .previousTrack,
        "\\": .nextTrack,
        ";": .volumeMute,
        "1": .mouseLeftClick,
        "2": .mouseMiddleClick,
        "3": .mouseRightClick,
        "space": .openTerminal,
        "/": .openEditor,
        ".": .toggleDarkMode,
        "=": .showKeyboardMap,
        "q": .sleepDisplay,
        "b": .pasteType,
    ]
}
