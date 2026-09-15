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
