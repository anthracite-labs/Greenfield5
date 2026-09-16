# Codemap: core session model and UniFFI bridge (`core/`)

Describes the tree as of 2026-09-16, base `main` @ `5a64ee9e` (implementation
phase; ADR-0006 stack, UniFFI bridge per ADR-0007). Types, wire codes, error
precedence, and the test suite are the committed contract; `Session::apply` is
the only mutator.

## What this crate is

`greenfield5-core` — the shared Rust core from
[ADR-0005](../decisions/0005-rust-native-moq-iroh-architecture.md): owns
session state, roles, pairing decisions. Platform capture, permissions,
lifecycle and media stay native. The native shells reach the core through the
**production UniFFI bridge** ([ADR-0007](../decisions/0007-uniffi-bridge.md)),
which delegates to the same state machine the u8-code seam describes; UI code
must never touch transport internals (which do not exist yet — MoQ/Iroh is the
next spike, Issue #11).

Dependencies exist now: `uniffi = { version = "0.32.1", features = ["cli"] }`
and `thiserror = "2"`, pinned in `core/Cargo.lock`. The crate is no longer
zero-dep; transport crates still arrive with the MoQ/Iroh follow-up.

## Files

| Path | Contents |
| :-- | :-- |
| `core/Cargo.toml` | `greenfield5-core`, edition 2024, rust-version 1.98, publish=false, `crate-type = ["lib","cdylib","staticlib"]`, deps `uniffi` 0.32.1 + `thiserror` 2, `[[bin]] uniffi-bindgen` |
| `core/Cargo.lock` | Committed lockfile (81 packages); pins the whole `uniffi_*` family at 0.32.1 |
| `core/rust-toolchain.toml` | Pins 1.98.1 + rustfmt/clippy (CI installs exactly this) |
| `core/uniffi.toml` | `[bindings.kotlin] package_name = "uniffi.greenfield5"` — the package the Android bridge imports |
| `core/uniffi-bindgen.rs` | 3-line binary entry calling `uniffi::uniffi_bindgen_main()`; used by CI as `cargo run --locked --bin uniffi-bindgen generate --library … --language {kotlin,swift}` |
| `core/src/lib.rs` | `pub mod seam; pub mod session; pub mod uniffi_api;` + `version()`; crate-root lint attributes (see unsafe boundary) and `uniffi::setup_scaffolding!()` |
| `core/src/session.rs` | The state model: enums, `Session`, `SessionError` + 25 tests |
| `core/src/seam.rs` | u8-code façade: `CoreSession`, `CoreError`, `codes` constants + 8 tests |
| `core/src/uniffi_api.rs` | The UniFFI bridge: mirror enums, `BridgeError`, `GreenfieldSession` object, code helpers + 7 tests |

## Call flow (current shape)

```text
Android MainActivity / iOS RootView          (UI only — no session logic)
        ↓
GreenfieldRustBridge.kt / .swift             (shell wrapper: load + narrow API)
        ↓
UniFFI-generated bindings                    (Kotlin via JNA / Swift linked to
uniffi/greenfield5/greenfield5_core.kt  or     Greenfield5Core.xcframework)
greenfield5_core.swift
        ↓
uniffi_api::{GreenfieldSession, …}           (typed enums + u8-code compat)
        ↓
session::Session                             the only state machine;
                                             apply(command) → state
```

Shells drive the session through the bridge (typed commands or stable u8
codes). The u8-code vocabulary is committed API in `seam::codes` and is
mirrored by the bridge's `role_*_code()` / `mode_*_code()` helpers and by
`state_code()` / `send_command()`; tests pin the two in sync. Wire codes are
append-only.

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
- Role guards apply to `StartPairing`, `RequestJoin`, `PeerRequestedJoin`,
  `ApproveViewer` and `ApprovalReceived` only.
- `CaptureStarted` / `CaptureStopped` are deliberately **not** role-guarded:
  both sides observe sharing interruption and resumption, because the capture
  lifecycle is the platform's and the session must outlive it (PRODUCT.md §7;
  test `viewer_side_observes_sharing_stop_and_resume`). Do not "fix" this into
  a sender-only rule.
- `Ended` is terminal: any command afterwards → `SessionEnded`.
- Interruption: `CaptureStopped` while Active → `SharingInterrupted`,
  recoverable; `End` always allowed until ended.

## seam.rs — u8-code surface

| Item | Purpose |
| :-- | :-- |
| `CoreSession::start(role_code, mode_code)` | Construct from u8 codes; unknown code → `CoreError::UnknownRoleCode(u8)` / `UnknownModeCode(u8)` |
| `send_command(command_code) -> Result<u8, CoreError>` | One-shot command; unknown code → `CoreError::UnknownCommandCode(u8)`; returns new state code |
| `role_code()` / `connection_mode_code()` / `state_code()` | Read-only accessors, u8 |
| `CoreError` | `UnknownRoleCode(u8)`, `UnknownModeCode(u8)`, `UnknownCommandCode(u8)`, `Session(SessionError)`; Display delegates |
| `codes::*` constants | Single source of truth for shell-side code values |
| `core_version()` | Version handshake for bridge compatibility checks |

The u8-code surface is deliberately what a UniFFI/JNI/C-ABI binding can
carry without leaking Rust enums across the boundary — that is the seam
decision in ADR-0006 (growable into UniFFI without UI coupling).

## uniffi_api.rs — the production bridge (ADR-0007)

| Item | Purpose |
| :-- | :-- |
| `Role`, `ConnectionMode`, `SessionState`, `SessionCommand` | `uniffi::Enum` mirrors of the session enums; `From` conversions both ways |
| `BridgeError` | `uniffi::Error` + `thiserror`; flattens `CoreError`/`SessionError` into 7 variants. **Kotlin name is `BridgeException`** — UniFFI rewrites a Rust error enum ending in `Error` |
| `GreenfieldSession` | `uniffi::Object` holding `Mutex<Session>`; `new(role, mode)` and `from_codes(role_code, mode_code)` constructors, typed `apply`, u8-code `send_command`, `role/mode/state/viewer_approved` accessors |
| `core_version()`, `role_sender_code()`, `mode_*_code()` | Free functions exported for shell-side sanity checks and code parity |

Host packages: Android imports `uniffi.greenfield5` (generated Kotlin, JNA over
`libgreenfield5_core.so` built by `cargo-ndk`); iOS links
`Greenfield5Core.xcframework` and the generated `greenfield5_core.swift`. Both
trees commit a pure-language stub so the shells compile without a Rust
toolchain; **CI deletes/overwrites the stub before generating real bindings**,
so a stub-only build is not native execution evidence.

## Tests

- `core/src/session.rs` `mod tests` (25): code round-trips, happy paths per
  role, error precedence, terminal state, 1:1 constraint, approval gating,
  interruption/resumption from both sides.
- `core/src/seam.rs` `mod tests` (8): unknown codes rejected, façade mirrors
  `Session` behaviour, constants match enum codes.
- `core/src/uniffi_api.rs` `mod tests` (7): typed journey, `from_codes`
  rejection, code helpers, error mapping. 40 tests total.
- Run: `cargo test` in `core/` (CI: `.github/workflows/stack.yml`, job
  "Rust core" — fmt → clippy `-D warnings` → test). The Android job adds the
  real-Rust JVM proof and `assembleRelease` (R8 keep rules); the iOS job adds a
  simulator build and the Swift bridge tests.

## Failure modes to keep in mind when extending

- Adding a variant without a wire code breaks the FFI contract — codes are
  committed API, append-only.
- `#![deny(missing_docs)]`: every public item needs a doc comment; `seam` and
  `session` re-deny it locally.
- The unsafe boundary is **deny-by-declaration, not deny-by-default**
  (ADR-0007): `core/src/lib.rs` carries a crate-level `#![allow(unsafe_code)]`
  because `uniffi::setup_scaffolding!()` must sit at the crate root and expands
  to `pub unsafe extern "C" fn` shims (scoping a lint attribute to a macro
  invocation does not reach them, and moving the invocation into a submodule
  breaks the `crate::UniFfiTag` contract). `#[deny(unsafe_code)]` is re-applied
  to the handwritten `seam` and `session` modules, and `#[allow(unsafe_code)]`
  is set on the macro-generated `uniffi_api`. No handwritten `unsafe` exists.
  **Every new module declared in `lib.rs` must carry its own
  `#[deny(unsafe_code)]`.** When upstream allows a narrower arrangement, restore
  the deny-by-default boundary (ADR-0007 follow-up 7).
