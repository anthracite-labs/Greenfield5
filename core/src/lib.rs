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
//! # Verification
//!
//! `cargo test` (toolchain pinned by `rust-toolchain.toml`); CI runs
//! `cargo fmt --check`, `cargo clippy -- -D warnings`, and `cargo test` in
//! `.github/workflows/stack.yml`.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

pub mod seam;
pub mod session;

/// The crate version, as compiled in (`CARGO_PKG_VERSION`).
pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}
