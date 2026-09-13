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
