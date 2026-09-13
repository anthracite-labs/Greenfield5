# Product

**Status: intentionally undefined.**

This repository was created from App-Factory, a generic engineering foundation.
No product definition exists yet, and this file deliberately contains no
requirements, personas, features, pricing, or positioning.

## Why this file exists

So that the absence of a product definition is explicit rather than ambiguous.
An agent that finds this file knows that inventing product requirements would
be a violation, not a contribution. Silence is not permission.

## Questions the product owner must answer first

Answer these in a GitHub issue, then land the result here in a reviewed PR.

| Question | Why it blocks everything else |
| :-- | :-- |
| What problem is being solved, for whom? | Without it, scope is unbounded. |
| Who is the user, and what do they do today instead? | Defines the baseline to beat. |
| What is explicitly out of scope? | Non-goals prevent drift more than goals do. |
| What does the first usable version do? | Sets the smallest shippable slice. |
| How is success observed? | Determines what has to be measurable. |
| What data does the product touch? | Drives the security and privacy posture. |
| What constraints are fixed (regulatory, budget, deadline, platform)? | Cannot be discovered later cheaply. |

## What must happen before this file gains content

1. A product owner writes the definition — problem, users, scope, non-goals.
2. The definition lands in a reviewed PR against this file.
3. Any technical consequence (framework, database, hosting, auth) is recorded
   as an ADR in [decisions/](decisions/README.md), not implied by code.
4. Only then may the repository move to the `architecture` and
   `implementation` lifecycle phases in
   [`../config/project.env`](../config/project.env).

## Guardrails in force until then

- No application source code, framework, database, auth scheme, hosting
  target, or UI may be introduced. The guard is
  `scripts/verify.sh` (check `no_app_stack`), driven by `ALLOW_APP_STACK` in
  [`../config/project.env`](../config/project.env).
- Engineering work proceeds on the foundation itself: rules, workflows,
  verification, memory, and decisions.

## Related

- [ARCHITECTURE.md](ARCHITECTURE.md) — the engineering system that exists today
- [DOMAIN.md](DOMAIN.md) — domain vocabulary (also undefined)
- [ROADMAP.md](ROADMAP.md) — lifecycle sequencing
- [FACTORY.md](FACTORY.md) — how this repository was instantiated
- [decisions/](decisions/README.md) — decision record index
