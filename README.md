# Caps for macOS

Native Swift/SwiftUI port of [Caps](../README.md) — a menu-bar keyboard utility that turns **Caps Lock** into a hold-modifier for home-row navigation, editing, media, and more.

> **Status:** menu-bar shell plus Caps Lock layer tracking. Accessibility status live-updates in Settings; a CGEvent tap owns Caps Lock / Right Command. Key remapping is not implemented yet.

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
│   ├── Views/             # Menu bar menu, Settings, About
│   ├── Modules/
│   │   ├── CapsInput/     # CGEvent tap / Caps Lock layer state
│   │   ├── CapsKeyMap/    # Key → action map (stubs)
│   │   ├── CapsConfig/    # Configuration persistence (stubs)
│   │   └── CapsSystem/    # Accessibility, media, app launch (stubs)
│   └── Resources/         # Info.plist, Assets
└── README.md              # this file
```

## Module boundaries (planned)

| Module | Responsibility |
|--------|----------------|
| **CapsInput** | CGEvent tap: Caps Lock hold / double-tap lock, Right Command alternate layer |
| **CapsKeyMap** | Map physical keys to actions (parity with `resource/map_caps.csv`) |
| **CapsConfig** | User settings (`~/Library/Application Support/Caps/config.json`) |
| **CapsSystem** | Accessibility permission, volume/media, display sleep, app launchers |

## Accessibility permission

Global key remapping requires **Accessibility** access. Open **Settings** from the menu bar and use **Grant Accessibility Access**. After you enable Caps in System Settings → Privacy & Security → Accessibility, the Settings window updates to **Granted** and starts the keyboard hook automatically (no restart in typical cases). If the hook still says **Not running**, quit and reopen Caps.

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

## Next steps

1. Expand `KeyMap` toward Windows parity using `resource/map_caps.csv` (WASD / IJKL arrows first).
2. Implement `SystemIntegration` actions (volume, Terminal, VS Code, dark mode).
3. Add Input Monitoring entitlement if required for certain key paths.
