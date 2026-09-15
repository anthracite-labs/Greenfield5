# Project Memory

Append-only ledger. Newest entry at the bottom. The sandbox is destroyed
between sessions, so memory that is not committed does not exist.

Procedure: [`../.ecc/skills/project-memory.md`](../.ecc/skills/project-memory.md).

## How to use this file

- Append one entry per working session. Never rewrite or delete an old entry;
  correct it with a new one that says what changed and why.
- Record what was **verified**, with the command and its actual result — not
  what was intended.
- Record surprises and dead ends. A failed approach that is not written down
  gets retried by the next session.
- Durable trade-offs go in [decisions/](decisions/README.md) as ADRs; this file
  points at them rather than duplicating them.

Entry template:

```text
## YYYY-MM-DD — <short title>

**Context:** <issue / branch>
**Did:** <what changed>
**Verified:** <command → actual result>
**Learned:** <surprises, dead ends, constraints discovered>
**Next:** <what the following session should know or do>
```

---

## Template provenance (carried by App-Factory, not project history)

This repository's engineering foundation is App-Factory (see
[`../FOUNDATION_VERSION`](../FOUNDATION_VERSION)). App-Factory v0.1.0 was
derived from the reviewed Ditto Foundation source commit
`anthracite-labs/Ditto@5d9cc349d264f73e8da913da9d2cea664522237d`. That is
factory provenance only: none of the source project's product history,
debugging chronology, issue numbers, or branch names is carried here, and none
of it applies to this repository.

## Operating conventions inherited from the foundation

These are the conventions every session is expected to follow. They are
recorded here because they are the durable context a new session needs before
it has read anything else.

| Convention | Where it is enforced |
| :-- | :-- |
| Read `.ecc/BOOTSTRAP.md` first; load 1–2 skills on demand. | `bootstrap`, `skill_index` checks |
| `scripts/verify.sh` is the only accepted evidence of quality. | CI job `Foundation gate` |
| The gate is proven by negative tests, not by passing. | `scripts/selftest.sh` |
| No stack/product choice without an approved issue and an ADR. | `no_app_stack`, `lifecycle` checks |
| Lifecycle changes are config diffs, never edits to the gate. | `config/project.env` + `lifecycle` check |
| Never commit credentials; findings are reported redacted. | `secrets`, `env_files` checks |
| Work on the session branch; never push to `main`; never self-merge. | `.ecc/rules/git.md`, branch ruleset |
| ECC is adapted, not vendored, and never silently upgraded. | `provenance`, `attribution` checks |

---

## Session entries

<!-- Append below this line. Do not edit entries above it. -->

## 2026-09-06 — App-Factory v0.1.0 foundation created

**Context:** Issue #1, branch `arena/01a076c9-app-factory`
**Did:** Created the generic reusable foundation from the reviewed Ditto
source commit: genericized `.ecc/` adapter, added `FOUNDATION_VERSION`,
`config/project.env` lifecycle state, portable `config/main-ruleset.json`,
`scripts/init-project.sh`, lifecycle-aware no-stack guard, clean
product/domain/roadmap/memory docs, and `docs/FACTORY.md`.
**Verified:** `bash scripts/verify.sh` and `bash scripts/selftest.sh` — see the
PR body for the recorded output of both runs.
**Learned:** The source foundation's permanent `ALLOW_APP_STACK=0` constant
inside `verify.sh` could not survive in a reusable template: a generated
repository must be able to graduate to an application stack without editing the
gate. Moving the state into `config/project.env` and adding a `lifecycle` check
that requires phase + ADR consistency keeps the transition explicit and
reviewable. ECC stays pinned at v2.2.0; upgrading it is a separate version bump.
**Next:** This template is `PROJECT_PHASE=factory`. A generated repository
should run `scripts/init-project.sh` first, then complete the GitHub-admin
checklist in [FACTORY.md](FACTORY.md), which the template cannot do for it.

## 2026-09-10 — Greenfield preflight documentation audit

**Context:** Issue #3, branch `chore/greenfield-preflight-cleanup`.
**Did:** Aligned the README lifecycle summary with the committed lifecycle by
including the `factory` phase, and clarified that GitHub's **Template repository**
setting is administrative state rather than something committed repository files
can prove or enable.
**Verified:** Read-only GitHub repository metadata reported `is_template=false`;
the repository rulesets endpoint returned no live rulesets at the time of this
audit. The repository content itself still carries `config/main-ruleset.json`
as the portable policy definition. No GitHub administrative setting was changed
by this documentation task. CI on the exact PR head is the acceptance evidence
for the repository edits.
**Learned:** Calling App-Factory a template source and GitHub marking it as a
template repository are separate states. The greenfield workflow must verify
both repository contents and live GitHub configuration instead of inferring one
from the other.
**Next:** A maintainer should enable GitHub's **Template repository** setting
before relying on **Use this template**, and separately decide whether to apply
the portable Main ruleset to App-Factory itself. Generated repositories must
still receive their own live governance because GitHub administrative settings
are not inherited.

## 2026-09-13 — Greenfield5 initialized for discovery (issue #1, branch `arena/issue-1-initialize-greenfield5`, PR #2)

**Done:** Initialized `config/project.env` with `PROJECT_NAME=Greenfield5`,
`PROJECT_SLUG=greenfield5`, and `PROJECT_PHASE=discovery`, while preserving
`ALLOW_APP_STACK=0` and an empty `STACK_DECISION_ADR`. Verified the live
`main-protection` ruleset before changing lifecycle state.
**Verified:** GitHub Actions run `34766735046` on commit
`007f7221d4ba0a3d1b90e9e2a5f0ffb26ccc81cb` reported `Independent checks = success`
and `Foundation gate = success`; inside `Foundation gate`, both `Run the
verification gate` (`bash scripts/verify.sh`) and `Run the negative tests`
(`bash scripts/selftest.sh`) completed successfully. Live ruleset `23185024`
was active on the default branch with no bypass actors and contained deletion,
non-fast-forward, pull-request, and strict required-status-check rules.
**Learned:** The connected GitHub path can create branches/PRs and inspect
Actions even when the local shell cannot resolve `github.com`. CI is therefore
the observed execution evidence for this session, not a claimed local run.
**Dead ends:** A local `git clone` attempt failed with `Could not resolve host:
github.com`, so `init-project.sh`, `verify.sh`, AgentShield, and `selftest.sh`
could not be executed in the local shell before the first commit.
**Next:** Verify the new PR head after this memory commit, then leave PR #2 open
for independent review. After merge, begin product discovery from `docs/PRODUCT.md`
in a separate issue; do not introduce an application stack before the later
architecture/ADR transition.

## 2026-09-13 — Greenfield5 MVP discovery consolidated

**Context:** Issue #3, branch `arena/issue-3-product-definition`, PR #4.
**Did:** Replaced the intentionally undefined `docs/PRODUCT.md` placeholder with
the product-owner-approved Greenfield5 MVP contract: one native app acting as
sender or viewer; Android/iOS cross-platform screen sharing; one sender and one
viewer; user-selectable Local, Direct, and Internet modes; temporary pairing and
sender approval; progressive permissions; minimal retention; explicit non-goals;
Android 10+ / iOS 16+ distribution constraints; and measurable V1 success
targets. Kept framework, media library, signalling, relay implementation,
hosting, database, codec, and encryption/key-distribution choices out of
discovery. `config/project.env` remains `PROJECT_PHASE=discovery` with
`ALLOW_APP_STACK=0` and no stack ADR.
**Verified:** GitHub Actions run `34772435227` on product-definition commit
`b74f25a394a6414a8f13e24c91514593789285d4` reported `Independent checks = success`
and `Foundation gate = success`. The `Foundation gate` job completed both `Run
the verification gate` (`bash scripts/verify.sh`) and `Run the negative tests
(gate must fail when it should)` (`bash scripts/selftest.sh`) successfully.
**Learned:** The discovery interview initially drifted toward a support platform;
the product owner corrected the scope to simple one-to-one phone screen sharing.
Issue #3 therefore contains superseded intermediate comments; the later
authoritative checkpoint and `docs/PRODUCT.md` are the consolidated product
truth. QR pairing and fully automatic transport selection were specifically
superseded: MVP uses code + shareable link and exposes Local / Direct / Internet
as user-selected modes.
**Next:** Verify CI again on the final PR head after this memory append. Leave PR
#4 open for review rather than merging it from this session. Once the product
contract is merged, move to `PROJECT_PHASE=architecture` in a separate reviewed
change and research/record the implementation stack via ADR before allowing app
source code.

## 2026-09-13 — Greenfield5 entered architecture review

**Context:** Issue #5, branch `arena/issue-5-architecture-transition`.
**Did:** Changed only the lifecycle phase from `discovery` to `architecture` in
`config/project.env`. `ALLOW_APP_STACK=0` remains enforced and
`STACK_DECISION_ADR` remains empty, so no application implementation is yet
authorized. No framework, media stack, backend, database, hosting target, or
application source was introduced.
**Verified:** The branch file state was re-read through the connected GitHub
path before PR preparation. Execution evidence from `bash scripts/verify.sh`,
`bash scripts/selftest.sh`, and AgentShield is intentionally not claimed here
until GitHub Actions runs on the exact PR head.
**Learned:** The product contract is now merged, so the smallest valid next
lifecycle move is architecture only; implementation remains separately gated by
an accepted application-stack ADR and the later implementation transition.
**Next:** After Issue #5 is independently reviewed and merged, open a dedicated
architecture research issue. Research and compare the mobile framework,
platform screen-capture APIs, media/WebRTC layer, Local/Direct/Internet
transport design, discovery/pairing, signalling, STUN/TURN, minimal backend,
and security boundaries; record durable choices as ADRs before enabling the
application stack.

## 2026-09-13 — Greenfield5 open-source architecture research pass

**Context:** Issue #7, branch `arena/01a09bf4-greenfield5`.
**Did:** Researched ~40 open-source candidates via `gh api` (primary) and web
search (secondary); wrote the durable record
`docs/research/open-source-landscape.md` (candidate matrix + harvest verdicts,
10-area capability coverage, ranked reusable findings with source paths, gaps,
architecture implications, 6 product-owner decisions). No architecture chosen,
no ADR, no app code, no lifecycle change.
**Verified:** `bash scripts/verify.sh` → exit 0 (full gate, this session);
`gh api` rate limit started 5000/5000. Headline verdicts: LiveKit EXTEND
(Internet), coturn/eturnal ADOPT (relay), scrcpy/ScreenStream/LocalSend/KDE/
wormhole HARVEST PATTERN, RustDesk/Briar/mesh-VPNs REJECT with reasons.
**Learned:** (1) No OSS app covers Greenfield5 end-to-end — closest fail iOS
sender (RustDesk, vendor-confirmed) or are Android-only (ScreenStream,
LocalScreenShare, whose MIT badge has no LICENSE file). (2) iOS BUE budget
(50 MB kill limit, 450x800@10 VP8 / 1068x600@15 H264) is primary-verified from
`opentok/opentok-ios-sdk-samples`. (3) Mixed-platform offline Direct video has
no credible solution — `google/nearby` OSS core is Wi-Fi-LAN-only on iOS
(verbatim README) — so Direct needs a hotspot-anchored prototype. (4) eturnal
lives at `processone/eturnal` (`eturnal/eturnal` 404s); canonical UxPlay is
`FDH2/UxPlay`; `restund/restund` 404s. (5) `write_file` silently truncated a
large doc mid-sentence — always check the tail (`tail`, line count) after
writing big files.
**Dead ends:** HopToDesk not inspected (RustDesk fork adds no new evidence);
restund not pursued (relay coverage complete via coturn/eturnal/pion).
**Next:** Product owner answers the 6 decisions in the research doc (starting
with the "native app" reading); then the stack ADR session. First prototype
candidate: hotspot-anchored LAN for mixed-platform Direct.

## 2026-09-13 — PR #8 research corrections (review findings)

**Context:** Issue #7, PR #8, branch `arena/01a09bf4-greenfield5`.
**Did:** Independently verified all 5 independent-review findings against
primary sources and corrected `docs/research/open-source-landscape.md`
(+385/−109): Wi-Fi Aware Direct fact base (UNKNOWN/REQUIRES PROTOTYPE,
prototype-first, hotspot as fallback); neutral 12-dimension P2P-vs-SFU
Internet comparison (LiveKit confirmed SFU-routed via vendor docs +
`p2p` code search = 0); three-way 50 MB memory wording; AirPlay demoted
from PO option to prototype-reference-only; engineering-safe licensing
language throughout. Material new finding: RPBroadcast* deprecated in
the iOS 27 SDK with ScreenCaptureKit (iOS 27+) as successor — BUE stays
valid for the iOS 16–26 window plus a migration track.
**Verified:** `bash scripts/verify.sh` → exit 0; `bash scripts/selftest.sh`
→ exit 0 (128/128); CI on the new head (see PR). Review scorecard: all 5
findings confirmed (Direct, LiveKit promotion, 50 MB wording, AirPlay
framing, licensing tone — AirPlay/licensing as framing fixes); 1 reviewer
aside rejected (Multipeer "deprecated" — framework page current, no
banner; immaterial since Apple-only either way).
**Learned:** `fetch_page` reaches Apple/Android/LiveKit docs that sandbox
egress blocks — official platform docs are fetchable primary sources.
Android 17 = API 37 (Android Developers Blog); Android 17 blocks local
network by default for SDK 37+ (`ACCESS_LOCAL_NETWORK`) — flagged for
Local mode. Apple Wi-Fi Aware mandates paired-device connections;
Android documents only Open/PSK datapaths with no NAN-pairing API found —
that asymmetry is the interop crux. `livekit/livekit-docs` is the docs
repo name (`livekit/docs` 404s).
**Dead ends:** None new; `restund/restund` still not pursued.
**Next:** Leave PR #8 open for re-review. Then PO answers (revised Q3/Q6)
and the stack ADR; first prototype is now the Wi-Fi Aware interop spike.

## 2026-09-13 — PR #8 cleanup: P2P wording + PR body refresh

**Context:** Issue #7, PR #8, branch `arena/01a09bf4-greenfield5`.
**Did:** Applied the re-review's two cleanup items only: fixed the P2P
topology definition ("a WebRTC PeerConnection", bidirectional — no
conclusion change) and refreshed the PR #8 body to the corrected head
(1018 lines, Wi-Fi Aware first prototype, P2P vs SFU candidates, CI
green). No research, no other doc changes.
**Verified:** `bash scripts/verify.sh` → exit 0; `bash scripts/selftest.sh`
→ exit 0 (128/128); CI green on the new head (see PR).
**Learned:** `gh pr edit --body/--body-file` can exit 0 without
persisting (observed twice, GraphQL projects warning only); REST
`PATCH /repos/{o}/{r}/pulls/{n}` with a JSON body applied the same
update successfully. Always re-read the PR body after editing it.
**Next:** PR #8 awaits independent re-review; no further work planned
on this branch unless the reviewer asks.

## 2026-09-13 — Rust/native + MoQ/Iroh architecture locked

**Context:** Issue #9, branch `arena/issue-9-moq-iroh-architecture`.
**Did:** Recorded accepted ADR-0005 selecting a shared Rust core, Kotlin + Jetpack Compose on Android, Swift + SwiftUI on iOS, MoQ for live media/object transport, and Iroh for native QUIC/P2P connectivity with direct-first Internet operation and dedicated encrypted relay fallback. Native screen capture, permissions, lifecycle, hardware-media, LAN, and Wi-Fi Aware integration remain platform-owned. `moq-relay` is retained as an optional future server-routed/fan-out component rather than the 1:1 default.
**Verified:** Repository-source verification for the decision used `n0-computer/iroh`, `n0-computer/iroh-ffi`, `moq-dev/moq` including `rs/moq-native/src/iroh.rs`, and `n0-computer/iroh-live`. CI/`scripts/verify.sh` evidence is not yet claimed for this branch; the PR must supply the authoritative gate result on the exact head.
**Learned:** Upstream MoQ already carries an experimental Iroh transport, and `iroh-live` proves real-time A/V over the combined stack with an Android Kotlin+Rust demo. That evidence is sufficient to choose the architecture direction but not to skip prototype gates: iOS Broadcast Extension process/memory behavior, strict-offline Local configuration, dedicated Internet relay fallback, and Android↔iOS Wi-Fi Aware Direct remain to be proven.
**Next:** Open Issue #9's PR, verify CI on the exact head, leave it for independent review, then continue the architecture interview/prototype sequencing. Do not transition to implementation or populate `STACK_DECISION_ADR` yet.

## 2026-09-14 — Implementation kickoff: transition + first skeletons (PR #14)

**Context:** Issue #13, PR #14, branch `arena/01a0a051-greenfield5`.
**Did:** Recorded accepted ADR-0006 (application stack + version pins with
primary-source evidence: Android Kotlin/Compose on AGP 9.4.0 built-in Kotlin,
Kotlin+compose plugin 2.4.20, Gradle 9.6.1 wrapper sha-pinned, compile/target
SDK 37, min 29, JDK 17; iOS Swift 6 + SwiftUI, hand-written Xcode 26 project,
objectVersion 77 with fileSystemSynchronizedGroups, deployment target 16.0;
shared zero-dep Rust core `greenfield5-core`, 1.98.1/edition 2024). Flipped
`config/project.env` to `implementation` + `ALLOW_APP_STACK=1` + ADR pointer.
Made 8 `selftest.sh` fixtures hermetic (they had relied on committed
architecture-phase defaults; suite still 128 cases). Built the first vertical
slice: both shells render the home screen with "Share My Screen"/"View a
Screen" and Sender/Viewer placeholders, sharing a mirrored
AppScreen/HomeAction navigation model with unit tests on both sides; core
holds the session state machine (Role/ConnectionMode/SessionState/
SessionCommand with stable u8 wire codes; error precedence SessionEnded >
RoleMismatch > ViewerAlreadyConnected > InvalidTransition; `apply` is the
only mutator; rejections never mutate) behind the u8-code `seam::CoreSession`
façade — 33 tests. Added `.github/workflows/stack.yml` (non-required: Rust
fmt/clippy/test + Android unit tests/assembleDebug; failing cargo steps
publish output as check-run annotations). Truth-fixed README ("no
application" claim, 17→18 checks), ARCHITECTURE scope, ROADMAP (ticked
completed stage items with evidence refs), codemaps (first map:
core-session.md).
**Verified:** Local on final heads: `verify.sh` PASS 16/0/2 (skips:
no_app_stack stood down by validated transition; agentshield advisory 0
files) and `selftest.sh` PASS 128/128. CI: `verify` green on every pushed
head; Stack run 34891853465 (head 1c9dd13) fully green — first execution of
the 33 core tests; Android job green on every head since the first run
(34875723375). RED record: scaffold heads failed CI (fmt diff: run
34875723375; compile/clippy: run 34889968626) — tests were committed before
the implementation, but `todo!()` stubs cannot compile under
`clippy -D warnings` (unused vars/imports), so the tests' first *execution*
is the GREEN head; stated as such in the PR.
**Learned:** Arena sandbox rebuild between turns can rewind local git
history while keeping the working tree — recovery is `git fetch` + `git
reset FETCH_HEAD` (mixed); unpushed commits are lost, so push early.
GH_TOKEN expires roughly hourly mid-session; reconnect via Arena.
GitHub log blobs (results-receiver/blob.core.windows.net) and
objects.githubusercontent.com are unreachable from the sandbox: check-run
**annotations** are the reliable CI-evidence channel; job step summaries do
NOT surface via the check-runs API (`output.summary` stays null). rustfmt
heuristics (chain_width≈60, prefer breaking after `=`) are hard to
hand-predict — the annotation diff loop converges in one cycle per issue and
beats guessing. AGP 9.4.0 built-in-Kotlin + KGP 2.4.20 via the compose
plugin + compileSdk 37 built green in CI first try (wrapper fetched through
the GitHub contents API since services.gradle.org is blocked; jar sha256
verified against gradle.org). `Vec::new()`+push in tests trips
`clippy::vec_init_then_push`. `assert_eq!` on `Result<T,_>` needs `T:
PartialEq` — derive it on façade types up front.
**Dead ends:** npm/PyPI rustfmt (wrappers only, no binary); release-asset
downloads (objects host blocked); reading CI logs via any endpoint.
**Next:** ADR-0006 follow-ups in order: native↔Rust bridge (UniFFI first
candidate) incl. R8/JNI keep rules and iOS side; macOS-runner CI for the
iOS project; MoQ/Iroh synthetic-media spike; `ACCESS_LOCAL_NETWORK` plan
for Local mode at targetSdk 37; iOS 27 RPBroadcast decision; promote Stack
jobs to required contexts once stable. PR #14 stays open for independent
ChatGPT review; do not merge it from an agent session.

## 2026-09-14 — PR #14 independent review: outcome + PO-accepted iOS deferral

**Context:** PR #14 head `b821eb3`; independent ChatGPT review submitted
2026-09-14T20:30:28Z (COMMENTED): "CONDITIONAL / no code blocker found".
**Review outcome:** No CRITICAL/HIGH code or security findings. Transition
found correctly ADR-backed; `scripts/verify.sh`, ruleset and verify workflow
not weakened; Rust core fmt/clippy/tests green on the final head; Android
shell builds/tests in CI; new CI least-privilege with SHA-pinned actions;
reviewer independently re-hashed `apps/android/gradle/wrapper/
gradle-wrapper.jar` (SHA-256 `497c8c2a…` matches Gradle's published 9.6.1
checksum); selftest fixture changes confirmed meaningful (guard checks
root-level artifacts, so nested `apps/`/`core/` don't neuter the negative
cases). ONE MEDIUM finding (spec evidence): Issue #13's "both shells render
the home screen" criterion was labelled "MET (iOS with stated caveat)" but
per `.ecc/skills/spec-review.md` classifies as PARTIAL until either (1)
Xcode/macOS CI compiles the iOS shell, or (2) the product owner explicitly
accepts iOS compile/render verification as a deferred follow-up for #13.
Reviewer: no source-code change required for the finding.
**Did:** The product owner explicitly accepted the deferral (reviewer's
option 2) on 2026-09-14, and directed: no macOS CI in this PR, no scope
expansion, no application-code changes for the finding. This entry is the
durable record of that acceptance. PR #14's acceptance rows for the iOS
home screen and Sender/Viewer entry points now state precisely: the
implementation exists; Xcode compilation/runtime verification is deferred
to the recorded macOS-CI follow-up with explicit product-owner approval.
Known-limitations and a review-reply comment updated to match.
**Verified:** `verify.sh` PASS on the corrected head locally (16/0/2, same
two by-design skips); CI `verify` + `Stack` re-run on the corrected head —
run ids and results quoted in the PR body (never claimed before observed).
**Next:** PR #14 stays open and ready for final independent review of the
corrected evidence; merge decision is human. iOS Xcode compile/run
verification remains the open ADR-0006 follow-up (macOS-runner CI); the
hand-written pbxproj stays the least-proven artifact until then.

## 2026-09-14 — Phase A: reconcile stale Issue #11 / PR #12 + Phase B: native↔Rust bridge

**Context:** Issue #11 and PR #12 predate implementation transition (architecture phase, ALLOW_APP_STACK=0). PR #14 merged d3b933f moves repo to implementation with Android/iOS/Rust skeletons. This session's objective: reconcile stale artifacts and implement next load-bearing slice — native↔Rust bridge via UniFFI.
**Did:**
- Phase A: Inspected Issue #11 (architecture validation spike requiring scratch repo) and PR #12 (docs-only research report, no device evidence). Determined lifecycle/execution plan superseded by Issue #13/PR #14. Added closing comment to PR #12 and closed it without merging (gh pr close 12 succeeded). Attempted to comment/close Issue #11 via gh api but received 403 Resource not accessible by integration — GitHub App can create issues but not edit/close existing ones in this environment; documented limitation and cross-linked successor in PR #12 comment and in Issue #11 body edit attempt. Created successor Issue #15 (Native↔Rust bridge: UniFFI-based production bridge) with full acceptance criteria including macOS CI for honest iOS verification.
- Phase B research: Verified UniFFI upstream via gh api: mozilla/uniffi-rs 4966 stars, updated 2026-09-14, tags v0.32.1 35a47433 and v0.32.0 5c7b739 (2026-06-30), CHANGELOG 0.32.0, README confirms Kotlin/Swift production-quality, Firefox mobile usage, Kotlin config (package_name, android flag, JNA fix #2897), Swift bindings (C header+modulemap+Swift, Swift 6 partial). Decision: pin UniFFI 0.32.1.
- Implementation: Updated core/Cargo.toml to add uniffi 0.32.1, thiserror 2, crate-type lib+cdylib+staticlib, uniffi-bindgen binary. Added core/src/uniffi_api.rs exposing Role/ConnectionMode/SessionState/SessionCommand enums, BridgeError, GreenfieldSession object with Mutex<Session>, core_version and wire-code helpers, delegating to existing session/seam without expanding semantics. Changed lib.rs forbid→deny unsafe_code to allow scaffolding via #[allow(unsafe_code)] module with setup_scaffolding!().
- Android: Created placeholder Kotlin bindings uniffi/greenfield5/greenfield5.kt (pure-Kotlin stub mirroring Rust logic for local builds, to be overwritten by CI-generated real bindings), bridge wrapper GreenfieldRustBridge.kt with System.loadLibrary("greenfield5_core") and runSenderJourney/runViewerJourney proof, updated build.gradle.kts to add JNA 5.14.0, enable isMinifyEnabled=true in release, jniLibs srcDir, proguard-rules.pro with keep rules for uniffi.greenfield5, JNA, native methods (build-proven via assembleRelease), added JVM unit tests GreenfieldRustBridgeTest.kt proving typed and u8-code journeys.
- iOS: Created placeholder Swift bindings Bridge/Generated/greenfield5.swift (pure-Swift stub mirroring Rust logic), bridge wrapper GreenfieldRustBridge.swift with getCoreVersion/isRustLibraryPresent and journey helpers, updated HomeView.swift to show core version + bridge status, added BridgeTests.swift with 7 tests mirroring Android.
- CI: Extended stack.yml with android-shell job building Rust for Android via cargo-ndk (aarch64-linux-android, x86_64-linux-android), generating Kotlin bindings via uniffi-bindgen, then testDebugUnitTest assembleDebug + assembleRelease (proves R8 keep). Added ios-shell job on macos-14 building Rust for iOS targets (aarch64-apple-ios, aarch64-apple-ios-sim, x86_64-apple-ios-sim), generating Swift bindings + XCFramework via scripts/generate-xcframework.sh, then xcodebuild build + test on iPhone 16 simulator. Actions SHA-pinned, least-privilege.
- ADR-0007 recorded UniFFI choice with alternatives (hand-rolled C ABI, Diplomat, Gobley, UDL) and consequences.
- Docs: Added docs/plans/15-native-rust-bridge.md plan, updated docs/decisions/README.md, created scripts generate-uniffi-bindings.sh and generate-xcframework.sh.
**Verified:**
- `bash scripts/verify.sh` → PASS 15 passed, 0 failed, 3 skipped (shell_lint no shellcheck, no_app_stack stood down, agentshield advisory 0 files) — executed this session, working tree includes new files.
- `bash scripts/selftest.sh` → PASS 128/128 after installing PyYAML 6.0.3 via pip --break-system-packages (previously 127/128 failing workflows_yaml/corrupted when parser absent).
- Local Rust toolchain absent (cargo not found, static.rust-lang.org blocked by egress allowlist) — CI is execution evidence for Rust core, Android NDK, Xcode.
- GitHub state: main SHA d3b933f (PR #14 merge), PR #12 closed 2026-09-14 via gh pr close, Issue #11 still open due to 403 but supersession documented, Issue #15 created https://github.com/anthracite-labs/Greenfield5/issues/15, Issue #16 test permission created then attempted close (also 403).
**Learned:**
- GitHub App can create issues (gh issue create succeeded for #15, #16) but cannot comment/close/edit issues via REST or GraphQL (403 Resource not accessible by integration) — PR comments/close work (gh pr comment/close succeeded). Need to document this permission asymmetry.
- forbid(unsafe_code) blocks UniFFI scaffolding which contains unsafe FFI shims; must use deny(unsafe_code) + #[allow(unsafe_code)] for scaffolding module only.
- UniFFI Kotlin bindings require JNA and cargo-ndk + NDK for Android .so; Swift bindings require XCFramework generation with lipo + xcodebuild create-xcframework.
- Placeholder pure-Kotlin/Swift stubs that mirror Rust session logic allow local builds and foundation gate to pass without Rust toolchain, while CI generates real bindings.
- stack.yml path filters must include apps/ios/** for iOS job to trigger.
- selftest.sh needs PyYAML to catch workflows_yaml corruption; install via pip --break-system-packages in sandbox.
**Next:**
- Push branch arena/01a0a1e4-greenfield5 and open PR for Issue #15 using PR template, with RED/GREEN evidence from CI (cargo test, Android unit tests, iOS xcodebuild).
- After CI green, leave PR open for independent ChatGPT review — do not self-merge.
- Then proceed to MoQ/Iroh synthetic-media spike (ADR-0005 follow-ups) using same bridge.
- Consider promoting Stack jobs to required contexts after stabilization (governance change).
- Commit core/Cargo.lock once generated by real toolchain (CI artifact) — never hand-written.

## 2026-09-15 — PR #17 repair: UniFFI Kotlin renames `*Error` to `*Exception`

**Context:** Issue #15 / PR #17 (native↔Rust bridge). Branch recovered from
GitHub, not from the exported Arena patch: remote head of
`arena/01a0a1e4-greenfield5` was `066271a` ("fix(ci): restore Android
real-FFI verification"), newer than the `e9c9703` quoted at handoff. The stale
patch was never applied. `066271a` had already repaired the malformed
`grep -q '^package uniffi.greenfield5` / unterminated-quote damage in
`.github/workflows/stack.yml` and
`apps/android/scripts/generate-uniffi-bindings.sh`: its parent `1be5783` was
867 lines with a duplicated `ios-shell:` job swallowed inside the broken
quoted string, and `066271a` restored the 544-line workflow. Verified by
`git diff a62e591 HEAD -- .github/workflows/stack.yml` = +12/-0, all
additive (fallback removal, `test -f`, package grep, wrong-package guard) —
no gate weakened.
**Did:** Diagnosed the remaining red job and fixed it. Exact-head CI on
`066271a`: `verify` run 34994291164 SUCCESS (Foundation gate + Independent
checks); `Stack` run 34994291167 → Rust core SUCCESS, iOS shell SUCCESS,
Android shell FAILURE at step 9. Check-run annotation (job 104466523275):
`:app:compileDebugKotlin` → `GreenfieldRustBridge.kt:3:27 Unresolved
reference 'BridgeError'`. Root cause (primary source, not guessed):
UniFFI v0.32.1 `uniffi_bindgen/src/bindings/kotlin/gen_kotlin/mod.rs`
`KotlinCodeOracle::convert_error_suffix` rewrites an error enum whose Rust
name ends in `Error` to `*Exception`, reached through
`EnumCodeType::type_label` → `class_name` → `is_name_used_as_error`; upstream
fixture `bindgen-tests/kotlin/tests/errors.kts` maps `TestError`→
`TestException`, `TestFlatError`→`TestFlatException`, and leaves
`TestErrorNoData` unchanged. `gen_swift` has no such rewrite, which is why the
iOS job stayed green while `BridgeTests.swift` keeps using `BridgeError`.
Changes: import `uniffi.greenfield5.BridgeException` in
`GreenfieldRustBridge.kt` (+ comment recording the upstream rule); renamed the
error type in the committed pure-Kotlin fallback
`uniffi/greenfield5/greenfield5.kt` so it still mirrors the generated API and
local no-Rust builds compile; fixed the stale `BridgeError` comment in
`GreenfieldRustBridgeTest.kt`; unescaped two leftover `\"` pairs in the
Android NDK step of `stack.yml` (same incident's damage; they defeated
quoting → SC2086 ×2 + SC2046; only CI log text changes).
**Verified:** `bash scripts/verify.sh` → PASS 16 passed, 0 failed, 2 skipped
(skips by design: `no_app_stack` stood down, `agentshield` advisory 0 files),
exit 0. `bash scripts/selftest.sh` → PASS 128/128, exit 0.
`shellcheck --severity=style` over `git ls-files '*.sh'` (7 scripts, same
invocation as the Independent checks job) → exit 0. Extracted all 32 `run:`
block scalars from both workflows and ran `bash -n` + shellcheck on each →
0 syntax errors; the 3 pre-fix findings dropped to the 2 pre-existing SC2038
`find | xargs` style notes. PyYAML 6.0.3 and shellcheck 0.11.0 were installed
in the sandbox first (`pip3 install --break-system-packages pyyaml
shellcheck-py`; apt is not usable — no root). No Rust, Gradle, or Xcode
toolchain in the sandbox, so cargo/Gradle/xcodebuild remain CI-only evidence.
**Learned:** The Android app had never been compiled against real generated
bindings before `066271a` — at `a62e591` the fallback stub was still present
and the generated file landed in `uniffi/greenfield5_core/` (package
`uniffi.greenfield5_core`, i.e. `core/uniffi.toml` `package_name` was not yet
in play), so the compile passed against the stub and
`RealRustBridgeProofTest` failed on `0.1.0-stub`. `core/uniffi.toml` was added
in `5b065df`. In library mode UniFFI's Kotlin `cdylib_name` defaults to the
library stem (`parse_config` in `bindings/kotlin/mod.rs`), so generated code
does `Native.register(..., "greenfield5_core")` and JNA resolves
`libgreenfield5_core.so` from the `jna.library.path` that
`apps/android/app/build.gradle.kts` already sets — no extra wiring needed.
Workflow `run:` blocks are NOT covered by the repo's `shell_lint` check (it
only lints `*.sh`), so malformed shell inside a block scalar reaches CI
undetected; extracting the blocks and linting them locally is the cheap
pre-flight. GitHub Actions raw logs are still unreachable from the sandbox
(`productionresultssa*.blob.core.windows.net` → EOF); check-run annotations
and uploaded artifacts are the only CI-evidence channels.
**Next:** The renamed import is now the regression guard for the Kotlin error
name — in CI it can only resolve against the real generated bindings, so any
future UniFFI naming change fails the Android compile loudly instead of
silently. Follow-ups deliberately NOT taken here (recorded, not fixed):
`apps/android/scripts/generate-uniffi-bindings.sh` duplicates the workflow's
rm/generate/validate sequence and lacks the `uniffi/greenfield5_core`
wrong-package guard the workflow has — decide whether CI should call the
script instead of inlining it; the 2 SC2038 `find | xargs` style notes; the
fallback's error variants are `data class`/`object` while UniFFI generates
plain `class` with an overridden `message` (tests only assert on
`toString()` containing the variant name, which holds for both).

## 2026-09-15 — PR #17 repair 2: the JVM bridge proof was pointed one level short

**Context:** Same session, same branch. While the naming fix was being
prepared, a concurrent push moved PR #17's head from `066271a` to `9596401`
("fix(android): remove stale generated error import", 1 deletion). The work
was re-based onto the new remote head rather than the stale one; GitHub stays
the source of truth. `9596401` fixed the compile by deleting the unresolved
import, and its Stack run 34995174223 (verify run 34995174204 SUCCESS) then
produced the first real evidence of the app compiling against generated
bindings: the `compileDebugKotlin` warnings name
`uniffi/greenfield5/greenfield5_core.kt`, so `core/uniffi.toml`
`package_name = "uniffi.greenfield5"` is honoured and the fallback really was
deleted. Rust core and iOS shell stayed SUCCESS.
**Did:** Diagnosed the remaining Android failure from the check-run
annotation (job 104472101320): `RealRustBridgeProofTest` failed at
`RealRustBridgeProofTest.kt:42` (`AssertionError`, the "native library must
be loaded in CI" assert) and `:90` (`ComparisonFailure`, version must be
exactly `0.1.0`). Root cause, arithmetic not guesswork:
`apps/android/app/build.gradle.kts` used `file("../../core/target/release")`,
which Gradle resolves against the `:app` project dir `apps/android/app`, i.e.
`<repo>/apps/core/target/release` — a directory that cannot exist. So
`System.load(greenfield5.native.lib.path)` had no library (line 42) and
`jna.library.path` / `java.library.path` / `LD_LIBRARY_PATH` all pointed
nowhere, so UniFFI's generated `Native.register(..., "greenfield5_core")`
could not bind and `coreVersion()` fell back to `0.1.0-fallback` (line 90).
The workflow's own `ls -lh ../../core/target/release/...` looked right only
because that step runs from `apps/android`; and the
`-Djna.library.path=${{ github.workspace }}/core/target/release` on the
gradle command line reaches the Gradle JVM, never the test worker. Fixed by
resolving from `rootProject.projectDir.parentFile.parentFile`
(= `<repo>`, since the Gradle build root is `<repo>/apps/android`) so the
count no longer depends on where `:app` sits. Also added
`testLogging { exceptionFormat = FULL; showStandardStreams = true }` and two
bounded "digest" annotations in the Android Gradle failure branches of
`stack.yml`.
**Verified:** Path arithmetic with `python3 os.path.normpath`:
`apps/android/app + ../../core/target/release` → `<repo>/apps/core/...`
(absent); `+ ../../../...` and `rootProject.projectDir.parentFile.parentFile`
both → `<repo>/core/target/release`, which equals what the workflow's
diagnostic resolves to from `apps/android`. `bash scripts/verify.sh` → PASS
16/0/2 exit 0; `bash scripts/selftest.sh` → PASS 128/128 exit 0;
`shellcheck --severity=style` over all 7 tracked `*.sh` → exit 0. Wrote a
throwaway harness that parses both workflows, extracts all 32 `run:` block
scalars (with `${{ }}` expressions substituted), and runs `bash -n` +
shellcheck on each and `compile()` on every embedded `<<'PY'` heredoc (23 of
them): 0 syntax errors, no new shellcheck finding, only the 2 pre-existing
SC2038 notes. Executed the new digest script against a synthetic Gradle log
shaped like the CI one → valid `::error title=...::` command, 1134 encoded
characters, and it surfaced exactly the `loadError=`/`jna.library.path=` lines
that were previously invisible. `TestExceptionFormat`'s fully qualified name
was confirmed by GitHub code search (6976 `build.gradle.kts` hits) rather than
recalled.
**Learned:** GitHub truncates a check-run annotation **message** to 4096
characters keeping the FRONT, so any publisher that encodes the last 60000
characters of a Gradle log yields only the distribution banner — this is why
several earlier sessions saw the same useless annotation and kept guessing.
Publish a bounded, filtered digest instead. Gradle's default test log format
prints only the exception class and line, so an assertion message carrying the
diagnostics never reaches CI output unless `exceptionFormat = FULL`.
`tasks.withType<Test> { ... }` resolves `file()`/`rootProject` against the
enclosing `Project` receiver, which is why the buggy relative path silently
produced a valid-looking but wrong absolute path.
**Dead ends:** `gh api .../actions/jobs/<id>/logs` → the redirect target
`productionresultssa*.blob.core.windows.net` returns EOF from the sandbox, so
raw job logs are still unreadable; annotations and uploaded artifacts are the
only channels. No JDK/Gradle/kotlinc/cargo/xcodebuild in the sandbox and
`services.gradle.org` is outside the egress allowlist, so the Kotlin DSL
change cannot be compiled locally — it is CI-verified only.
**Next:** Observe the Stack run for this head; the digest annotations now make
any further Android runtime failure readable in one cycle. Open follow-ups,
deliberately not changed here: `environment("CI", System.getenv("CI") ?: "")`
in `build.gradle.kts` sets `CI` to an empty string locally, and
`RealRustBridgeProofTest` tests `System.getenv("CI") != null`, so `isCI` is
true on a developer machine without Rust and the documented local skip never
triggers; `apps/android/scripts/generate-uniffi-bindings.sh` still duplicates
the workflow's rm/generate/validate sequence and lacks the workflow's
`uniffi/greenfield5_core` wrong-package guard; the 2 SC2038 `find | xargs`
notes; and the fallback's error variants are `data class`/`object` where
UniFFI generates plain `class` with an overridden `message`.
