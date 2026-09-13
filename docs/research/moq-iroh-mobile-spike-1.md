# Architecture Spike 1 — Android↔iOS MoQ over Iroh with synthetic video

**Issue:** [#11](https://github.com/anthracite-labs/Greenfield5/issues/11)
**Date:** 2026-09-13
**Branch:** `arena/01a09c70-greenfield5` (session branch; the issue names
`arena/issue-11-moq-iroh-mobile-spike`, which this session cannot create — see
§1.4)
**Status:** research complete, **no execution evidence obtainable in this
environment**
**Related:** [ADR-0005](../decisions/0005-rust-native-moq-iroh-architecture.md) ·
[open-source-landscape.md](./open-source-landscape.md) ·
[ARENA.md](../ARENA.md)

---

## 0. Verdict, in one page

**The question:** can a Kotlin/Android endpoint and a Swift/iOS endpoint sharing
one Rust core exchange live synthetic encoded video over MoQ + Iroh, using a
direct path when available and Iroh relay fallback when it is not?

**Answer this session:** **NOT ESTABLISHED — every execution criterion (1–9) is
UNVERIFIED.** Nothing from the required evidence list could be built, run, or
measured here, because this sandbox has no Rust toolchain, no package-registry
egress, no JDK/Android SDK/NDK, no macOS/Xcode, and no attached devices. §1
records the exact commands and results behind that statement, including the
attempts to import a toolchain.

**Recommendation requested by criterion 10:** **PASS WITH CONDITIONS
(provisional)** — i.e. continue with MoQ-over-Iroh on mobile, conditional on
Spike 1B actually executing. That recommendation rests on static evidence only
and is labelled INFERRED throughout. It is a *recommendation to continue*, not a
validated pass; presenting it as a validated pass would violate the repository's
honesty rules and the issue's own criterion 8.

**The conditions, stated up front (all four must hold before this becomes a
real PASS):**

1. Spike 1A compiles the spike core **against released crates with no
   `[patch.crates-io]` block** (§11) — if it does not, the patch question
   reopens and the recommendation narrows.
2. The iOS endpoint uses the **software decode path** (`openh264` +
   `Surface::into_rgba`), because every Apple GPU path in the pinned MoQ crates
   is `target_os = "macos"` (§6.1). Hardware iOS codecs are a separate, later
   decision.
3. LAN test rows dial **explicit `EndpointAddr` addresses**, not mDNS, because
   tickets carry no addresses and Android needs a multicast lock (§5.4).
4. Spike 1B runs on **two physical devices and a Mac** — the emulator/simulator
   rows are useful intermediate signals but are explicitly *not* the evidence
   Issue #11 asks for.

**The one-line reason the static evidence is favourable:** the harvested
upstream path already contains every load-bearing component — a released MoQ
Iroh transport (`moq-native` 0.19.17 `iroh` feature), a working Android
JNI/media/transport bridge, a synthetic moving-pattern video source, and an
upstream direct-vs-relay path readout — and no contradicting evidence was found
at the pinned commits.

### Evidence grade per required item

| # | Required evidence | Grade | Why |
| :-- | :-- | :-- | :-- |
| 1 | Android build/FFI proof | **UNVERIFIED** | No Rust toolchain, no JDK, no Android SDK/NDK in this sandbox; `dl.google.com` blocked. Build recipe is written and grounded in upstream files (§5) but never executed. |
| 2 | iOS build/FFI proof | **UNVERIFIED** | Requires macOS + Xcode; sandbox is Linux. Apple SDKs are not redistributable, so no honest substitute exists (§6). |
| 3 | Android↔iOS MoQ-over-Iroh session | **UNVERIFIED** | Needs 1 and 2 plus two devices. |
| 4 | Visible moving synthetic video on a physical receiving device | **UNVERIFIED** | No device attached. The synthetic source that makes this cheap is upstream (`moq_media::test_source::video`) — see §3.4. |
| 5 | Verified direct Iroh path | **UNVERIFIED** | Path readout API is verified in source (§8); no live connection was made. |
| 6 | Verified relay fallback | **UNVERIFIED** | Forcing switch verified in source (§9); not executed. |
| 7 | ≥ 60 s sustained delivery | **UNVERIFIED** | Not executed. |
| 8 | Session-establishment time | **UNVERIFIED** | Not executed. |
| 9 | First-frame time | **UNVERIFIED** | Not executed. |
| 10 | Observed bitrate and reconnect behaviour | **UNVERIFIED** | Not executed. |

The required report content below is therefore split into two kinds of material,
always labelled: **VERIFIED** items are source facts I read at a pinned commit
in this session (with the file and symbol named), and **UNVERIFIED** items are
planned procedures that have never run.

---

## 1. What could and could not be executed here

### 1.1 Environment preflight — VERIFIED

```console
$ cat /etc/os-release            # Debian GNU/Linux 12 (bookworm)
$ id                             # uid=1001(user) gid=1001 groups=1001(user),27(sudo)
$ nproc; free -h                 # 2 vCPU; 3.8 GiB RAM; 20 GB free disk
$ command -v rustc cargo rustup java javac gradle xcodebuild swift adb cmake ninja clang
# (no output: none of these exist)
$ command -v python3 node npm gcc make
/usr/bin/python3  /usr/local/bin/node  /usr/local/bin/npm  /usr/bin/gcc  /usr/bin/make
$ sudo -n true                   # exit 0 — passwordless sudo exists, but see 1.2
```

`sudo` is available, which would normally be enough to `apt-get install` a
toolchain. It is not enough here, because the package mirrors are unreachable
(§1.2).

### 1.2 Import attempts — VERIFIED failures

The instruction to "import the relevant stuff and try again" was attempted
seriously, in four directions. All four failed at the network layer:

**(a) Direct toolchain bootstrap.** Blocked host list (HTTP status, `000` =
connection/TLS failure):

| Host | Result | What it would have provided |
| :-- | :-- | :-- |
| `static.rust-lang.org` | `000` | rustup toolchain distributions |
| `sh.rustup.rs` | `000` | rustup installer |
| `crates.io`, `index.crates.io`, `static.crates.io` | `000` | the dependency registry |
| `dl.google.com` | `000` | Android SDK/NDK/JDK distributions |
| `repo1.maven.org`, `plugins.gradle.org`, `services.gradle.org` | `000` | Gradle/AGP/AndroidX artifacts and the Gradle wrapper distribution |
| `deb.debian.org`, `security.debian.org`, `archive.ubuntu.com` | `000` | `apt-get install rustc openjdk-17-jdk` |
| `rsproxy.cn`, `mirrors.tuna.tsinghua.edu.cn`, `mirrors.ustc.edu.cn`, `mirrors.aliyun.com` | `000` | every known Rust dist mirror |
| `raw.githubusercontent.com`, `objects.githubusercontent.com`, `ghcr.io` | `000` | alternate artifact paths |

Reachable hosts, for contrast: `github.com` (200), `api.github.com` (200),
`pypi.org` (200), `files.pythonhosted.org` (200), `registry.npmjs.org` (200).

**(b) PyPI route.** PyPI is reachable, so I inspected the only two candidate
packages:

- `rustup` 1.29.0.1 ships `rustup-1.29.0.1-py3-none-manylinux_2_17_x86_64.whl`
  (7.93 MB). That is the **rustup-init binary only**; installing it produces a
  rustup that must still download toolchains from `static.rust-lang.org`, which
  is blocked. Dead end.
- `cargo` 0.3 (11 KB) is an unrelated Python dependency-injection library — a
  name collision, not the Rust build tool. Dead end.

**(c) npm route.** `registry.npmjs.org` was searched for toolchain wrappers
(`/-/v1/search?text=rust toolchain rustc`). Results are build *helpers*
(`@napi-rs/cross-toolchain`, `setuptools-rust` analogues) that all require an
existing `rustc`. Dead end.

**(d) Source-only route.** Even if a compiler could be obtained out of band,
the stack is unbuildable here: cargo resolves `tokio`, `rustls`, `noq`,
`web-transport-*` and hundreds more from `crates.io`, and **no `vendor/`
directory or lockfile-complete offline cache exists in any of the pinned
repositories** (checked: `ls -d vendor` in `iroh-live`, `iroh-ffi`, `moq`,
`iroh` and `Frando/moq` — absent in all five). A GitHub-tarball
workaround would require hundreds of hand-written `[patch]` entries and matching
every transitive version by hand; that is not a spike, it is a fork of the
ecosystem.

**Conclusion (VERIFIED):** no path to a Rust build exists in this sandbox, and
no path to an Android build (missing SDK/NDK/JDK) or an iOS build (missing
macOS/Xcode) exists at all.

### 1.3 What that means for the acceptance criteria

Nothing in criteria 1–9 can be produced here, by construction. The mitigation
that keeps the spike moving is §13 (build in CI), because GitHub Actions runners
have the network access this sandbox lacks.

### 1.4 One process deviation, stated plainly

Issue #11 asks the durable work to land on
`arena/issue-11-moq-iroh-mobile-spike`. This session is pinned to
`arena/01a09c70-greenfield5` and is not permitted to create or push any other
branch. This branch is therefore a continuation of the same repository history
whose default branch already carries the merged ADR-0005 work, and the PR
raised from it references Issue #11. Flagged for the reviewer rather than
worked around.

---

## 2. Exact upstream pins — VERIFIED

Every repository below was fetched **depth-1 at the exact commit named** from
`github.com` in this session; the `git rev-parse HEAD` after checkout matched the
expected SHA in all cases.

| Repository | Ref | Commit | Role in the spike |
| :-- | :-- | :-- | :-- |
| `n0-computer/iroh-live` | `main` | `de7f43bfc466988f08b7e63acdd7fb295a9f9fd2` | Harvest baseline: Android JNI bridge, `iroh-moq`, `moq-media`, synthetic sources |
| `n0-computer/iroh-ffi` | `main` | `3103bf5295be6d50c5272ff7a426e9b539f3f587` | Swift/Kotlin packaging reference; relay presets; **no MoQ surface** |
| `moq-dev/moq` | `main` | `df79bf0ee27b8796c788b0df8af27dcb44c5f725` | Upstream MoQ, incl. `rs/moq-native/src/iroh.rs` |
| `n0-computer/iroh` | `main` | `ec04e273f9499bb00b074605d50e25f0faecb455` | Path API and transport controls |
| `Frando/moq` | `iroh-live-3` | `253441fdb49b0d5606d4bdee54e4571478269a08` | The patch baseline `iroh-live` actually builds against |
| `moq-dev/moq` | tag `moq-native-v0.19.17` | `535d6e434be08edbb143bf93708ac5296e077ebb` | The released crate `iroh-live` declares |
| `moq-dev/moq` | tag `moq-net-v0.2.20` | `cf52dad164896de618df4c5d073e528888f0c8f1` | The released crate `iroh-live` declares |
| `moq-dev/moq` | tag `moq-video-v0.0.23` | `535d6e434be08edbb143bf93708ac5296e077ebb` | Same release commit as `moq-native` (monorepo tags) |
| `n0-computer/iroh-ffi` | release `v1.1.0` (2026-07-16) | assets: `IrohLib.xcframework.zip`, `libiroh-darwin-aarch64.tar.gz`, … | Prebuilt Apple binary; `Package.swift` pins `releaseTag = "v1.1.0"`, checksum `ad46dadf…`, platforms iOS 17.5 / macOS 14.5 |

### 2.1 The dependency closure `iroh-live` declares — VERIFIED

Read from `iroh-live/Cargo.toml` at `de7f43b`:

```
iroh = 1.2.0        (features: metrics, portmapper, fast-apple-datapath, tls-aws-lc-rs)
iroh-gossip = 0.101.0     hang = 0.20.11        moq-net = 0.2.20
moq-mux = 0.9.14          moq-audio = 0.0.23    moq-video = 0.0.23
moq-native = 0.19.17      moq-relay = 0.14.16   web-transport-iroh = 0.7.0
```

plus a `[patch.crates-io]` block repointing `hang`, `moq-audio`, `moq-mux`,
`moq-native`, `moq-net`, `moq-relay` and `moq-video` at
`github.com/Frando/moq` branch `iroh-live-3`. `Cargo.lock` pins that branch to
`253441fdb49b0d5606d4bdee54e4571478269a08` (ten `source = "git+https://github.com/
Frando/moq?branch=iroh-live-3#253441f…"` entries; `moq-native` at lock line
5587–5589). **Do not resolve this branch by head — the lockfile revision and the
branch head happen to agree today (`253441f`), but nothing enforces that.**

### 2.2 What is actually *in* the patch — VERIFIED

`git log --oneline moq-dev/main..Frando/iroh-live-3` is exactly **seven**
commits, and their file impact is:

| Commits | Crates touched | Subject |
| :-- | :-- | :-- |
| 6 commits (`cf0b413`, `62f4638`, `b7362ad`, `0413202`, `4f23740`, `2a00b0e`) | `rs/moq-mux` only | fMP4 export fragment ordering/rolling |
| 1 commit (`253441f`) | `rs/moq-video` only | "convert a surface by reference, and to BGRA" |

No commit in the branch touches `rs/moq-native` or `rs/moq-net`. That is the
fact §11 turns into a decision.

---

## 3. Harvest map — reuse first, invent last

Everything in this section is **VERIFIED** by reading the pinned sources. This
is the part of the spike that did succeed: the harvest targets are identified
precisely enough that a build-capable environment can execute them.

### 3.1 Android: the proven media/transport/JNI path (`iroh-live/demos/android`)

| Upstream artifact | Size / shape | Take it for Spike 1 |
| :-- | :-- | :-- |
| `demos/android/rust/` (`iroh-live-android`, `crate-type = ["cdylib"]`) | 1 259-line `src/lib.rs`, 18 `Java_com_n0_irohlive_demo_IrohBridge_*` entry points plus `JNI_OnLoad` | **Yes, verbatim shape.** `JNI_OnLoad` → shared Tokio runtime → opaque `jlong` session handles; `borrow_handle`/`take_handle` handle discipline |
| `demos/android/app/.../IrohBridge.kt` | Kotlin `object` with `System.loadLibrary("iroh_live_android")` + 18 `external fun`s | **Yes, renamed.** The Kotlin↔Rust ABI convention is the reusable part |
| `demos/android/Makefile.toml` | cargo-make pipeline: `cargo ndk -t arm64-v8a -P 26 --link-libcxx-shared -o app/src/main/jniLibs build -p iroh-live-android --release`, then strip, then `./gradlew assembleDebug` | **Yes.** NDK auto-detect from `$ANDROID_HOME/ndk/*`, `llvm-strip` to bring ~500 MB down to ~21 MB |
| `moq-media-android` (`camera`, `renderer`, `handle`) | `CameraSink::push_rgba`/`push`, `AndroidRenderer` with EGL/AHardwareBuffer | **Renderer: yes.** **Camera: delete.** Spike 1 needs no Camera2. The draw path is `Surface::HardwareBuffer` → `render_hardware_buffer` (EGL external texture) or `Surface::I420` → `I420::{y,u,v}` → `render_nv12`; **no CPU colour conversion anywhere**, so it does not depend on the patched `moq-video` conversion API (§11) |
| `demos/android/rust/Cargo.toml` | `jni 0.21`, `ndk 0.9 (api-level-26)`, `ndk-context`, `tokio 1.53`, `moq-video` with `mediacodec` | **Yes**, minus `moq-media/aec` (microphone echo cancellation) |
| Gradle setup: wrapper **8.11.1**, AGP **8.7.3**, Kotlin **2.1.0**, Compose BOM 2024.12.01, `compileSdk 35`, `minSdk 26`, `targetSdk 34`, Java 17, `abiFilters = arm64-v8a, x86_64` | — | **Yes**, with camera/zxing dependencies removed |
| `AndroidManifest.xml` | `INTERNET`, `CAMERA`, `RECORD_AUDIO` | Keep `INTERNET` only — no capture permissions are needed for this spike |

Upstream's own note about that crate is worth carrying over: `jni` is held at
0.21 on purpose, because 0.22 splits `JNIEnv` into an owned `Env` and an
`EnvUnowned` and would require rewriting every entry point. `moq-native` 0.19.17
uses `jni 0.22` on Android for its platform TLS verifier — so **two jni majors
coexist in one build**; that compiled for upstream, but it is a build risk worth
knowing about before it turns into a confusing link error.

### 3.2 Transport: two candidate shapes

| Option | Where it lives | Released? | Verdict for Spike 1 |
| :-- | :-- | :-- | :-- |
| `moq-native` feature `iroh` → `rs/moq-native/src/iroh.rs` | `moq-dev/moq` | **Yes** (`iroh` feature = `dep:web-transport-iroh`, `dep:web-transport-proto`, `dep:noq-proto`) | Underlying transport; dial by endpoint id; WebTransport-over-H3 *and* raw QUIC negotiated by ALPN |
| `iroh-moq` (`Moq`, `MoqSession`, `MoqProtocolHandler`) | `iroh-live` | No (workspace-local) | **Harvest (copy) it.** 820 lines (`iroh-moq/src/lib.rs`); owns session lifecycle with a dedupe actor, `Moq::publish`/`connect`/`incoming_sessions`, `MoqSession::{subscribe, announced, remote_id, conn, closed}`, `alpns()` spanning every `moq_net::ALPNS` + H3. Its dependencies are `iroh`, `moq-net`, `web-transport-iroh`, `web-transport-proto`, `n0-error`, `n0-future`, `tokio`, `url` — **no `moq-media` and no `moq-video`**, so copying it does not drag the media crates in |

Copying the second and depending on the first gives the spike a publisher, a
subscriber, announced-broadcast discovery and multi-version ALPN negotiation
without taking the patch block (§11). Whether `iroh-moq` compiles unchanged
against **released** `moq-net` 0.2.20 is INFERRED-yes from the empty diff in
§11 and must be confirmed by the first `cargo check` in Spike 1A.

### 3.3 Session, ticket and identity

- `iroh_live::Live::from_env()` binds an endpoint with `presets::N0` (pkarr +
  DNS + mDNS via `iroh-mdns-peer-lookup`), optional router, optional gossip.
  VERIFIED.
- `LiveTicket` is `iroh-live:<base64url(endpoint id)>/<broadcast name>` and
  deliberately carries **no socket addresses** — resolution is pkarr/DNS
  (needs internet) or mDNS (needs a multicast socket). VERIFIED.
- Consequence for a LAN-only physical test: **use an explicit address list**
  (`EndpointAddr::from_parts(id, [ip:port])`) rather than relying on mDNS.
  Android needs a `WifiManager.MulticastLock` for mDNS and the upstream demo
  does not request one, and pkarr needs Internet. This is a trap that would
  otherwise be discovered by two devices that simply never find each other.
  (§5.4.)

### 3.4 Synthetic video — already in the tree

`moq_media::test_source::video(size, framerate)` returns a `VideoSource::Frames`
stream that paints a **diagonal gradient advancing every frame** (upstream's
comment: *"a static image compresses to almost nothing after the first keyframe,
so a test watching for bytes on the wire would pass on a pipeline that had
stalled"*) and is installed with a single call:

```rust
let broadcast = live.publish("spike")?;
broadcast.video().set(moq_media::test_source::video(Size::new(640, 360), 30))?;
```

That is the requested "smallest synthetic source": no camera, no MediaProjection,
no ReplayKit, and it satisfies "continuously moving" by construction.

---

## 4. Prototype structure for the executable run (Spike 1B)

### 4.1 Where the code lives — guard compliance

`config/project.env` is `PROJECT_PHASE=architecture` / `ALLOW_APP_STACK=0`, and
`scripts/verify.sh`'s `check_no_app_stack` rejects a root-level `Cargo.toml`,
`Makefile`, `src/`, `app/` or `lib/` in this repository. **No executable spike
code is committed to Greenfield5 in this PR.** Kotlin, Swift and Rust sources
below are *proposals written into a document*; nothing here was compiled.

The issue offers two acceptable homes for the executable half:

1. an isolated scratch/prototype repository or an upstream-example fork, or
2. a reviewed governance change permitting spike code without enabling the
   production stack.

This session did **not** create a GitHub repository or fork, because repository
creation is administration and requires explicit human authorization
(`.ecc/BOOTSTRAP.md`, hard rule 8). **Blocker B0 in §12 is exactly this
authorization.** The recommended home is a fork of `n0-computer/iroh-live`
(branch `greenfield5-spike-1`) so the harvest is a diff against upstream rather
than a copy with no provenance.

### 4.2 Proposed layout (in the scratch/fork repository)

```
spike/
  core/                      # Rust: the whole shared core, ~1 crate
    src/lib.rs               # tiny FFI surface (§4.3), CDylib
    src/session.rs           # endpoint + publish/subscribe + status snapshot
  android/                   # Kotlin host, adapted from demos/android
    app/src/main/java/…/SpikeBridge.kt      # external fun (renamed IrohBridge)
    app/src/main/java/…/MainActivity.kt     # SurfaceView + render loop
    rust/                    # thin JNI wrapper over core (cargo-ndk cdylib)
  ios/                       # Swift host
    Spike/SpikeApp.swift     # UIImageView + Timer(1/30)
    Spike/spike_core.h       # C ABI header for core
  tools/
    measure.py               # reads status JSON from both devices over adb/console
```

The `core` crate must keep **only** the transport/media/measurement surface and
no capture, no UI, no pairing — the boundary ADR-0005 reserves.

### 4.3 The intentionally tiny FFI surface

Ten functions, flat handles, JSON for anything with structure (keeps both
bindings trivial and keeps ABI churn out of the picture):

| # | Call | Purpose (issue requirement) |
| :-- | :-- | :-- |
| 1 | `gf_endpoint_create(config_json) -> u64` | create endpoint; config carries relay mode (`default` / `custom url` / `disabled`), bind addrs, secret key, preset |
| 2 | `gf_endpoint_close(h)` | close endpoint |
| 3 | `gf_ticket(h) -> char*` | endpoint id + explicit addrs for deterministic LAN dialling |
| 4 | `gf_publish_test_video(h, w, h, fps, bitrate) -> int` | publish synthetic encoded video |
| 5 | `gf_session_connect(h, peer_id, addrs_json) -> u64` | connect/accept session (dial side) |
| 6 | `gf_session_accept(h, timeout_ms) -> u64` | accept side |
| 7 | `gf_subscribe_video(session, name) -> u64` | subscribe to video |
| 8 | `gf_video_next_frame(track, timeout_ms) -> u64` + `gf_frame_to_rgba(frame, buf, cap) -> size` + `gf_frame_free(frame)` | pull decoded frames (latest-wins slot, CPU RGBA) |
| 9 | `gf_status_json(handle) -> char*` | direct-vs-relay/path state + measurements |
| 10 | `gf_session_close(s)`, `gf_last_error() -> char*` | lifecycle and errors |

`gf_status_json` is the single observation point for evidence 5–10, and it is a
thin serialization of things upstream already computes (§8, §10) — no new
metrics machinery.

### 4.4 Binding choice per platform

- **Android/Kotlin:** hand-written JNI in the harvested style (opaque `jlong`
  handles, `JNI_OnLoad` + process-wide runtime). Proven upstream on a real
  device; no codegen pipeline to babysit.
- **iOS/Swift:** `#[no_mangle] extern "C"` + a hand-written 40-line
  `spike_core.h` and a `module.modulemap`, consumed as a static `.a` in an
  Xcode/SwiftPM target. Rationale: the surface is ten functions, and the
  alternatives cost more than they save — `uniffi` (what `iroh-ffi` uses) is the
  right call once the surface stabilises, and `cbindgen` adds a tool dependency
  for a header that fits on one screen. `iroh-ffi`'s `Package.swift` /
  `IrohLib.podspec` remain the reference for how Apple packaging is done when
  this graduates.

### 4.5 Build recipes (to be run in Spike 1B, not here)

Android (mirrors `demos/android/Makefile.toml`):

```sh
export ANDROID_HOME=~/Android/Sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/28.0.12674087   # NDK 28+
rustup target add aarch64-linux-android
cargo install cargo-ndk
cargo ndk -t arm64-v8a -P 26 --link-libcxx-shared -o android/app/src/main/jniLibs \
  build -p gf-spike-core --release
find android/app/src/main/jniLibs -name '*.so' ! -name 'libgf_spike_core.so' \
  ! -name 'libc++_shared.so' -delete
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip \
  android/app/src/main/jniLibs/arm64-v8a/libgf_spike_core.so
(cd android && ./gradlew assembleDebug)
$ANDROID_HOME/platform-tools/adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

iOS (macOS only):

```sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cargo build --release --target aarch64-apple-ios          # static lib for device
cargo build --release --target aarch64-apple-ios-sim      # simulator, for first smoke
xcodebuild -project ios/Spike.xcodeproj -scheme Spike -destination 'generic/platform=iOS' build
```

---

## 5. Android build findings

### 5.1 What upstream proves — VERIFIED

- The Android demo is real and device-tested in upstream's own words
  (`docs/platforms.md`: *"Android | Tested on device, two-way audio and video
  against a Linux desktop"*; `demos/android/README.md`: *"Tested end to end on a
  real Android device"*). It is a **preview**, not a supported SDK.
- Toolchain: `ANDROID_HOME`, NDK 28+, `cargo-ndk`, `cargo-make`, JDK 17+,
  `rustup target add aarch64-linux-android`, minSdk 26 (AAudio), arm64-v8a
  (x86_64 optional for the emulator).
- `cargo ndk` copies dependency `.so` files into `jniLibs`; upstream's pipeline
  deletes everything except `libiroh_live_android.so` and `libc++_shared.so`
  (`--link-libcxx-shared`), then strips with the NDK's `llvm-strip`.

### 5.2 Risks specific to this spike — INFERRED / UNKNOWN

| Risk | Grade | Mitigation |
| :-- | :-- | :-- |
| Artifact size — upstream measures ~500 MB unstripped `cdylib` → ~21 MB stripped | INFERRED (their number) | Strip in the pipeline from the start (§4.5) |
| Two `jni` majors in one build (`0.21` bridge, `0.22` inside `moq-native`) | VERIFIED that both are pulled | Compile early in Spike 1A before writing any UI |
| openh264 + MediaCodec H.264 path from `moq-video` builds for `aarch64-linux-android` | INFERRED | `cargo check --target aarch64-linux-android` in CI is the first gate |
| Android 17 (API 37) blocks local-network access by default for SDK-37 apps (`ACCESS_LOCAL_NETWORK`) | INFERRED from earlier research in this repo | Keep `targetSdk 34` for the spike; note it for Local mode later. Not a spike-1 blocker |

### 5.3 Physical requirement — UNVERIFIED

Criteria 1, 4, 5, 6 are physical-device criteria. An emulator can show moving
video, and that is worth doing as a cheap intermediate signal, but **it is not
the required evidence** and must not be reported as such.

### 5.4 The LAN discovery trap — VERIFIED (and a real finding)

`LiveTicket` carries no addresses (§3.3). On a LAN with no Internet route,
resolution falls to mDNS; Android will not receive multicast for that lookup
without a `WifiManager.MulticastLock`, and the upstream demo does not take one.
Spike 1 must therefore dial by explicit address (`EndpointAddr::from_parts`) for
its same-Wi-Fi rows, or take the lock. Discovering this by starting two phones
and watching nothing happen would burn a day.

---

## 6. iOS build findings

This is the least-baked part of the harvest, and the report's most important
negative finding. Every line below is VERIFIED at the pins.

### 6.1 What does not exist for iOS in the harvest

| Component | Gate in the pinned source | iOS consequence |
| :-- | :-- | :-- |
| VideoToolbox **decode** | `#[cfg(target_os = "macos")] mod videotoolbox;` — `moq-video/src/decode/backend/mod.rs:27` | No hardware decode on iOS |
| VideoToolbox **encode** | `#[cfg(target_os = "macos")] mod videotoolbox;` — `moq-video/src/encode/backend/mod.rs:29` | No hardware encode on iOS |
| `Surface::PixelBuffer` (`CVPixelBuffer`) | `#[cfg(target_os = "macos")]` — `moq-video/src/frame.rs:390` | No zero-copy Apple surface on iOS |
| `Surface::into_pixel_buffer()` | `#[cfg(target_os = "macos")]` — `moq-video/src/frame.rs:584` | Cannot hand a decoded frame to CoreVideo/Metal on iOS |
| wgpu renderer (`render/metal.rs`) | `#[cfg(target_os = "macos")]` — `moq-video/src/render/mod.rs:54` | No decode-to-screen renderer for iOS |
| iOS anywhere in the workspace | `grep -rn 'target_os = "ios"'` over `iroh-live`, `moq-video`, `moq-media`: **no hits** | iOS has never been targeted by this stack |

These five gates were read twice — once in `moq-dev/moq` `main` (`df79bf0`) and once
in the released `moq-video` 0.0.23 tag (`535d6e4`) — and the line numbers above are
identical in both, so the conclusion does not depend on which tree the spike
pins.

Upstream says so themselves (`docs/platforms.md`): *"iOS | Upstream has
AVFoundation and VideoToolbox. Never built or tested here."* `iroh-live`'s
`DEVELOPMENT.md`: *"Windows and iOS have never been built here."*

### 6.2 What does work for iOS, and why the spike is still feasible — INFERRED

The escape hatch is that the **CPU path is unconditional and present in the
released crate**:

| Function | Released `moq-video` 0.0.23 (`535d6e4`) | `Frando/moq@iroh-live-3` branch |
| :-- | :-- | :-- |
| `Surface::into_i420(self) -> Bytes` | `frame.rs:549` | `frame.rs:549` (unchanged) |
| `Surface::into_rgba(self) -> Rgba` | `frame.rs:562` | `frame.rs:592` (kept as a shim over the new borrowing form) |
| `Surface::into_rgba_with(self, &Config)` | `frame.rs:567` | `frame.rs:598` |
| `Surface::to_rgba(&self)` / `to_rgba_with(&self, ..)` | **absent** | `frame.rs:562`, `:567` — added by the one patch commit |
| `Surface::to_bgra(&self)` / `to_bgra_with(&self, ..)` | **absent** | `frame.rs:578`, `:583` — added by the one patch commit |
| `Surface::rgba(&[u8], Size)` (build a CPU frame) | `frame.rs:453` | `frame.rs:453` |
| `I420::{y,u,v}` plane accessors | `frame.rs:936/941/947` | same API, shifted to `:973/978/984` |

None of these carry a `cfg(target_os)` gate, and `openh264` is compiled
**everywhere** (`mod openh264;` in both encode and decode backend `mod.rs`;
the crate's doc says *"H.264 encodes and decodes everywhere, because openh264 is
vendored and statically linked upfront"*). So the minimal iOS viewer is:

```
MoQ over iroh → openh264 software decode → Surface::I420 → into_rgba()
              → FFI → Swift: CGImage/UIImageView (or CVPixelBuffer if the
              Swift side allocates it and we fill the planes)
```

That is enough for criterion 4 (visible moving pattern) at 640×360/30 fps, and
it is honest about being a software path. Reaching iOS **hardware** codecs means
either extending the `target_os = "macos"` gates upstream to
`any(target_os = "macos", target_os = "ios")` (a patch, and a conversation with
upstream) or doing VideoToolbox in Swift and crossing the surface by handle —
both are out of scope for Spike 1 and belong in a later decision.

One caveat that only shows up when building against released crates rather than
the patch branch: `into_rgba` **consumes** the surface, while the branch's
`to_rgba` borrows. That is not a problem for this design — `VideoTrack::take()`
hands back an owned `Frame` from the latest-wins slot, so consuming it is the
natural shape — but any *copied* `moq-media` code that was written against the
borrowing form must be adapted, and that is the concrete cost behind the
condition in §11.

### 6.3 Packaging findings

- `iroh` itself is iOS-ready: `iroh-ffi` v1.1.0 ships `IrohLib.xcframework.zip`
  and `libiroh-darwin-aarch64.tar.gz` from a real GitHub release, with
  `Package.swift` declaring iOS 17.5 / macOS 14.5. VERIFIED via `gh api
  repos/n0-computer/iroh-ffi/releases`.
- `iroh-ffi` exposes the Iroh 1.0 surface to Swift **and** Kotlin (endpoints,
  connections, `PathSnapshot{is_ip, is_relay, is_selected, rtt_ms, stats}`, path
  watchers, tickets, `RelayMode`, dedicated-relay presets via
  `preset_iroh_services`). **It exposes no MoQ surface at all** — `grep -rin
  moq` over `src/` and the READMEs returns nothing. The preflight comment on
  Issue #11 told us to establish that boundary explicitly; this is it:
  *`iroh-ffi` is a reference for packaging and for relay plumbing, not a path to
  the media stack.*
- `fast-apple-datapath` — `iroh-live` enables it and iroh's manifest describes
  it as *"Use private Apple APIs to send multiple packets in a single syscall."*
  Greenfield5 ships apps; private-API use is an App Store review risk that should
  be decided deliberately, not inherited from a demo. UNKNOWN whether Apple
  accepts it; flag for a later decision, not for this spike.

### 6.4 iOS build proof — UNVERIFIED, and why

Building any Apple target requires macOS with Xcode and the Apple SDKs, which
are neither present here nor redistributable to a Linux sandbox. There is no
simulator that runs on Linux. The first honest iOS signal available in this
project is therefore **CI**: a `macos-latest` GitHub Actions job running
`cargo check --target aarch64-apple-ios` (Spike 1A, §13) — a *compile* proof,
not the FFI-load proof the issue asks for.

---

## 7. Physical-device test matrix — UNVERIFIED

Rows exactly as the issue specifies, with the evidence each row must produce.
**Nothing in this table has been run.**

| # | Sender | Viewer | Network case | Expected | Status | Evidence artifact to capture |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| R1 | Android | iOS | same Wi-Fi/LAN | direct path, continuous video | UNVERIFIED | `gf_status_json` samples (path_type=`direct`), screen recording, frame counters |
| R2 | iOS | Android | same Wi-Fi/LAN | direct path, continuous video | UNVERIFIED | same, roles swapped |
| R3 | Android | iOS | different Internet paths / NAT | direct if possible, else relay | UNVERIFIED | both sides' status JSON + relay assignment logs |
| R4 | iOS | Android | forced relay | relay fallback works, MoQ API unchanged | UNVERIFIED | status JSON with `path_type=relayed`, identical call sequence |
| R5 | either | either | 60 s soak on R1 | ≥ 60 s sustained delivery | UNVERIFIED | frame timeline (timestamp, arrival time) over ≥ 60 s |
| R6 | either | either | kill/restart sender mid-session | reconnect behaviour recorded | UNVERIFIED | disconnect reason, re-dial count, time-to-first-frame-after-reconnect |

Device-recorded sheet (fill in when executed — deliberately empty):

| Field | Android device | iOS device |
| :-- | :-- | :-- |
| Model / SoC | | |
| OS version | | |
| App build / core commit | | |
| Direct-path observed (`path_type`) | | |
| Relay observed (`path_type`) | | |

---

## 8. Direct-path evidence — the mechanism is verified, the observation is not

VERIFIED at the pins:

- `iroh`'s `Connection::paths()` returns `PathList`; each `Path` exposes
  `is_selected()`, `is_ip()`, `is_relay()`, `remote_addr()`, `rtt()` and
  `stats()` (`iroh/src/socket/remote_map/remote_state/path_watcher.rs:446+`);
  `Connection::path_events()`/`paths_stream()` give change notifications
  (`iroh/src/endpoint/connection.rs:1154–1186`).
- `iroh-moq`'s `MoqSession::conn()` hands the `Connection` straight out, so no
  plumbing is required to reach any of it.
- **Upstream already computes the exact readout the issue asks for**:
  `iroh-live/src/util.rs` `spawn_stats_producer` (≈ line 505) samples the
  selected path and sets
  `net.path_type = if selected.is_relay() { "relayed" } else { "direct" }` plus
  `net.path_addr = selected.remote_addr()`, `net.rtt_ms`, loss rate, and
  `NetStats::bw_up_mbps`/`bw_down_mbps`.

So criterion 5 costs a JSON serialization, not a subsystem: `gf_status_json`
returns `{path_type, path_addr, rtt_ms, cwnd, udp_tx_bytes, udp_rx_bytes,
loss_pct, frames_decoded, frames_published, first_frame_ms, session_ms}`.

Recording rule for R1/R2: sample every 500 ms for 30 s after first frame; the
row passes when `path_type == "direct"` for ≥ 95 % of samples **and** the
selected path's remote address is an IP transport address (not a relay URL).

---

## 9. Relay-fallback evidence — mechanism verified, not executed

Three candidate forcing methods, best first. All are configuration, not code:
the application-level MoQ call sequence is identical in every case, which is
precisely what criterion 6 requires.

1. **`EndpointBuilder::clear_ip_transports()`** — VERIFIED public at
   `iroh/src/endpoint.rs:510`: *"Removes all IP based transports."* The endpoint
   then has only relay transports, so the connection cannot use a direct path.
   Deterministic, in-process, no OS changes, and reversible for the A/B
   comparison in the same binary. **This is the recommended forcing method for
   R4.** `clear_relay_transports()` (line 517) is the mirror, useful to prove
   the direct-only case.
2. **Network-level**: block UDP between the two devices (router ACL or a
   different-network topology). Strongest external validity — proves fallback
   under *real* conditions rather than a configured one — and worth doing once
   as a cross-check on method 1.
3. **Relay-url-only addressing**: construct the peer address with relay
   addresses only (`EndpointAddr` containing just the relay URL), the shape
   iroh's own tests use (`iroh/src/test_utils/test_transport.rs:684–687`).
   Useful to force relay *selection* without disabling IP transports.

Note on a near-miss: `iroh/src/socket.rs` documents a `RelayOnly` path-selection
mode, but at `ec04e27` the term appears **only in that doc comment** — no public
accessor was found by grep. Do not plan around it; `clear_ip_transports` is the
supported switch.

Relay infrastructure for R4: the n0 default relays are fine for proving the
mechanism; a *dedicated* relay is what ADR-0005 requires for production and is
reachable through `iroh-ffi`'s `preset_iroh_services` (relays + API secret →
short-lived relay token). Testing the dedicated path is a reasonable addition to
R4 if time allows, but it is not required by Issue #11.

---

## 10. Measurements — definitions fixed, values UNVERIFIED

Every value below is a row in the results table that a Spike 1B run must fill.
None were measured here. The point of writing them down now is that the
definitions are agreed *before* numbers exist.

| Metric | Definition (exact) | Source of truth | Threshold to accept |
| :-- | :-- | :-- | :-- |
| Session-establishment time | t(`MoqSession::connect` returns) − t(`gf_session_connect` entry), client side; server side from `incoming_sessions().next()` | monotonic clock in core, reported in `gf_status_json.session_ms` | P50 < 3 s on LAN; Internet reported, no threshold |
| First-frame time | t(first `VideoTrack::take() == Some(frame)`) − t(session established) | core; `first_frame_ms` | < 1.5 s on LAN (INFERRED target; must be replaced by the measured value) |
| Sustained delivery ≥ 60 s | frames decoded per second over the soak; longest gap between consecutive frames | frame timeline log | ≥ 95 % of expected frames (30 fps → ≥ 28.5 fps mean), no gap > 1 s |
| Observed bitrate (uplink) | Δ`path.stats().udp_tx.bytes` / Δt on the publisher, and `NetStats.bw_up_mbps` | path stats (VERIFIED field: `udp_tx.bytes`) | within ±30 % of the configured encoder bitrate for 640×360/30 |
| Observed bitrate (downlink) | Δ`udp_rx.bytes` / Δt on the subscriber | path stats | consistent with uplink minus loss |
| Loss / cwnd / RTT | `path.stats().lost_packets`, `.cwnd`, `path.rtt()` | path stats | reported, not thresholded |
| Direct vs relay | `path_type` label + `remote_addr` family | `spawn_stats_producer` (§8) | see §8/§9 pass rules |
| Disconnect/reconnect | `MoqSession::closed()` reason, re-dial attempts, time to next first frame | session + `path_events()` | recorded; a reconnect must land on whichever path is available and must not require an API change |

Results table (to be filled by Spike 1B):

| Metric | R1 Android→iOS | R2 iOS→Android | R3 Internet | R4 forced relay |
| :-- | :-- | :-- | :-- | :-- |
| Session ms | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| First frame ms | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| Sustained fps (60 s) | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| Longest gap ms | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| Bitrate uplink/downlink | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| path_type | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |
| Reconnect behaviour | UNVERIFIED | UNVERIFIED | UNVERIFIED | UNVERIFIED |

---

## 11. Are released upstream crates sufficient, or are `iroh-live` patches still required?

This is the question the preflight comment asked to answer explicitly. The
static evidence says **released crates are sufficient for Spike 1's path, at the
cost of adapting a small number of call sites** — and the patch is avoidable
there.

**VERIFIED facts:**

1. The seven branch-only commits in `Frando/moq@iroh-live-3` touch
   `rs/moq-mux` (six commits, fMP4 export ordering) and `rs/moq-video` (one
   commit, "convert a surface by reference, and to BGRA") — **nothing else**.
2. `rs/moq-native/src/iroh.rs` at the released tag `moq-native-v0.19.17`
   (`535d6e4`) is **byte-identical** to the branch baseline: `git diff --stat
   <tag> <branch> -- rs/moq-native/src/iroh.rs` is empty.
3. `rs/moq-net` at the released tag `moq-net-v0.2.20` (`cf52dad`) is
   **byte-identical** to the branch (`git diff --stat` empty) — and `cf52dad`
   is itself one of the eleven commits between the release tag and the branch
   head.
4. The whole distance between the release commit and the branch head is
   **eleven commits**: the seven above, plus `cf52dad` (moq-net draft-21),
   `26057f5` (V4L2 camera mode listing), `1ff16d4` (moq-video: name every
   backend publicly) and one CI-only commit. So a released-crates build differs
   from the harvest baseline by two `moq-video` API additions, one `moq-net`
   addition, and nothing else.
5. **No file in the harvested workspace calls the patched-only API.**
   `grep -rn '\.to_rgba(\|\.to_bgra(\|to_rgba_with(\|to_bgra_with('` over
   `iroh-live`, `moq-media`, `moq-media-android`, `moq-media-egui`, `demos` and
   `iroh-live-cli` returns **zero** matches. The only conversion call sites are
   `demos/pi-zero/src/gles.rs:294` (`into_rgba`) and `iroh-live-cli/src/scan.rs:742`
   (`into_i420`) — both of which exist in the released tag as well.
6. The Android bridge's render path touches **no** conversion API at all: it
   goes `Surface::HardwareBuffer` → EGL, or `Surface::I420` → `I420::{y,u,v}` →
   `render_nv12` (§3.1).

**INFERRED conclusion:** a Spike 1 core that (a) copies `iroh-moq` (whose
dependencies do not include `moq-media`/`moq-video`), (b) takes `moq-native`
(`iroh` feature), `moq-net` and `moq-video` **from crates.io**, and (c) builds
its own small synthetic source on `Surface::rgba(..)` plus `Frame`, touches
**none** of the seven patches. If `moq-media` itself is copied instead of
reimplemented, its own sources are written against an eleven-commit-newer tree,
so a released build is expected to need a handful of call-site edits (chiefly
`to_rgba`/`into_rgba` naming and any use of the new backend-naming API) — cheap,
but not zero.

**How to turn this into a fact (Spike 1A, §13):** `cargo check` the spike core
with **no `[patch.crates-io]` block at all**. If it builds, Greenfield5 has
proved it can use released upstream crates for the transport-plus-CPU-frame
path. If it fails, the error will name exactly which crate and API is missing —
and the fallback ladder is: (1) pin one crate to the released tag rather than
the branch, (2) copy the tiny amount of missing code, (3) take the branch pin —
in that order, so the patch stays an escape hatch rather than a foundation.

**Where the patch is still required (VERIFIED as used by the harvest):** the
`iroh-live` workspace patches these crates in `Cargo.toml` and pins the branch
revision in `Cargo.lock`, so every in-repo consumer — including the Android demo
crate — builds against `main`-era sources. Anything doing fMP4/`hang` export
needs the six `moq-mux` commits. So: *harvesting the repository wholesale drags
the patch in; harvesting the transport plus a CPU-frame path does not.*


---

## 12. Blockers, ranked

| # | Blocker | Grade | Smallest mitigation | Owner decision needed |
| :-- | :-- | :-- | :-- | :-- |
| **B0** | No authorized home for executable spike code (repo/fork creation is administration, and this session may not create branches or repositories) | VERIFIED (process) | Authorize a fork of `n0-computer/iroh-live` in `anthracite-labs`, or a new `greenfield5-spike-1` repository | **Yes** |
| **B1** | This sandbox cannot build anything: no Rust toolchain, no crates.io, no JDK/SDK/NDK, no macOS/Xcode (§1.2) | VERIFIED | Move all build work to GitHub Actions runners (open network) plus a developer Mac for Apple targets | No |
| **B2** | No physical devices attached to any build environment | UNVERIFIED (availability) | Run criteria 3–7 on a Mac + one Android device + one iPhone | **Yes** (hardware) |
| **B3** | iOS media stack is macOS-gated in the pinned MoQ crates: no VideoToolbox encode/decode, no Apple zero-copy surface, no wgpu renderer (§6.1) | VERIFIED (source) | Spike uses the software path (openh264 + `into_rgba` + Swift draw); hardware iOS codecs become a later, explicit decision | No for spike; **yes** before implementation |
| **B4** | `openh264` on `aarch64-apple-ios` has never been built by upstream in this stack | UNKNOWN | `cargo check --target aarch64-apple-ios` in CI (Spike 1A) | No |
| **B5** | LAN discovery without Internet: tickets carry no addresses; Android needs a multicast lock for mDNS (§5.4) | VERIFIED | Dial by explicit `EndpointAddr` addresses in the spike's LAN rows | No |
| **B6** | `fast-apple-datapath` uses private Apple APIs; App Store review impact unknown | UNKNOWN | Leave as-is for the spike; decide before shipping | **Yes**, later |
| **B7** | Two `jni` majors inside one Android build | VERIFIED (manifest) | Compile-only CI gate before writing UI | No |

---

## 13. Smallest recommended next spike

**Spike 1A — build-and-compile proof, no devices (~half a day, CI only).**
This is the smallest thing that can convert four UNVERIFIED items into VERIFIED
ones, and it needs no hardware and no human:

1. In the authorized scratch/fork repo (B0), create the `core` crate with the
   §4.3 surface and **no `[patch.crates-io]` block** — released crates only, so
   the run answers §11 as a side effect. Adapt conversion call sites to
   `into_rgba` (§6.2) rather than taking the branch pin.
2. CI jobs (GitHub-hosted runners, which have the egress this sandbox lacks):
   - `ubuntu-latest`: `cargo ndk -t arm64-v8a -P 26 build -p gf-spike-core`
     with NDK installed → proves criterion 1's native half and answers §11
     (released crates sufficient?).
   - `macos-latest`: `cargo check --target aarch64-apple-ios` → proves the iOS
     native half compiles and answers B4 (`openh264` on iOS).
   - Publish the `.so`/`.a` artifacts and `nm`-dump the ten exported symbols.
3. Only then touch UI.

**Spike 1B — the physical run (the issue's actual acceptance criteria).**
Two devices on one Wi-Fi, one Mac, ~half a day: R1 (Android→iOS, direct), R5
(60 s soak, measurements), R4 (relay forced with `clear_ip_transports`), then
R2/R3/R6. Everything needed for 1B is already specified above: the harvest map
(§3), the surface (§4.3), the recipes (§4.5), the readouts (§8–10) and the test
matrix (§7).

**Deliberately not recommended now:** iOS hardware codecs, screen capture
(MediaProjection/ReplayKit/ScreenCaptureKit), pairing, Wi-Fi Aware, dedicated
relay provisioning, or any `config/project.env` change. All are out of scope for
Issue #11.

---

## 14. Scope compliance

| Issue constraint | Status |
| :-- | :-- |
| No MediaProjection / ReplayKit / ScreenCaptureKit | Honoured — nothing added |
| No Greenfield5 pairing flow | Honoured |
| No Wi-Fi Aware | Honoured |
| No accounts/backend | Honoured |
| No production UI | Honoured |
| No implementation lifecycle transition | Honoured — `config/project.env` untouched (`PROJECT_PHASE=architecture`, `ALLOW_APP_STACK=0`) |
| No executable Kotlin/Swift/Rust in the product tree | Honoured — this PR adds two Markdown documents only |
| Do not disable a guard to make a change fit | Honoured — the guard was never edited |

---

## 15. Evidence index — what was actually run this session

| Action | Result |
| :-- | :-- |
| `git fetch --depth 1 <repo> <sha>` × 4 pins (+ `Frando/moq` branch) | all four pins plus the branch revision fetched and `rev-parse`-verified |
| `git ls-remote --tags https://github.com/moq-dev/moq` | release tags enumerated; `moq-native-v0.19.17`→`535d6e4`, `moq-net-v0.2.20`→`cf52dad`, `moq-video-v0.0.23`→`535d6e4` |
| `git diff` released tag ↔ `iroh-live-3` for `rs/moq-native/src/iroh.rs`, `rs/moq-net`, `rs/moq-native` | `iroh.rs` identical; `moq-net` identical; `moq-native` differs only in websocket ALPN + tests |
| `git log --oneline moq-dev/main..Frando/iroh-live-3` + per-commit `--stat` | seven commits, six in `moq-mux`, one in `moq-video` |
| `gh api repos/n0-computer/iroh-ffi/releases` | v1.1.0 (2026-07-16) assets incl. `IrohLib.xcframework.zip` |
| `grep -rin moq src/ README*.md` in `iroh-ffi` | **no hits** — MoQ is not exposed by the Iroh FFI |
| `git rev-list --count <release-tag>..<branch>` and the 11-commit listing | release commit is 11 commits behind the harvest baseline: 7 branch commits + `cf52dad`/`26057f5`/`1ff16d4` + one CI commit |
| `git show <tag>:rs/moq-video/src/frame.rs` vs the branch, greps for `to_rgba`/`to_bgra`/`into_rgba`/`into_i420` | released 0.0.23 has only the consuming `into_*` forms; the borrowing `to_*` forms are patch-only; **zero call sites** in the harvest use them |
| `grep -rn 'target_os = "ios"'` over `moq-video`, `moq-media`, `iroh-live` | no hits |
| `ls -d vendor` in each of the five checkouts (`iroh-live`, `iroh-ffi`, `moq`, `iroh`, `Frando/moq`) | no `vendor/` in any of them — no offline dependency tree |
| `grep -c` for JNI entry points and Kotlin `external fun`s | 18 and 18 (plus `JNI_OnLoad`); `demos/android/rust/src/lib.rs` is 1 259 lines, `iroh-moq/src/lib.rs` is 820 |
| Source reads for §3, §4, §6, §8, §9, §10, §11 | file-and-line citations given inline |
| Egress probes over ~30 hosts; PyPI/npm package inspection | only `github.com`, `api.github.com`, `pypi.org`, `files.pythonhosted.org`, `registry.npmjs.org`, `codeload.github.com` reachable; no toolchain obtainable |
| Compilation, packaging, device runs, measurements | **not performed** — no toolchain, no SDK, no devices (§1) |

*Nothing in this report is a substitute for the physical test. The honest summary
is: the plan is de-risked and evidenced; the execution has not happened.*
