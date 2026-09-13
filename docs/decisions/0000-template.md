<!-- Template: copy to NNNN-<kebab-title>.md and fill every section.
     Procedure: ../../.ecc/skills/decisions.md -->

# ADR-NNNN: <Decision title>

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | superseded by ADR-NNNN
**Deciders:** <who or what decided>

<!-- STACK DECISIONS ONLY: the ADR that selects the application stack must
     also carry a Decision Type metadata line whose value is the word
     "application-stack", written in the same bold-label style as the fields
     above and placed alongside them.

     scripts/verify.sh requires that line, plus an accepted status, before
     ALLOW_APP_STACK=1 is permitted in config/project.env. It is validated as
     a real standalone metadata line: text inside comments like this one, or
     inside code fences, deliberately does NOT count. The literal marker is
     therefore not reproduced here - see docs/FACTORY.md for the exact line to
     copy. -->

## Context

<The situation, constraints, and forces at play. 2-5 sentences. Cite evidence:
a command output, a verified capability, an upstream ref — not an impression.>

## Decision

<The change being made, stated plainly. 1-3 sentences.>

## Alternatives considered

### Alternative: <name>

- **Pros:** <benefits>
- **Cons:** <drawbacks>
- **Why not:** <the specific reason this was rejected>

## Consequences

### Positive

- <what becomes easier>

### Negative

- <what becomes harder, or what this costs>

### Follow-ups

- <work this decision creates, or explicitly defers>
