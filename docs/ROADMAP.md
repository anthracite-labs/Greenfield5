# Roadmap

Lifecycle sequencing only. No dates or feature promises — product scope lives
in [PRODUCT.md](PRODUCT.md), decisions live in
[decisions/](decisions/README.md).

The stages below map one-to-one onto `PROJECT_PHASE` in
[`../config/project.env`](../config/project.env), so the roadmap and the
machine-checked repository state cannot drift apart.

```text
factory  →  discovery  →  architecture  →  implementation
   │            │              │                 │
 template   product not     product defined,  stack recorded in an ADR;
 itself     yet defined     stack being       application code allowed
                            decided (ADR)     (ALLOW_APP_STACK=1)
```

## Stage: factory (`PROJECT_PHASE=factory`)

Only the App-Factory template repository itself sits here. Work in scope:
maintaining the generic foundation — rules, workflows, verification, negative
tests, CI, provenance. No product work of any kind.

Exit condition: a new repository is generated from the template and
`scripts/init-project.sh` moves it to `discovery`.

## Stage: discovery (`PROJECT_PHASE=discovery`)

The default state of a newly generated application repository.

- [x] Run `scripts/init-project.sh`, then `scripts/verify.sh` and
      `scripts/selftest.sh` — both must pass before any other work.
      (Done: `PROJECT_NAME`/`PROJECT_SLUG` set in `config/project.env`.)
- [x] Complete the repository-admin checklist in [FACTORY.md](FACTORY.md);
      template copies files, not GitHub configuration.
      (Done: ruleset required contexts enforced; CI green on `main`.)
- [x] Open a product-discovery issue and answer the questions in
      [PRODUCT.md](PRODUCT.md). (Done: PRODUCT.md carries the reviewed MVP
      contract.)
- [x] Record the domain vocabulary in [DOMAIN.md](DOMAIN.md) as it emerges.
      (Done.)

The no-stack guard is active. Application-stack artifacts are rejected.

Exit condition: [PRODUCT.md](PRODUCT.md) contains a reviewed product
definition.

## Stage: architecture (`PROJECT_PHASE=architecture`)

- [x] Open an architecture issue proposing the implementation stack.
      (Done: issue #13, building on accepted
      [ADR-0005](decisions/0005-rust-native-moq-iroh-architecture.md).)
- [x] Evaluate real alternatives; record the choice as an ADR in
      [decisions/](decisions/README.md) with the costs stated.
      (Done: [ADR-0006](decisions/0006-application-stack.md), six
      alternatives with costs.)
- [x] Decide the testing strategy and what the stack-specific CI gate will run.
      (Done: ADR-0006 testing section; `.github/workflows/stack.yml` runs
      Rust fmt/clippy/test and Android unit tests + debug assembly.)

The no-stack guard remains active until the ADR exists. It is not disabled to
"try something out".

Exit condition: an accepted stack ADR.

## Stage: implementation (`PROJECT_PHASE=implementation`)

- [x] Mark the stack ADR with `**Decision Type:** application-stack` and
      `**Status:** accepted`. (Done:
      [ADR-0006](decisions/0006-application-stack.md).)
- [x] Set `PROJECT_PHASE=implementation`, `ALLOW_APP_STACK=1` and
      `STACK_DECISION_ADR=docs/decisions/NNNN-<title>.md` in
      `config/project.env`, in one reviewed PR that changes nothing else.
      (Done in the issue #13 PR, which bundles the transition with the first
      skeleton as that issue explicitly directs; nothing about the gate or
      its required contexts changed.)
      `scripts/verify.sh` rejects the transition unless all three agree, the
      ADR exists, is not the template, carries the stack marker, and is
      accepted. Both `lifecycle` and `no_app_stack` validate this
      independently, so neither can be bypassed by running one check alone.
- [x] Add stack-specific lint/test/build jobs to CI. The foundation gate keeps
      running alongside them; it is never replaced.
      (Done: `.github/workflows/stack.yml`, non-required until stabilized —
      ADR-0006 follow-up 5.)
- [x] Add codemaps under [codemaps/](codemaps/README.md) as code areas appear.
      (Started: [codemaps/core-session.md](codemaps/core-session.md).)

## Explicitly not planned in the foundation

- Any framework, database, auth scheme, hosting target, or UI choice. Those are
  per-project decisions made in the `architecture` stage.
- Native ECC plugin compatibility — Arena has no plugin runtime.
- Browser E2E in the foundation gate — no browser binaries in the sandbox.
- `.git/hooks/` enforcement — hooks do not survive a fresh clone.
