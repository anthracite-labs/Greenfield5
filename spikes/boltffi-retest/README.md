# BoltFFI patched-candidate retest (spike, not production)

PR #18 answered *"is BoltFFI 0.30.1 usable as Greenfield5's bridge?"* with
**DEFER**, on three concrete blockers. This spike asks the narrower follow-up:
**if the smallest correctness-preserving fixes are applied to exactly those
blockers, does BoltFFI become technically suitable?** Nothing here is a
dependency of the product tree, `docs/decisions/0007-uniffi-bridge.md` is
unchanged, and the production UniFFI bridge remains the control
(`.github/workflows/stack.yml` is untouched by this branch).

Nothing in this directory edits generated code. Every fix changes the
**generator source** (`boltffi_backend`), the CLI is built from a patched
checkout of an exact upstream commit, and the generated Swift/Kotlin is
therefore produced by the patched generator.

## Pinned upstream

| Item | Value |
| :-- | :-- |
| Release | `v0.30.1` |
| Tag commit | `2e6320a6d92cb591d22b908477f3a47da7ebc9bc` |
| License | MIT |
| Fetched by | `scripts/fetch-patched-boltffi.sh` (`git init` + `fetch --depth 1 <sha>` + detach) |
| Runtime crate | `boltffi = "=0.30.1"` from crates.io, unchanged |
| Generator | built from the checkout: `cargo build --release -p boltffi_cli` |
| Kotlin fix source | upstream PR #732, head `1b4b0d79e658a04fd1a1f71f007c939f43f8eba7` (open, unmerged) |
| Swift fix prior art | Portal `69262432dbc54ad4a0b806b1b04515ad384a53a4` (design/source only, no CI job) |

The templates are `askama` `#[template(path = "target/...")]` includes, so they
are compiled into the CLI binary. Rebuilding the CLI from the patched checkout
is what puts the patches into the generated output.

## Patches

| Patch | SHA-256 | Provenance |
| :-- | :-- | :-- |
| `patches/0001-swift-async-sendable-cancel-free.patch` | `ce9307979e8176cc531fb1efe35a7dde5a031199f180fa134a81278f82706e53` | no release, merged commit or open PR at this tag; independently derived, agrees with Portal's patch |
| `patches/0002-upstream-pr732-kotlin-inflight-counter.patch` | `44265dc879c89554ae076b1a1889c1f325142cd28c4120b1800e3642aecfd0cc` | upstream PR #732 verbatim (2 files, byte-identical to that head); unmerged, 56 behind this tag, no Swift coverage |
| `patches/0003-kotlin-stream-receiver-retain.patch` | `46726e7b12337a1e88ba277c3fdb2a1f91bb4e6759f9262360167748017bc178` | local extension closing a gap PR #732 leaves on the stream-subscribe path; offered upstream |

Each patch header records the upstream base, the invariant that was violated,
why the change restores it, which test fails if it is reverted, and (for the
local extension) the full six-question acceptance record. A patch that only
made CI green would not qualify.

Together: 4 files changed, 59 insertions(+), 25 deletions(-).

Known limitation, stated rather than hidden: upstream's own Kotlin template
tests (`boltffi_backend/tests/kotlin/exports.rs` and its snapshots) are **not**
updated, because this environment has no `cargo` to run them against. An
upstream offer must also refresh those snapshots. The spike's evidence does not
depend on upstream's suite.

## Ownership model (what the Kotlin fix actually guarantees)

`OPEN → CLOSING → CLOSED`: the counter starts at 1 (the object's own
reference). Instance methods, async methods and stream subscribes retain before
they can dereference the handle and release on their own terminal path — for
async calls, in the future's free hook, because the Rust async wrapper keeps a
shared reference until the future completes. `close()` flips the flag and drops
the initial reference; whichever release reaches zero performs the single
native free. Calls after close fail fast and `close()` never blocks. This is the
shape UniFFI generates for Kotlin objects, and it is why upstream #732's own
review asked for the async retain to outlive the whole future.

## Layout

```
patches/                            tracked, reviewable generator fixes
scripts/fetch-patched-boltffi.sh    exact-SHA fetch, fail-closed apply, provenance (portable SHA-256)
scripts/android-emulator-proof.sh   assemble, boot/reuse one emulator, run real JNI instrumentation
scripts/apple-proof.sh              red | partial | test — integrates the real Xcode project
scripts/swift-typecheck.sh          Swift 6 `-typecheck` probe on generated Swift (supplemental)
scripts/run-with-timeout.py         bounded process runner (macOS has no timeout(1))
src/lib.rs, tests/contract.rs       isolated candidate: same contract semantics, no product code
host/Contract.kt, host/Contract.swift   native contract suites per platform
android/                            isolated instrumentation app (minSdk 29, no JNA)
```

## What the CI jobs prove

Candidate work lives in `.github/workflows/boltffi-retest.yml`, deliberately
separate from `stack.yml` so a candidate failure can never erase the UniFFI
control's evidence. `candidate-rust` runs the isolated Rust contract;
`candidate-android` and `candidate-apple` both build the **unpatched** CLI first
and assert the defect is present in this head's generated output (RED), then
apply the patches to the same checkout, rebuild, and assert the corrected output
(GREEN) before any execution:

- Android RED is a generated-source assertion (no counter, `close()` calling
  native directly, `boltffiHandle()` passed straight into native calls); GREEN
  re-asserts the counter and that no native call reads `boltffiHandle()`
  directly. Then debug + minified release + instrumentation assembly, a booted
  or reused emulator, `am instrument` for `NativeContractTest` and
  `ConcurrentCloseTest`, and a non-gating **RED probe** that runs the same
  stress against the unpatched generation in the same instrumentation process
  and records crash signals.
- Apple RED is the real thing: the unpatched generated Swift is installed into a
  copy of `Greenfield5.xcodeproj` and a bounded `xcodebuild build` must fail
  with the non-Sendable diagnostics. GREEN rebuilds the CLI, reinstalls the
  generated bridge, and runs build + simulator tests, including a non-gating
  **differential probe** that builds a parameters-only variant (`@Sendable`
  without `T: Sendable`) so the CI answers whether the extra constraint is
  required instead of asserting it.

## Local reproduction

The scripts are plain bash and are exercised by the workflow. `--verify-only`
prints patch hashes without network access. Everything else needs a Rust
toolchain for the CLI build, plus the Android SDK or Xcode depending on target.
