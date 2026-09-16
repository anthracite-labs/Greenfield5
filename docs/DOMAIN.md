# Domain

**Status: product defined, domain vocabulary not yet recorded.**

The product is defined in [PRODUCT.md](PRODUCT.md) (reviewed MVP contract,
Issue #3). What is still missing is the domain record itself: entities,
ubiquitous language, invariants, and business rules in one place.

This file exists so that the gap is explicit. Filling it from the now-executable
session model is ADR-0006 follow-up 8. Until then the authoritative statements
live where they are enforced — session semantics in
[`core/src/session.rs`](../core/src/session.rs) and
[codemaps/core-session.md](codemaps/core-session.md), product rules in
[PRODUCT.md](PRODUCT.md).

## Skeleton to fill in (leaves intentionally empty until the domain record is written)

### Entities

| Entity | Definition | Identity | Invariants |
| :-- | :-- | :-- | :-- |
|  |  |  |  |

### Ubiquitous language

| Term | Means | Does NOT mean |
| :-- | :-- | :-- |
|  |  |  |

### State transitions

| From | Event | To | Guard |
| :-- | :-- | :-- | :-- |
|  |  |  |  |

### Business rules

| Rule | Rationale | Enforced where |
| :-- | :-- | :-- |
|  |  |  |

## Terms that do have meaning today (engineering, not product)

These describe the foundation, not any product domain.

| Term | Meaning here |
| :-- | :-- |
| **Foundation** | The generic engineering system shipped by App-Factory. |
| **Adapter** | `.ecc/` — the ECC-on-Arena adaptation. Not native ECC. |
| **Skill / workflow** | An on-demand Markdown procedure under `.ecc/skills/`. |
| **Rule** | A standing, always-in-force constraint under `.ecc/rules/`. |
| **Role** | A sequential review persona under `.ecc/roles/` (not a subagent). |
| **Gate** | `scripts/verify.sh` — deterministic, non-zero on failure. |
| **Lifecycle phase** | `PROJECT_PHASE` in `config/project.env`. |
| **No-stack guard** | The `no_app_stack` check, driven by `ALLOW_APP_STACK`. |
| **Project memory** | `docs/MEMORY.md` — append-only, Git-tracked. |
| **ADR** | A record under `docs/decisions/` for a durable trade-off. |

## Related

- [PRODUCT.md](PRODUCT.md) — product definition (reviewed MVP contract)
- [ARCHITECTURE.md](ARCHITECTURE.md) — the engineering system
- [decisions/](decisions/README.md) — decision record index
