# App-Factory

A reusable, product-agnostic engineering foundation for building applications
with **Arena Agent Mode** under **ECC** discipline and **ChatGPT** review.

> **ECC is repository-owned, Arena-executed, ChatGPT-supervised.**

**Foundation version:** see [`FOUNDATION_VERSION`](FOUNDATION_VERSION) — `0.1.0`.

This repository is the reusable template source. It contains **no application**:
no framework, no database, no auth scheme, no hosting target, no UI, and no
product definition. That is the point. What it ships is the machinery that makes
those decisions disciplined when they are eventually made.

## What you get

| | |
| :-- | :-- |
| **ECC-on-Arena adapter** | Engineering rules, 10 on-demand workflows, 3 review personas, adapted from ECC v2.2.0 (MIT), fully attributed. Not native ECC. |
| **Deterministic gate** | `scripts/verify.sh` — 17 committed checks, non-zero on failure, re-run independently in CI. |
| **Negative tests** | `scripts/selftest.sh` — injects faults into a throwaway copy and asserts the gate rejects each one. A gate that only ever passes proves nothing. |
| **Lifecycle state** | `config/project.env` — factory → discovery → architecture → implementation, with a no-stack guard that stands down only via a reviewed, ADR-backed transition. |
| **Portable governance** | `config/main-ruleset.json` — a branch-protection payload with no instance ids, applicable to any new repository. |
| **Clean documentation set** | Product, domain, roadmap, architecture, security, memory, and factory docs that start empty on purpose. |

## Operating model

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

## Starting a session

Arena auto-loads nothing. One short instruction is enough:

> Read `.ecc/BOOTSTRAP.md`, initialize the project engineering protocol,
> inspect project memory and the skill index, then work GitHub Issue #X. Load
> only skills relevant to that issue.

Or print the same briefing:

```bash
bash scripts/bootstrap.sh
```

Startup context is deliberately small: the bootstrap protocol, the standing
engineering rules, the skill index, project memory, and the lifecycle config.
Workflows are loaded one or two at a time, only when the task calls for them.

## Creating a new application from this foundation

Read [`docs/FACTORY.md`](docs/FACTORY.md) — it is the authoritative checklist.
Before expecting GitHub's **Use this template** action, confirm that this source
repository is administratively marked as a **Template repository**. That GitHub
setting is not represented by committed files; if it is not enabled, use the
copy fallback documented in `docs/FACTORY.md` rather than treating the repository
contents as proof that template mode is active.

The short version after the new repository exists:

```bash
bash scripts/init-project.sh --name "<Project Name>"   # non-destructive; does not commit
bash scripts/verify.sh
bash scripts/selftest.sh
```

> **A template repository copies files, not GitHub configuration.** Visibility,
> branch rulesets, GitHub App installations, Actions permissions, secrets, and
> required checks are **not** inherited and must be set up by a human. No
> script here performs repository administration.

## Repository map

```text
AGENTS.md                  engineering entry point for agents and humans
FOUNDATION_VERSION         App-Factory foundation version (0.1.0)
.ecc/                      the ECC-on-Arena adapter (rules, skills, roles, provenance)
config/project.env         lifecycle phase and the application-stack guard
config/main-ruleset.json   portable branch-protection template
docs/                      product, domain, architecture, roadmap, security, memory, factory
docs/decisions/            architecture decision records
scripts/                   verify, selftest, bootstrap, init-project, sync-ecc
.github/workflows/verify.yml   independent CI execution of the same gate
```

## Quality gate

```bash
bash scripts/verify.sh     # authoritative — exits non-zero on failure
bash scripts/selftest.sh   # proves the gate still rejects faults
```

GitHub Actions runs both on every push and pull request, as the jobs
**`Foundation gate`** and **`Independent checks`**. Those exact names are the
required status contexts in `config/main-ruleset.json`, and the gate fails if
the workflow and the ruleset ever disagree.

## Provenance and licensing

- The `.ecc/` adapter is derived from
  [Everything Claude Code (ECC)](https://github.com/affaan-m/ECC) v2.2.0, MIT
  licensed. The full upstream notice is committed at
  [`.ecc/LICENSE-ECC`](.ecc/LICENSE-ECC) and verified by sha256; every adapted
  file carries an attribution header. Details:
  [`.ecc/UPSTREAM.md`](.ecc/UPSTREAM.md).
- This is an **adaptation, not native ECC**. Arena has no plugin runtime, no
  slash commands, no lifecycle hooks, and no subagents; no compatibility with
  the ECC runtime is claimed.
- **Factory provenance:** App-Factory v0.1.0 was derived from the reviewed
  source foundation
  `anthracite-labs/Ditto@5d9cc349d264f73e8da913da9d2cea664522237d`. Generated
  repositories identify themselves by `FOUNDATION_VERSION` and inherit none of
  that project's history.
