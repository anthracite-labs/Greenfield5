# ADR-0007: UniFFI as the native↔Rust bridge mechanism

**Date:** 2026-09-14
**Status:** accepted
**Deciders:** Implementation agent, based on ADR-0005/ADR-0006 and primary-source UniFFI research

## Context

ADR-0005 selected a shared Rust core with native Kotlin/Swift shells and required a narrow, versioned, observable, testable seam. ADR-0006 pinned the concrete Android/iOS/Rust toolchain (AGP 9.4.0, Kotlin 2.4.20, Gradle 9.6.1, Rust 1.98.1) and deferred the FFI mechanism choice to the first bridge follow-up, naming UniFFI as first candidate.

Issue #15 requires the smallest production-tree bridge proving native shells can call the existing Rust core without coupling UI to transport internals, with Android release/R8/JNI keep treatment build-proven and iOS real integration verified via macOS CI.

Primary-source verification performed 2026-09-14:
- `mozilla/uniffi-rs` repo: 4966 stars, updated 2026-09-14T14:35:33Z, default branch main (gh api).
- Latest stable tags: v0.32.1 (35a47433d8f015302fbf608f2b395eff6972c36f), v0.32.0 (2026-06-30, 5c7b739...). CHANGELOG 0.32.0 notes fixes for renaming, clippy, ambiguous methods, mutable_records config, Kotlin uniffiIsDestroyed, askama 0.15.6.
- Supported targets: Kotlin, Swift, Python, Ruby built-in; used extensively by Mozilla Firefox mobile (README).
- Kotlin: generates Kotlin library loading Rust cdylib via JNA, configurable package_name, cdylib_name, android flag for Android optimizations, android_cleaner option. JNA direct-mapped u8/u16 fix #2897 noted.
- Swift: generates C header + modulemap + Swift source, Swift 6 partial support, Sendable conformance. Integration via XCFramework.
- Build: proc-macros with `uniffi::setup_scaffolding!()` or UDL with `include_scaffolding!()`, bindgen binary via `uniffi::uniffi_bindgen_main()`, library mode recommended (`generate --library`).

The existing Rust core (`core/src/session.rs`, `seam.rs`) already exposes stable u8 wire codes and a narrow facade, with 33+8 tests. The bridge must preserve those semantics.

## Decision

Adopt **UniFFI 0.32.1** as the pinned FFI mechanism for Greenfield5's native↔Rust bridge.

- Add `uniffi = { version = "0.32.1" }` and `thiserror = "2"` to `core/Cargo.toml`, crate-type `["lib", "cdylib", "staticlib"]`, and `uniffi-bindgen` binary.
- Expose existing session model via `core/src/uniffi_api.rs` using proc-macros (`#[derive(uniffi::Enum/Object/Error)]`, `#[uniffi::export]`, `setup_scaffolding!()`), delegating to `session.rs`/`seam.rs` without expanding semantics.
- Generate Kotlin bindings into `apps/android/app/src/main/java/uniffi/greenfield5/` and Swift bindings into `apps/ios/Greenfield5/Bridge/Generated/`, with placeholder pure-Kotlin/Swift stubs committed for local builds (foundation gate) and real JNA/XCFramework bindings generated in CI.
- Android: JNA dependency `net.java.dev.jna:jna:5.14.0@aar`, `jniLibs` for `libgreenfield5_core.so` built via `cargo-ndk`, R8 keep rules in `proguard-rules.pro` build-proven via `assembleRelease`.
- iOS: XCFramework generation script `apps/ios/scripts/generate-xcframework.sh` building `aarch64-apple-ios`, `aarch64-apple-ios-sim`, `x86_64-apple-ios-sim`, and Swift bindings, integrated into Xcode project via synchronized groups, verified via macOS CI (`xcodebuild` simulator).
- CI: extend `stack.yml` with `android-shell` job building Rust for Android and generating Kotlin bindings, and new `ios-shell` job on `macos-14` building Rust for iOS, generating Swift bindings + XCFramework, and running `xcodebuild build` and `test`.

## Alternatives considered

### Alternative: Hand-rolled C ABI with manual JNI/Swift bridging

- **Pros:** No extra dependency, full control over memory/error handling, minimal binary size, no code generator.
- **Cons:** Manual memory management, error handling, and type mapping for Kotlin/Swift; no idiomatic class generation; higher maintenance; need to maintain JNA/JNI glue and Swift header manually; more unsafe code.
- **Why not:** UniFFI provides idiomatic Kotlin/Swift generation, is production-proven in Firefox mobile, and matches ADR-0006 first candidate. Hand-rolled C ABI would require more custom unsafe code and would not be smaller for this slice.

### Alternative: Diplomat (C/C++ focused)

- **Pros:** Focused on C/C++ interop, good for zero-copy, alternative to UniFFI.
- **Cons:** Less mature for Kotlin/Swift, smaller community, less documentation for Android/iOS integration, not used by Firefox mobile.
- **Why not:** UniFFI has explicit Kotlin/Swift production support and broader adoption for mobile.

### Alternative: Gobley / KMM UniFFI plugin

- **Pros:** Provides Gradle plugin for UniFFI + Kotlin Multiplatform, automates binding generation.
- **Cons:** Adds KMM complexity, extra Gradle plugin dependency, not needed for this slice which is JVM Android only; still uses UniFFI under the hood.
- **Why not:** Adds unnecessary abstraction for minimal bridge; can be adopted later if KMM becomes relevant. Direct UniFFI usage keeps dependency surface smaller.

### Alternative: UDL file instead of proc-macros

- **Pros:** UDL is older, stable, documented, separates interface definition from Rust code.
- **Cons:** Requires duplicating API in UDL file and Rust code, risk of drift; proc-macros keep single source of truth in Rust.
- **Why not:** Proc-macros are now recommended for new crates (per UniFFI docs), avoid duplication, and work with library mode. UDL can be added later if needed for features not yet supported by proc-macros.

## Consequences

### Positive

- Single source of truth for API in Rust, idiomatic Kotlin/Swift bindings generated.
- Production-proven by Firefox mobile, with active maintenance (v0.32.1 latest stable).
- Preserves narrow seam: UI depends on bridge API only, not transport internals.
- Android R8 keep rules and JNI loading are build-proven via release assembly.
- iOS integration is real project integration, not unused files, verified via macOS CI.
- Existing Rust core remains independently testable (cargo test).

### Negative

- Adds `uniffi` and `thiserror` dependencies to core (previously zero-dep); increases compile time and binary size.
- Generated bindings are large and must be committed or generated in CI; placeholder stubs needed for local builds without Rust toolchain.
- JNA dependency on Android adds ~1MB AAR and requires keep rules.
- XCFramework generation requires multiple Rust targets and macOS runner minutes (~10x cost on private repo).
- `forbid(unsafe_code)` could not be retained. The unsafe boundary is real but
  narrower in guarantee than "crate-level deny plus one module allow":
  - UniFFI's `setup_scaffolding!()` must be invoked at the **crate root** — its
    expansion emits `pub struct UniFfiTag`, which UniFFI's derive output
    references as `crate::UniFfiTag` (uniffi-rs v0.32.1:
    `uniffi_macros/src/enum_.rs`, `record.rs`, `ffiops.rs`) — and that expansion
    contains `pub unsafe extern "C" fn` FFI shims
    (`uniffi_macros/src/setup_scaffolding.rs`).
  - A lint attribute cannot be scoped to a macro invocation: `#[allow(unsafe_code)]`
    placed directly on `setup_scaffolding!()` was reported as `unused_attributes`
    under `-D warnings` with Rust 1.98 (commit d318aa9), so it never reached the
    expanded items.
  - Therefore `core/src/lib.rs` carries a **crate-level** `#![allow(unsafe_code)]`,
    with `#[deny(unsafe_code)]` re-applied to the handwritten `seam` and `session`
    modules and `#[allow(unsafe_code)]` on `uniffi_api` (UniFFI derive/export
    output).
  - Precise consequence: `unsafe` is denied in all handwritten product logic, but
    the crate is **deny-by-declaration, not deny-by-default** — a new module that
    omits its own `#[deny(unsafe_code)]` inherits the crate-level allow. No
    handwritten `unsafe` exists in the crate today. See follow-up 7.
  - Narrowing was evaluated against uniffi-rs v0.32.1 and rejected: it requires
    moving the scaffolding off the crate root, which the `crate::UniFfiTag`
    contract and the `#[macro_export]`ed `uniffi_reexport_scaffolding!` (whose body
    resolves `$crate::uniffi_reexport_hack`) both forbid.

### Follow-ups

1. Commit `core/Cargo.lock` once generated by real toolchain (CI artifact) — never hand-written.
2. Promote iOS and Android jobs to required status contexts after stabilization (governance change).
3. Replace placeholder Kotlin/Swift stubs with CI-generated bindings committed after first green CI run, or keep generation in CI only.
4. Add `ACCESS_LOCAL_NETWORK` handling for Local mode at targetSdk 37 (flagged in research).
5. Proceed to MoQ/Iroh synthetic-media spike (ADR-0005 follow-ups) using same bridge.
6. Evaluate Gobley plugin if KMM or more complex Android targets needed.
7. Restore a deny-by-default unsafe boundary when upstream allows it. The
   crate-level `#![allow(unsafe_code)]` in `core/src/lib.rs` exists only because
   UniFFI's scaffolding must sit at the crate root and a lint attribute cannot be
   scoped to a macro invocation. Re-evaluate on any UniFFI upgrade that either
   emits its own `#[allow(unsafe_code)]` inside the scaffolding expansion, or
   supports scaffolding in a module without breaking `crate::UniFfiTag`. Until
   then, every new module declared in `core/src/lib.rs` must carry an explicit
   `#[deny(unsafe_code)]`, and that requirement is stated in the source comment
   above the crate-level attributes.
