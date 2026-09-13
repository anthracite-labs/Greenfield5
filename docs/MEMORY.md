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
