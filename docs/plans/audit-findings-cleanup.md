# Plan — audit-findings cleanup (post-audit maintenance)

**Base:** `main` @ `5a64ee9e7bbc8904416851eae1a4573b13dc2d07` (re-fetched this
session: branch `arena/01a0ab42-greenfield5`, tree clean).
**Scope owner:** the read-only evidence-first audit performed immediately before
this task. No GitHub issue number; the audit's findings are the acceptance
input. Issue #11 is explicitly **not** touched.
**Skills loaded:** `planning.md` (this file), `tdd.md` (parser change),
`code-review.md`, `security-review.md` (CI workflow change), `verification.md`.

## Requirement

Resolve exactly four verified findings that the audit proved against the current
tree, and nothing else:

1. **F1 (MEDIUM)** — `docs/codemaps/core-session.md` describes a pre-bridge core
   and contradicts ADR-0007 and current code.
2. **F2 (LOW)** — several documentation/comments assert states the tree has
   moved past (product "undefined"; Stack CI without iOS; wrong ROADMAP
   follow-up reference; Android bindgen script claiming CI calls it; iOS bridge
   comment naming the wrong stub file; both shells saying the bridge "has not
   landed").
3. **F3 (LOW, reclassified by the task owner)** — the iOS CI *success-summary
   parser* cannot recognise Swift Testing output, so a green iOS job publishes
   `WARNING: no "Executed N tests" count found - NOT EVIDENCE` even though the
   raw log shows 4 `AppNavigationTests` + 7 `BridgeTests` = 11 passing cases and
   `** TEST SUCCEEDED **`. The `xcodebuild` gate itself is **not** weakened; the
   defect is only in the summarisation of a *passing* run.
4. **F4 (LOW)** — two ProGuard keep rules name classes/packages that do not
   exist.

## Acceptance criteria (verbatim intent from the task)

- F1: correct the UniFFI/`thiserror` dependency statement, the "future bridge"
  framing, the file table (`uniffi_api.rs`, `uniffi.toml`, `uniffi-bindgen.rs`,
  `Cargo.lock`), the unsafe-boundary statement (ADR-0007's exact model), the
  capture-command role claim, the `CoreError` variant descriptions, test-count
  wording, and the date/current-state marker. Source + ADR-0007 are authority.
- F2: correct only demonstrably stale statements; no stylistic rewrite; no scope
  expansion.
- F3: preserve the `xcodebuild` gate; do not weaken test execution; do not turn
  the warning into a success without evidence; recognise the real Swift Testing
  case/result output; report a meaningful executed-test count or an equivalent
  count derived from verified passing test-case lines; keep annotations bounded.
- F4: remove/correct only keep rules that refer to nonexistent packages/classes;
  no broader suppression; no new blanket `-dontwarn`/`-keep **`; keep the
  release path build-proven by CI.
- Guardrails: no architecture, semantic, toolchain, product, ADR, or Issue #11
  change; no BoltFFI revival; no MoQ/Iroh code.

## Surveyed ground (read this session)

- `docs/codemaps/core-session.md`, `docs/codemaps/README.md`,
  `docs/DOMAIN.md`, `README.md`, `docs/ROADMAP.md`,
  `docs/decisions/0007-uniffi-bridge.md`, `docs/decisions/0006-application-stack.md`.
- `core/Cargo.toml`, `core/Cargo.lock`, `core/rust-toolchain.toml`,
  `core/uniffi.toml`, `core/uniffi-bindgen.rs`, `core/src/lib.rs`,
  `core/src/session.rs`, `core/src/seam.rs`, `core/src/uniffi_api.rs`.
- `apps/android/app/proguard-rules.pro`,
  `apps/android/app/src/main/java/dev/greenfield5/app/bridge/GreenfieldRustBridge.kt`,
  `apps/android/app/src/main/java/dev/greenfield5/app/ui/AppNavigation.kt`,
  `apps/android/app/src/main/java/dev/greenfield5/app/MainActivity.kt`,
  `apps/android/scripts/generate-uniffi-bindings.sh`.
- `apps/ios/Greenfield5/Bridge/GreenfieldRustBridge.swift`,
  `apps/ios/Greenfield5/Greenfield5App.swift`,
  `apps/ios/Greenfield5/AppNavigation.swift`.
- `.github/workflows/stack.yml` (iOS test job + success notice).
- CI evidence for F3: check-run annotations `104749318038` (run `35082423424`)
  and, for verbatim Swift Testing output shapes, check-runs `104847425246` /
  `104881538243` (this repository's own macOS jobs).

## Chosen approach

Minimal, finding-scoped edits. The parser change is a Python heredoc inside
`.github/workflows/stack.yml`; it is developed RED→GREEN with a local harness
that **extracts the heredoc from the workflow file itself** (no re-implemented
stand-in) and runs it against fixture logs built from verbatim CI lines.

Fixture grounding: the GitHub job-log blob host
(`productionresultssa*.blob.core.windows.net`) is unreachable from this sandbox
(SSL_ERROR_SYSCALL, reproduced twice), so the observable CI channel is
check-run annotations. Verbatim shapes captured from this repository's CI:

```
✔ Test run with 19 tests passed after 1.674 seconds.        ← U+2714, pass summary
✘ Test run with 8 tests failed after 2.943 seconds with 2 issues.   ← U+2718, fail summary
✘ Test completionInsideThePollFrameNeverFreesTheFuture() failed after 0.112 seconds with 1 issue.
	 Executed 0 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds   ← XCTest counter; counts XCTest cases only
** TEST SUCCEEDED **
```

## Phases (each names its verification)

1. **F4 — ProGuard.** Confirm the real packages (`dev.greenfield5.app.bridge`,
   `uniffi.greenfield5`), delete the two dead keep rules, add a one-line reason.
   Verify: re-grep the file; full R8 proof is CI (`assembleRelease`) because no
   JDK/Gradle exists locally.
2. **F1 — codemap.** Targeted edits against `core/**` and ADR-0007.
   Verify: `grep` for every removed string returns nothing; `verify.sh` `links`.
3. **F2 — stale statements.** Eight targeted file edits.
   Verify: `git grep` for each stale phrase returns nothing.
4. **F3 — parser.** RED: current parser vs the Swift Testing fixture → must emit
   the observed `NOT EVIDENCE` warning. GREEN: patched parser → reports the
   summary count `11` and never warns on that fixture; negative fixtures
   (no-signal log, legacy `Executed 0 tests` only) must still warn rather than
   fabricate a pass.
   Verify: harness run, then exact-head `Stack` CI.
5. **Close-out.** `docs/MEMORY.md` entry, `git diff main...HEAD` read, commit,
   push, PR, observe exact-head `Stack` + `verify` runs.

## Risks / unknowns

- No `cargo`/`java`/`gradle`/`swift`/`xcodebuild` locally ⇒ Rust, Android and
  iOS execution evidence is CI-only; historical runs are not evidence for the
  new head.
- `stack.yml` is path-filtered, so this PR's own `Stack` run **will** trigger.
- The sandbox cannot read raw job logs; the parser's post-change output must be
  read back as a check-run annotation.
- Verification tooling needs PyYAML + shellcheck installed in the sandbox
  (`pip3 install --break-system-packages pyyaml shellcheck-py`), otherwise
  `verify.sh` skips two checks and `selftest.sh` fails one case.

## Out of scope (explicitly not doing)

Issue #11; MoQ/Iroh; MediaProjection/ReplayKit; backend/database; UniFFI or any
toolchain upgrade; BoltFFI revival; ADR edits; session semantics; UI behaviour;
stylistic doc rewrites; new CI checks or gates.
