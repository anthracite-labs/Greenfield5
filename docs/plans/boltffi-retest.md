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
| Swift async Sendable | open-PR rung empty; external prior art | `patches/0001-swift-async-sendable-cancel-free.patch`; independent 3-annotation change to `templates/target/swift/async.swift`; agrees with Portal `69262432`; `T: Sendable` **proven necessary** by the retest's own differential probe, not retained on preference |
| Kotlin in-flight counter | **open upstream PR #732** | `patches/0002-upstream-pr732-kotlin-inflight-counter.patch`; PR #732's cumulative change to `render/class.rs` + `templates/target/kotlin/class.kt`, applied **verbatim** (working tree byte-identical to that head for both paths), ported because the PR's base is not this tag; Java/C# halves deliberately not ported (contract is Kotlin/Swift) |
| Kotlin stream subscribe retain | local extension (PR #732 gap) | `patches/0003-kotlin-stream-receiver-retain.patch`; three sites in `templates/target/kotlin/stream.kt`; **not yet filed upstream** - the intended form is a three-line follow-up to PR #732, and the header records the 6-question acceptance answers |
| Swift async future ownership | local patch (no upstream fix exists) | `patches/0004-swift-async-future-lifetime.patch`; one file, `templates/target/swift/async.swift`; issued because the *same* defect class was already fixed once upstream (`b01038ef`, "do not double-drive async poll Ready via return and callback") and the owner/lifetime half was still open at `main` `d5eba2e3`; header records the two concrete UAF mechanisms, the rejected alternatives (`canPoll()` re-check, free-after-`cancel`, blocking lock, `passRetained` shortcuts) and the 6-question acceptance answers |

- Deterministic provenance check: the four patches apply cleanly to a pristine
  tag checkout (`git apply --check`), and the resulting tree hashes to a single
  value the CI run re-derives and publishes (`BOLTFFI_PATCHED_TREE_SHA256`).
- Upstream status re-checked 2026-09-16 (immutable refs): release v0.30.1 =
  `2e6320a6d92cb591d22b908477f3a47da7ebc9bc`; `main` =
  `d5eba2e347a957a7fce67bb738ae37d985ba082b`; `git diff <tag> main --
  boltffi_backend/templates/target/swift/` is **empty**; PR #732 head
  `1b4b0d79e658a04fd1a1f71f007c939f43f8eba7`, still open, `mergeable_state
  blocked`, and it touches no Swift file. So the Swift defect is both unreleased
  and unfixed upstream, and nothing was re-invented locally.

## Ownership audit - per path (2026-09-16)

Source-level audit of every path a foreign shell can take into the generated
bridge, against the *pinned* tag `2e6320a6` plus patches 0001-0004. "Owns" names
the thing that holds the native allocation; "acquires" is when the foreign side
takes a reference; "races" is what can destroy the allocation while the path is
live; "releases" is who gives the last reference back. Status is one of
**safe** (no window at this pin), **patched** (a window existed and the listed
patch closes it), **N-A** (the shape does not exist at this pin), or
**unresolved** (a window remains; recorded, not papered over).

| # | Path | Owns | Acquires | Races | Releases | Exercised by Greenfield5 | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | receiver sync call (Kotlin) | the Kotlin object's `handle`, refcounted by `__boltffi_calls` (`AtomicLong(1)`) | `boltffiRetain()` before the native call | `close()` from another thread | `finally { boltffiRelease() }`; the decrement to zero performs the only native free | yes (`GreenfieldSession.sendCommand`, contract suite) | **patched** (0002 = upstream #732 verbatim) |
| 2 | receiver async call (Kotlin) | same | `boltffiRetain()` inside `createFuture` | `close()` while the future runs | the future's `free` hook (`boltffiCallAsync`'s own `finally`); creation failure releases in the `catch` before rethrow | yes (`waitValue`) | **patched** (0002; this is the retain the #732 review thread asked for) |
| 3 | async creation failure (Kotlin) | same | retain already taken when `create()` throws | a `close()` racing the failed creation | explicit `boltffiRelease()` in `catch`, then rethrow - no leak, no premature free | yes (`waitValue(fail: true)`) | **patched** (0002) |
| 4 | stream subscribe (Kotlin) | subscription handle from `Native.<subscribe>`, independent of the receiver | `boltffiRetain()` around the subscribe call only (0003) | `close()` during subscribe | `boltffiRelease()` in the surrounding `finally`; the subscription's own `free`/`unsubscribe` takes the subscription handle | yes (`events`, `eventsBatch`) | **patched** (0003, local; PR #732 left these three sites on `boltffiHandle()` = check-then-act) |
| 5 | stream delivery after subscribe (Kotlin) | the **subscription handle**, not the receiver: the async flow, the batch subscription and the cancellable all call `Native::<pop_batch>`, `Native::<poll>`, `Native::<unsubscribe>` against the subscription they hold | the receiver is read **only** by the subscribe call itself, which patch 0003 wraps in `boltffiRetain()`/`boltffiRelease()` | a `close()` after subscribe cannot reach the receiver handle any more: there is no post-subscribe receiver read left to race | subscription `free`/`unsubscribe` (its own handle) | yes (`events`, `eventsBatch`, `boundedBatch`, `BOLT_CANCEL`) | **patched on the generated Kotlin side** (0003) - see the path-5 note below; the Rust-side question is bounded, not proven |
| 6 | object-valued parameter, sync call (Kotlin/Swift) | the callee's own reference (the caller's object is alive for the duration of the call) | macro-side `Handle::shared(handle)` at entry (`param/handle.rs`) | nothing - the synchronous frame keeps the caller's reference alive | macro drops the borrow when the call returns | yes (Kotlin `apply(command:)`, Swift `roundTrip`) | **safe** (single-threaded by construction for the duration of a sync call) |
| 7 | object-valued parameter, async call (Kotlin/Swift) | *nothing at this pin* | none | the caller can close/drop the argument while the future still dereferences it | - | no (spike's async API takes primitives only) | **N-A at the pinned tag** - upstream added the retention only on `main` (`d5eba2e3`: `engine.shared().await` inside `rust_future_new(async move { .. })`, with dedicated compile tests); recorded as a re-test trigger, not as a candidate defect |
| 8 | callback lowering with object/callback handles (Swift) | the runtime holds the `BoltFFICallbackHandle` produced by `Unmanaged.passRetained(wrapper)` | handle creation transfers ownership to the runtime | nothing - the runtime owns it | `takeRetainedValue`/`release(handle)` in the bridge; the proxy's own `deinit` releases the boxed Swift implementation | yes (stream callbacks, `Listener` shapes) | **safe** (owned transfer, single consumer) |
| 9 | close / repeated close (Kotlin) | the object's initial reference | - | - | `close()` = `compareAndSet(false, true)` then one `boltffiRelease()`; later closes are no-ops | yes | **patched** (0002) |
| 10 | call after close (Kotlin) | - | `boltffiRetain()` throws `IllegalStateException` before any native call | - | - | yes (`stateCode` after close in the contract suite) | **patched** (0002) |
| 11 | receiver sync/async call (Swift) | the generated class instance's `handle`; ARC | none needed - the caller's reference is live for the call | `deinit` cannot run while the caller holds the instance | `deinit { release(handle) }`, exactly once by ARC | yes | **safe** (no explicit `close()`, so no close race exists on Apple) |
| 12 | async call, future handle (Swift) | `BoltFFIFutureLifetime` (one raw handle + the `@Sendable` free) | the call takes the handle `Arc::into_raw` in `rust_future_new` returned | the *old* driver freed it from the Ready path, the error path and both cancellation branches while a `Task`-scheduled re-poll could still run (mechanism A) and while the runtime was inside its own `poll` frame (mechanism B); v2's deferred free had no window but let the future outlive the call | `Owner.freeOnQueue()` - queue-confined and idempotent - called from the terminal step *before* the caller is resumed (v3); `deinit` is only a last chance | yes - this is `BoltOwnership.repeatedCancellation`, the SIGSEGV | **patched** (0004 v3; the 0001 pair only made it compile, v2 was safe but not observable) |
| 13 | stream subscribe / batch pull / cancellable (Swift) | the subscription class holds the subscription `handle`; ARC | subscribe call | `cancel()` from another thread | `deinit { free(handle) }`; the cancellable's `cancel()` is flag-guarded and idempotent | yes (`events`, `eventsBatch`, `boundedBatch`) | **safe** (ARC single owner; no close-vs-call race by construction) |
| 14 | repeated cancellation / cancel after completion (Swift) | `BoltFFIFutureState` (`BoltFFIFutureState.finish()` is a single atomic exchange) | - | - | terminal state is consumed once; the second `finish()` returns `.finished` and neither resumes nor frees; the winner's terminal step cancels, frees, then resumes, in that order, on the call's queue | yes (`repeatedCancellation`, `cancellationRacingReadiness`) | **patched** (0004 v3: atomic arbitration unchanged, every free funnelled through the one idempotent site) |

**Path 5, stated precisely (re-inspected 2026-09-16 against the patched
templates, not from memory).** Patch 0003 replaces the receiver read at all three
stream-subscribe sites with `boltffiRetain().let { receiver -> try {
Native.<subscribe>(receiver) } finally { boltffiRelease() } }`, and nothing after
`subscribe` reads the receiver: the async flow hands `subscription` plus the
`Native::<pop_batch>/<poll>/<unsubscribe>` references to `BoltFfiStreamContext`,
and the batch/cancellable shapes hold the subscription's own `handle` and call
`popBatch(handle, ...)`, `wait(handle, ...)`, `unsubscribe(handle)`. Two
independent checks agree, and both run in CI: the templates emit `boltffiHandle()`
in exactly one place - its own declaration - and the Android job asserts that at
build level, on both trees (RED: the unpatched tree must still contain
check-then-act sites, or the probe refuses to call itself a RED; GREEN: every
generated line containing `boltffiHandle()` must be the declaration).
The bounded residual is on the Rust side: `close()` frees the receiver while a
subscription is live, which is safe only if the Rust subscription does not borrow
the receiver. In this fixture it does not -
`EventProbe::events()/events_batch()` return `self.subscription.clone()`, an
independent `Arc<EventSubscription<u32>>` (`src/lib.rs`), so the subscription
outlives and does not dereference the probe. For an object whose subscription
*did* borrow its receiver, the generated Kotlin cannot prove anything and that is
exactly the contract upstream #664 covers. Recorded as a bounded residual, not as
verified.

**What this audit does not claim.** Only paths 1-4, 9-10 (Kotlin) and 11-14
(Swift) are executed by this spike. Path 5 is closed on the generated Kotlin side
by 0003 with the Rust-side residual above; paths 6-8 are argued from the
macro/template source, with 6 and 8
structure-safe by the ownership model and 7 not constructible at this pin. No
global "close races fixed" claim is made: the close machinery is Kotlin-only
(Apple has no explicit `close()`), and the async receiver retain is the part of
#664 that these 4 patches close on the paths Greenfield5 actually uses.

**Asymmetry recorded, not hidden:** generated Swift classes have no explicit
`close()` - only `deinit` + ARC - so "close racing an in-flight call" is a
Kotlin/Java/C# problem (upstream #664), and the Swift side is analysed and
tested (terminal-exactly-once invariants) rather than patched.

**Gap found in upstream #732 and closed locally:** its diff leaves the stream
templates on `Native.<subscribe>(boltffiHandle())`. The macro expansion proves
that is the same defect on the subscription path, which the acceptance criteria
require to be accounted for. Patch 0003 applies upstream's own retain idiom to
the three delivery shapes - and remains labelled local, not upstream.

**Swift future-handle defect, stated precisely.** `rust_future_free` may be
called only when nothing can dereference the handle any more: no poll in flight,
no callback the runtime makes into the module, and no re-poll queued but not yet
run. Patch 0004's owner is what enforces that, and
`host/LifetimeProbe.swift` asserts it against a model of the contract
(borrowed poll/cancel/complete, consuming free) rather than against a hope.

### Patch 0004 v3 - free before resume (2026-09-16)

The invariant is now stated in one line, and each clause is executable:

1. `rust_future_free(handle)` happens **exactly once** per call -
   `Owner.freeOnQueue()` is queue-confined and idempotent, and the lifetime's
   `deinit` is only a last chance to call it.
2. It never runs while anything can still dereference the handle - the free is
   queued behind every poll and cancel on the call's serial `DispatchQueue`, so it
   cannot execute inside `RustFuture::poll`, inside a displaced-continuation
   delivery, or inside the callback the runtime makes into the module.
3. It runs **before the caller is resumed** - `terminal(cancel:then:)` frees and
   then resumes, on the success/error-status path and on the cancellation path, so
   a native future cannot outlive the call that created it and a caller that reads
   its native state right after the call cannot race a live future.

The one path that keeps the deferred form is a *thrown* error from the generated
completion closure: `Error` is not `Sendable`, and boxing it would be the
`@unchecked Sendable` escape this candidate refuses, so that path resumes from the
poll frame and lets `deinit` release the handle - still exactly once, still never
inside a native frame. It is recorded, not hidden.


> **PENDING (not evidence):** the change set committed as `4227404` is **not yet
> dispatched** - GitHub authentication in the sandbox went invalid mid-session
> (`gh auth status`: GH_TOKEN no longer valid; every `gh api` call returns
> `Bad credentials`), so the push and the run it triggers are waiting on a
> reconnect. Until that run exists, nothing in `4227404` is verified: the close-race
> expectation fix, the deterministic Android contract-token check, the rebased
> `T: Sendable` differential, the cancellation-aware restore guard and the
> consolidated diagnostics are all **local changes with a passing local gate only**
> (`verify.sh` PASS 17/0/2, `selftest.sh` PASS 128). The last executed head remains
> `97a4924` (run `35111780326`).

## Evidence log (executed, newest first)

Every entry is an executed CI run of `.github/workflows/boltffi-retest.yml` on
this branch. Raw job logs are not retrievable from the sandbox, so each step also
publishes annotations (`::notice` / `::error`); those annotations, plus the
artifact set, are what is quoted here.

**Run `35111780326` (head `97a4924`) - Apple native GREEN, on the same 19 tests that
failed before; Android executes and its close-race expectation is corrected.**

Jobs: Rust `104847425592` **success**; Apple `104847425246` **success**; Android
`104847425692` **failure** (close-race suite, cause below).

*Swift 6 pair, both sides executed.* RED: `SWIFT_TYPECHECK_unpatched_EXIT=1`,
`:702:13` and `:703:13`, "capture of 'cancel'/'free' with non-sendable type
`(RustFutureHandle?) -> Void` ... in a '@Sendable' closure". GREEN:
`SWIFT_TYPECHECK_patched_EXIT=0` on the patched generator. Same probe, same flags
(`-swift-version 6 -parse-as-library`), same generated file, so the pair now
decides something instead of being asserted as text.

*Lifetime pair, both sides executed.* RED (pre-0004 runtime):
`completionInsidePollFrame=VIOLATION(free inside a native call; free inside a native
callback) ... violations=2` and `wakeDrivenRepoll=VIOLATION(...) ... violations=2`,
two named tests failing (`completionInsideThePollFrameNeverFreesTheFuture`,
`wakeDrivenRepollNeverOutlivesTheFree`), 8 tests in the probe run. GREEN (0004 v3):
all six scenarios `clean ... violations=0`, with the counts that make the claim
falsifiable - `completionInsidePollFrame=clean free-once=true polls=1 completes=1
frees=1`, `cancellationOfParkedCall=clean polls=1 cancels=1 frees=1`,
`wakeDrivenRepoll=clean polls=2 completes=1 frees=1 displacements=1`,
`repeatedCancellation=clean`, `preCancelled=clean`. The one non-clean line is
recorded as observed upstream behaviour, not a candidate result:
`displacement-completed-a-pending-future=observed(upstream policy)`.

*Apple native result - `+1.167 s, 19 tests, all passed`, on real Rust:*

```
Test run with 19 tests passed after 1.167 seconds.
BOLT_PROOF version=0.1.0 sender=PASS viewer=PASS typed_errors=PASS layout=PASS
BOLT_ERR typed=BridgeError delivered=true
BOLT_BACKLOG policy=unbounded produced=100 nativeDropped=0 consumed=20 hostBuffered=80
BOLT_BOUNDED policy=batch produced=100 consumed=100 nativeDropped=0 hostBuffered=0
BOLT_CANCEL consumedAfterCancel=32 consumedAfterMore=32
BOLT_LIFETIME completionInsidePollFrame=clean free-once=true polls=1 completes=1 frees=1
BOLT_LIFETIME cancellationOfParkedCall=clean polls=1 cancels=1 frees=1
BOLT_LIFETIME wakeDrivenRepoll=clean polls=2 completes=1 displacements=1
BOLT_LIFETIME repeatedCancellation=clean / preCancelled=clean
```

This is the same suite that failed at `c260caf` with 45 + 4
`(probe.active() -> 1) == 0` ownership issues: 0004 v3's free-before-resume removed
the window between the caller being resumed and the native future being freed. The
lifetime probe's own assertions are unchanged between the two runs, so the
difference is the runtime, not the test.

Recorded honestly, not as a pass:
* `BOLT_BACKLOG policy=unbounded ... hostBuffered=80` - the unbounded host path is
  still unbounded; the *bounded* claim rests on `BOLT_BOUNDED policy=batch
  100/100/0/0`, which executed.
* `BOLT_CANCEL consumedAfterCancel=32 consumedAfterMore=32` - the subscription does
  not grow after cancellation, measured, not inferred.

*Android, the close-race expectation was wrong.* Debug APK + instrumentation APK
built and installed, boot 20 s, KVM usable, and the contract suite ran through
Kotlin -> generated -> JNI -> Rust with markers:
`BOLT_PROOF version=0.1.0 sender=PASS viewer=PASS typed_errors=PASS layout=PASS
async=PASS cancellation=PASS repeated_cancel=100 raced_cancel=100 batch=8/100
dropped=92` and `BOLT_STREAM produced=200 consumed=26 nativeDropped=98
unconsumed=76`. The close suite then failed at `ConcurrentCloseTest.kt:97`
(`java.lang.IllegalStateException: AsyncProbe is closed` thrown from
`AsyncProbe.boltffiRetain$boltffi_android_proof`): the test called `release()`
after `close()` and treated the rejection as a crash. Rejection after close *is*
the contract patch 0002 (upstream #732) implements, so the test now expects it, and
the RED/GREEN contrast for Android no longer rests on a race: the unpatched
generated Kotlin has no counter at all (`__boltffi_calls`, `boltffiRetain`,
`boltffiRelease` = 0 occurrences; every entry point reads `boltffiHandle()`), while
the patched tree has all three - asserted by token, per build.

*Two harness defects this run exposed, both fixed:*
  1. `concurrency: cancel-in-progress` on `boltffi-retest-${{ github.ref }}` means a
     push cancels the in-flight run. The head push cancelled its own predecessor
     mid-RED, and the `if: always()` restore step then published
     `::error BoltFFI generation missing`, which reads like a generation defect
     under a half-built workspace. The restore step is now gated on
     `steps.green.outcome == 'success'`, and a companion step states plainly that
     the native run is NOT EXECUTED when GREEN did not run.
  2. The `T: Sendable` differential still started from the *unpatched* tree, so the
     token it removes was absent, the preparation exited non-zero, and
     `continue-on-error: true` reported a success with no result. It now starts
     from the patched tree; the probe summaries are written to files and published
     in one notice, because per-step notices compete for one annotation budget
     (both probe results were dropped in `35111780326`).


**Run `35108329894` (head `c260caf`) - both RED/GREEN pairs executed; one real
candidate difference found, in the cancellation path.**

Jobs: Rust `104835220621` **success**; Apple `104835220552` **failure**; Android
`104835220328` **failure**.

*Swift 6 pair, executed.* RED (unpatched v0.30.1, standalone probe):
`-swift-version 6` exits 1 at `Greenfield5BoltSpikeBoltFFI.swift:702:13` and
`703:13` - "capture of 'cancel'/'free' with non-sendable type
`(RustFutureHandle?) -> Void` ... in a '@Sendable' closure". GREEN-side text
assertions pass on the patched generator (cancel/free `@escaping @Sendable`, the
completion value constrained with `T: Sendable`, one `BoltFFIFutureLifetime`).

*Lifetime pair, executed against a real Xcode test target.* RED (pre-0004 runtime,
`--exclude 0004`):

```
BOLT_LIFETIME completionInsidePollFrame=VIOLATION(free inside a native call; free inside a native callback) free-once=true polls=1 completes=1 frees=1
BOLT_LIFETIME wakeDrivenRepoll=VIOLATION(free inside a native call; free inside a native callback) polls=2 displacements=1 ... violations=2
```

GREEN (patched runtime, same probe):

```
BOLT_LIFETIME completionInsidePollFrame=clean free-once=true polls=1 completes=1 frees=1 violations=0
BOLT_LIFETIME cancellationOfParkedCall=clean polls=1 cancels=1 frees=1 violations=0
BOLT_LIFETIME wakeDrivenRepoll=clean polls=2 completes=1 frees=1 displacements=1 violations=0
BOLT_LIFETIME repeatedCancellation=clean ... preCancelled=clean ...
```

*The native acceptance run executed* (`apple-proof.sh test`, 19 tests over the
real Rust library): the mocked lifetime suite passed; **the only failures were the
two real-Rust cancellation tests** - `BoltOwnership.repeatedCancellation` with 45
issues and `cancellationRacingReadiness` with 4, every one of them
`Expectation failed: (probe.active() -> 1) == 0`.
Diagnosis, from the runtime source rather than from the test: `RustFuture::cancel`
only marks the continuation scheduler cancelled; the `Arc<RustFuture>` - and with
it the async body and its `active` guard - is dropped by `rust_future_free`
(`consume_future`). Patch 0004 v2 deferred the free to the lifetime's `deinit`,
which is *safe* but asynchronous: the caller could be resumed before the free ran,
so a native future could outlive the call that created it. That is a real
observable difference, not a test artifact, and it is now fixed in the candidate
rather than accommodated in the test - see "Patch 0004 v3" below.

*Harness defects fixed in this commit (all three hid or mis-attributed evidence):*
  1. `run-with-timeout.py` opened logs in **append** mode, so the final
     `spikes/boltffi-retest/test.log` held the *lifetime RED* run's violations and
     the GREEN run's clean lines in one file - a diagnostics step could publish a
     violation from the unpatched runtime as if it came from the patched one. Logs
     are now truncated per invocation, and `apple-proof.sh` writes per-mode logs
     (`apple-test.log`, `apple-lifetime.log`, plus matching build logs).
  2. The differential probe started from the *unpatched* tree, so it also failed
     on artifacts of the probe's own invocation and could not attribute its
     failure. It now starts from the patched tree and removes only
     `: Sendable` from `boltffiAsyncCall`, which isolates the token.
  3. The standalone probe compiled the generated file as top-level code, where
     Swift 6 isolates top-level declarations to the main actor, reporting
     "main actor-isolated let 'boltffiAsyncPollCallback' can not be referenced from
     a nonisolated context" (and the same for the stream callback) - diagnostics the
     app's own Swift 6 build (`SWIFT_VERSION = 6.0`) does not produce. The probe now
     passes `-parse-as-library`, and a **Swift 6 GREEN typecheck** was added to the
     patched-generation step so the pair is executed on both sides instead of only
     being asserted as text.

*Android, real JNI execution for the first time.* KVM is usable on this runner
(`ANDROID_KVM_PRESENT=yes`, udev rule, `ANDROID_ACCEL=usable`,
`ANDROID_BOOT_COMPLETED after 20s`); the debug app and instrumentation APKs built,
installed and ran the real contract suite through Kotlin -> generated bindings ->
JNI -> Rust: `dev.greenfield5.boltproof.NativeContractTest: OK (1 test)`,
`ANDROID_DEBUG_CONTRACT=PASS`. The job then failed on the *next* command, a marker
grep: Android routes the test process's `println` to logcat (`System.out`), not to
the `am instrument` protocol stream, so `BOLT_PROOF` was in `DEBUG_CONTRACT-logcat.txt`
and not in `debug-contract.log`. The close-race suite is therefore
**NOT EXECUTED** in this run - recorded as such, not as a pass. The marker greps now
read both files, and the Android diagnostics publish one notice per log (the single
concatenated notice had truncated away exactly the close-race logs).


**Run `35102072270` (head `628a614`) - both REDs reproduced for real; GREEN skipped
by a harness defect.**

Jobs: Rust `104813721854` **success**; Apple `104813721788` **failure**; Android
`104813721353` **failure**. (Earlier in this session the run for head `63ad133`,
run `35100417583`: Rust success, Apple `104808136376` failure, Android
`104808136519` failure - Apple's lifetime probe did not compile because
`RustFutureHandle`/`FfiStatus` are C-module types the app module does not
re-export; fixed in `628a614` by spelling `UnsafeRawPointer` and taking the
completion closure's parameter types from the generated signature.)

*Swift 6 RED, executed* - `swift-typecheck.sh` found the generated Swift at
`generated/apple/Sources/BoltFFI/Greenfield5BoltSpikeBoltFFI.swift` (modulemap
`generated/apple/BoltSpike.xcframework/ios-arm64-simulator/Headers/module.modulemap`)
and `-swift-version 6` rejected it with exit 1:
`702:13: error: capture of 'cancel' with non-sendable type '(RustFutureHandle?) -> Void' ... in a '@Sendable' closure`,
`703:13: error: capture of 'free' with ...` plus
`629:13 main actor-isolated let 'boltffiAsyncPollCallback' can not be referenced from a nonisolated context`
and `804:34` for the stream poll callback. This is the first time the RED probe
compiled anything: every earlier attempt died in the harness.

*Lifetime RED, executed* (pre-0004 runtime built by `--exclude 0004`, driven by
the real Xcode test target on a simulator):

```
BOLT_LIFETIME completionInsidePollFrame=VIOLATION(free inside a native call; free inside a native callback) free-once=true polls=1 cancels=0 completes=1 frees=1 displacements=0 violations=2
BOLT_LIFETIME cancellationOfParkedCall=clean polls=1 cancels=1 completes=0 frees=1 displacements=0 violations=0
BOLT_LIFETIME displacement-completed-a-pending-future=observed(upstream policy)
BOLT_LIFETIME wakeDrivenRepoll=VIOLATION(free inside a native call; free inside a native callback) polls=2 cancels=0 completes=1 frees=1 displacements=1 violations=2
BOLT_LIFETIME preCancelled=clean polls=0 cancels=1 completes=0 frees=1 displacements=0 violations=0
Test run with 8 tests failed after 9.385 seconds with 2 issues.
```

  Two independent mechanisms are now measured, not argued: (a) the completion
  path frees the future **while the runtime is still inside `RustFuture::poll`**
  (`free inside a native call` + `free inside a native callback` on the very first
  poll), and (b) the wake-driven re-poll path displaces the parked continuation
  (`displacements=1`), the displaced delivery completes the call from inside the
  poll frame, and the free lands there too. Mechanism (b) is the one the SIGSEGV
  in run `35092248876` came from.
*Harness defect that cost this run its GREEN phase*: the Lifetime RED step wraps
the probe in a function that re-enables `set -e` (for fail-fast inside the chain),
and shell options are global - so the probe's `xcodebuild` exit 65 killed the step
before the assertion could publish the violation it had already written to
`lifetime-red.log`. GREEN generation, lifetime GREEN, the differential probe, the
restore and the whole native run were therefore **skipped**, and the restore guard
correctly failed closed ("generated-patched holds no generated Swift"). Fixed by
running the probe in a subshell.
*Android*: unpatched baseline RED is recorded (provenance `BOLTFFI_PATCHED=no`,
`BOLTFFI_DIFFSTAT= 0 files changed`; GREEN provenance carries the in-flight counter
and the receiver retain), KVM prep works on this runner
(`ANDROID_KVM_PRESENT=yes`, `ANDROID_KVM_NOT_WRITABLE=yes` -> udev rule ->
`READABLE/WRITABLE=yes`, `ANDROID_ACCEL=usable`, `ANDROID_BOOT_COMPLETED after
20s`), but **no native execution happened**: the instrumentation APK failed to
compile - `Unresolved reference 'eventsBatch' on receiver of type 'EventProbe'` -
because the generated Kotlin exposes stream accessors as extension functions and
Kotlin needs an explicit import for them. Fixed by importing
`dev.greenfield5.bolt.eventsBatch`. The close-race RED probe is consequently
"NOT EXECUTED", never PASS.
*Diagnostics*: the per-log notices added in `628a614` published the violation, the
Kotlin compiler error and the Android RED-probe result from this one run, where the
previous single concatenated notice had truncated away exactly the failing file.


**Run `35098039373` (head `580e425`, patch 0004 first execution) - two harness
defects, no candidate result yet.**

- Rust job `104800184990` **success**: the patch set does not disturb the Rust
  contract suite (0004 touches only the Swift template).
- Apple job `104800185152` **failed before it reached the compiler**, and the new
  diagnostics say why: the RED assertion reported
  *"BoltFFI Swift 6 RED was not the Sendable defect"* with an empty log extract,
  and the always-run restore step reported
  *"generated-patched holds no generated Swift"*.
  Root cause, found from the CLI source rather than guessed: with
  `layout = "ffi-only"` the Apple pack writes the Swift API to
  `<targets.apple.spm.output>/Sources/BoltFFI` (`pack/apple/mod.rs:239-245`;
  `apple_spm_output()` defaults to `targets.apple.output`), **not** to
  `generated/swift`, which only exists in the `split` layout. `swift-typecheck.sh`
  searched only `generated/swift`, hit its own guard, and exited 1 - a harness
  result that the old diagnostics could not distinguish from a compiler result.
  Fixed: the probe searches both layouts, type-checks *all* generated Swift files
  (not just the first), prints `SWIFT_TYPECHECK_MISSING` plus a bounded tree dump
  when it finds nothing, and the workflow now emits the log tail as an
  `::error`/`%0A`-encoded annotation for either cause.
- Android job `104800184728` **failed at patch application**:
  `error: patch failed: boltffi_backend/templates/target/swift/async.swift:110 /
  patch does not apply`. Root cause: the fetch script checked *every* patch
  against the pristine tree before applying any. That was valid only while the
  patches touched disjoint files; 0004 edits the same file as 0001, so the
  pre-flight check rejected a correct patch set. Fixed: patches are now checked
  and applied cumulatively, and a failure rolls the checkout back to the pristine
  tag so no half-patched generator can be built.
- Control added, because both defects were "code in a workflow that only runs on
  a runner": `scripts/verify.sh` now has a `workflow_steps` check that extracts
  every `run:` body from every workflow, runs `bash -n` on it and `compile()` on
  every embedded python heredoc. Verified negatively: an injected
  generator-expression error and an injected unmatched `fi` both make it FAIL
  (the first version of the check had a real gap - step indices restart per job,
  so two jobs' steps overwrote each other in the scratch directory and went
  unchecked; the job name is now part of the file name).
- Also found at this head: the runner reports
  `Node.js 20 is deprecated ... forced to run on Node.js 24` for the two pinned
  actions. Advisory only; the pins are unchanged.


**Run `35089590460` (head `6e0922f`) - Swift 6 RED reproduced for real.**

- Unpatched v0.30.1, real project, real compiler, generated file
  `Greenfield5BoltSpikeBoltFFI.swift`:
  `702:13: error: capture of 'cancel' with non-sendable type '(RustFutureHandle?) -> Void' (aka '(Optional<UnsafeRawPointer>) -> ()') in a '@Sendable' closure`,
  the same for `free` at `703:13`, each followed by
  `note: a function type must be marked '@Sendable' to conform to 'Sendable'`.
  Same defect and same lines as PR #18's harvest record, now produced by the
  harness that also runs the GREEN half.
- Differential probe (params only: the two `@Sendable` annotations, **no**
  `T: Sendable`): `xcodebuild exit 65` with
  `678:46: error: sending 'value' risks causing data races`. `T: Sendable` is
  therefore required by this toolchain; patch 0001 keeps all three changes.
- GREEN generator assertion passed: the patched CLI emits >=2
  `@escaping @Sendable (RustFutureHandle?) -> Void` and
  `func boltffiAsyncCall<T: Sendable>(`.
- Harness defect found and fixed at this head: `apple-proof.sh` invoked
  `xcodebuild` from the spike directory, so the previous run reported
  `'Greenfield5.xcodeproj' does not exist` instead of a compiler result; every
  bounded invocation now runs inside the copied project.
- Still open at that head: the Apple "restore the patched generation" step
  checked `generated-patched/swift`, which the apple pack does not create here
  (its Swift API lives under `generated/apple/Sources`), so it is now a search
  for any generated Swift. The Android RED assertion also gated on shapes it
  had assumed (`Native.*(boltffiHandle())` inside `close()`) instead of measured;
  it now publishes the whole generated tree plus per-file structural facts and
  gates only on provenance.
- Not yet executed at that head: the Android emulator proof (and therefore the
  minified-release path) and the iOS native test run.

**Patch set at head `6e0922f`** (SHA-256 of each file as committed; the current
heads are re-derived and published by the workflow on every run):

| Patch | Bytes | SHA-256 |
| --- | --- | --- |
| `0001-swift-async-sendable-cancel-free.patch` | 4742 | `2a615096a174a5f5ee3b8d681a02f05cf8260cb05938f88dfe7ed96bd7784330` |
| `0002-upstream-pr732-kotlin-inflight-counter.patch` | 8874 | `44265dc879c89554ae076b1a1889c1f325142cd28c4120b1800e3642aecfd0cc` |
| `0003-kotlin-stream-receiver-retain.patch` | 6057 | `03ecb4f702266a4f8a1f3ffefe991a714d0be8173de38964b12a4541e5e63bea` |

Re-verified at that head: all three `git apply --check` clean against a pristine
`2e6320a6` checkout, combined diffstat **4 files, +59/-25**
(`target/kotlin/render/class.rs`, `templates/target/kotlin/class.kt`,
`templates/target/kotlin/stream.kt`, `templates/target/swift/async.swift`).


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
3. **RED → GREEN, two independent pairs, same generator:**
   - *Swift 6 compilation*: the Apple job builds the *unpatched* CLI first and
     type-checks its generated Swift with `swiftc -swift-version 6`
     (`scripts/swift-typecheck.sh`), which must fail on the non-Sendable
     `cancel`/`free` captures; the patched CLI is then rebuilt and the same
     command must pass. A non-gating differential probe type-checks a
     *params-only* variant (cancel/free `@Sendable` without `T: Sendable`) to
     decide empirically whether the constraint is required.
   - *Swift future lifetime*: the job rebuilds the runtime with
     `--exclude 0004` (same generator, one fix removed) and runs
     `scripts/apple-proof.sh lifetime`, i.e. `host/LifetimeProbe.swift` against
     the generated runtime; that must fail with a recorded lifetime violation.
     The patched runtime then runs the same probe, which must pass, and the full
     `apple-proof.sh test` adds the real-Rust suite (`BOLT_PROOF`,
     `BOLT_BACKLOG`, `BOLT_LIFETIME`) on the simulator.
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

- ~~**`T: Sendable` may be unnecessary**~~ - decided by the differential probe on
  2026-09-16: it is required (the params-only variant still fails with "sending
  'value' risks causing data races"), so patch 0001 keeps all three changes.
- **Emulator boot** is the highest-risk step; PR #18's failure was opaque.
  Mitigation: publish everything (image, command line, accel report, adb state,
  boot properties, emulator stdout/stderr), preflight KVM/accel, finite ceiling.
- **Generated-file layout for `pack android`** is not yet confirmed from a real
  run: the RED baseline published a single `.kt` whose shapes look like the
  Kotlin runtime helper rather than the class module. The new per-file listing
  resolves it; the GREEN assertions (counter + retain/release + retain-wrapped
  subscribe, no raw `boltffiHandle()` argument) are the ones that must hold, and
  they passed.
- **Patch 0002/0003 are not compiled in this sandbox** (no cargo). The method
  path is upstream-CI-proven; the stream path is verified structurally and by
  the generated-source assertions, then by compilation on CI.
- **Host API names**: PR #18's Kotlin host is compile-proven; the Swift host has
  never compiled (its Apple job failed earlier), so Swift symbol names are
  inferred from the generator templates and verified on CI.
- **Patch 0004's first draft was wrong and was corrected before it ran**: merely
  queueing the *poll* while still freeing inline from the callback leaves the
  wake path freeing inside the runtime's callback frame. The free is now
  enqueued on the same serial queue that issues every poll and cancel, which is
  what the host probe checks first.
- **`RustFutureHandle` is a non-Sendable raw pointer**: the deferred free must
  therefore capture an immutable box that owns it, not the pointer itself, or
  Swift 6 rejects the closure. The probe and the GREEN generator assertion both
  fail closed if that box disappears.
- CI minutes: each candidate job is long; every iteration must publish enough
  diagnostics to avoid a blind second attempt.
- `spikes/` is candidate-only. If the result is KEEP or DEFER, the spike and its
  CI jobs are removed before final-head verification.

## Out of scope (explicit)

MoQ, Iroh, screen capture, ReplayKit, MediaProjection, pairing, audio, UI
redesign, production BoltFFI migration, production UniFFI changes, and any
change to `config/project.env`. No physical-device claims; anything not executed
is recorded as SKIPPED / NOT EXECUTED / UNVERIFIED — PHYSICAL DEVICE REQUIRED.
