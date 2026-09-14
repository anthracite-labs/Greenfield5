# Codemap: core session model (`core/`)

Describes the tree as of 2026-09-14 (issue #13 skeleton, pre-GREEN commit).
All public function bodies are `todo!()` stubs until the implementation
commit lands — types, codes, error precedence, and tests are the contract.

## What this crate is

`greenfield5-core` — the shared Rust core from
[ADR-0005](../decisions/0005-rust-native-moq-iroh-architecture.md): owns
session state, roles, pairing decisions. Both native shells (Android, iOS)
will talk to it **only** through `seam.rs`; UI code must never touch
transport internals. No dependencies (zero-dep crate by design; transport
crates arrive with the MoQ/Iroh follow-up).

## Files

| Path | Contents |
| :-- | :-- |
| `core/Cargo.toml` | `greenfield5-core`, edition 2024, rust-version 1.98, publish=false, zero deps |
| `core/rust-toolchain.toml` | Pins 1.98.1 + rustfmt/clippy (CI installs exactly this) |
| `core/src/lib.rs` | `pub mod seam; pub mod session;` + `version()`; `#![forbid(unsafe_code)]`, `#![deny(missing_docs)]` |
| `core/src/session.rs` | The state model: enums, `Session`, `SessionError` + tests |
| `core/src/seam.rs` | FFI-shaped façade: `CoreSession`, `CoreError`, `codes` constants + tests |

## Call flow (target shape, post-bridge)

```text
Android MainActivity / iOS RootView        (UI only — no session logic)
        ↓ future bridge (UniFFI or pinned FFI, ADR-0006 follow-up 1)
seam::CoreSession        u8 codes in, u8 codes out (FFI-safe surface)
        ↓ translates codes ↔ enums
session::Session         the only state machine; apply(command) → state
```

Nothing else may construct or mutate `Session` across the seam: shells send
`SessionCommand` codes and read back state/error codes.

## session.rs — key types

| Type | Values (wire codes) |
| :-- | :-- |
| `Role` | Sender=0, Viewer=1 |
| `ConnectionMode` | Local=0, Direct=1, Internet=2 (PRODUCT.md §4) |
| `SessionState` | Idle=0, AwaitingPeer=1, AwaitingApproval=2, Active=3, SharingInterrupted=4, Ended=5 |
| `SessionCommand` | StartPairing=0, RequestJoin=1, PeerRequestedJoin=2, ApproveViewer=3, ApprovalReceived=4, CaptureStarted=5, CaptureStopped=6, End=7 |
| `SessionError` | SessionEnded, RoleMismatch, ViewerAlreadyConnected, InvalidTransition{..} |

`Session::apply(command) -> Result<SessionState, SessionError>` is the only
mutator. `code()`/`from_code()` round-trips keep the wire representation
stable for the FFI layer.

### Error precedence (tested)

When several errors could apply, the most terminal wins:

```text
SessionEnded > RoleMismatch > ViewerAlreadyConnected > InvalidTransition
```

Rationale: an ended session rejects everything; a wrong-role command is a
protocol bug (louder than a busy-viewer condition); a duplicate viewer only
matters while the session lives.

### State machine rules encoded in tests (PRODUCT.md §3–§5)

- 1:1 only: a second viewer join while one is connected →
  `ViewerAlreadyConnected`.
- Sender approval gates Active: viewer cannot reach Active without
  `ApproveViewer` (sender side) / `ApprovalReceived` (viewer side).
- Role-specific commands: e.g. `CaptureStarted` is sender-only →
  `RoleMismatch` from a viewer session.
- `Ended` is terminal: any command afterwards → `SessionEnded`.
- Interruption: `CaptureStopped` while Active → `SharingInterrupted`,
  recoverable; `End` always allowed until ended.

## seam.rs — FFI-shaped surface

| Item | Purpose |
| :-- | :-- |
| `CoreSession::start(role_code, mode_code)` | Construct from u8 codes; invalid code → `CoreError::InvalidCode(..)` |
| `send_command(command_code) -> Result<u8, CoreError>` | One-shot command; returns new state code |
| `role_code()` / `connection_mode_code()` / `state_code()` | Read-only accessors, u8 |
| `CoreError` | `Session(SessionError)` wrapper + `InvalidCode(u8)`; Display delegates |
| `codes::*` constants | Single source of truth for shell-side code values |
| `core_version()` | Version handshake for bridge compatibility checks |

The u8-code surface is deliberately what a UniFFI/JNI/C-ABI binding can
carry without leaking Rust enums across the boundary — that is the seam
decision in ADR-0006 (growable into UniFFI without UI coupling).

## Tests

- `core/src/session.rs` `mod tests` (~20): code round-trips, happy paths per
  role, error precedence, terminal state, 1:1 constraint, approval gating.
- `core/src/seam.rs` `mod tests` (8): invalid codes rejected, façade mirrors
  `Session` behaviour, constants match enum codes.
- Run: `cargo test` in `core/` (CI: `.github/workflows/stack.yml`, job
  "Rust core" — fmt → clippy `-D warnings` → test).

## Failure modes to keep in mind when extending

- Adding a variant without a wire code breaks the FFI contract — codes are
  committed API, append-only.
- `#![deny(missing_docs)]`: every public item needs a doc comment.
- `#![forbid(unsafe_code)]`: the future bridge crate may need `unsafe` at
  the boundary; that belongs in a separate, reviewed crate, not here.
