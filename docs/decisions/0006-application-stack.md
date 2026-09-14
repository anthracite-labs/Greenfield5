# ADR-0006: Greenfield5 application stack, repository layout, and implementation transition

**Date:** 2026-09-14
**Status:** accepted
**Decision Type:** application-stack
**Deciders:** Product owner (explicit approval to enter implementation recorded in Issue #13), on the architecture accepted in ADR-0005

## Context

ADR-0005 (accepted 2026-09-13) selected the Greenfield5 architecture — a
shared Rust core, Kotlin + Jetpack Compose on Android, Swift + SwiftUI on iOS,
MoQ as the live media/object transport over Iroh's QUIC/P2P connectivity — but
deliberately did **not** authorize implementation, and it is not the
application-stack record that `config/project.env` requires: it carries no
`**Decision Type:** application-stack` marker, by design.

Issue #13 records the product owner's explicit approval to move into
implementation now, inside this repository: "The purpose of Greenfield5 is to
build the application, not to create a separate prototype product first."
Architecture-risk prototypes (ADR-0005 follow-ups 1–5) will therefore live in
this repository's implementation tree rather than in a separate prototype
product.

The foundation gate (`scripts/verify.sh`) requires a dedicated, accepted
application-stack ADR before `ALLOW_APP_STACK=1` is valid. This ADR is that
record. It pins the concrete toolchain and the repository layout, which
ADR-0005 left open.

Version pins below were verified against primary sources on 2026-09-14:

| Component | Version | Primary evidence (fetched this session) |
| :-- | :-- | :-- |
| Android Gradle Plugin | 9.4.0 (stable, September 2026) | developer.android.com AGP 9.4.0 release notes; Google Maven `maven-metadata.xml` lists `9.4.0` between `9.4.0-rc02` and `9.5.0-alpha01` |
| Gradle | 9.6.1 | AGP 9.4.0 compatibility table (minimum/default Gradle 9.6.0); gradle.org/release-checksums for 9.6.1 |
| Kotlin / Compose compiler plugin | 2.4.20 (stable, 2026-09-07) | kotlinlang.org/docs/releases.html |
| Compose BOM | 2026.08.00 | developer.android.com BOM mapping page ("Always use the latest Compose BOM version: 2026.08.00") |
| androidx.activity (activity-compose) | 1.13.0 | developer.android.com/jetpack/androidx/releases/activity |
| Android SDK levels | compileSdk 37, targetSdk 37, minSdk 29 | Android 17 = API 37, stable since 2026-06-16; AGP 9.4 max API level 37; PRODUCT.md §11 (Android 10+ floor) |
| JDK (Android build) | 17 (Temurin) | AGP 9.4.0 compatibility table (JDK minimum/default 17) |
| Rust | 1.98.1 (stable, 2026-09-03), edition 2024 | blog.rust-lang.org release announcements |
| iOS deployment target | 16.0 | PRODUCT.md §11 (iOS 16+ floor); ADR-0005 (BUE window iOS 16–26, ScreenCaptureKit migration for iOS 27+) |
| Xcode project format | objectVersion 77 (Xcode 16+ file-system-synchronized groups) | structure modeled on a real Xcode 16/26-generated `project.pbxproj` inspected via GitHub code search |

## Decision

Greenfield5 enters the **implementation** phase with the following concrete
stack and layout, inside this repository:

### Repository layout

```text
core/            shared Rust core (greenfield5-core crate; Cargo workspace root)
apps/android/    Kotlin + Jetpack Compose app (Gradle project, AGP 9.4.0)
apps/ios/        Swift + SwiftUI app (committed Greenfield5.xcodeproj)
```

Transport experiments and prototypes required by ADR-0005 (strict-offline
Local, Wi-Fi Aware Direct, relay fallback, iOS process model) will live in
these trees — no separate prototype repository.

### Rust core

- Crate `greenfield5-core`, Rust **1.98.1** pinned via `core/rust-toolchain.toml`,
  edition 2024, **zero external dependencies** at this stage (pure `std`).
- First deliverable: the session-role/state model (`Role`,
  `ConnectionMode`, `SessionState`, `SessionCommand`, `Session`,
  `SessionError`) encoding the product invariants from PRODUCT.md §2/§4/§5/§7:
  exactly one sender and one viewer, sender approval before screen data,
  sharing can stop while the session remains alive, ended is terminal.
- MoQ/Iroh dependencies are **not** added by this ADR; they arrive with the
  bridge/transport work under explicit version pins (ADR-0005 follow-up 6),
  recorded at that time.

### Native/core seam

- `greenfield5_core::seam` exposes a narrow facade (`CoreSession`, stable
  `u8` wire codes for role/mode/state/command, `core_version()`) — the exact
  surface a future FFI mechanism will export. UI code consumes this seam only;
  it never touches transport internals (which do not exist yet).
- The FFI **mechanism** (UniFFI vs hand-rolled C ABI vs other) is deliberately
  **not** chosen here: it is the first bridge follow-up issue, decided against
  real generated-binding evidence, and will be pinned then (ADR-0005 already
  requires the seam to stay narrow, versioned, observable, testable).

### Android

- AGP **9.4.0** with **built-in Kotlin** (no `org.jetbrains.kotlin.android`
  plugin; the Compose compiler plugin `org.jetbrains.kotlin.plugin.compose`
  **2.4.20** carries the KGP version), new AGP DSL, Gradle **9.6.1** wrapper
  with `distributionSha256Sum` set to the official checksum; wrapper jar
  sourced from `gradle/gradle@v9.6.1` and byte-verified against
  gradle.org/release-checksums (sha256 `497c8c2a…`).
- Compose BOM **2026.08.00**, `activity-compose` **1.13.0**, Material 3.
- `compileSdk = 37`, `targetSdk = 37`, `minSdk = 29`; JDK 17; JVM target 17.
- Namespace/applicationId `dev.greenfield5.app` (neutral placeholder identity;
  changing it later is a store-listing decision, not an architectural one).
- Build-file shape mirrors Google's official `android/compose-samples`
  AGP 9 configuration (verified via api.github.com this session).

### iOS

- Committed `Greenfield5.xcodeproj` (objectVersion 77, file-system-synchronized
  source groups, shared scheme, generated Info.plist), SwiftUI app,
  `IPHONEOS_DEPLOYMENT_TARGET = 16.0`, `SWIFT_VERSION = 6.0`, bundle id
  `dev.greenfield5.app`, automatic signing with **no** development team
  committed.
- No Swift Package/FFI dependency yet — the core is bridged in the follow-up
  issue.

### CI

- New workflow `.github/workflows/stack.yml` adds two jobs alongside the
  untouched foundation gate: **Rust core** (`cargo fmt --check`,
  `cargo clippy -- -D warnings`, `cargo test`) and **Android app**
  (`./gradlew testDebugUnitTest assembleDebug`, Temurin JDK 17 via
  `actions/setup-java` v6.0.1 pinned by commit sha). Least privilege
  (`contents: read`); path-filtered; not added to the ruleset's required
  contexts in this change.
- iOS CI (macOS runners) is **deferred**: it is a runner-spend decision for
  the product owner and is proposed as the immediate follow-up issue. Until it
  exists, the committed iOS project is structurally validated (pbxproj/plist
  parsers) but not compile-validated — stated honestly wherever claimed.

### Lifecycle transition (this ADR authorizes it)

`config/project.env` moves to `PROJECT_PHASE=implementation`,
`ALLOW_APP_STACK=1`,
`STACK_DECISION_ADR=docs/decisions/0006-application-stack.md`.
`scripts/verify.sh` and `config/main-ruleset.json` are not edited; the
foundation gate keeps running on every PR, and its `no_app_stack` guard stands
down only through its own validated transition rules.

## Alternatives considered

### Alternative: separate prototype repository first

- **Pros:** keeps product tree "clean" until architecture risk is proven;
  prototype throwaway cost is isolated.
- **Cons:** duplicates governance/CI setup; prototypes mature into products
  anyway (the research already showed the closest OSS candidates failed
  end-to-end); PO would maintain two repositories.
- **Why not:** the product owner explicitly rejected this in Issue #13:
  architecture risk will be validated inside this repository and, where
  practical, inside the real app shells.

### Alternative: pin the older sample-proven toolchain (AGP 9.3.1 + Kotlin 2.4.10)

- **Pros:** exact combination Google's compose-samples shipped when inspected
  (2026-09-14), so near-zero first-build risk.
- **Cons:** not the current stable AGP (9.4.0 shipped September 2026 with
  Gradle 9.6 compatibility documented); Issue #13 asks for "current stable
  Android tooling".
- **Why not:** AGP 9.4.0's own compatibility table gives the required pins
  (Gradle ≥ 9.6.0, JDK 17, API ≤ 37); the fallback pair is recorded here so a
  CI-observed incompatibility can be resolved by dropping to the
  sample-proven combination in one reviewed line, not by improvising.

### Alternative: XcodeGen/Tuist spec instead of a committed .xcodeproj

- **Pros:** smaller, friendlier diffs; project regenerated from YAML.
- **Cons:** Issue #13 requires committed iOS project files; adds a
  generation tool dependency and a regeneration step every contributor must
  run; Xcode 16+ synchronized groups already shrink the pbxproj to roughly
  one screen of content.
- **Why not:** committed project with synchronized groups gets the small-diff
  benefit without the extra tool.

### Alternative: hand-rolled C ABI FFI crate committed now

- **Pros:** a "real" bridge shape exists from day one.
- **Cons:** picks the FFI mechanism before evaluating UniFFI against it with
  real bindings; ADR-0005 requires the mechanism decision to be evidence-based
  and pinned; a speculative ABI now is exactly the coupling the seam is meant
  to avoid.
- **Why not:** the seam facade + stable wire codes is the part that must exist
  now; the mechanism is the bridge follow-up issue.

### Alternative: classic (pre-Xcode 16) pbxproj with explicit file references

- **Pros:** parseable by older tooling; well-trodden format.
- **Cons:** every Swift/asset file needs manual PBXFileReference/PBXBuildFile
  entries — the exact hand-maintenance synchronized groups eliminate; no
  supported Xcode in the team's window (16–26) needs it.
- **Why not:** objectVersion 77 synchronized groups are the current template
  output and keep the hand-written file small and auditable.

### Alternative: enable iOS (macOS-runner) CI in this PR

- **Pros:** immediate compile evidence for the hand-written pbxproj/Swift.
- **Cons:** macOS runner minutes are a ~10x-billed spend on a private repo;
  runner image/Xcode availability cannot be probed from this sandbox, so
  iteration would be blind and costly; PO has not approved that spend.
- **Why not:** deferred to a follow-up issue as a deliberate spend decision;
  the limitation is stated in the PR rather than papered over.

## Consequences

### Positive

- The whole product (shells, core, transport experiments) lives under one
  governed repository: same gate, same branch rules, same ADR discipline,
  same memory.
- Foundation `no_app_stack` guard stands down through its own validated
  transition — the lifecycle machinery from ADR-0004 is exercised exactly as
  designed, for the first time.
- Rust core and Android app have executable CI evidence from day one; the
  session model is TDD-verified (RED run observed in CI before GREEN).
- Narrow seam with stable wire codes means the future FFI mechanism choice can
  change without touching UI code.

### Negative

- The Arena sandbox has no Rust/JVM/Xcode toolchain (verified this session),
  so CI is the execution evidence for stack code; local runs are limited to
  the foundation gate and structural validation. Every claim must say which
  path produced it.
- AGP 9.4.0 + Kotlin 2.4.20 + Gradle 9.6.1 is a current-but-fresh combination;
  first-build friction is possible (fallback pins recorded above).
- The hand-written iOS project has no compile evidence until macOS CI exists —
  a real, disclosed gap.
- Stack CI adds runner minutes to every PR touching `core/` or `apps/android/`.
- `scripts/selftest.sh` fixtures had to be made hermetic (they previously
  assumed the committed config was un-transitioned); the negative suite now
  sets its own preconditions in every lifecycle case.

### Follow-ups

1. **Bridge issue (next):** choose and pin the FFI mechanism (UniFFI first
   candidate), wire Android and iOS shells to `greenfield5-core` through the
   seam, add JVM/Swift-side seam tests.
2. **iOS CI decision:** product owner approves macOS runner spend; add an
   `xcodebuild` job (simulator destination) that compiles the committed
   project and runs any iOS tests.
3. **Transport spikes in-tree** (ADR-0005 follow-ups 1–5): MoQ-over-Iroh
   synthetic media, iOS Broadcast Extension process model, strict-offline
   Local, dedicated relay fallback, Wi-Fi Aware Direct — with exact
   `moq-dev/moq`/Iroh pins recorded when added (ADR-0005 follow-up 6).
4. Commit `core/Cargo.lock` once the first external dependency lands
   (generated by a real toolchain run, never hand-written).
5. Maintainer decision: promote `Rust core` / `Android app` checks to required
   status contexts (requires editing `REQUIRED_CI_CONTEXTS` in verify.sh +
   `config/main-ruleset.json` + the live ruleset — a governance change with
   its own review).
6. Android 17 local-network behavior: with `targetSdk 37`, Local mode will
   need `ACCESS_LOCAL_NETWORK` handling (flagged in the 2026-09-13 research
   memory); address in the Local-mode transport spike.
7. App icons/branding assets (placeholder vector adaptive icon on Android,
   empty AppIcon set on iOS).
8. Fill `docs/DOMAIN.md` vocabulary from the now-executable session model.
