//! Shared Greenfield5 core.
//!
//! This crate holds the product logic that Android and iOS must agree on
//! byte-for-byte: the session role/state model today, and — per
//! [ADR-0005](https://github.com/anthracite-labs/Greenfield5/blob/main/docs/decisions/0005-rust-native-moq-iroh-architecture.md)
//! — pairing/admission, protocol models, and MoQ-over-Iroh transport
//! orchestration as those land in follow-up work.
//!
//! # Ownership boundaries (ADR-0005)
//!
//! The Rust core owns session state and transitions. Platform screen capture,
//! permissions, lifecycle, hardware media, LAN/Wi-Fi Aware integration, and UI
//! remain native (Kotlin/Compose on Android, Swift/SwiftUI on iOS) and are
//! deliberately *not* abstracted here.
//!
//! # The seam
//!
//! [`seam`] is the narrow facade the native shells will consume once the
//! native↔Rust bridge is wired (follow-up issue). It speaks in stable integer
//! wire codes so the eventual FFI mechanism — UniFFI or another pinned choice,
//! decided in that follow-up — can export this surface without UI code ever
//! depending on Rust types or transport internals.
//!
//! # UniFFI bridge (ADR-0007)
//!
//! [`uniffi_api`] exposes the same session model via UniFFI proc-macros,
//! pinned at 0.32.1 (mozilla/uniffi-rs tags v0.32.1 35a47433, v0.32.0 5c7b739).
//! The existing [`seam`] remains the stable u8-code contract; the UniFFI
//! layer delegates to it and does not expand session semantics.
//!
//! # Verification
//!
//! `cargo test` (toolchain pinned by `rust-toolchain.toml`); CI runs
//! `cargo fmt --check`, `cargo clippy -- -D warnings`, and `cargo test` in
//! `.github/workflows/stack.yml`.

#![deny(unsafe_code)]
#![deny(missing_docs)]
#![allow(clippy::all)]

pub mod seam;
pub mod session;
#[allow(unsafe_code)]
#[allow(missing_docs)]
#[allow(clippy::all)]
pub mod uniffi_api;

/// The crate version, as compiled in (`CARGO_PKG_VERSION`).
pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

// UniFFI scaffolding — proc-macro only, no UDL. The macro generates unsafe FFI
// shims. We place it in its own module with allowed unsafe_code and missing_docs,
// avoiding the `unused_attributes` lint that occurs when `#[allow]` is placed
// directly on the macro invocation in Rust 2024 (see stack.yml tail200 diagnostics
// for run 34961828367). Our own modules above deny unsafe_code, preserving the
// safety boundary.
#[allow(unsafe_code)]
#[allow(missing_docs)]
#[allow(clippy::all)]
mod uniffi_scaffolding {
    uniffi::setup_scaffolding!();
}
