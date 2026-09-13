# ADR-0005: Adopt a Rust core with native mobile apps and MoQ over Iroh

**Date:** 2026-09-13
**Status:** accepted
**Deciders:** Product owner, informed by Issue #7 architecture research and the 2026-09-13 MoQ/Iroh verification pass

## Context

Greenfield5 is a one-sender/one-viewer mobile screen-sharing product with native Android and iOS apps, user-selected Local, Direct, and Internet connection modes, and no remote-control or conferencing scope. The merged research in [`docs/research/open-source-landscape.md`](../research/open-source-landscape.md) found no end-to-end application to adopt and established that the difficult platform surfaces remain native: Android MediaProjection/foreground-service/network APIs and iOS ReplayKit/ScreenCaptureKit/Broadcast Upload Extension/network APIs.

The follow-up transport research verified three important upstream facts. First, [`n0-computer/iroh`](https://github.com/n0-computer/iroh) is a Rust QUIC/P2P library whose connection model is direct connectivity with NAT traversal and encrypted relay fallback, with maintained mobile FFI work in [`n0-computer/iroh-ffi`](https://github.com/n0-computer/iroh-ffi). Second, [`moq-dev/moq`](https://github.com/moq-dev/moq) implements Media over QUIC in Rust and already contains an experimental Iroh transport in `rs/moq-native/src/iroh.rs`, including an `iroh://` native connection path. Third, [`n0-computer/iroh-live`](https://github.com/n0-computer/iroh-live) demonstrates real-time audio/video over Iroh + MoQ, including a Kotlin + Rust Android two-way calling demo, while explicitly remaining an early tech preview and not proving Greenfield5's screen-capture or iOS production path.

The product owner selected a Rust shared core with Kotlin/Jetpack Compose on Android and Swift/SwiftUI on iOS, and selected MoQ over Iroh as the media/network direction. This ADR records that architecture choice without authorizing implementation: `config/project.env` remains in the `architecture` phase with the application-stack guard enabled.

## Decision

Greenfield5 will use a **shared Rust core** for session state, pairing/admission logic, protocol models, media-session orchestration, and transport/network logic. The Android application will be **Kotlin + Jetpack Compose** and the iOS application will be **Swift + SwiftUI**; platform capture, permissions, lifecycle, hardware media integration, and platform-specific nearby/LAN APIs remain native rather than being abstracted into Rust.

Greenfield5 will use **MoQ as the live media/object transport layer over Iroh's native QUIC/P2P connectivity**. The preferred Internet shape is direct Iroh connectivity first with a Greenfield5-controlled/dedicated Iroh relay fallback when direct connectivity fails. `moq-relay` is not the default 1:1 media path; it remains available if a future requirement actually needs MoQ-aware fan-out, caching, browser interop, or server-routed distribution.

This is an architecture decision, not the final application-stack lifecycle transition. No application source or dependency is authorized by this ADR alone.

## Ownership boundaries

### Rust core owns

- temporary session state and state transitions;
- pairing/join-code protocol logic and sender approval state;
- shared authentication/admission primitives and key/session models;
- MoQ track/session orchestration;
- Iroh endpoint/session orchestration and reconnect/path state;
- shared protocol serialization and error models;
- transport selection policy where the operating system exposes a usable path.

### Android native owns

- Kotlin + Jetpack Compose UI;
- MediaProjection screen capture;
- foreground-service lifecycle and Android permission flows;
- MediaCodec/hardware media integration or equivalent native codec plumbing;
- Android LAN/NSD and Wi-Fi Aware integration;
- Android-specific app lifecycle and store/system integration.

### iOS native owns

- Swift + SwiftUI UI;
- ReplayKit Broadcast Upload Extension for the current iOS 16–26 support window;
- ScreenCaptureKit migration path for iOS 27+;
- VideoToolbox/hardware media integration or equivalent native codec plumbing;
- iOS Network/Wi-Fi Aware integration and required pairing UI;
- iOS lifecycle, App Group/IPC, extension, permission, and store/system integration.

## Connection-mode interpretation

### Local

Use the same MoQ-over-Iroh media/session stack where possible, but configure Iroh for **strict offline operation**: no dependency on n0 public discovery/relay infrastructure and no Internet requirement. Local discovery/address exchange remains a Greenfield5 responsibility through native LAN mechanisms. The exact offline Iroh endpoint configuration is a required prototype before implementation is considered proven.

### Direct

Prefer the same MoQ-over-Iroh stack if the platform-specific direct transport yields a usable IP/UDP path. Android↔iOS Wi-Fi Aware interoperability remains **UNKNOWN / REQUIRES PROTOTYPE**; this ADR does not claim that Iroh removes that platform unknown. If Wi-Fi Aware cannot expose a compatible path, hotspot-anchored LAN remains the fallback candidate already recorded in research.

### Internet

Prefer direct Iroh connectivity and NAT traversal. If direct connectivity fails, fall back to a **dedicated Greenfield5-controlled or contracted Iroh relay** carrying opaque encrypted traffic. The free/shared n0 relay infrastructure is not an SLA or production dependency. `moq-relay` is deferred as the default because Greenfield5 is exactly one sender and one viewer and does not currently require server-side fan-out or cache semantics.

## Alternatives considered

### Alternative: Flutter shell with native Kotlin/Swift capture modules

- **Pros:** One shared product/UI codebase; mature cross-platform app tooling; existing WebRTC plugins demonstrate native capture bridges.
- **Cons:** Adds a second shared runtime above the native OS surfaces while the hardest capture/network work remains platform-specific; increases bridge/plugin surface around lifecycle-sensitive code.
- **Why not:** The product owner chose native platform UI and a Rust shared core. Rust provides the intended cross-platform sharing boundary without requiring a cross-platform UI framework.

### Alternative: Pure Kotlin and Swift with duplicated product/session logic

- **Pros:** Maximum platform-native simplicity; no FFI boundary for shared logic.
- **Cons:** Duplicates session, protocol, pairing, transport, reconnect, and security logic across two codebases and increases the risk of protocol divergence.
- **Why not:** Greenfield5 needs substantial shared protocol/network behavior, and Rust is a natural common layer for the selected MoQ/Iroh ecosystem.

### Alternative: WebRTC P2P with ICE/STUN/TURN fallback

- **Pros:** Mature mobile ecosystem; well-understood NAT traversal; proven capture/render integrations.
- **Cons:** Pulls Greenfield5 toward libwebrtc's larger opinionated media/session stack, while shared business/network logic would still need a separate cross-platform layer; offers less direct control over the media pipeline than the selected MoQ stack.
- **Why not:** The product owner selected MoQ/Iroh after verifying that upstream MoQ already integrates an Iroh transport and that Iroh's Rust-first direct/relay connection model aligns with Greenfield5's 1:1 topology.

### Alternative: LiveKit or another SFU-routed default

- **Pros:** Bundled signalling, reconnection, mobile SDKs, server-side observability, and mature fan-out.
- **Cons:** Places a media server in the path of every Internet session and adds standing SFU bandwidth/operations for a product that permits exactly one viewer.
- **Why not:** Greenfield5's topology is 1:1 and prefers direct media where possible. The merged research already established that an SFU-first default is not topology-equivalent to that product contract.

### Alternative: `moq-relay` as the default Internet media path

- **Pros:** MoQ-aware relay semantics, caching/fan-out, browser/WebTransport compatibility, and a natural path to large broadcast distribution.
- **Cons:** Makes server-routed media the default and pays for capabilities Greenfield5's one-viewer MVP does not require.
- **Why not:** The current product needs direct-first 1:1 transport. Keep `moq-relay` available for requirements that actually benefit from MoQ-aware server behavior rather than making it mandatory now.

### Alternative: Raw QUIC/Iroh with a Greenfield5-specific media protocol

- **Pros:** Maximum control and minimal dependency on an evolving MoQ specification.
- **Cons:** Greenfield5 would own framing, track semantics, prioritization, partial-reliability behavior, live-edge decisions, media catalog evolution, and interoperability rules that MoQ already addresses.
- **Why not:** Research-before-inventing favors adopting the existing open protocol and implementation family unless a prototype demonstrates a concrete MoQ blocker.

## Consequences

### Positive

- One shared Rust protocol/network core aligns directly with the Rust implementations of Iroh and MoQ.
- Native Kotlin/Swift retain full access to lifecycle-sensitive screen capture, hardware codecs, Wi-Fi Aware/LAN APIs, permissions, and store/platform behavior.
- Internet topology remains direct-first and avoids mandatory media-server bandwidth for successful P2P sessions.
- Iroh provides one endpoint abstraction for direct paths and relay fallback, reducing the need to recreate ICE/STUN/TURN-style machinery in Greenfield5.
- MoQ provides explicit live-media objects/tracks, prioritization, independent QUIC streams, and partial-reliability semantics instead of inventing a private media protocol.
- The architecture keeps `moq-relay` as an optional future capability rather than closing the door on browser/fan-out/server-routed use cases.

### Negative

- The active MoQ ecosystem and wire specifications are still evolving; Greenfield5 must pin exact versions/commits and plan upgrades deliberately.
- `moq-dev/moq`'s Iroh transport is currently documented as experimental, so production suitability is not assumed by this ADR.
- `n0-computer/iroh-live` is an early technical preview; it is evidence and harvest material, not a production dependency to adopt wholesale.
- iOS system-wide screen sharing remains constrained by the Broadcast Upload Extension process/memory model for iOS 16–26 and requires a ScreenCaptureKit migration path for iOS 27+.
- Greenfield5 must own or contract production relay capacity rather than rely on free/shared n0 infrastructure.
- Strict-offline Local mode requires explicit Iroh configuration and local discovery/address exchange; stock Internet-assisted discovery behavior cannot silently remain enabled.
- Android↔iOS Wi-Fi Aware Direct interoperability is still unproven and is not solved merely by choosing Iroh.
- Rust/native FFI becomes a critical product boundary and must be kept narrow, versioned, observable, and testable.

### Follow-ups

Before the later implementation-stack ADR/lifecycle transition, prove the following minimum spikes:

1. **MoQ-over-Iroh mobile transport:** one Android and one iOS native app embedding the Rust core can establish a MoQ session over Iroh, publish/subscribe a synthetic encoded video track, and survive direct/relay path conditions.
2. **iOS sender process model:** determine whether Iroh/MoQ networking can live safely in the Broadcast Upload Extension memory/lifecycle envelope or whether encoded frames must cross App Group/IPC into the host app/core process.
3. **Strict-offline Local:** construct an Iroh endpoint/configuration with all public discovery/relay dependencies disabled and exchange addressing through Greenfield5's LAN pairing path.
4. **Internet relay:** test direct NAT traversal and automatic fallback using dedicated Iroh relay infrastructure under representative home, carrier, CGNAT, and blocked-UDP conditions.
5. **Direct Wi-Fi Aware:** run the previously defined physical Android↔iOS interoperability spike; if a usable IP/UDP path exists, verify that Iroh can operate over the resulting addresses/path.
6. **Protocol pinning:** choose and record the exact `moq-dev/moq`, Iroh, and FFI versions/commits only when implementation is authorized; do not track moving branches implicitly.
7. **Final stack transition:** once the remaining owner choices and prototype gates are resolved, create the separate application-stack ADR required by `config/project.env`, then transition to `PROJECT_PHASE=implementation` and `ALLOW_APP_STACK=1` in its own reviewed change.
