# Plan — Issue #13: Implementation kickoff (Android + iOS + Rust core skeleton)

**Date:** 2026-09-14
**Branch:** `arena/01a0a051-greenfield5`
**Skill:** `.ecc/skills/planning.md` (this record) + `.ecc/skills/tdd.md` (Rust core)

## Requirement

Move Greenfield5 from `architecture` into `implementation` and build the first
real application skeleton **in this repository**: record a final
application-stack ADR based on accepted ADR-0005, flip the lifecycle config
that the foundation gate validates, and bootstrap the three product trees —
Kotlin/Compose Android shell, Swift/SwiftUI iOS shell, and a shared Rust core
with a testable session-role/state model — behind a narrow native/core seam
that can later grow into UniFFI or another pinned FFI mechanism. No separate
prototype repository; no weakening of `scripts/verify.sh`, the branch rules, or
ADR discipline.

## Acceptance criteria (verbatim from Issue #13)

- lifecycle transition is ADR-backed and passes the foundation gate;
- app-stack artifacts live in Greenfield5 itself;
- Android/iOS/Rust skeleton is reviewable as one implementation PR;
- no weakening of `scripts/verify.sh` or the branch rules.

First vertical slice (verbatim): 1. both native shells render the Greenfield5
home screen; 2. both expose Sender and Viewer entry points; 3. the shared Rust
core has a testable session-role/state model; 4. Android is configured against
current stable Android tooling; 5. iOS project files are committed and target
the supported iOS window; 6. follow-up work wires the real native↔Rust bridge
and then MoQ/Iroh synthetic media inside these app shells.

Non-goals (verbatim): production screen capture; production relay deployment;
accounts; remote control; final pairing UX; claiming real-device transport
evidence before it exists.

## Approach

One PR on the session branch containing, in order:

1. **ADR-0006** (`docs/decisions/0006-application-stack.md`) — the final
   application-stack decision derived from ADR-0005, carrying the exact
   metadata lines `scripts/verify.sh` requires
   (`**Decision Type:** application-stack`, `**Status:** accepted`), with
   version pins justified from primary sources fetched this session
   (developer.android.com AGP 9.4.0 release notes, Kotlin 2.4.20 release page,
   Rust 1.98.1 announcement, Gradle 9.6/9.7 release notes + checksums, Compose
   BOM 2026.08.00 mapping page, Android 17/API 37 stable June 2026).
   Index it in `docs/decisions/README.md`.
2. **Lifecycle transition** — `config/project.env`: `PROJECT_PHASE=implementation`,
   `ALLOW_APP_STACK=1`, `STACK_DECISION_ADR=docs/decisions/0006-application-stack.md`.
   A config diff only; `scripts/verify.sh` is NOT edited.
3. **Selftest fixture hygiene (required, not a weakening)** — four negative
   cases in `scripts/selftest.sh` silently assume the *committed* config is
   un-transitioned (`rejected-in-factory-phase`, `allow-without-phase-or-adr`,
   `allow-without-adr`, `only-missing-adr-fails-closed`), and the `init/*`
   cases assume `ALLOW_APP_STACK=0`. Once this repo legitimately transitions,
   those fixtures would assert against the wrong baseline. Fix = make each
   fixture hermetic (explicitly `set_config` its precondition). Every injected
   fault and expected verdict stays identical; no case is removed; verify.sh is
   untouched. This is the only defensible way to keep the negative suite
   meaningful in a transitioned repository, and it is flagged for the
   independent reviewer.
4. **Rust core** (`core/`) — `greenfield5-core` crate, edition 2024, zero
   external dependencies, `rust-toolchain.toml` pinned to 1.98.1. Session
   role/state model (`Role`, `ConnectionMode`, `SessionState`,
   `SessionCommand`, `Session`, `SessionError`) grounded in `docs/PRODUCT.md`
   §2/§4/§5/§7 (one sender + one viewer, sender approval gate, sharing can
   stop while the session lives), plus a narrow `seam` facade with stable
   integer wire codes — the surface a future UniFFI/C-ABI bridge will export.
   **TDD via CI** (no Rust toolchain exists in this sandbox — verified): the
   first push carries full tests with `todo!()` stubs so CI shows a real RED;
   the second push implements the logic for GREEN. Evidence: both CI runs
   recorded in the PR body.
5. **Android shell** (`apps/android/`) — AGP 9.4.0 (built-in Kotlin, new DSL),
   Gradle 9.6.1 wrapper (jar fetched from `gradle/gradle@v9.6.1` via
   api.github.com; sha256 verified against gradle.org/release-checksums:
   `497c8c2a…`; `distributionSha256Sum` set to the official 9.6.1 bin zip
   checksum `9c0f7fae…`), Kotlin/Compose-compiler plugin 2.4.20, Compose BOM
   2026.08.00, activity-compose 1.13.0, compileSdk/targetSdk 37, minSdk 29
   (PRODUCT.md: Android 10+), JDK 17, namespace/applicationId
   `dev.greenfield5.app`. Home screen with "Share My Screen" / "View a Screen"
   entry points → placeholder Sender/Viewer screens. JVM unit tests for the
   navigation mapping. Layout mirrors Google's official compose-samples
   configuration for the AGP 9 era (`src/main/java`, `android.kotlin` DSL).
6. **iOS shell** (`apps/ios/`) — hand-written `Greenfield5.xcodeproj`
   (objectVersion 77, `PBXFileSystemSynchronizedRootGroup`, modeled on a real
   Xcode 16/26-generated project inspected via GitHub code search), SwiftUI
   app with the same home screen + entry points, `IPHONEOS_DEPLOYMENT_TARGET =
   16.0` (PRODUCT.md: iOS 16+), `SWIFT_VERSION = 6.0`, bundle id
   `dev.greenfield5.app`, shared scheme, generated Info.plist. Validated
   locally with the `pbxproj` Python parser + `plistlib` (structural only —
   no Xcode exists on Linux; compiling is deferred to the follow-up macOS CI
   decision, stated honestly in the PR).
7. **Stack CI** (`.github/workflows/stack.yml`, new file; `verify.yml`
   untouched) — `Rust core` job (fmt/clippy/test, toolchain from
   rust-toolchain.toml) and `Android app` job (setup-java temurin 17 pinned to
   `de7274f0…` = v6.0.1; `./gradlew testDebugUnitTest assembleDebug`) with
   path filters. `permissions: contents: read`. Foundation gate keeps running
   alongside; ruleset/required-contexts unchanged (adding required contexts is
   a maintainer admin action + gate change — follow-up, not this PR).
8. **Docs truth-fix** — README.md (currently claims "This repository is the
   reusable template source… contains no application", which the transition
   falsifies), ARCHITECTURE.md application-architecture section (the file
   itself instructs this once an ADR selects a stack), one small codemap for
   the core (ROADMAP implementation-stage checklist), MEMORY.md session entry.

## Phases and verification

| # | Phase | Verification |
| :- | :-- | :-- |
| 1 | Plan doc (this file) | committed before code |
| 2 | ADR-0006 + index + project.env + selftest fixture hygiene | `bash scripts/verify.sh` exit 0 (lifecycle accepts transition, no_app_stack SKIPs); `bash scripts/selftest.sh` exit 0 locally and in CI |
| 3 | Rust core RED (tests + `todo!()` stubs), Android tree, iOS tree, stack.yml, .gitignore | local: gate + selftest + pbxproj/plist/toml/yaml structural validation; CI: `Rust core` job RED (tests fail for `todo!()`), `Android app` job green |
| 4 | Rust core GREEN (implement state machine + seam) | CI: `cargo test` green on the new head; RED→GREEN mapping recorded |
| 5 | Reviews (code, spec-vs-issue, security — CI/dependency triggers apply) | findings graded and addressed in-branch |
| 6 | MEMORY.md + final gate runs + PR body with evidence | `verify.sh`/`selftest.sh` exit 0 immediately before final push; CI green on final head |

## Risks / unknowns

- **No local Rust/JVM/Xcode toolchain** (verified: `cargo`, `java`, `swiftc`
  absent; crates.io/services.gradle.org/dl.google.com egress blocked). CI is
  the execution evidence; the sandbox can only do structural checks. This is
  the established pattern from memory (2026-09-13 entries) and is stated
  plainly, never presented as local execution.
- **AGP 9.4.0 + Kotlin 2.4.20 + Gradle 9.6.1 is a fresh combination.**
  Mitigations: AGP 9.4's own compatibility table (Gradle ≥9.6.0, JDK 17, max
  API 37); build-file shape copied from Google's compose-samples AGP 9
  configuration; fallback pins recorded in ADR-0006 (AGP 9.3.1 + Kotlin
  2.4.10 — the exact combination the samples ship). CI iterations are cheap.
- **Hand-written pbxproj cannot be compiled here.** Mitigation: model on a
  real Xcode-generated objectVersion 77 project; parse-validate locally; first
  `xcodebuild` verification is the fast-follow macOS CI issue. Stated as a
  known limitation, not hidden.
- **Selftest edits touch the negative-test suite** — the most sensitive file
  after verify.sh. Mitigation: fixtures only, no coverage removed, each change
  justified per case in the PR, security review pass applied, independent
  reviewer explicitly pointed at it.
- GitHub App needs Workflows write permission for `stack.yml` pushes
  (FACTORY.md §4); if the push is rejected, that is the cause.

## Out of scope (deliberately)

- Native↔Rust bridge wiring, UniFFI choice, MoQ/Iroh dependencies and
  version pins (issue item 6 + ADR-0005 follow-ups 1–6; transport spikes).
- Screen capture, pairing UX, join codes over the wire, relay deployment,
  accounts, remote control (issue non-goals).
- macOS/iOS CI runner spend decision (proposed as immediate follow-up issue).
- Making stack CI checks *required* in the ruleset (needs gate + GitHub admin
  changes by a human; follow-up).
- DOMAIN.md vocabulary rewrite (follow-up; noted in MEMORY).
- Any edit to `scripts/verify.sh`, `config/main-ruleset.json`, or
  `.github/workflows/verify.yml`.
