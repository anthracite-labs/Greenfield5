# Architecture

**Scope: the engineering system.** There is no application architecture here,
because App-Factory contains no application (see [PRODUCT.md](PRODUCT.md)). A
repository generated from this template records its own application
architecture in this file once an ADR selects a stack.

## Operating model

> **ECC is repository-owned, Arena-executed, ChatGPT-supervised.**

```text
Human product owner
        ↓
ChatGPT — planning / architecture / independent PR review
        ↓
GitHub — durable source of truth
        ↓
Arena Agent Mode — developer / executor
        ↓
ECC-on-Arena repository adapter
        ↓
branch → tests → PR → CI → ChatGPT review → merge
```

## The system that exists

```text
                    ┌─────────────────────────────┐
                    │  ChatGPT (independent layer)│
                    │  planning input, PR review  │
                    └──────────────┬──────────────┘
                                   │ reviews the real diff
                                   ▼
┌──────────────────────────────────────────────────────────────────┐
│  GitHub  (durable source of truth)                               │
│  issues · branches · PRs · Actions · default-branch ruleset      │
└───────────────────────────────┬──────────────────────────────────┘
                                │ clone / push / gh api
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│  Arena Agent Mode sandbox (ephemeral)                            │
│  reads .ecc/BOOTSTRAP.md → loads 1–2 skills → plans → implements │
│  → reviews → runs scripts/verify.sh → commits → opens PR         │
└───────────────────────────────┬──────────────────────────────────┘
                                │ only committed files survive
                                ▼
                    ┌─────────────────────────────┐
                    │  .ecc/  (repository-owned)  │
                    │  rules · skills · roles ·   │
                    │  VERSION · UPSTREAM.md      │
                    └─────────────────────────────┘
```

## Component responsibilities

| Component | Responsibility | Deliberately does not |
| :-- | :-- | :-- |
| `FOUNDATION_VERSION` | The App-Factory template version of this repository | Track the product or the ECC version |
| `.ecc/BOOTSTRAP.md` | Small, complete session protocol | Duplicate rules; load every workflow |
| `.ecc/rules/` | Standing, always-in-force rules | Describe task procedure (that is skills) |
| `.ecc/skills/` | On-demand task workflows, routed by `INDEX.md` | Auto-load; run without being read |
| `.ecc/roles/` | Sequential review personas for one agent | Pretend to be parallel subagents |
| `.ecc/VERSION`, `.ecc/UPSTREAM.md` | Upstream ECC provenance and licence record | Vendor upstream code |
| `config/project.env` | Committed lifecycle state (phase, stack guard) | Hold secrets or be sourced by a shell |
| `config/main-ruleset.json` | Portable branch-protection intent | Apply itself; contain instance ids |
| `docs/MEMORY.md` | Durable cross-session memory | Replace ADRs or PR descriptions |
| `docs/decisions/` | Durable trade-off records | Track task state |
| `docs/FACTORY.md` | Instantiation and admin checklist | Automate GitHub administration |
| `scripts/verify.sh` | Deterministic quality gate | Test application behaviour (none exists) |
| `scripts/selftest.sh` | Negative tests that prove the gate can fail | Modify the real working tree |
| `scripts/init-project.sh` | One-time, non-destructive project identity setup | Commit, push, or change GitHub settings |
| `scripts/bootstrap.sh` | Session briefing from repository state | Mutate anything |
| `scripts/sync-ecc.sh` | Upstream inspection and diff preparation | Overwrite local adaptations |
| `.github/workflows/verify.yml` | Independent execution of the same gate | Trust an agent's self-report |

## Lifecycle as repository state

The foundation's no-stack guard is not a permanent property of the gate; it is
a function of committed configuration.

```text
config/project.env                 scripts/verify.sh
──────────────────                 ─────────────────
PROJECT_PHASE=discovery      ──▶   check_lifecycle   validates the state itself
ALLOW_APP_STACK=0            ──▶   check_no_app_stack rejects stack artifacts
STACK_DECISION_ADR=

           ── reviewed PR, after an accepted stack ADR ──▶

PROJECT_PHASE=implementation ──▶   check_lifecycle   accepts: phase + ADR agree
ALLOW_APP_STACK=1            ──▶   check_no_app_stack stands down (SKIP)
STACK_DECISION_ADR=docs/decisions/NNNN-....md
```

A single shared helper, `validate_stack_transition`, decides whether the guard
may stand down, and **both** `check_lifecycle` and `check_no_app_stack` call
it. Neither check trusts the other to have run, so `verify.sh
--only=no_app_stack` reaches the same verdict as a full run — a check that
stands down because it assumed another check validated the state is not a
guard.

The transition is rejected unless `ALLOW_APP_STACK=1`,
`PROJECT_PHASE=implementation`, and `STACK_DECISION_ADR` all agree **and** the
referenced ADR exists, is not the `0000-template.md` skeleton, carries
`**Decision Type:** application-stack`, and is marked
`**Status:** accepted`. Existing on disk is not approval. Both directions, and
every rejection path, are covered by negative tests in
`scripts/selftest.sh`.

## Design principles

1. **Small startup context.** Bootstrap plus the always-read set is a few
   pages. Everything else is loaded only when the task needs it.
2. **Everything durable is in Git.** The sandbox dies between sessions;
   uncommitted knowledge does not exist.
3. **Verification is a program, not a promise.** A committed script with a
   non-zero exit path, re-run by CI, is the only accepted evidence of quality.
4. **A gate that never fails proves nothing.** `scripts/selftest.sh` injects
   faults into a throwaway copy and asserts the gate rejects each one.
5. **Adapt, do not import.** Upstream ECC is large; this adapter carries 10
   workflows, 4 rules, and 3 personas, and never claims to be native ECC.
6. **State, not surgery.** Lifecycle changes are config diffs reviewed in a PR,
   never edits to the script that enforces them.
7. **No product assumptions.** The template chooses no framework, database,
   auth scheme, or hosting target for anyone.

## Execution environment

See [ARENA.md](ARENA.md) for the concise, generic harness reference and the
re-verification instruction. Environment facts are project-local and must be
re-checked rather than inherited as guarantees.

## Related

- [ROADMAP.md](ROADMAP.md) — lifecycle stages
- [FACTORY.md](FACTORY.md) — instantiating a new application repository
- [SECURITY.md](SECURITY.md) — repository security policy
- [decisions/](decisions/README.md) — decision record index
- [../.ecc/UPSTREAM.md](../.ecc/UPSTREAM.md) — ECC provenance and omissions
