# Greenfield5 — iOS shell

SwiftUI shell for Greenfield5 (Issue #13, ADR-0006). UI-only by design: all
session/pairing/protocol logic will live in the shared Rust core
(`core/`) and reach this app exclusively through the native-to-core seam
when the bridge follow-up lands.

## Requirements

- Xcode 26 (project uses `objectVersion 77` with file-system-synchronized
  groups; older Xcode cannot open it).
- iOS 16.0 deployment target (PRODUCT.md §11 supported window).
- Swift 6 language mode (`SWIFT_VERSION = 6.0`, strict concurrency).

## Layout

- `Greenfield5/` — app sources, synchronized root group (no per-file
  pbxproj references; Xcode picks up new files automatically).
  - `Greenfield5App.swift` — `@main` entry point.
  - `AppNavigation.swift` — `AppScreen` / `HomeAction` model and the single
    navigation rule `destination(for:)`, mirroring the Android shell.
  - `RootView.swift` — `NavigationStack` host.
  - `HomeView.swift` — the two primary actions ("Share My Screen",
    "View a Screen").
  - `SenderView.swift`, `ViewerView.swift` — role entry-point placeholders.
  - `Assets.xcassets` — placeholder app icon slot and accent color.
- `Greenfield5Tests/` — Swift Testing suite covering the navigation rule.

## Building and testing

```sh
xcodebuild -project Greenfield5.xcodeproj -scheme Greenfield5 build
xcodebuild -project Greenfield5.xcodeproj -scheme Greenfield5 test \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Both require macOS + Xcode; this repository's Linux-based CI does not run
them (see ADR-0006 consequences: macOS runner CI is a recorded follow-up).

## Explicitly not here yet (Issue #13 follow-ups)

- Native-to-Rust bridge (UniFFI or pinned FFI) — follow-up 1.
- ReplayKit capture / broadcast upload extension — platform follow-up;
  note the iOS 27 `RPBroadcast` deprecation decision recorded in
  `docs/MEMORY.md`.
- MoQ/Iroh transport, pairing UX, join codes.
