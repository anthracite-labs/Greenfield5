# Plan — BoltFFI patched-candidate retest (follow-up to PR #18)

**Status:** active. Written before any executable change on this branch; the
prior-art gate below was completed before the first push.

## Requirement (restated)

PR #18 answered "is BoltFFI 0.30.1 usable as Greenfield5's native↔Rust bridge?"
with **DEFER**, on three concrete blockers: (1) the generated Swift async
runtime does not compile under this project's Swift 6 settings; (2) upstream
#664 documents an unresolved concurrent-`close()` / in-flight-call ownership
race; (3) Android packaged and assembled but never reached real JNI execution
because the emulator did not boot. This task asks a different question: **if the
smallest correctness-preserving fixes are applied to exactly those three
blockers, does BoltFFI become technically suitable?** It is not a re-run of the
eight-donor survey, and it is not authorised to migrate production code.

## Acceptance criteria (from the task brief, verbatim intent)

1. Swift 6: generated async runtime compiles under the project's existing
   settings (no weaker language mode, no warning suppression) and executes
   native async calls, typed async errors, cancellation-before-completion,
   cancellation racing readiness, cleanup after cancellation, and repeated
   cancellation without double-free. RED must reproduce with the unmodified
   0.30.1 generator against the same compiler command.
2. #664: a defensible ownership/close model with defined lifecycle states,
   rejected-after-close calls, drain-or-retain of in-flight work (including
   async calls held until the Rust future stops dereferencing the receiver),
   idempotent close, exactly-once native free, verified by source analysis *and*
   a stress test that actually executes.
3. Android: real `Kotlin → generated BoltFFI → JNI → Rust` execution on an
   emulator, covering version, sender/viewer journeys, one-viewer rejection,
   invalid-code rejection, typed errors, mixed-width struct round-trip, async
   success/error/cancellation, events incl. a deliberately slow consumer,
   shutdown and concurrent close; plus debug, minified release and
   instrumentation assembly, and no JNA dependency.
4. iOS: real `Swift → patched generated BoltFFI → Rust` execution with the
   current Xcode project, Swift 6, iOS 16 floor, and a real generated
   XCFramework.
5. Events: bounded end-to-end story, not a bounded native ring feeding an
   unbounded host queue; produced/accepted/consumed/dropped/backlog recorded.
6. Struct/error regressions re-tested through the foreign APIs.
7. Production UniFFI control untouched and still green; candidate failure can
   never erase control evidence.
8. A single decision: ADOPT / DEFER (exact trigger) / KEEP UNIFFI / BLOCKED.

## Prior-art research gate (completed 2026-09-16, before first push)

The task's patch-selection order is: released fix > merged commit > open
upstream PR with a defensible implementation > proven external prior art >
minimal independent patch. Findings, newest first.

**1. BoltFFI upstream — no released or merged fix; one open PR.**

- Latest release is still **v0.30.1**, tag
  `2e6320a6d92cb591d22b908477f3a47da7ebc9bc` (2026-08-17); `main`
  `d5eba2e347a957a7fce67bb738ae37d985ba082b`.
- Commits touching `boltffi_backend/templates/target/swift` since 2026-08-01:
  `7c51c156` (style), `b01038ef` ("do not double-drive async poll Ready"),
  `4de706e6` (dart/swift wire buffers). **None** adds Sendable annotations to
  the async cancellation closure. Searches for `Sendable type:pr` returned only
  the closed #718; nothing in the 22 open PRs fixes the Swift async captures.
- **PR #732** ("fix: close the `close()` race with an in-flight call counter"):
  state **OPEN**, head `1b4b0d79e658a04fd1a1f71f007c939f43f8eba7`, branch
  `fix/close-race-inflight-counter`, updated 2026-08-14, `mergeable_state`
  `blocked`, 6 commits ahead / 56 behind `main`, merge base
  `6f5809af821b6a3d90fad815ad82a5b1adf79a45`. Exact-head CI run
  **31794820582 = success**, 26/26 check-runs on that SHA. Commits:
  `4ea49c29` (counter), `c22f8925` (async retain until the future frees; reserve
  C# helper names), `2c1d17b9`/`ce986b2d`/`f28e0420` (tests), `1b4b0d79`
  (snapshots). Scope: Kotlin, Java, C#, tests — **no Swift backend change**.
- Consequences: the released-fix and merged-commit rungs are empty, so the
  active rung is **open upstream PR with a defensible implementation** — its
  Kotlin half — plus a local extension where it has a gap (below).

**2. UniFFI — the ownership design is the field's converged answer.**

- `uniffi_bindgen/src/bindings/kotlin/templates/ObjectTemplate.kt` at
  `mozilla/uniffi-rs` `main` = `f2eea6cd7a94995cc522a6d70d1a9bb61fc6cc57`:
  `AtomicLong` in-flight counter starting at 1, `AtomicBoolean` destroyed flag,
  CAS-increment at method entry, decrement at exit, `destroy()` flips the flag
  and drops the initial reference, and the free happens when the last active
  call exits. Its comments explicitly reject a `ReadWriteLock`-based `destroy`
  because a blocking destroy "seems to meet that bar" for hidden blocking
  semantics and can hang. This is the same lifecycle this retest implements for
  Kotlin, and it is the design upstream #732's author cites.

**3. Portal — independent Swift-6 prior art (source/design level only).**

- `VikashLoomba/Portal`, inspected at `main` =
  `8e55cc895b2dc3e1d1dcc6e4ff4840999f9a9ff1`; original implementation commit
  `69262432dbc54ad4a0b806b1b04515ad384a53a4` ("feat: ship Portal as native
  SwiftUI app", 2026-08-26).
- `scripts/patch-boltffi-swift.sh` applies exactly three substitutions to the
  generated file and **fails closed** unless it sees exactly the reviewed old or
  patched shape: `func boltffiAsyncCall<T>(` → `<T: Sendable>`, and both
  `cancel`/`free` parameters → `@escaping @Sendable (RustFutureHandle?) -> Void`.
  `scripts/verify-swift-boundary.sh` then greps for those three exact strings,
  and `docs/DESIGN-swiftui-boltffi.mdx` ("BoltFFI 0.30.1 generated Swift patch")
  states the same two problems this retest found: non-Sendable captures in the
  `@Sendable` cancellation closure, and a completion value crossing a
  concurrency domain without `T: Sendable`. It also states the patch must be
  removed only after unmodified generated source passes the same strict gate,
  and that it avoids #778 by never letting generated classes cross a concurrency
  domain.
- **Verification limits, stated plainly:** Portal is *not* CI-verified for this
  patch. Its only CI jobs are `test-ts` (success) and `rust` (failure at
  "Run make test") on the latest run `33683227317`; there is no macOS/Swift job
  at all. So Portal is design/source prior art, not executed evidence.
- **Licensing:** the GitHub API reports `license: null` for that repository.
  Nothing from it is copied. The change below is an independent modification of
  BoltFFI's own template, derived from the compiler diagnostic and the generated
  source; it agrees with Portal's because it is the same three-line statement of
  the same requirement. Portal is cited as prior art only.

**4. Local implementation decisions (provenance per fix).**

| Fix | Source rung | Provenance |
| --- | --- | --- |
| Swift async Sendable | open-PR rung empty; external prior art | `patches/0001-swift-async-sendable-cancel-free.patch`; independent 3-annotation change to `templates/target/swift/async.swift`; agrees with Portal `69262432`; `T: Sendable` retained unless CI proves it unnecessary (then narrowed) |
| Kotlin in-flight counter | **open upstream PR #732** | `patches/0002-upstream-pr732-kotlin-inflight-counter.patch`; PR #732's cumulative change to `render/class.rs` + `templates/target/kotlin/class.kt`, applied **verbatim** (working tree byte-identical to that head for both paths), ported because the PR's base is not this tag; Java/C# halves deliberately not ported (contract is Kotlin/Swift) |
| Kotlin stream subscribe retain | local extension (PR #732 gap) | `patches/0003-kotlin-stream-receiver-retain.patch`; three sites in `templates/target/kotlin/stream.kt`; offered upstream |

- Deterministic provenance check: the three patches apply cleanly to a pristine
  tag checkout (`git apply --check`, all three), and the resulting tree hashes to
  a single value the CI run re-derives and publishes
  (`BOLTFFI_PATCHED_TREE_SHA256`).

## Lifecycle and retain/release structural review (all paths)

Generated Rust wrapper (macro-expanded, `boltffi_macros`) converts the raw
handle with `Handle::shared(handle)` before any method body runs, so a foreign
referenced-count that reaches zero mid-call is a use-after-free with no second
check at the boundary.

| Path | Handle use | Retain held | Free performed by |
| --- | --- | --- | --- |
| sync instance method (Kotlin) | `__boltffi_receiver` from `boltffiRetain()` | entry → `finally { boltffiRelease() }` | last `boltffiRelease()` (count 1 from construction + 1 per in-flight call) |
| async instance method (Kotlin) | same, captured into `createFuture` | entry → the future's `free` hook (`boltffiCallAsync` calls `free(rustFuture)` exactly once in its `finally`) | same; creation failure releases in a `catch` before rethrow |
| async future creation throws (Kotlin) | retain already taken | released in `catch (Throwable)` | same |
| stream subscribe (Kotlin, patch 0003) | receiver dereferenced by `Handle::shared` inside `Native.<subscribe>` | `boltffiRetain()` → `finally { boltffiRelease() }` around the call | subscription is `Arc::into_raw` of the method result, so it does not borrow the receiver; its own `free`/`unsubscribe` take the subscription handle only |
| `close()` (Kotlin) | none | flags closed, drops the initial reference | the release that decrements to zero |
| repeated close (Kotlin) | none | `compareAndSet(false, true)` makes later calls no-ops | unchanged |
| call after close (Kotlin) | `boltffiRetain()` throws `IllegalStateException` before any native call | never taken | unchanged |
| Swift instance method | `handle` (ARC keeps the caller's reference alive for the call) | ARC | `deinit { release(handle) }` |
| Swift async instance method | same | ARC; the task frame owns the boxed reference | `deinit` after the call returns |
| Swift stream subscription | subscribe takes the handle; subscription class owns `handle`/`readBatch`/`free` | ARC | `deinit` (batch) / `cancel()` path (cancellable) |
| cancellation (Kotlin/Swift) | terminal arbitration in generated runtime | async retain released by the future's free hook | exactly one of complete/cancel paths |

**Asymmetry recorded, not hidden:** generated Swift classes have no explicit
`close()` — only `deinit` + ARC — so "close racing an in-flight call" is a
Kotlin/Java/C# problem (upstream #664), and the Swift side is analysed and
tested (terminal-exactly-once invariants) rather than patched.

**Gap found in upstream #732 and closed locally:** its diff leaves the stream
templates on `Native.<subscribe>(boltffiHandle())`. The macro expansion proves
that is the same defect on the subscription path, which the acceptance criteria
require to be accounted for. Patch 0003 applies upstream's own retain idiom to
the three delivery shapes.

## Approach

**Do not edit generated output.** Every fix changes the *generator source*
(`boltffi_backend`), and the CLI is built from a patched BoltFFI checkout at an
exact immutable SHA, so generated Swift/Kotlin is produced by the patched
generator. The runtime crate stays the published `boltffi = "=0.30.1"`; the
templates are `askama` `#[template(path = …)]`, i.e. embedded into the CLI at
build time (verified: `src/target/swift/render/function.rs:341-342`), so
rebuilding the CLI from the patched checkout is what puts the patches into the
generated code.

## Phases

1. **Recover and relocate the harness** into `spikes/boltffi-retest/`.
2. **Patch provenance** via `scripts/fetch-patched-boltffi.sh` (exact-SHA
   checkout, `git apply --check` first, patch SHA-256 + changed files +
   patched-tree SHA-256 published).
3. **RED → GREEN for Swift 6**: the Apple job builds the *unpatched* CLI first,
   installs that generated Swift into the real project copy and records that the
   bounded `xcodebuild` build fails with the non-Sendable diagnostics, then
   rebuilds the patched CLI and runs the real build+test. A non-gating
   differential probe builds a *params-only* variant (cancel/free `@Sendable`
   without `T: Sendable`) to decide empirically whether the constraint is
   required.
4. **Android native execution**: `scripts/android-emulator-proof.sh` — no-JNA
   gate, debug/release/instrumentation assembly, explicit image/AVD, recorded
   acceleration and command line, finite boot ceiling with full diagnostics on
   failure, then real instrumentation runs and markers.
5. **Events/backpressure, structs, errors**: produced/accepted/consumed/dropped
   printed on both platforms; bounded batch path is the bounded strategy, the
   async stream path is measured and reported rather than blessed.
6. **Control preserved**: `stack.yml` jobs stay byte-identical to `main`; the
   candidate lives in its own workflow.
7. **Decision + documentation**: append to
   `docs/research/open-source-mobile-architecture-harvest.md` and
   `docs/MEMORY.md`; new ADR **only** if ADR-0007 is superseded.

## Risks / unknowns

- **`T: Sendable` may be unnecessary**: decided by the CI differential probe, not
  by preference. If unnecessary, patch 0001 is narrowed to the two annotations
  and the headers/docs are updated.
- **Emulator boot** is the highest-risk step; PR #18's failure was opaque.
  Mitigation: publish everything, preflight KVM/accel, finite ceiling.
- **Patch 0002/0003 are not compiled in this sandbox** (no cargo). The method
  path is upstream-CI-proven; the stream path is verified structurally and by
  the generated-source assertions, then by compilation on CI.
- **Host API names**: PR #18's Kotlin host is compile-proven; the Swift host has
  never compiled (its Apple job failed earlier), so Swift symbol names are
  inferred from the generator templates and verified on CI.
- CI minutes: each candidate job is long; every iteration must publish enough
  diagnostics to avoid a blind second attempt.
- `spikes/` is candidate-only. If the result is KEEP or DEFER, the spike and its
  CI jobs are removed before final-head verification.

## Out of scope (explicit)

MoQ, Iroh, screen capture, ReplayKit, MediaProjection, pairing, audio, UI
redesign, production BoltFFI migration, production UniFFI changes, and any
change to `config/project.env`. No physical-device claims; anything not executed
is recorded as SKIPPED / NOT EXECUTED / UNVERIFIED — PHYSICAL DEVICE REQUIRED.
