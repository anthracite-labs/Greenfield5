# Domain

**Status: intentionally undefined.**

No domain model, ubiquitous language, entities, or business rules exist yet,
because no product has been defined (see [PRODUCT.md](PRODUCT.md)).

This file exists so that the gap is explicit. It will hold the domain
vocabulary — entities, invariants, state transitions, and the meanings the
team agrees on — once a product definition exists.

## Skeleton to fill in (leave empty until the product is defined)

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

- [PRODUCT.md](PRODUCT.md) — product definition (undefined)
- [ARCHITECTURE.md](ARCHITECTURE.md) — the engineering system
- [decisions/](decisions/README.md) — decision record index
