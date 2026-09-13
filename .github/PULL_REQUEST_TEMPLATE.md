## What changed

<!-- One or two paragraphs. What is in this diff, and why. -->

## Issue

<!-- e.g. Closes #N — or Refs #N when the work is partial. -->

## Acceptance criteria conformance

<!-- One row per criterion from the issue. Evidence = a command and its actual
     output, or a file path. "Done" is not evidence. -->

| Criterion (verbatim from the issue) | Where implemented | Evidence | Verdict |
| :-- | :-- | :-- | :-- |
|  |  |  | MET / PARTIAL / NOT MET / N/A |

## Verification

```text
command:  bash scripts/verify.sh
result:   <PASS/FAIL — N passed, N failed, N skipped>
executed: <name the check or code path the run actually reached>

command:  bash scripts/selftest.sh
result:   <PASS/FAIL — N cases behaved as asserted>
```

- [ ] `bash scripts/verify.sh` exits 0 locally
- [ ] `bash scripts/selftest.sh` exits 0 locally (the gate still rejects faults)
- [ ] GitHub Actions `Foundation gate` and `Independent checks` are green
      (or the failure is explained below)
- [ ] Any skipped check is named and its reason stated

## Reviews performed

- [ ] Code review (`.ecc/skills/code-review.md`)
- [ ] Spec review against the issue (`.ecc/skills/spec-review.md`)
- [ ] Security review — mandatory if `.ecc/rules/security.md` triggers apply
- [ ] Complexity pass: nothing speculative, no unused abstraction

## Project memory and decisions

- [ ] `docs/MEMORY.md` updated with this session's entry
- [ ] ADR added in `docs/decisions/` (or: no durable decision was made)

## Scope confirmation

- [ ] No product requirements introduced
- [ ] No framework, database, auth, hosting, or UI choice introduced
- [ ] No application source code added (or the ADR that permits it is linked)
- [ ] `config/project.env` unchanged — or the lifecycle transition is explicit,
      ADR-backed, and is the only thing this PR changes
- [ ] No guard was weakened or disabled to make this change fit
- [ ] No GitHub administrative setting was changed by a script
- [ ] The ECC adapter is described as an adaptation, not native ECC
- [ ] ECC was not upgraded (or the upgrade has its own issue, ADR, and version bump)

## Known limitations / follow-ups

<!-- What this PR does not do, what could not be verified here and why, and
     what the next step should be. -->

## For the independent reviewer

<!-- Anything ChatGPT should look at hardest: the riskiest file, the assumption
     you are least sure of, the check you could not run. -->
