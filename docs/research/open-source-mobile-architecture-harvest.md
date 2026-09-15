# Open-source mobile architecture harvest

Inspection date: **2026-09-15 (UTC)**. Status: **BLOCKED / partial research
checkpoint**, not a completed A/B or migration decision. UniFFI remains the
control under ADR-0007. No production files or dependencies changed.

## Scope

Should the newly merged UniFFI bridge be replaced before async transport/media
increases the FFI surface? Which donor packaging, observability and capture
lifecycle patterns reduce upcoming implementation risk? This report records a
first source pass across all eight required donors. Phase B has **not been
implemented or executed**; Phase C cannot be signed off. Missing runtime proof
is neither parity nor disproven parity. See the [plan](../plans/mobile-architecture-harvest.md).

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

## UniFFI baseline findings and A/B comparison

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

**Android, iOS, async and stream acceptance: NOT MET.** No candidate was built,
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

## Unknowns and spec review

Overall task conformance: **FAIL / incomplete**, not a completed harvest + A/B.
Baseline verification and durable plan are present; all eight pins and initial
pattern verdicts are recorded. Full donor inspection is PARTIAL. Android/iOS
parity, generated outputs, async/stream execution, packaging delta, artifact size,
reproducibility, candidate security review and final FFI decision are NOT MET.
No production change or ADR supersession is justified by this checkpoint.
TDD not run: no executable behavior added. No failed runtime experiments exist
to report; tool discovery failed to find native toolchains. `gh issue view`
failed on deprecated Projects classic GraphQL fields; REST issue APIs succeeded.

## Recommended next step

**Exactly one next PR: complete the isolated BoltFFI A/B evidence spike**, retaining
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
