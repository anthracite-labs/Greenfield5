# Plan — mobile architecture harvest and BoltFFI A/B

Date: 2026-09-15. Branch: `arena/01a0a701-greenfield5`.

## Requirement

Reduce uncertainty before the native/Rust media boundary grows. Research eight
pinned upstream donors, preserving the merged UniFFI bridge as control; compare
an isolated BoltFFI candidate only through executable evidence, not benchmark
headlines. Do not change the product, transport direction, or approved seam.

## Baseline and authority

Bootstrap and Step 0 read before work; research then planning workflows loaded.
`git fetch origin`, GitHub commits/main API and PR #17 API agree on
`6c85f9a098aba114c94c6247257ea013fa53abd1`; PR #17 merged. Bridge paths exist
in origin/main. Lifecycle is implementation, ALLOW_APP_STACK=1, ADR-0006;
ADR-0007 remains the bridge authority. Open issues are #11 (synthetic media)
and #16 (test permission). #15 is the bridge predecessor, not authorization to
close #11. #11's architecture-phase paragraph is historical and conflicts with
the now-merged lifecycle; do not restore it or weaken any gate.

This task is supplied in chat, not a new approved GitHub issue. Do not claim to
implement or close #11 or #15. Their criteria remain reference constraints.

## Acceptance checklist (task)

- Verify merged baseline and current product/roadmap/ADRs/issues.
- Pin all eight donors, default branches, SHA, date, license and inspected paths.
- Scope, constraints, method, provenance, gap/harvest matrices, all domain
  findings, licensing, unknowns and next step in the required research document.
- Explicit ADOPT / HARVEST / REJECT per significant pattern; distinguish source
  verification, inference and missing runtime proof.
- Preserve UniFFI; isolated BoltFFI parity for version, enums, commands, codes,
  typed errors, creation/query/application, both journeys, admission and invalid
  code rejection. No host behavioral clone as native proof.
- Android generated API, real ABI libraries/JNI calls, debug/tests/minified
  release; Swift generated API, native Apple package, Xcode integration,
  simulator build and bridge tests, both returning Rust version 0.1.0.
- Spike-only async and bounded sequence stream tests in Kotlin and Swift:
  cancellation, errors, ordering, shutdown, backpressure, drops and cleanup.
- Observed comparison table, no invented scores or size deltas.
- Choose ADOPT BOLTFFI / KEEP UNIFFI / DEFER BOLTFFI only with sufficient
  evidence; otherwise report BLOCKED rather than fabricate a completed decision.
- Security/code/spec review, verify.sh and selftest.sh; exact-head CI evidence;
  append memory; superseding ADR only if architecture actually changes.
- Session-only conventional commits and PR; leave open for independent review.

## Phase A — Research

No production bridge replacement. Inspect primary source from the eight fresh
clones (outside product tree), release/issue APIs and the merged bridge/build
files. Record exact source evidence and separate conceptual harvest from copying
or dependency adoption. Verify pins via git rev-parse and licenses in source.
Produce `docs/research/open-source-mobile-architecture-harvest.md`.

## Phase B — Executable A/B spike

Only after source/API feasibility and tool access are established. Use a separate
spike crate/module without removing control. Load TDD workflow before executable
changes. First write failing contract tests against the actual Rust boundary;
then implement the smallest wrapper delegating to existing session semantics.
Generate real Kotlin/JNI and Swift outputs with matching pinned CLI/runtime,
never stubs. Add async and bounded event tests before claiming parity. Run both
platforms in CI if local tools are absent; preserve fail-closed native proofs.
Record failures and available/unavailable commands, counts and measurements.

## Phase C — Decision

Review observed parity, packaging diff, async/stream ownership, unsafe/loading
and upstream risk. Adoption requires both platform proofs and material benefit;
no benefit means KEEP, concrete unresolved blocker may justify DEFER with a
specific trigger. Incomplete experiments mean task BLOCKED, not a negative
technical finding. Do not publish a superseding ADR without adoption evidence.
Review every changed file, run repository gates, append memory, commit/push the
session branch, open a PR and inspect exact-head runs.

## Risks / unknowns

Current `command -v` found none of cargo, rustc, java, gradle, adb, xcodebuild or
swift; host is Linux. Local native execution is unavailable. CI is a possible
execution route, not yet evidence. Physical devices are unavailable here.
Dependency download egress, CI access/minutes, evolving stream ABI/Swift
concurrency and iOS extension budgets can block conclusions. Do not start
production implementation while these critical questions remain open.

## Exclusions

No MoQ implementation, real capture, pairing/join UX, accounts, backend, relay
deployment, browser viewer, remote control, rooms, audio UX, store setup, UI
redesign, unrelated upgrades or CI governance changes. No copied upstream code
or new product dependency in Phase A. Maintain native Kotlin/Compose,
Swift/SwiftUI, Rust, Android 10+/iOS 16+, narrow seam, progressive permissions,
no content retention, one sender/viewer, and ADR-0005 mode semantics.

## Continuation — executable Phase B (PR #18, 2026-09-15)

Re-fetched PR #18 OPEN at 5ca0dff699a88048bb1d062a4f56c8eef9d7636e,
base 6c85f9a098aba114c94c6247257ea013fa53abd1. Production tree unchanged.
Reuse Phase A; no donor survey repeated. BoltFFI stable v0.30.1 resolves to
2e6320a6d92cb591d22b908477f3a47da7ebc9bc, same version as Crux. CLI and
runtime exact =0.30.1. All six identified acceptance issues still open.

Execution design: isolated `spikes/boltffi` crate compiling the existing
`core/src/session.rs` and `seam.rs` by path, not copying their behavior and not
linking UniFFI into the candidate. Independent generated output directories.
Production core/app jobs remain unchanged; candidate jobs added to Stack with
finite timeouts, failure annotations and artifact capture. CI generates the
lockfile with real Cargo; retrieve and commit it before final candidate proof.

Test sequence: first RED exact-version Rust test against deliberately empty
export; then delegate version/session operations and encode contract journeys,
typed errors, invalid codes, mixed-layout round-trip, async cancel and bounded
sequence stream probes. Runner: `cargo test --manifest-path spikes/boltffi/Cargo.toml`.
Host proofs must load generated native bindings, never behavioral substitutes.
Android candidate uses same Gradle toolchain/minSdk 29 in an isolated app module;
Apple candidate generated package is tested with Swift/Xcode and simulator app
integration if generation succeeds. Run controlled close stress separately with
a timeout; even success cannot overrule documented unsafe concurrent close.

Before each push review diff and run foundation gates. After concrete generator/
platform failures use smallest source-backed fix; do not weaken tests. Final
ADOPT requires all proofs. A reproducible upstream blocker may justify precise
DEFER with unexecuted downstream criteria explicitly reported. KEEP/DEFER removes
disposable candidate/build/dependency code while retaining evidence at experiment
SHAs and final exact-head production CI. Continue PR #18, never create another PR.

Failure capture: run 35028595606, both generation matrix jobs failed at Set up
job: setup-android SHA 4dc3… could not be resolved. Root cause: candidate used
a stale research citation rather than the current control workflow pin. The
control and fresh upstream commits/v3 API agree on 9fc6c4e9069bf8d3d10b2204b1fb8f6ef7065407.
Smallest fix: use that already-reviewed current pin. Not a BoltFFI defect or
external execution blocker. Re-run on the next head; no checks relaxed.

Run 35028960389: Rust candidate 33+4 PASS. Apple CLI installed 0.30.1, but
pack failed for four default targets; no host proof. Hypothesis: targets were
not installed, and default x86_64-apple-ios is unsupported in this toolchain
(the control already limits simulator to arm64). Install the same supported
Apple targets and configure them explicitly; enable CLI verbose diagnostics.
Android setup action failed again with no readable failure annotation; raw job
logs redirect to blocked blob storage. Replace the opaque action in candidate
only with explicit sdkmanager commands and captured errors, retaining exact NDK.
Control action/jobs remain untouched. Not yet an upstream defect finding.

Run 35029393019 Android setup captured `Failed to find package
'platforms;android-37'`. Next attempt matches the control's NDK-only provision
and lets the unchanged compileSdk 37 Gradle configuration resolve its SDK; no
SDK downgrade. If NDK provision fails, capture available NDK/platform package
listing before exit. This distinguishes environment availability from FFI bugs.
