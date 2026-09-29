# Caps for macOS

Native Swift/SwiftUI port of [Caps](../README.md) — a menu-bar keyboard utility that turns **Caps Lock** into a hold-modifier for home-row navigation, editing, media, and more.

> **Status:** menu-bar utility with Accessibility status, single-instance launch, hold Caps Lock for the layer (Right Command is hold-only), double-tap Caps Lock for normal caps lock, home-row remaps, media keys, Caps+Q sleep, Caps+B paste-type (robo paste), and Caps+= (or the menu bar item) for the keyboard map. Mouse and remaining app shortcuts are not implemented yet.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15 or later (Xcode 16 recommended)
- Apple Silicon or Intel Mac

## Open in Xcode

```bash
open macos/CapsMac.xcodeproj
```

Select the **CapsMac** scheme, then **Product → Run** (⌘R).

The app runs as a **menu-bar utility** (`LSUIElement`): no Dock icon. Look for the keyboard icon in the menu bar. Launch Services refuses a second copy; a new launch (including Xcode Run) closes any stale Caps process so only one keyboard hook is active.

## Project layout

```
macos/
├── CapsMac.xcodeproj/     # Xcode project (open this)
├── CapsMac/
│   ├── CapsMacApp.swift   # @main entry, MenuBarExtra + Settings
│   ├── App/               # AppDelegate, shared AppState
│   ├── Views/             # Menu bar menu, Settings, About, keyboard map window
│   ├── Modules/
│   │   ├── CapsInput/     # CGEvent tap / Caps Lock layer state
│   │   ├── CapsKeyMap/    # Key → action map (navigation live)
│   │   ├── CapsConfig/    # Configuration persistence (stubs)
│   │   └── CapsSystem/    # Accessibility, media keys, app launch (partial)
│   └── Resources/         # Info.plist, Assets, keyboard-map-tks.svg
└── README.md              # this file
```

## Module boundaries (planned)

| Module | Responsibility |
|--------|----------------|
| **CapsInput** | CGEvent tap: hold Caps Lock / Right Command activates the layer; double-tap Caps Lock toggles caps (single tap stays off) |
| **CapsKeyMap** | Arrows, selection, word/browser jumps, Backspace → Delete, media keys, Caps+B paste-type, Caps+= map |
| **CapsConfig** | User settings (`~/Library/Application Support/Caps/config.json`) |
| **CapsSystem** | Accessibility, volume/media keys, Caps+Q sleep, keyboard map window; app launchers still stubbed |

## Accessibility permission

Global key remapping requires **Accessibility** access. Open **Settings** from the menu bar and use **Grant Accessibility Access**. After you enable Caps in System Settings → Privacy & Security → Accessibility, the Settings window updates to **Granted** and starts the keyboard hook automatically (no restart in typical cases). If the hook still says **Not running**, quit and reopen Caps.

macOS ties Accessibility grants to the app’s **code signature** (CDHash). Debug builds signed **ad hoc** (no `DEVELOPMENT_TEAM`) get a new hash on every rebuild, so System Settings drops the grant. This project sets `DEVELOPMENT_TEAM` to a stable Apple Development team in `CapsMac.xcodeproj` so local Debug builds keep the same signing identity across rebuilds. After switching from ad-hoc to team signing, you may need **one** fresh Accessibility enable for the new binary; later rebuilds should retain it. Clone on another machine: set `DEVELOPMENT_TEAM` in Xcode to your team or adjust the project setting.

## Paste-type (Caps+B)

Hold the Caps layer and press **B** to run **paste-type** (Windows “robo paste”): after a short wait (up to ~2.5 seconds, or press **Space** to start immediately), Caps types the current clipboard as **raw keystrokes**—not ⌘V—so it works in fields that block paste. Space during the wait only ends the wait; it is not typed. An empty clipboard does nothing.

## Command-line build (optional)

On a Mac with Xcode command-line tools:

```bash
cd macos
xcodebuild -scheme CapsMac -configuration Debug -destination 'platform=macOS' build
```

The built app is under `DerivedData` or:

```bash
xcodebuild -scheme CapsMac -configuration Debug -destination 'platform=macOS' -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/CapsMac.app
```

## Windows reference

The shipping Windows build lives at the repo root (`caps.ahk` → `caps.exe`). See [README.md](../README.md) and [APP_FEATURES.md](../APP_FEATURES.md) for the full shortcut map.

## Keyboard map

Hold **Caps Lock** and press **=**, or choose **Keyboard Map** from the menu bar. The same Windows SVG (`keyboard-map-tks.svg`) opens in an in-app window.

## Next steps

1. Expand `KeyMap` toward Windows parity (mouse 1/2/3, remaining apps).
2. Implement remaining `SystemIntegration` actions (Terminal, VS Code, dark mode, display sleep).
3. Add Input Monitoring entitlement if required for certain key paths.
