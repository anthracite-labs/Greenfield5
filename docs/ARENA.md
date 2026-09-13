# Arena Execution Environment — concise reference

**Read this only when a task touches tooling, network, or CI limits.** It is a
short orientation, not a guarantee. Every statement below is an *expectation to
re-verify in the current session*, because harness behaviour changes and this
template is reused across projects and across time.

## Provenance of this reference

App-Factory was derived from a source foundation that included a ~40 KB
point-in-time Arena capability audit performed on 2026-09-06. That audit is
**historical provenance for the original derivation, not a universal runtime
guarantee**, and it is deliberately not carried into this template: a large
startup document that ages badly is worse than a short one that tells you to
check. This page is the distilled, generic summary.

If a project needs a full audit, perform a fresh one, commit it as a dated
project document, and reference it from `docs/MEMORY.md`.

## Expectations that shape the engineering system

| Area | Expectation | Consequence in this foundation |
| :-- | :-- | :-- |
| Persistence | Nothing survives a session except what is committed and pushed. | Git is the only memory; `docs/MEMORY.md` is append-only. |
| Instruction loading | No file is auto-loaded. `AGENTS.md` is not magic. | Sessions start by explicitly reading `.ecc/BOOTSTRAP.md`. |
| Shell state | Variables, `cd`, and exports do not survive between tool calls. | Scripts resolve their own repo root; no cross-call state. |
| Long-lived processes | Need the dedicated process tools, not a shell call. | The foundation gate is one-shot and needs no server. |
| Servers / preview | Bind `0.0.0.0`; the browser is not inside the sandbox. | Relevant only after a stack is chosen; not used here. |
| Network egress | Allowlisted. Assume `github.com`, `api.github.com`, and the npm/PyPI registries; assume everything else is blocked. | `sync-ecc.sh` uses the GitHub API only; AgentShield comes from npm. |
| Browsers | No browser binaries and no reliable download path. | No browser E2E in the foundation gate. |
| Harness features | No plugin runtime, slash commands, lifecycle hooks, or subagent API. | Roles are sequential personas; enforcement is `scripts/verify.sh` + CI, never `.git/hooks/`. |
| Git / GitHub | `git` and `gh` are available and authenticated for the session repository. | Branch → PR → CI → review is the whole workflow. |
| CI | GitHub Actions runs the same committed gate independently. | Quality never depends on an agent's self-report. |

## How to verify rather than assume

| Question | Check it with |
| :-- | :-- |
| Is a tool present? | `command -v <tool>` before relying on it. |
| Is a host reachable? | One attempt; on failure report it, do not retry blindly. |
| Is the workflow permission sufficient? | Read the failure from the CI run; do not guess. |
| Did a check actually run? | Read the gate's own PASS/SKIP/FAIL line. A SKIP is not a PASS. |

State plainly in the PR what could not be verified in the session. An
unverifiable claim is a defect, not a detail.

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md) — the engineering system
- [../.ecc/rules/engineering.md](../.ecc/rules/engineering.md) — the standing rules that cite these expectations
