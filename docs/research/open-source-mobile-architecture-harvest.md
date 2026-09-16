# Open-source mobile architecture harvest

Inspection date: **2026-09-15 (UTC)**. Current decision: **DEFER BOLTFFI** until
a released version generates Swift-6-compatible async cancellation callbacks
and resolves the documented concurrent-close ownership contract (#664), then
rerun the native async/event/ownership acceptance tests. See **Executed A/B and
decision** below for CI evidence and remaining unexecuted tests. UniFFI remains
the production bridge under ADR-0007; disposable candidate code was removed.

## Scope

Should the newly merged UniFFI bridge be replaced before async transport/media
increases the FFI surface? Which donor packaging, observability and capture
lifecycle patterns reduce upcoming implementation risk? This report records a
first source pass across all eight required donors, followed by an executable
CI comparison. The initial checkpoint did not execute Phase B; the continuation
below supersedes that status. Missing runtime proof is neither parity nor
disproven parity. See the [plan](../plans/mobile-architecture-harvest.md).

Excluded: production capture, media transport implementation, pairing UX,
accounts, backend, browser viewer, relay deployment, rooms, remote control,
audio UX, store setup, unrelated upgrades and governance changes.

## Greenfield5 constraints and baseline

VERIFIED via `git fetch origin`, commits/main API, PR #17 API and local tree:

- main = `6c85f9a098aba114c94c6247257ea013fa53abd1`.
- PR #17 MERGED at `2026-09-15T21:26:34Z`, merge commit equals main.
- `core/src/uniffi_api.rs`, Android bridge/tests and iOS bridge/XCFramework
  script exist on origin/main. No baseline divergence found.
- `PROJECT_PHASE=implementation`, `ALLOW_APP_STACK=1`,
  `STACK_DECISION_ADR=docs/decisions/0006-application-stack.md`.
- ADR-0007 selects UniFFI 0.32.1; no superseding decision introduced here.
- Open issues returned by GitHub: #11 synthetic Android/iOS media; #16 test
  permission. #15/PR #17 are the preceding bridge work. #11's old
  architecture-phase restriction is stale relative to merged config/ADR-0006;
  this report does not close or implement its media acceptance criteria.

PRODUCT/ROADMAP/ADR-0005/0006/0007 require native Kotlin/Compose and
Swift/SwiftUI, shared Rust, narrow FFI, Android 10+ / iOS 16+, current-platform
compatibility, one sender/one viewer, no accounts/control/content persistence,
progressive permissions and stable session/seam semantics. Capture lifetime is
not session lifetime: capture revocation can leave a connected, clearly
interrupted session. Internet is direct-first Iroh with dedicated connectivity
relay fallback; Local is strictly offline; Direct needs compatible nearby IP
connectivity, not merely an Internet connection that happens to be P2P.

## Method

GitHub APIs for repository/default branch, issues, releases and CI; fresh
shallow Git clones for exact HEAD and primary source. Donor clones live outside
the product tree and are not dependencies. Source excerpts and targeted searches
are a **partial inspection**, not exhaustive audits or upstream test execution.
Paths below identify inspected files (some by relevant excerpts). Immutable
source URLs use the recorded SHA. No benchmark measurements were adopted.

Confidence vocabulary:

- **VERIFIED**: the cited source/API actually contained the reported mechanism
  or assertion. Upstream claims of device testing remain upstream claims.
- **INFERRED**: applicability/risk deduced from that source; not executed here.
- **UNKNOWN**: required evidence not obtained. No substitution of desktop,
  source presence, or simulator success for physical-device evidence.

## Provenance

All entries are **conceptual reference only**: no copied code, adapted code or
new upstream dependency. File-level license obligations still require review
before a future adaptation. GitHub's single-license metadata is insufficient:
iroh-ffi declares MIT OR Apache-2.0. iroh-live README declares the same, but
its LICENSE-MIT contains Apache text: dual-license provenance needs clarification.

| Upstream / default branch | Exact SHA inspected | License | Files inspected | Evidence confidence |
|---|---|---|---|---|
| redbadger/crux / `master` | `2075a20d23a1a209f89cebd9b3847e1b0c313dc6` | Apache-2.0 | [LICENSE](https://github.com/redbadger/crux/blob/2075a20d23a1a209f89cebd9b3847e1b0c313dc6/LICENSE); [crux_core/CHANGELOG.md](https://github.com/redbadger/crux/blob/2075a20d23a1a209f89cebd9b3847e1b0c313dc6/crux_core/CHANGELOG.md); [examples/counter/shared/boltffi.toml](https://github.com/redbadger/crux/blob/2075a20d23a1a209f89cebd9b3847e1b0c313dc6/examples/counter/shared/boltffi.toml); [examples/counter/shared/Cargo.toml](https://github.com/redbadger/crux/blob/2075a20d23a1a209f89cebd9b3847e1b0c313dc6/examples/counter/shared/Cargo.toml); [examples/counter/Android/shared/build.gradle.kts](https://github.com/redbadger/crux/blob/2075a20d23a1a209f89cebd9b3847e1b0c313dc6/examples/counter/Android/shared/build.gradle.kts); [.github/workflows/examples.yaml](https://github.com/redbadger/crux/blob/2075a20d23a1a209f89cebd9b3847e1b0c313dc6/.github/workflows/examples.yaml) | VERIFIED source excerpts; runtime UNKNOWN |
| boltffi/boltffi / `main` | `d5eba2e347a957a7fce67bb738ae37d985ba082b` | MIT | [LICENSE](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/LICENSE); [README.md](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/README.md); [Cargo.toml](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/Cargo.toml); [BOLTFFI_TOML_SPEC.md](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/BOLTFFI_TOML_SPEC.md); [docs/src/content/docs/async.mdx](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/docs/src/content/docs/async.mdx); [docs/src/content/docs/streaming.mdx](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/docs/src/content/docs/streaming.mdx); [boltffi_backend/templates/target/swift/stream.swift](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/boltffi_backend/templates/target/swift/stream.swift); [boltffi_backend/templates/target/kotlin/class.kt](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/boltffi_backend/templates/target/kotlin/class.kt); [boltffi_backend/src/target/swift/render/stream.rs](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/boltffi_backend/src/target/swift/render/stream.rs); [boltffi_cli/src/pack/android/mod.rs](https://github.com/boltffi/boltffi/blob/d5eba2e347a957a7fce67bb738ae37d985ba082b/boltffi_cli/src/pack/android/mod.rs) | VERIFIED source excerpts; runtime UNKNOWN |
| n0-computer/iroh-ffi / `main` | `3103bf5295be6d50c5272ff7a426e9b539f3f587` | MIT OR Apache-2.0 | [LICENSE-MIT](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/LICENSE-MIT); [LICENSE-APACHE](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/LICENSE-APACHE); [Cargo.toml](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/Cargo.toml); [src/android_init.rs](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/src/android_init.rs); [kotlin/android/src/main/kotlin/computer/iroh/IrohAndroid.kt](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/kotlin/android/src/main/kotlin/computer/iroh/IrohAndroid.kt); [scripts/verify_android_page_size.sh](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/scripts/verify_android_page_size.sh); [.github/workflows/release.yml](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/.github/workflows/release.yml); [.github/workflows/release_swift.yml](https://github.com/n0-computer/iroh-ffi/blob/3103bf5295be6d50c5272ff7a426e9b539f3f587/.github/workflows/release_swift.yml) | VERIFIED source excerpts; runtime UNKNOWN |
| n0-computer/hello-iroh-ffi / `main` | `3249baad34fd400005c5397f021677fc2ea1671a` | MIT | [LICENSE](https://github.com/n0-computer/hello-iroh-ffi/blob/3249baad34fd400005c5397f021677fc2ea1671a/LICENSE); [kotlin-android/app/src/main/java/computer/iroh/dot/net/IrohPeer.kt](https://github.com/n0-computer/hello-iroh-ffi/blob/3249baad34fd400005c5397f021677fc2ea1671a/kotlin-android/app/src/main/java/computer/iroh/dot/net/IrohPeer.kt); [swift/HelloIroh/IrohPeer.swift](https://github.com/n0-computer/hello-iroh-ffi/blob/3249baad34fd400005c5397f021677fc2ea1671a/swift/HelloIroh/IrohPeer.swift) | VERIFIED source excerpts; runtime UNKNOWN |
| n0-computer/iroh-live / `main` | `de7f43bfc466988f08b7e63acdd7fb295a9f9fd2` | Declared MIT OR Apache-2.0; LICENSE-MIT text mismatch | [LICENSE-MIT](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/LICENSE-MIT); [LICENSE-APACHE](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/LICENSE-APACHE); [README.md](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/README.md); [docs/platforms.md](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/docs/platforms.md); [demos/android/README.md](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/demos/android/README.md); [moq-media/src/frame_channel.rs](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/moq-media/src/frame_channel.rs); [moq-media/src/subscribe/video.rs](https://github.com/n0-computer/iroh-live/blob/de7f43bfc466988f08b7e63acdd7fb295a9f9fd2/moq-media/src/subscribe/video.rs) | VERIFIED source excerpts; runtime UNKNOWN |
| livekit/client-sdk-android / `main` | `12433f2299cde56ea4c085a36ab873d2f51294da` | Apache-2.0 | [LICENSE](https://github.com/livekit/client-sdk-android/blob/12433f2299cde56ea4c085a36ab873d2f51294da/LICENSE); [NOTICE](https://github.com/livekit/client-sdk-android/blob/12433f2299cde56ea4c085a36ab873d2f51294da/NOTICE); [CHANGELOG.md](https://github.com/livekit/client-sdk-android/blob/12433f2299cde56ea4c085a36ab873d2f51294da/CHANGELOG.md); [livekit-android-sdk/src/main/java/io/livekit/android/room/track/screencapture/ScreenCaptureService.kt](https://github.com/livekit/client-sdk-android/blob/12433f2299cde56ea4c085a36ab873d2f51294da/livekit-android-sdk/src/main/java/io/livekit/android/room/track/screencapture/ScreenCaptureService.kt); [livekit-android-sdk/src/main/java/io/livekit/android/room/track/LocalScreencastVideoTrack.kt](https://github.com/livekit/client-sdk-android/blob/12433f2299cde56ea4c085a36ab873d2f51294da/livekit-android-sdk/src/main/java/io/livekit/android/room/track/LocalScreencastVideoTrack.kt) | VERIFIED source excerpts; runtime UNKNOWN |
| livekit/client-sdk-swift / `main` | `eda7d80001cfe87e406dbfa58d77e9694de39727` | Apache-2.0 | [LICENSE](https://github.com/livekit/client-sdk-swift/blob/eda7d80001cfe87e406dbfa58d77e9694de39727/LICENSE); [NOTICE](https://github.com/livekit/client-sdk-swift/blob/eda7d80001cfe87e406dbfa58d77e9694de39727/NOTICE); [Sources/LiveKit/Broadcast/NOTICE](https://github.com/livekit/client-sdk-swift/blob/eda7d80001cfe87e406dbfa58d77e9694de39727/Sources/LiveKit/Broadcast/NOTICE); [Sources/LiveKit/Broadcast/LKSampleHandler.swift](https://github.com/livekit/client-sdk-swift/blob/eda7d80001cfe87e406dbfa58d77e9694de39727/Sources/LiveKit/Broadcast/LKSampleHandler.swift); [Sources/LiveKit/Broadcast/IPC/BroadcastUploader.swift](https://github.com/livekit/client-sdk-swift/blob/eda7d80001cfe87e406dbfa58d77e9694de39727/Sources/LiveKit/Broadcast/IPC/BroadcastUploader.swift) | VERIFIED source excerpts; runtime UNKNOWN |
| rustdesk/rustdesk / `master` | `851d2df88cc8ef7a8368f74e8b2e7254861ee00a` | AGPL-3.0 | [LICENCE](https://github.com/rustdesk/rustdesk/blob/851d2df88cc8ef7a8368f74e8b2e7254861ee00a/LICENCE); [flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainService.kt](https://github.com/rustdesk/rustdesk/blob/851d2df88cc8ef7a8368f74e8b2e7254861ee00a/flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/MainService.kt) | VERIFIED source excerpts; runtime UNKNOWN |

## Gap matrix

| Greenfield5 gap | Upstream solution | Evidence | Applicability |
|---|---|---|---|
| Native packaging glue | Crux BoltFFI target config and generated directories | Counter config, Gradle module, changelog | INFERRED reduction; not measured in Greenfield5 |
| Async/event ownership | BoltFFI suspend/async APIs and stream subscriptions | async/stream docs and Swift template | Mixed: bounded Rust buffer does not bound Swift host buffer |
| Android Iroh DNS initialization | JNI VM/application-context installation | iroh-ffi android_init.rs | Required before endpoint for this donor Iroh version, regardless of generator |
| Connectivity evidence | Both hello-iroh hosts poll selected path and RTT | Kotlin/Swift IrohPeer | HARVEST diagnostics, not demo identity/UI |
| Live-edge media delivery | Single latest-frame slot and bounded encoded read-ahead | iroh-live frame_channel.rs, subscribe/video.rs | Different queues for decoded pictures vs encoded dependencies |
| Android revoke/dispose races | Explicit capture service, callback, resource ownership | LiveKit Android capture sources/changelog | HARVEST lifecycle only |
| iOS process separation | Broadcast handler + IPC uploader to app | LiveKit Swift handler/uploader | Candidate, needs suspension/memory proof |
| Capture active without viewer | Distinct stopCapture and projection destruction | RustDesk MainService.kt | Caution, not a product architecture to copy |

## Harvest matrix

Verdicts below apply to **patterns**, not blanket package approval. HARVEST
means conceptual reimplementation in a later authorized slice; none is already
implemented. No new dependency meets the task's ADOPT gate in this checkpoint.

| Pattern | Source | Verdict | Reason | Risk | Required Greenfield5 proof |
|---|---|---|---|---|---|
| Target-configured Android/Apple packaging | Crux | HARVEST | Replaces bespoke generation plumbing | Actual artifact reproducibility unknown | Clean double build + ABI/API diff |
| Matching exact CLI/runtime pins | Crux 0.30.1 | HARVEST | Limits generator/runtime skew | Lockfile/platform drift remains | Locked rebuild on both CI hosts |
| Crux app architecture and byte-only type generation | Crux | REJECT | Existing typed seam need not become Crux event/effect architecture | Extra serialization/runtime model | Not needed |
| Crux minSdk 34 | Crux counter | REJECT | Violates Android 10+ floor | Excludes supported devices | Keep minSdk 29 |
| BoltFFI dependency migration now | BoltFFI | REJECT | Adoption gate lacks A/B evidence; not a permanent rejection | Concurrent close, Swift buffering/Sendable | Complete isolated A/B before reconsidering |
| Native JNI rather than JNA | BoltFFI | HARVEST | Plausible Android simplification | JNI still unsafe; R8 rules still needed | Real JNI Android invocation and minified runtime |
| Default unbounded Swift event delivery | BoltFFI | REJECT | Native ring capacity does not bound host backlog | Memory growth with slow consumer | Bounded host delivery and drop counters |
| Batch stream control | BoltFFI | HARVEST | Explicit bounded polling may avoid async backlog | Cancellation/free races | Slow consumer + close/cancel stress |
| VM + application context before endpoint | iroh-ffi | HARVEST | Android resolver prerequisite independent of FFI generator | Global-ref lifetime; failure reporting | Instrumentation cold start, duplicate init, DNS |
| AAR ABI staging / XCFramework validation | iroh-ffi | HARVEST | Explicit artifact ownership | Not evidence of this app's packaging | Inspect every required slice, native tests |
| 16 KB ELF validation concept | iroh-ffi | HARVEST | Native page-size compatibility is separate from Kotlin compilation | Donor checker can succeed with no matching files | Fail on empty ABI set; ELF + APK alignment and device test |
| Donor floating CI actions | iroh-ffi | REJECT | Release workflow has setup-ndk@main | Supply-chain drift | SHA-pin Greenfield5 actions |
| Selected path + RTT snapshots | hello-iroh-ffi | HARVEST | Distinguishes chosen path from available candidates | Raw addresses are sensitive diagnostics | Direct/relay path change timeline, redacted logs |
| Demo UI, persistent identity, services API key | hello-iroh-ffi | REJECT | Unnecessary product/telemetry scope | Hidden identity/history | No transplant |
| iroh-moq session/ALPN integration | iroh-live | HARVEST | Closest existing MoQ/Iroh integration | API/fork churn; iOS unproven | Pinned Android/iOS synthetic stream |
| moq-media orchestration | iroh-live | HARVEST | Reuses upstream codec plumbing without entire app | Transitive fork/features | Minimal compile/size/runtime evaluation |
| Android MediaCodec integration design | iroh-live | HARVEST | Android two-way H.264 donor evidence | Codec device variation | Encoder/decoder capability and fallback tests |
| AHardwareBuffer/EGL zero-copy rendering | iroh-live | HARVEST | Avoid decoded-frame byte-array FFI | Buffer pool/fence/resource ownership | Surface teardown + frame lifetime/device tests |
| Latest decoded-frame slot | iroh-live | HARVEST | Bounds GPU surfaces and favors live edge | Must not drop arbitrary encoded reference frames | Slow renderer, produced/consumed/drop accounting |
| Bounded encoded read-ahead | iroh-live | HARVEST | Bounds memory without arbitrary encoded-frame dropping | Latency/backpressure interaction | Slow decoder and keyframe recovery |
| Cancellation/shutdown structure | iroh-live | HARVEST | Lifetime-bound workers are preferable to detached media tasks | Detailed paths not fully audited | Repeated start/stop; no surviving tasks |
| Adaptive rendition | iroh-live | HARVEST | Existing policy rather than private protocol | Unnecessary complexity for first stream | Fixed-rendition proof first, later switching/keyframes |
| Audio pipeline | iroh-live | HARVEST | AEC/device integration lessons | Permission and handset audio differences | Separate later audio slice; no audio UX here |
| Test-pattern source | iroh-live | HARVEST | Isolates transport from capture permissions | Feature pulls codec dependencies | Moving encoded output on both platforms |
| Ticket/session admission model | iroh-live | REJECT | A ticket is not sender approval or one-viewer enforcement | Unauthorized screen visibility | Preserve core admission semantics |
| Browser/WebTransport relay | iroh-live-relay | REJECT | No MVP browser viewer; not connectivity relay | Donor says no authentication | Not needed |
| Rooms/multiparty/gossip | iroh-live | REJECT | Exactly one sender/viewer | Product/operational expansion | Not needed |
| Progressive MediaProjection permission + service lifetime | LiveKit Android | HARVEST | OS ownership separate from transport | Permission-result/service race | Denied consent, revoke, lock and restart |
| Projection stop/dispose cleanup | LiveKit Android | HARVEST | Handles asynchronous stop/resource teardown | Callback thread races | Revocation simultaneous with disposal |
| Optional system audio failure handling | LiveKit Android | HARVEST | Avoid stale audio replay after revoke | App capture restrictions | Revocation before first buffer and read errors |
| Extension handler/IPC/termination | LiveKit Swift | HARVEST | Maintained system-wide sharing pattern | App suspension, IPC budget | App background/kill and extension stop |
| Single in-flight video sample | LiveKit Swift | HARVEST | Limits uploader concurrency | Audio queue and async error paths need separate audit | Slow IPC, failure, memory high-water mark |
| LiveKit transport/signaling/rooms/server/tokens | Both LiveKit SDKs | REJECT | Conflicts with ADR-0005 and minimal MVP | Backend/auth expansion | Not needed |
| Projection-vs-capture lifetime lessons | RustDesk | HARVEST | Stop producing is not necessarily stop projection | Privacy indicator remains | Assert indicators and consent on no-viewer/end |
| RustDesk remote-control/accessibility architecture/code | RustDesk | REJECT | Product mismatch and AGPL import gate | Copyleft; unattended/control behavior | No code imported |

## BoltFFI findings

VERIFIED source: inspected main identifies version 0.30.1. GitHub release API
returned v0.30.1 (2026-08-17) as newest release in the returned list. Crux's
workflow installs CLI with `--version '=0.30.1' --locked`; counter config uses
`boltffi pack` target outputs. Crux changelog explicitly replaces UniFFI binding
generation, removes crux_cli, deprecates compatibility bindgen, but retains a
separate facet app-type codegen step. Gradle still manually consumes generated
Kotlin/jniLibs directories. Thus “all glue disappeared” is false. This inspected
module has no JNA dependency; historical repository-wide JNA removal and exact
before/after artifact counts were not established.

VERIFIED source: BoltFFI's Android pack implementation handles binding expansion
and optional desktop JNI native packaging. Its templates generate native handle
wrappers. Async docs specify Kotlin `suspend fun`, Swift `async` / `async throws`
and native cancellation. Streaming docs specify Flow/AsyncStream, callback and
batch modes, a native ring buffer dropping **new** events when full rather than
blocking the producer. These are API/source observations, **not executed tests**.

Important VERIFIED source limitation: Swift `templates/target/swift/stream.swift`
constructs `AsyncStream(bufferingPolicy: .unbounded)`, yields without using the
yield result, and installs an onTermination handler. INFERRED: a bounded Rust
ring does not bound the generated Swift queue; a slow Swift consumer can
accumulate events after native draining. Callback/batch mode is an alternative
to test, not a proved solution. Do not benchmark raw video over FFI.

Open reports fetched at inspection time (issue existence/content VERIFIED,
affected Greenfield5 runtime UNKNOWN):

- [#778](https://github.com/boltffi/boltffi/issues/778): exported Swift classes
  need Sendable even though Rust classes require Send + Sync.
- [#771](https://github.com/boltffi/boltffi/issues/771): Apple multi-module build.
- [#780](https://github.com/boltffi/boltffi/issues/780): generated fromReader/layout
  inconsistency. Do not assume zero-copy struct layout correctness.
- [#664](https://github.com/boltffi/boltffi/issues/664): concurrent close remains
  check-then-act; a thread can free a handle while another call uses it. Full
  body inspected; Kotlin class template also has atomic closed flag followed by
  separate check. Treat as a security acceptance blocker until ownership is
  proved safe, not something to paper over with unchecked Sendable.
- [#871](https://github.com/boltffi/boltffi/issues/871): Kotlin error variant
  `message` field requires override; [#872](https://github.com/boltffi/boltffi/issues/872)
  reports unchecked foreign callback exceptions becoming success.
- [#60](https://github.com/boltffi/boltffi/issues/60): pull-driven lazy streams;
  [#55](https://github.com/boltffi/boltffi/issues/55): Kotlin Cleaner safety net.

Release/PR search found merged Android desktop JNI packaging fix
[#649](https://github.com/boltffi/boltffi/pull/649), and v0.30.0 release notes list
cross-crate stream retention fix [#812](https://github.com/boltffi/boltffi/pull/812)
and WASM wake callback fix [#821](https://github.com/boltffi/boltffi/pull/821).
The latter is **not** mobile stream correctness evidence. Exact release inclusion
of every searched JNI fix was not resolved. Do not extrapolate broad maturity
from merged fixes or benchmark headlines.

Tooling: configuration exposes min_sdk and Apple deployment_target; Crux's
counter uses Android 34, which Greenfield5 must not inherit. Full compatibility
with Greenfield5's AGP/Kotlin/Swift/Xcode pins and Android 29/iOS 16 was not tested.
Getting-started, error/classes implementation, JNI internals, all mobile test
fixtures and repeat-build reproducibility remain incomplete inspection areas.

## UniFFI baseline findings and checkpoint A/B comparison (historical)

Control source: `core/src/uniffi_api.rs` delegates to the existing Rust Session
with Arc/Mutex, typed enums/errors and u8 facade methods. Android generation
replaces fallback Kotlin rather than coexisting with it. `core/uniffi.toml`
fixes package imports; bridge naming and R8 retain JNA-specific compatibility.
Apple script uses separate header staging, normalized modulemap, removes builtin
module uses, combines simulator slices and requires real xcodebuild packaging.
Committed fallback/placeholder paths are not themselves native proof.

Re-fetched historical control CI: Stack run **35022211567**, head
`a52c7cb42ffdd20b61fae4ea35b8fc0c4485f655`, jobs **Rust core**, **Android shell**,
**iOS shell** all `success`. This is the PR's pre-merge head, **not** the final
head of this report. Android proof runs host JVM/JNA against host Rust, with
Android native assembly separately; it is not Android device invocation evidence.
The current Swift version test checks nonempty, not exactly 0.1.0. Strengthen
candidate test evidence rather than inherit these limits as acceptable parity.
`core/Cargo.lock` exists in current merged source; older ADR/PR follow-up text
saying it is absent is historical, not current truth.

| Dimension | UniFFI control | BoltFFI spike |
|---|---|---|
| Android native mechanism | JNA calling Rust cdylib; packaged ABI .so | No spike; donor JNI implementation inspected |
| JNA required | Yes, JNA 5.14.0 AAR + JVM test dependency | Donor does not need JNA; Greenfield5 removal unproved |
| Android build glue | cargo-ndk, generation script, source staging, host paths | pack android candidate; no resulting diff |
| Apple build glue | Header staging/modulemap normalization/lipo/XCFramework script | pack apple candidate; no Xcode integration produced |
| Generated artifact count | Committed placeholders not valid generated count | UNKNOWN; none generated |
| Custom scripts | Two bridge generation/packaging scripts plus workflow steps | UNKNOWN remaining script count |
| Known workarounds | Package/error names, JNA/R8, builtin modules, synchronized group staging | Open Sendable/layout/multi-module issues; local workarounds untested |
| Rust unsafe exposure | Crate allow; deny on handwritten session/seam modules | Generated JNI/raw handles; not audited end-to-end |
| Kotlin API ergonomics | Typed session/error wrappers, JNA ownership | Donor typed APIs/suspend/Flow; ungenerated for this seam |
| Swift API ergonomics | Typed generated wrapper, static native library | async/AsyncStream documented; class Sendable report open |
| Error mapping | BridgeError variant mapping in Rust | UNKNOWN contract parity |
| Async API | Current bridge synchronous | Documented async; not executed |
| Streaming API | None in current bridge | Native bounded/drop-new ring, Swift unbounded async template |
| Cancellation | No async seam exercised | Documentation/template only; close race report open |
| Debug build | Historical control job success | NOT RUN |
| Android minified release | Included in historical control job | NOT RUN; no runtime/R8 proof |
| iOS build | Historical control job success | NOT RUN |
| iOS tests | Historical control job success; version assertion weaker than requested | NOT RUN |
| Binary/app size delta | No same-toolchain A/B measurements | UNKNOWN |
| CI complexity | Platform jobs plus native proof annotations | No candidate CI; cannot quantify reduction |
| Dependency maturity | Proven merged integration; UniFFI established upstream | Crux adoption plus active unresolved issue set |
| Relevant open upstream issues | Script references UniFFI #2917; not freshly revalidated here | BoltFFI #664/#778/#771/#780/#871/#872 |
| Migration cost | Zero to preserve | UNKNOWN; API wrappers/tests/loading/build diff required |

**At the initial checkpoint: Android, iOS, async and stream acceptance NOT MET.** No candidate had been built,
no parity failure was reproduced, no sender/viewer candidate journey was run,
and no native version result was obtained. Tool discovery returned no cargo,
rustc, java, gradle, adb, xcodebuild or swift; Linux cannot supply Xcode.
CI is a possible remaining execution route, **not demonstrated unavailable**.
This checkpoint stops short of implementing that route; lack of local tools
alone does not prove the task impossible.

## Iroh mobile findings

VERIFIED: iroh-ffi manifest selects Iroh **1.0.0** family. android_init.rs holds
process-lifetime JavaVM and Application global references in ndk_context before
Endpoint construction because Android DNS reads LinkProperties. This prerequisite
belongs to Iroh/platform initialization, not UniFFI: BoltFFI does not eliminate
it. INFERRED hardening for Greenfield5: explicitly report initialization failure;
do not blindly copy the donor's Once plus logged/default error path, which can
make failed initialization non-retryable.

Release workflow stages cargo-ndk ABI libraries; Swift release workflow builds,
verifies, zips and bakes artifact SHA. Harvest mechanisms, not its floating
setup-ndk action. The inspected page-size checker skips nonexistent glob matches
and can return success for no libraries. Greenfield5 must assert required ABI
presence first and inspect ELF/APK alignment separately. No 16 KB device test ran.

hello-iroh Kotlin and Swift both poll connection path snapshots, mark the selected
path, distinguish relay/IP, and show RTT. Harvest cancellation of the previous
monitor when replacing a connection; retain source-of-truth observations instead
of inferring a mode from the requested UI setting. Avoid copying raw-address
logging, services keys or persistent demo identity wholesale.

**Relay distinction (ADR-0005):** Iroh connectivity relay carries encrypted
peer connectivity when direct IP fails. iroh-live-relay is a media/browser
WebTransport bridge; it is not required for Internet fallback and is rejected
for this MVP. Strict offline Local and cross-platform nearby Direct still need
separate endpoint configuration/device evidence. No network run occurred here.

## MoQ/media findings

VERIFIED upstream assertions: iroh-live README and Android demo describe Kotlin
+ Rust, two-way audio/video, MediaCodec H.264 and EGL AHardwareBuffer rendering.
Platform docs narrow Android testing to Android against Linux desktop. iOS is
**never built/tested here** in donor wording, not merely “not production-ready.”
README also warns of unfinished APIs, limited device testing, room redesign and
unauthenticated browser relay. Docs contain inconsistencies about Windows/Pi
support; do not elevate broad platform tables to mobile proof.

Upstream now sources codecs from moq-video/moq-audio and relies on a Frando/moq
branch patch set awaiting upstream integration. Adopting moq-media is therefore
not a small isolated dependency decision: transitive pins, codec licenses,
features and Apple compile proof need a separate audit. No fork block copied.

VERIFIED source: decoded frame_channel is a single overwrite slot with produced
count and close notification. Encoded subscription read-ahead uses bounded mpsc;
these are intentionally different loss policies. HARVEST low-volume diagnostics
across FFI and media handles within platform/Rust code, not chatty raw-frame
arrays. Cancellation, reconnect, adaptive switching and audio were identified
but not fully source-audited or exercised in this checkpoint.

Physical-device evidence: **UNVERIFIED — PHYSICAL DEVICE REQUIRED** for every
Greenfield5 Android/iOS direction, moving picture, forced relay and 60-second
sustained run. Upstream Android testimony is not Greenfield5 device evidence.

## Android capture findings

VERIFIED source: LiveKit separates projection permission result, foreground
capture service and track lifetime. Projection callback invokes stop handlers;
track source explicitly discusses onStop racing disposal. Changelog records
SurfaceTextureHelper disposal and cancellation leaks (#986), plus revoked
projection before first microphone buffer and failed AudioRecord reads (#982).
Ignoring read failure could replay stale audio; HARVEST immediate release/error
handling rather than transport-dependent mixing machinery.

INFERRED acceptance design: permission only on requested sharing, fresh consent
when required, start required mediaProjection service before capture, explicit
idempotent stop on revoke, release surfaces/codecs/audio exactly once, leave
core session interrupted rather than forcibly end it, and test denial/revoke/
lock/late callback/rapid restart. Do not request general notification permission
as a product prerequisite. Actual permission-flow, manifest and lifecycle tests
need deeper inspection and Android 29/current-device verification.

RustDesk caution: MainService.stopCapture can detach a reusable virtual display
surface rather than stop the projection. Source also has stale-projection
callback identity checks. INFERRED: “not producing frames” and “privacy indicator
cleared” are distinct states; teardown tests must check both. This does **not**
prove that current RustDesk always captures with zero viewers. That symptom and
current iOS sender capability were not independently reproduced/established.
No RustDesk iOS sender evidence supports Greenfield5's requirement. Reject its
architecture and all AGPL code import; retain conceptual privacy test lessons.

## iOS capture findings

VERIFIED: LiveKit LKSampleHandler forwards samples through BroadcastUploader,
closes uploader on broadcast finish, listens for stop notification, and finishes
on closed IPC connection. Uploader permits one video upload in flight and drops
incoming video while busy; app audio is gated by receiver demand. That is a
useful bounded-video pattern, not evidence that **all** queues are bounded:
audio creates asynchronous send tasks, and asynchronous video-send failure
cleanup needs deeper review. Handler's unchecked Sendable is not a transferable
safety proof. App-group socket implementation and IPC tests were located but
not fully inspected/executed.

| Greenfield5 shape | Benefit | Cost / failure question | Current verdict |
|---|---|---|---|
| A: extension encodes/transmits directly | Does not route samples through a potentially suspended app | Codec + Rust + Iroh/QUIC queues compete within extension process budget; independent admission/teardown | HARVEST candidate separation idea only; UNKNOWN feasibility |
| B: extension forwards samples to app | Closest inspected LiveKit architecture; extension keeps smaller duties | IPC copies/encoding cost, app suspension/kill and bounded audio must be proven | HARVEST first comparative reference, not adopted design |
| C: extension uses smaller shared Rust/media component | Can limit dependency/features while retaining local transmit ownership | Still same extension process limit; Rust is not a separate budget; duplicate runtime/endpoint risk | HARVEST feature-isolation idea; UNKNOWN feasibility |

No architecture selected based on elegance. Measure extension resident-memory
high-water mark on supported physical devices; kill/background the app, throttle
IPC, revoke sharing and verify all tasks/buffers stop. Apple's exact applicable
memory/resource policy was not freshly verified in this pass; do not turn a
commonly cited 50 MB figure into a tested Greenfield5 allowance. No file-backed
screen/audio spool is permitted. Preserve ADR-0005's native capture ownership
and current/future API compatibility plan rather than transplant LiveKit SDK.

## Licensing / attribution and security review

Documentation-only diff. All donors are conceptual references with exact pins
and path links above; **no source copied, no adaptation shipped, no dependencies
added**. MIT requires copyright/license retention for substantial copies;
Apache-2.0 requires applicable license/notices and change notices for modified
files. LiveKit Android NOTICE includes additional WebRTC/BSD, MIT and Apache
attributions; Swift Broadcast/NOTICE credits react-native-webrtc inspiration.
Future fragments require file-specific review, not GitHub badge approval.
RustDesk AGPL code must not enter the product without owner/legal approval.
Codec/transitive license review is outstanding before media adoption.
**Provenance anomaly:** iroh-live LICENSE-MIT and LICENSE-APACHE compare equal
and both contain Apache-2.0 text despite the README dual-license claim. Do not
rely on an MIT election without upstream clarification; no code was copied.

Security pass performed on this documentation diff and researched risks:

- Pins identify inspected source, not runtime dependency adoption. Do not execute
  instructions in donor files. Clones were read, not built.
- Existing core lockfile and fail-closed CI retained. CLI/runtime version matching
  and lockfiles remain mandatory for a candidate.
- No new handwritten/generated unsafe code, native artifacts, loading path,
  shell script, network configuration or CI permission change in this diff.
- Candidate JNI handle ownership, concurrent close and cancellation are unresolved
  **HIGH acceptance risks**; adoption is blocked pending proof. Swift queue
  growth is another acceptance risk, not an exploit introduced by this report.
- Preserve SHA-pinned actions/contents:read; reject donor floating-action copying.
- Do not copy donor initialization error swallowing or empty-artifact success.
- Capture/IPC future tests must constrain buffers, protect app-group socket access,
  clean up tasks and exclude captured content, tickets and credentials from logs.
- Connectivity relay configuration remains ADR-0005's dedicated fallback, not
  public/demo infrastructure selected silently.

No CRITICAL/HIGH security defect introduced by these docs was identified.
This is **not** a completed generated-code/JNI/dependency security audit of an
executable candidate. Foundation scanner/gate evidence belongs to the PR.

## Initial checkpoint unknowns and spec review (historical)

At the initial checkpoint, overall task conformance: **FAIL / incomplete**, not a completed harvest + A/B.
Baseline verification and durable plan are present; all eight pins and initial
pattern verdicts are recorded. Full donor inspection is PARTIAL. Android/iOS
parity, generated outputs, async/stream execution, packaging delta, artifact size,
reproducibility, candidate security review and final FFI decision are NOT MET.
No production change or ADR supersession is justified by this checkpoint.
TDD not run: no executable behavior added. No failed runtime experiments exist
to report; tool discovery failed to find native toolchains. `gh issue view`
failed on deprecated Projects classic GraphQL fields; REST issue APIs succeeded.

## Initial checkpoint next step (superseded by continuation below)

**Checkpoint recommendation: complete the isolated BoltFFI A/B evidence spike**, retaining
UniFFI. Pin CLI/runtime together (Crux comparison baseline 0.30.1, with the release
source resolved before use), delegate to the existing core, run native Kotlin and
Swift contract tests in CI, and include slow-consumer and concurrent-close tests.
No media/capture feature in that PR. Reconsider adoption only after bounded host
event delivery and safe close/cancellation are demonstrated (or upstream #664
and #778 fixes are pinned and validated) and both platform builds/tests pass.
This is a continuation trigger, **not** a completed DEFER BOLTFFI decision.

After that decision, the media candidate remains one fixed-rendition synthetic
encoded moving stream through Rust/Iroh/MoQ between Android and iOS, usable
receiver rendering, selected path/RTT and direct/forced connectivity-relay
observations for 60 seconds. This describes the later acceptance target, not a
second PR recommendation or authorization to implement capture now.

## Executed A/B and decision — PR #18 continuation

### Decision and precise trigger

**DEFER BOLTFFI** until a **released**, exactly pinned CLI/runtime pair:

1. generates Swift async cancellation code that compiles unchanged under this
   project's Swift 6 settings (no suppression, no generated-source patch);
2. resolves upstream **#664**'s documented concurrent-close ownership contract;
3. then passes the rerun native async/cancellation, slow-consumer/bounded-stream,
   close/cleanup and existing session-contract acceptance tests on both platforms.

The concrete blocker is **not lack of local tooling**. GitHub Linux/macOS runners
installed and executed BoltFFI, built real target libraries and generated stable
sources. Xcode then rejected the generated async runtime twice. Adoption would
require editing generated safety-sensitive code or weakening the Swift language
settings; neither is acceptable for this narrow comparison. This is a bounded
deferral, not a claim that UniFFI is universally better or BoltFFI can never fit.
No ADR supersedes ADR-0007 because no production mechanism changes.

The user permits unmet downstream criteria when execution establishes a concrete
DEFER reason. That exception applies here. **Full mobile parity is not claimed**:
Swift tests could not compile, Android runtime testing stopped at emulator boot,
and host cancellation/slow-stream/close safety remain unverified. This decision
must not be presented as every item in the original definition of done passing.

### Version, isolation and provenance

VERIFIED: fresh releases/latest API returned **v0.30.1**, published 2026-08-17;
tag resolves to **2e6320a6d92cb591d22b908477f3a47da7ebc9bc**. Same release as the
Crux checkpoint, avoiding a floating-main comparison. Manifest used
`boltffi = "=0.30.1"`; CLI installed with
`cargo install boltffi_cli --version '=0.30.1' --locked` and reported 0.30.1.
BoltFFI is MIT; no generated source or upstream fragments remain in the final
product tree. The previous iroh-live license anomaly remains unresolved.

Candidate was `spikes/boltffi`, a separate Rust crate compiling the existing
`core/src/session.rs` and `seam.rs` by path. No semantic copy, no UniFFI linked
into the candidate. The wrapper adapted this repository's own typed bridge;
spike-only fixtures added an async gate, eight-slot sequence subscription and
wire/mixed-width padding records. Candidate outputs were isolated from production.
An independent Android application used the existing pinned version catalog and
Gradle wrapper, minSdk 29 and compile/targetSdk 37. Apple CI copied the existing
Xcode project to a temporary output directory, replaced only its generated
bridge/native artifact in that copy, and kept Swift 6/iOS 16 settings intact.
Production UniFFI jobs continued alongside the candidate.

Real CI Cargo generated the candidate lockfile; its ordered annotation chunks
were retrieved, parsed as TOML and committed at fd97096. Subsequent candidate
Rust tests ran `--locked`. Candidate lock contained **82 package records**,
control lock **81**, including their respective roots; this is a lock graph
count, **not** runtime binary dependencies or a security score. Candidate also
used exact thiserror 2.0.20 (matching the control lock), coroutines 1.10.2,
AndroidX test runner 1.6.2 and test JUnit extension 1.2.1. CLI has its own
published locked build graph, not included in the 82 count.

### Executed attempts (not interchangeable heads)

| Head | Stack run | Observed candidate result |
|---|---|---|
| `7032f36c5084fb560426716f1f764c12b6502f65` | 35028391885 | Expected RED: exported Rust version returned empty string, assertion expected 0.1.0; dependency installed/compiled |
| `e4223defe2ac49e37ed1341a1dfbc4da588171f3` | 35028595606 | Rust 33 existing + 4 candidate tests PASS; generation matrix failed action resolution before execution |
| `069b322f4c032400b45ac2215e9eac9f8d070bcb` | 35028712207 | Corrected action SHA; Android setup action failed; Apple CLI attempt later superseded |
| `fd97096cad04b0868af1f31abf7d2fca501ca115` | 35028960389 | Apple CLI installed, pack failed on default target set; Android opaque setup failed again |
| `d2e7eec02014c8cf6964e8aa1c6bf10d18d2cf1e` | 35029393019 | Explicit SDK setup reported platform 37 unavailable; Apple native builds succeeded before run superseded during generation |
| `2958066a69b06f4170ed09f22a2d52807ad011a3` | 35029785166 | Both platforms packaged native artifacts and repeated source generation; Rust 33+6 PASS; host integration paths needed correction |
| `9732a04f31cc71e6db1ab899bd55a4cd8d16cbb6` | 35030494991 | Swift 6 generated cancellation capture errors; Android fixture lacked Compose runtime |
| `a2904045e56c784ac6b972c7cef8b7bc041e9d05` | 35031170818 | Same Swift errors reproduced; Android assemblies completed, emulator boot wait exited 124; native host tests NOT EXECUTED |

These runs are **experimental evidence**, not final-head CI. Superseded control
jobs were canceled by workflow concurrency; their incomplete results are not
control failures. Manual cancel API returned 403; automatic supersession worked.
Raw job logs redirected to inaccessible blob storage, so bounded success/failure
annotations and job-step statuses were used. No downloaded log was fabricated.

Fixes were confined and source-backed: correct stale action SHA to the control's
current pin; expose SDK command errors rather than opaque action failure;
install/configure supported arm64 Apple targets; use AGP Kotlin source sets;
consume actual ffi-only package layout; supply Compose runtime through the same
BOM as the shell. No test assertion was relaxed, SDK floor reduced, Swift warning
suppressed, or generator source patched. The earlier sdkmanager platform 37
error was **not a lasting blocker**: control-equivalent NDK provision followed
by unchanged Gradle compileSdk 37 reached assembly.

### Rust contract evidence

VERIFIED in run 35031170818, **BoltFFI Rust experiment**, job **104589829119**:
33 existing tests and these six candidate tests passed:

- `native_core_version_is_exact`: **0.1.0**;
- `sender_viewer_and_rejection_contract`: typed sender, numeric viewer journey,
  one-viewer rule, invalid codes and unchanged state on rejection;
- `mixed_layout_round_trip`: u8/u64/u16/String record;
- `native_stream_capacity_drop_and_stop`: 100 produced, 8 accepted/consumed in
  order, **92 dropped**, empty after drain, inactive after stop;
- `async_future_cancel_releases_guard`: Pending poll makes active count 1;
  dropping future returns count to 0; release returns 42; fallible path returns
  typed SessionEnded; final count 0;
- `padding_struct_and_vector`: u16/u32 values and vector round-trip.

These are **Rust tests**, not JNI/Swift tests. Rust struct round-trip does not
exercise generated foreign layout and does not resolve upstream #780. The exact
version test has a real observed RED→GREEN; the other fixtures were written
before implementation but their first recorded execution was GREEN.

### Android result

VERIFIED: run 35031170818, **BoltFFI generation (ubuntu-latest)**,
job **104589829243**, generated Kotlin/JNI and real arm64-v8a/x86_64 libraries.
`assembleDebug assembleRelease assembleDebugAndroidTest` ran with `set -e` and
completed before SDK image installation and AVD creation. Thus debug, minified
release and test-APK assembly succeeded; this is not minified runtime proof.
Candidate Gradle dependencies and source contain **no JNA** or jna.library.path.
Generated API has enums, BridgeError subclasses, AutoCloseable class handles,
`fromCodes`, suspend waitValue, Flow and batch subscription methods.

The subsequent **180-second emulator boot wait exited 124**. The following
APK installation, `am instrument`, native contract and isolated close-stress
invocations were not reached. The compact log did not capture emulator startup
logs, so the reason for failure to boot is **UNKNOWN**; do not assert missing KVM
or missing hardware as a proved cause. No `BOLT_PROOF` runtime marker exists.

Android native `coreVersion()`, host contract parity, host struct layout,
coroutine cancellation, Flow slow-consumer behavior and 500-iteration concurrent
close stress are therefore **NOT EXECUTED**, not failed BoltFFI assertions.
No Kotlin behavioral implementation was used to create CI success.

### Apple result and reproducible blocker

VERIFIED: real arm64 iOS device/simulator static libraries, XCFramework and
Swift package generated; copied existing Xcode project consumed the candidate.
Runs **35030494991** (job **104587724335**) and **35031170818** (job
**104589829219**) both failed in `xcodebuild build` while compiling generated
`Greenfield5BoltSpikeBoltFFI.swift` under **SWIFT_VERSION=6.0**:

```text
702:13: error: capture of 'cancel' with non-sendable type
'(RustFutureHandle?) -> Void' ... in a '@Sendable' closure
703:13: error: capture of 'free' with non-sendable type
'(RustFutureHandle?) -> Void' ... in a '@Sendable' closure
```

Primary source at the selected release:
[async.swift](https://github.com/boltffi/boltffi/blob/2e6320a6d92cb591d22b908477f3a47da7ebc9bc/boltffi_backend/templates/target/swift/async.swift)
declares `cancel` and `free` as `@escaping` function parameters, not Sendable,
and captures them in `withTaskCancellationHandler`'s onCancel closure.
This is more specific than open **#778** (exported class Sendable): the observed
failure is in the **generated async runtime**, before the cross-task class test.
Do not claim #778 itself was reproduced or that adding unchecked Sendable to an
app wrapper fixes these generated captures.

Swift native version/journeys, errors, async success/cancel, stream delivery and
padding tests were not executed because the app build failed. No placeholder
archive or Swift fallback was accepted as native proof.

### Source stability and native sizes

Within each successful generation attempt, pack ran twice from identical input.
Android **2** and Apple **6** source/header/modulemap/package files compared
identically by SHA-256. Selected hashes also repeated across 9732a04 and a290404
(the Rust exported input was unchanged). No binary reproducibility claim.

| Generated artifact | SHA-256 |
|---|---|
| Kotlin Greenfield5BoltSpike.kt | `e827c2987b597482983e2a9cdd41ebd20468b1d3e9fa1c7b18ea1203341f3b15` |
| Swift Greenfield5BoltSpikeBoltFFI.swift | `eff1b44ee0cf1333ac0e195c77ca5ee5c5261eed46ced90ad66b37f53317f938` |
| C header (both platforms) | `9f867b017fc115f13e73decb40021b151e619140a3551f7aeb3d4f4de6ae337c` |
| Apple modulemap (both slices) | `ab07f92803cfafe501d2fa0c121ef461c91a12f8e10f569ff16f2070fe80892a` |
| Package.swift | `00636706682d6b09797545ebd8207e0239bbb9a4958f667bc47deedfc0d8c3e0` |

Sizes published in run 35029785166 and subsequent source inventories:

| Candidate release artifact | Bytes |
|---|---:|
| Android arm64-v8a .so | 5,701,768 |
| Android x86_64 .so | 5,439,640 |
| Apple arm64 device .a | 19,914,584 |
| Apple arm64 simulator .a | 19,907,032 |

No comparable control artifact measurement was collected on the same build
configuration. **No size delta is claimed.** A static archive is not comparable
to an Android shared library; candidate includes experimental probe APIs too.

### Completed evidence comparison (supersedes checkpoint table)

“NOT EXECUTED” below is an observed coverage boundary, not a fabricated result.

| Dimension | UniFFI control | BoltFFI candidate |
|---|---|---|
| Android bridge mechanism | Host JNA proof + packaged Android Rust libraries | Generated JNI + two real Android ABIs; emulator invocation not reached |
| JNA dependency | Runtime AAR + JVM test dependency | **Eliminated** in isolated candidate |
| Android generation steps | cargo-ndk plus UniFFI bindgen/staging | `boltffi pack android` generates/stages Kotlin/JNI/artifacts |
| Android custom glue | JNA paths, bindgen script, package/error-name conventions | JNA paths/proof plumbing eliminated; source-set/ABI configuration retained; emulator proof setup added |
| Android debug | Historical control build proven; final-head results in PR | Assembly succeeded before emulator boot timeout |
| Android minified release | Historical control build proven; final-head results in PR | Assembly succeeded; JNI-only keep rules remain; no release runtime proof |
| Apple generation steps | Rust targets + bindgen + custom XCFramework script | `boltffi pack apple`, explicit device/simulator architectures |
| Apple custom glue | Header staging, builtin module workaround, lipo/script, placeholder cleanup | Generator replaces header/modulemap/XCFramework glue; no custom lipo for single simulator slice; package/source/project wiring still needed |
| Apple build | Retained native control | **FAIL twice**: generated async cancel/free captures under Swift 6 |
| Apple tests | Control seven bridge tests; exact-version assertion strengthened after experiment | Not executed: app build fails |
| Generated Kotlin API | Typed wrapper over JNA | Typed errors/enums/classes, suspend, Flow and batch; compilation reached assembly |
| Generated Swift API | Typed wrapper, existing synchronous contract | Generated typed API; async runtime fails required compiler mode |
| Typed errors | Existing mapped session errors | Rust mappings PASS; foreign delivery not executed |
| Async behavior | Current production bridge synchronous; no comparable async spike | Rust future success/failure/drop PASS; Kotlin unexecuted; Swift compile blocker |
| Cancellation | Not exercised across current bridge | Rust guard active 1→0 PASS; host cleanup not proved |
| Slow stream consumer | No stream seam in current control | Rust capacity/drop test PASS; host slow consumer not executed |
| Host buffering | Not applicable to synchronous control | Swift default template unbounded; Kotlin Flow suspending send; runtime backlog unmeasured |
| Concurrent close | Not stressed in this experiment | Fixture written, not executed; #664 remains open and documented unsafe pattern |
| Struct round-trip | No comparable layout probe | Rust mixed-width/vector PASS; foreign padding not exercised, #780 unresolved |
| Generated source stability | Not regenerated twice in this comparison | 2 Android / 6 Apple files identical within repeat generation |
| Native artifact sizes | Same-config measurements unavailable | Four artifact sizes above; no claimed improvement/delta |
| Dependency count/change | 81 Cargo lock records, JNA dependencies | 82 Cargo lock records + separate locked CLI build; no JNA |
| Known upstream blockers | Existing workarounds retained; no new control defect found | Observed Swift 6 async runtime failure; #664/#778/#771/#780/#871/#872 still open on refresh |
| Migration complexity | No migration required | Package tooling simplifies builds, but compiler/safety workaround burden unacceptable at this pin |

Specific Android glue: `System.loadLibrary` is **replaced by generated native
loading**, not eliminated as a mechanism. UniFFI Error→Exception naming and
package workaround disappear from the candidate; Kotlin package configuration
still exists. Manual copying of generated Kotlin is unnecessary, but AGP Kotlin
source-directory integration remains. Host-JNA proof is replaced by instrumented
JNI proof infrastructure, not “no testing glue.”

Specific Apple glue: generator creates headers/modulemaps/XCFramework/package;
no handwritten builtin-module stripping was used. The candidate used only the
same arm64 simulator target as current control, so it does **not** demonstrate
multi-architecture lipo support. Existing placeholder deletion was still needed
in the temporary comparison copy, not proof that production migration needs
zero cleanup. Synchronized Xcode group/path integration remained. Crux-like
packaging improvement is real but does not compensate for unbuildable async
Swift code at the required language setting.

### Ownership, streams and security decision

Re-fetched #664, #778, #771, #780, #871 and #872: all OPEN. Passing a stress test
would not disprove #664; here it did not execute at all. Current generated
Kotlin wrappers check a closed flag separately from native invocation. A safe
Greenfield5 invariant would require one owner to serialize **all** calls,
cancellation and disposal, draining in-flight async/stream work before release.
No such enforced host lifecycle was proved by this candidate. It must not be
assumed merely because the Rust session uses a Mutex.

The event fixture used one producer and one consumer for the upstream SPSC
subscription. It is not a general concurrent event bus. Rust drop accounting
is measured; Swift `.unbounded` host buffering remains source-verified, not a
measured memory leak. Batch mode keeps explicit pull control in source but host
boundedness/cleanup is unverified. No raw media or network operations were added.

#872 is **NOT APPLICABLE TO CURRENT CANDIDATE** for user-defined foreign callback
traits: none were exported. Generated internal async/stream callbacks still form
part of the native safety surface. #871's message-field shape was not used;
foreign error delivery was not proved. No finding is inferred away from a green
Rust test.

Security review: exact runtime/CLI pins, real lockfile, fixed paths/argument
arrays, annotation escaping, read-only CI permissions, pinned actions and finite
timeouts reviewed. Candidate added no handwritten unsafe. Generated FFI/JNI and
upstream subscription code remain an unsafe trust boundary. The observed Swift
compiler rejection and unresolved close contract prevent adoption; no unsafe
patch or warning suppression used. Host native loading, R8 runtime, callback
cleanup and concurrent-close execution remain incomplete audit areas, explicitly
not signed off. No secrets, captured content, relay config or persistence added.

### Final tree and spec disposition

Disposable `spikes/boltffi` implementation, lockfile, generated outputs and
candidate CI jobs were removed after the decision. Reproduction source remains
in Git history at the experiment SHAs above; results remain in this report and
GitHub check annotations. The Stack workflow is restored to the merged control.
A useful control-test hardening remains: Swift `coreVersionIsExact` asserts
**0.1.0**, replacing nonempty-only acceptance; it is not a bridge migration.

| Requirement group | Disposition |
|---|---|
| Bootstrap/ref refresh/reuse research/plan | MET; same PR and branch, no donor survey repeated |
| Exact pins, real lock, isolated shared-semantics candidate | MET during experiment; removed per DEFER final-tree policy |
| Rust contract, future-drop, native bounded ring, padding fixture | MET at Rust level (39 tests) |
| Android generation/ABI/debug/minified/test APK build | MET; not runtime proof |
| Android JNI call/contracts/async/Flow/close | NOT EXECUTED: emulator boot timed out |
| Apple package/generation/current project integration | MET through attempted app build |
| Apple build/native contract/async/events | Build FAIL; tests NOT EXECUTED due concrete generated Swift 6 blocker |
| Source stability/packaging analysis | MET for candidate; control repeat generation/size delta not measured |
| Candidate security | Review performed; adoption safety gate NOT MET |
| Final decision | DEFER with precise released-fix + rerun trigger; no adoption claim |
| Cleanup/memory/final CI | Cleanup and memory in final tree; exact-head CI recorded in PR body |

### Exactly one recommended next PR

**Synthetic Android↔iOS Iroh/MoQ moving-media slice using retained UniFFI.**
Keep it to one encoded moving test pattern, receiver rendering and selected
path/RTT diagnostics, with direct and forced **Iroh connectivity relay** cases
and a 60-second sustained run. No real capture, pairing, audio UX, browser relay
or rooms. Physical-device results remain **UNVERIFIED — PHYSICAL DEVICE REQUIRED**
until actually observed. The BoltFFI deferred-fix rerun is a trigger, not a
second immediate PR recommendation.

## BoltFFI candidate retest - executed results (2026-09-16, PR #19)

Immutable upstream refs re-checked this session: boltffi v0.30.1 =
`2e6320a6d92cb591d22b908477f3a47da7ebc9bc` (newest tag); `origin/main` =
`932107ba`, and `git diff --name-only v0.30.1 origin/main` over
`boltffi_backend/{templates,src}/target/{swift,kotlin}` and
`boltffi_core/src/runtime` is **empty**, so the pin still covers every surface
patched here. Open upstream: PR #732 head `1b4b0d79e658`, 31 files, newest review
`4b25c777` **CHANGES_REQUESTED** (2026-08-01); issues #664 and #778 open; adjacent
#770/#889/#893. Fix `b01038ef35…` present in both the tag and main.

Executed on this candidate (run `35111780326`, head `97a4924`):

| Acceptance area | Result | Evidence |
| --- | --- | --- |
| Swift 6 RED (unpatched) | FAILS as required | `SWIFT_TYPECHECK_unpatched_EXIT=1`, `:702:13`/`:703:13` non-Sendable capture in `@Sendable` closure |
| Swift 6 GREEN (patched, same probe) | PASSES | `SWIFT_TYPECHECK_patched_EXIT=0` |
| Lifetime RED (pre-0004 runtime) | 2 violations, 2 named tests | `VIOLATION(free inside a native call; free inside a native callback)` |
| Lifetime GREEN (0004 v3) | clean, 6/6 probes | `free-once=true`, `frees=1` per probe, `violations=0` |
| Apple native contract/async/streams/layout/errors | PASSES | `Test run with 19 tests passed`; `BOLT_PROOF`, `BOLT_BOUNDED batch 100/100/0`, `BOLT_CANCEL 32/32` |
| Apple ownership/cancellation | PASSES | `BOLT_LIFETIME repeatedCancellation=clean`, `preCancelled=clean`, `wakeDrivenRepoll=clean polls=2 displacements=1` |
| Stream backpressure | bounded path executed, unbounded path recorded | `BOLT_BOUNDED policy=batch produced=100 consumed=100 nativeDropped=0 hostBuffered=0` vs `BOLT_BACKLOG policy=unbounded ... hostBuffered=80` |
| Android Kotlin → generated → JNI → Rust | EXECUTES | `OK (1 test)`, `BOLT_PROOF ... async=PASS cancellation=PASS repeated_cancel=100 raced_cancel=100`, `BOLT_STREAM produced=200 consumed=26 nativeDropped=98 unconsumed=76` |
| Android close-race suite | NOT PASSING YET | test treated the required post-close rejection as a crash (`ConcurrentCloseTest.kt:97`); corrected, rerun pending |
| #778-shaped async (class-returning) Sendable | characterization | non-gating probe; result published by the diagnostics step |
| Physical device | **UNVERIFIED — PHYSICAL DEVICE REQUIRED** | no physical-device run in this environment |

The candidate's ownership invariant, now stated in one line and enforced by patch
0004 v3: `rust_future_free(handle)` runs exactly once, never inside a native call or
a runtime-delivered callback, and always before the caller is resumed. The
previous behavior is what the pre-patch run recorded.

## Correction — exact-head PR #19 result (`b1adb9d33025424aa463bfd66061959baab71fc5`, 2026-09-16)

The preceding PR #19 entry described an earlier head and is superseded for
acceptance purposes by this exact-head result. Run `35121808215` belongs to
`b1adb9d33025424aa463bfd66061959baab71fc5`: Rust job `104881538499` passed;
Apple job `104881538243` passed with 19 real-Rust simulator tests; Android job
`104881538579` failed in minified instrumentation with
`ClassNotFoundException: kotlin.jvm.internal.Lambda` after the debug path passed.
The control workflow run `35121808672` passed (`104881172108`,
`104881171652`). The PR therefore remains **DEFER**, not ADOPT: minified native
execution failed, host buffering is unbounded (`100 produced / 20 consumed /
80 hostBuffered`), ownership coverage is not exhaustive, and no material
advantage over UniFFI was measured. Candidate source/workflow were removed after
this finite retest; no generated output was retained or hand-edited. Physical
device evidence remains **UNVERIFIED — PHYSICAL DEVICE REQUIRED**.
