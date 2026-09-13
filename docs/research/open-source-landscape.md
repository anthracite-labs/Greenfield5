# Open-Source Architecture Research: What Greenfield5 Can Reuse

**Date:** 2026-09-13
**Issue:** [#7](https://github.com/anthracite-labs/Greenfield5/issues/7)
**Status:** research record — informs architecture, decides nothing
**Product contract:** [docs/PRODUCT.md](../PRODUCT.md) (authoritative; repository state wins on conflict)

## Purpose

Answer one question with primary evidence: *what already exists that
Greenfield5 can adopt, extend, or learn from?* This pass does **not** choose
the Greenfield5 architecture, stack, or vendors. It narrows the field, records
reusable findings with source paths, names explicit gaps, and leaves only
genuine product-owner trade-offs open.

## Method and evidence standard

- **Primary source:** the GitHub repository itself via `gh api`
  (metadata, README, directory listings, release tags, license files),
  observed 2026-09-13. Star counts and push dates are point-in-time.
- **Secondary source:** `web_search` results (vendor docs, maintainer
  statements, comparisons). Used for platform constraints and orientation;
  never as the sole basis for a load-bearing reuse claim.
- Every finding is labeled:
  - **VERIFIED** — observed in this session from the named primary source.
  - **INFERRED** — reasonable technical reading of verified facts, stated as
    inference, not fact.
  - **UNKNOWN / REQUIRES PROTOTYPE** — could not be verified from accessible
    evidence; a prototype or spike must answer it.
- Inspection depth per candidate is stated in its dossier. Candidates with
  metadata-only inspection are labeled as such and carry no strong verdict.

## Harvest verdicts

| Candidate | Platforms | License | Verdict |
| :-- | :-- | :-- | :-- |
| RustDesk + rustdesk-server | Win/Mac/Linux/Android/iOS (client); iOS view-only | AGPL-3.0 | **REJECT** (as foundation; harvest rendezvous/relay ops notes) |
| scrcpy | Android sender → desktop viewer | Apache-2.0 | **HARVEST PATTERN** |
| ScreenStream + ScreenStreamWeb | Android sender → browser/RTSP viewers | MIT | **HARVEST PATTERN** |
| LocalScreenShare-Android | Android → Android (LAN/hotspot) | **none found** (MIT badge unverified) | **PROTOTYPE REFERENCE** |
| LiveKit server + mobile SDKs | Server (Go); Android / iOS / Flutter SDKs | Apache-2.0 | **EXTEND** (Internet-mode foundation) |
| Jitsi Meet (+ SDK samples) | Web; Android/iOS via RN SDK | Apache-2.0 | **HARVEST PATTERN** |
| flutter-webrtc | Flutter (Android/iOS/…) | MIT | **EXTEND** if Flutter is chosen, else **HARVEST PATTERN** |
| react-native-webrtc | React Native (Android/iOS) | MIT | **EXTEND** if React Native is chosen, else **HARVEST PATTERN** |
| LocalSend | Android/iOS/desktop (Flutter) | Apache-2.0 | **HARVEST PATTERN** |
| KDE Connect (Android + iOS) | Android/iOS/desktop | GPL-2.0 (Android) / GPL-3.0 + App Store exception (iOS) | **HARVEST PATTERN** |
| Magic Wormhole (+ mailbox/transit; wormhole-william) | CLI/libs, no mobile app | MIT | **HARVEST PATTERN** |
| coturn | Server (C) | BSD (3-clause, Citrix) | **ADOPT** (relay component, given a WebRTC transport) |
| eturnal | Server (Erlang) | Apache-2.0 | **ADOPT** (alternative relay) |
| pion/turn | Go library | MIT | **HARVEST PATTERN** |
| google/nearby (Connections core) | Android (full media); iOS (Wi-Fi LAN only) | Apache-2.0 | **HARVEST PATTERN** (+ gap evidence for Direct) |
| android-airplay-server (+ UxPlay) | Android receiver for iOS/macOS senders | GPL-3.0 | **PROTOTYPE REFERENCE** (iOS→Android LAN path) |
| Moonlight clients + Sunshine host | Android/iOS viewers; desktop-only host | GPL-3.0 | **HARVEST PATTERN** (viewer techniques only) |
| mediasoup | Server (C++/Node) | ISC | **HARVEST PATTERN** (higher-assembly SFU alternative) |
| pion/webrtc | Go library | MIT | **HARVEST PATTERN** (server-side WebRTC) |
| Galène | Server (Go), web clients | MIT | **REJECT** (no mobile story) |
| PairDrop / Snapdrop | Web (all platforms) | GPL-3.0 | **HARVEST PATTERN** (light inspection) |
| apprtc | Web sample (archived) | BSD-3-Clause | **PROTOTYPE REFERENCE** |
| Briar | Android (+desktop/mailbox) | GPL-3.0 | **REJECT** (Android-only, messaging, no video) |
| Berty / Wesh | Android/iOS (unhardened) | mixed/partial (see dossier) | **REJECT** (not hardened, API unstable, messaging) |
| SimpleX Chat | Mobile/desktop messaging | AGPL-3.0 | **REJECT** (messaging relay; no video) |
| Tailscale / Headscale | Mesh VPN + control plane | BSD-3-Clause | **REJECT** (account/control-plane model mismatch) |
| Nebula | Overlay network + lighthouse | MIT | **REJECT** (PKI/lighthouse model mismatch) |
| ZeroTier (+ libzt SDK) | P2P network + embeddable SDK | MPL-2.0 core + non-free parts | **REJECT** (network-join model mismatch) |

No working open-source application was found that covers Greenfield5
end-to-end (all four phone pairings as sender *and* viewer, Local/Direct/
Internet modes, short-code pairing with sender approval, relay fallback).
Greenfield5 is therefore an **assembly and integration task**, not an adoption
task. The closest applications each fail at least one hard requirement; the
strongest reusable material is infrastructure (LiveKit, coturn), platform
technique references (BUE socket bridging, MediaProjection capture), and
protocol designs (pairing, LAN discovery).

## Candidate dossiers

### RustDesk + rustdesk-server — REJECT (as foundation)

- **What:** remote-desktop system (control-first), Rust core + Flutter UI,
  self-hostable rendezvous (`hbbs`) and relay (`hbbr`) servers.
  **VERIFIED** (`rustdesk/RustDesk` README; `rustdesk-server` README:
  `hbbs` ID/rendezvous on port 21116, `hbbr` relay on 21117; repo tree shows
  `src/` + `Cargo.toml` + `flutter/` with `android/` and `ios/`).
- **Platforms:** desktop + Android + iOS clients. **iOS is controller-only:
  it cannot share its own screen** — **VERIFIED** via RustDesk's own blog
  ("View an iOS screen remotely: No — Not supported today").
- **Activity:** `rustdesk/RustDesk` ★123k, pushed 2026-09-13;
  `rustdesk-server` ★10k, pushed 2026-08-07. Very active.
- **License:** AGPL-3.0, both repos (**VERIFIED** via API metadata).
- **Security design:** self-hosted rendezvous/relay with key option (`-k`/`KEY`);
  details of client crypto not inspected — **UNKNOWN** for Greenfield5
  purposes (irrelevant once rejected).
- **Limitations vs PRODUCT.md:** (1) no iOS sender — fails two of four
  pairings; (2) product model is remote control with permanent IDs,
  unattended access, and Accessibility-based input — directly against MVP
  non-goals (no remote control, no AccessibilityService, temporary
  no-account sessions); (3) proprietary protocol — hbbs/hbbr cannot carry
  Greenfield5 media without adopting the whole stack; (4) AGPL on client
  and server constrains a store-distributed consumer product.
- **Harvest notes (what survives rejection):** the self-hosted
  rendezvous+relay split with `ALWAYS_USE_RELAY` fallback semantics is a
  reasonable ops model to mirror; the Rust-core/Flutter-shell mobile
  structure is a proven shape for shared logic + native capture.
- **Verdict rationale:** fails iOS sender and the product model
  simultaneously; nothing salvageable as a foundation.

### scrcpy — HARVEST PATTERN

- **What:** Android screen display/control from desktop over USB/TCP;
  on-device Java server captures and encodes, desktop client renders.
  **VERIFIED** (`Genymobile/scrcpy` ★149k, pushed 2026-09-11; server tree
  `server/src/main/java/com/genymobile/scrcpy/` with `video/`, `audio/`,
  `device/`, `display/`, `control/` packages).
- **Platforms:** Android sender only; viewers are desktop (no phone viewer,
  no iOS anywhere).
- **License:** Apache-2.0 (**VERIFIED**). Permissive for study and reuse.
- **Release:** v3.3.2 (2026-07-12) (**VERIFIED**).
- **Security design:** ADB/USB or TCP pairing model built for developer
  workflows, not consumer pairing — unsuitable as Greenfield5's pairing
  story (**INFERRED** from architecture; not inspected deeply).
- **Limitations vs PRODUCT.md:** no iOS, no phone-to-phone path, no session/
  pairing model, no relay; control-injection half is an explicit non-goal.
- **Reuse value:** the best open reference for the Android sender video
  path: MediaProjection → hardware encode (H.264/H.265) → low-latency
  framing. Study `video/` + `device/` + `display/`; ignore `control/`.
- **Verdict rationale:** production-quality technique reference for one
  capability (Android capture/encode), not a system to adopt.

### ScreenStream + ScreenStreamWeb — HARVEST PATTERN

- **What:** Android app streaming the device screen in three independent
  modes: Local MJPEG over built-in HTTP server (no Internet, optional PIN),
  Global WebRTC via a public signalling service, RTSP mode for compatible
  clients. **VERIFIED** (README mode table; repo modules `app/`, `mjpeg/`,
  `rtsp/`, `webrtc/`, `webrtc-runtime/`, `common/`).
- **Viewers are browsers/RTSP players, not phones** (**VERIFIED** from
  README: "view the stream in a web browser, or use RTSP mode with a
  compatible RTSP client").
- **Signalling:** `dkrivoruchko/ScreenStreamWeb` (★47, MIT, pushed
  2026-09-03) holds the signalling server + web client; README claims
  direct E2E-encrypted WebRTC from phone to browser with the server only
  signalling (**VERIFIED** as a stated design; crypto not audited).
- **Platforms:** Android sender only. No iOS.
- **Activity/license:** ★2.5k, pushed 2026-09-13, MIT (**VERIFIED**),
  Play-deployed with F-Droid variant.
- **Limitations vs PRODUCT.md:** single-platform; no phone viewer; no
  short-code/link pairing, no sender approval, no single-viewer admission,
  no relay fallback, no Direct mode; WebRTC mode requires its Internet
  signalling service.
- **Reuse value:** closest Android-sender prior art under a permissive
  license: the `webrtc/` module (Android WebRTC screen sender), the `rtsp/`
  module (on-device RTSP path — one level below `rtsp/src/main/java/info/`
  not enumerated; exact server class **UNKNOWN**), and the small
  self-hostable signalling server as a complexity reference.
- **Verdict rationale:** excellent donor for the Android sender, but its
  architecture (three independent modes, browser viewers, service-backed
  WebRTC) diverges too far to extend into Greenfield5.

### LocalScreenShare-Android — PROTOTYPE REFERENCE

- **What:** minimal Kotlin + Jetpack Compose app: Android phone-to-phone
  screen share over Wi-Fi/hotspot; MediaProjection → JPEG → TCP sockets;
  NSD discovery; random 6-digit PIN per session. **VERIFIED** (README "How
  It Works", tech-stack table, feature list).
- **Status:** self-described "Experimental" weekend project (★18, pushed
  2026-02-28) (**VERIFIED**). Roadmap (H.264, audio, WebRTC) unimplemented.
- **License:** README badge claims MIT but **no LICENSE file exists in the
  repo root** (**VERIFIED** via root listing) — treat as **no license
  (all rights reserved)**. Must not be copied into Greenfield5.
- **Security design:** PIN-gated sessions claimed ("Secure Pairing"), but no
  TLS/encryption is mentioned anywhere in the inspected material —
  transport security **UNKNOWN**, presumed absent (**INFERRED** from
  "JPEG over TCP sockets" with no crypto dependency named).
- **Limitations vs PRODUCT.md:** Android-only; JPEG/TCP cannot meet the
  latency/quality targets at scale; no Internet mode, no relay, no approval
  flow, no audio.
- **Reuse value:** proves the Local-mode shape on Android end-to-end
  (NSD + PIN + socket streaming + hotspot-friendly) in one small readable
  codebase. Reimplement the pattern; do not reuse the code.
- **Verdict rationale:** technique demonstrator with a license defect and no
  production qualities.

### LiveKit (server + client-sdk-android/swift/flutter) — EXTEND

- **What:** open-source WebRTC SFU (Go, built on Pion) plus first-party
  mobile SDKs with screen-sharing support, token-based rooms, data
  channels, E2EE option, and built-in TURN. **VERIFIED** (server README;
  `client-sdk-swift` has `Sources/LiveKit/Broadcast/` with
  `LKSampleHandler.swift`, `BroadcastScreenCapturer.swift`, `IPC/`;
  Android SDK documents `setScreenShareEnabled` via MediaProjection intent;
  Flutter SDK documents `useiOSBroadcastExtension`).
- **Platforms:** Android, iOS, Flutter clients; self-hostable server.
- **Activity/license:** server ★20.9k, Apache-2.0, pushed 2026-09-12;
  release v1.13.6 (2026-08-26) (**VERIFIED**). All three mobile SDKs pushed
  within days of this pass (**VERIFIED**).
- **Security design:** server-minted access tokens per room/participant;
  DTLS-SRTP media; optional E2EE; coturn-compatible relay. Fits a
  no-account product if Greenfield5 mints short-lived tokens behind its own
  pairing step (**INFERRED** — standard LiveKit deployment shape, not
  Greenfield5-verified).
- **Limitations vs PRODUCT.md:** (1) LiveKit is a transport/rooms layer, not
  a product: join codes, shareable links, 10-minute expiry, sender
  approval, single-viewer admission are Greenfield5-specific session logic
  to build on top; (2) server-dependent — Local (no-Internet) and Direct
  modes need a separate design (an SFU cannot run on the phones);
  (3) operating or contracting server + TURN capacity is a new standing
  commitment (see product-owner decision 2).
- **Reuse value:** the strongest Internet-mode foundation found: one Apache
  stack covering signalling, SFU forwarding, NAT traversal/relay, and all
  four pairings' sender+viewer media paths, with the iOS BUE already
  implemented in the Swift and Flutter SDKs.
- **Verdict rationale:** adopt the transport, build the product on top.
  EXTEND, not ADOPT, because the session/pairing/Local/Direct layers remain
  Greenfield5 work.

### Jitsi Meet (+ jitsi-meet-sdk-samples) — HARVEST PATTERN

- **What:** full video-conferencing stack (SFU + Prosody/Jicofo signalling)
  with a React-Native-based mobile SDK supporting screen sharing on both
  mobile OSes. **VERIFIED** (repo ★29.9k, Apache-2.0, pushed 2026-09-12;
  code search finds `ios/app/broadcast-extension/SampleHandler.swift` and
  `SampleUploader.swift` in-repo; Jitsi handbook documents the BUE →
  Unix-socket → RN-WebRTC bridge and the `RTCAppGroupIdentifier` /
  `RTCScreenSharingExtension` Info.plist contract).
- **Limitations vs PRODUCT.md:** meetings-oriented (multi-party rooms,
  chat, moderation) with heavier server assembly than LiveKit; mobile SDK
  inherits React Native; no short-code consumer pairing model.
- **Reuse value:** the in-repo broadcast extension plus the documented
  socket-bridge pattern is the clearest end-to-end iOS-sender reference
  tied to a working system; the Android screen-share path in the same SDK
  covers the other half.
- **Verdict rationale:** heavier to extend than LiveKit for a 1:1 product;
  take the iOS technique, not the system.

### flutter-webrtc — EXTEND (conditional) / HARVEST PATTERN

- **What:** Flutter WebRTC plugin (★4.5k, MIT, pushed 2026-09-11)
  (**VERIFIED**). iOS side contains `Sources/flutter_webrtc/Broadcast/`
  (`FlutterBroadcastScreenCapturer.m`, `FlutterSocketConnection*.m`) and
  `FlutterRPScreenRecorder.m` (**VERIFIED**) — i.e. both the BUE
  socket-bridge and in-app capture paths.
- **Limitations:** plugin only — no signalling, relay, pairing, or session
  logic; inherits libwebrtc binary size and version churn (**INFERRED**,
  standard for WebRTC plugins).
- **Verdict rationale:** if the later stack decision selects Flutter, this
  is the natural media-sender/viewer base (EXTEND). Otherwise it remains
  the cleanest small-room demonstration of BUE→app socket bridging under a
  permissive license (HARVEST PATTERN).

### react-native-webrtc — EXTEND (conditional) / HARVEST PATTERN

- **What:** React Native WebRTC module (★5k, MIT, pushed 2026-09-10)
  (**VERIFIED**). `ios/RCTWebRTC/` contains `ScreenCapturer`,
  `ScreenCaptureController`, `ScreenCapturePickerViewManager`, and
  `SocketConnection` (**VERIFIED**) — the same BUE bridge shape Jitsi
  documents.
- **Verdict rationale:** mirror of flutter-webrtc for a React Native stack
  decision; otherwise a pattern reference. Framework choice belongs to the
  later ADR, not this pass.

### LocalSend — HARVEST PATTERN

- **What:** cross-platform (Flutter) LAN file/message sharing: REST API +
  HTTPS, no Internet, no accounts; includes a Rust WebSocket signalling
  server (`server/`: "A signaling server for LocalSend") for newer
  link-based flows. **VERIFIED** (README; ★90.8k, Apache-2.0, pushed
  2026-09-12; release v1.18.2).
- **Limitations vs PRODUCT.md:** files/messages, not realtime video; no
  screen capture, no relay fallback, no admission model to reuse directly.
- **Reuse value:** the best Local-mode product precedent: permissionless
  LAN discovery + encrypted device-to-device transfer + store-distributed
  Flutter app on both mobile OSes. Its discovery/HTTPS session shape is the
  template Greenfield5's Local mode should be compared against.
- **Verdict rationale:** design precedent, not donor code.

### KDE Connect (Android + iOS) — HARVEST PATTERN

- **What:** device-to-device LAN features (clipboard, notifications, files,
  remote input) over TLS, with UDP-broadcast discovery and certificate-
  pinned pairing. **VERIFIED** in outline (Android README: "over the
  already existing Wi-Fi network, and using TLS encryption"; both repos
  active: Android pushed 2026-09-13, iOS pushed 2026-08-20).
- **Licenses:** Android `COPYING` is GPL v2 (**VERIFIED** from file head);
  iOS `License.md` is GPLv3 **with an explicit additional permission for
  App Store distribution** (**VERIFIED** — the holders state they do not
  want the GPL/App-Store conflict to block derived apps).
- **Limitations vs PRODUCT.md:** no video/screen path at all; desktop-
  centric product; Android-side GPL-2.0 still constrains code reuse.
- **Reuse value:** the pairing protocol design (discovery → certificate
  exchange → pinned TLS channel) is directly relevant to Local/Direct
  admission without accounts. Reimplement the design; do not lift the code.
- **Verdict rationale:** protocol lesson, not a dependency.

### Magic Wormhole (+ mailbox/transit servers; wormhole-william) — HARVEST PATTERN

- **What:** short human-pronounceable codes that authenticate (PAKE) an
  end-to-end-encrypted channel, with separate mailbox (rendezvous) and
  transit-relay servers. **VERIFIED** (README: codes, wordlist,
  single-use; links to `magic-wormhole-mailbox-server` and
  `magic-wormhole-transit-relay`; MIT; ★22.9k, pushed 2026-09-13).
  `psanford/wormhole-william` (★1.3k, MIT) is a Go implementation.
- **Limitations vs PRODUCT.md:** CLI/library for files/text; no mobile app,
  no realtime video, no sender-approval or single-viewer semantics.
- **Reuse value:** the reference design for Greenfield5's hardest custom
  piece — turning a short join code into an authenticated session without
  accounts: PAKE-bound codes, single-use, short-lived, with relay fallback
  for the data path. Whether to reuse the protocol or reimplement its shape
  is an architecture-decision detail.
- **Verdict rationale:** pairing-protocol blueprint, not a component.

### coturn — ADOPT (relay component, given a WebRTC transport)

- **What:** the de-facto self-hosted STUN/TURN server (C). ★14.4k, pushed
  2026-09-08 (**VERIFIED**). Latest release object returned by the API:
  `docker/4.18.0-r0` (2026-09-08) (**VERIFIED** as returned; release
  hygiene should be re-checked at adoption time).
- **License:** 3-clause BSD (Citrix) — **VERIFIED** from the `LICENSE`
  file head (API metadata reports NOASSERTION/Other, which understates it).
- **Why adopt:** every 2026 comparison found still treats coturn as the
  default production TURN (secondary: BlogGeek 2026 "run coturn and not
  think twice"; self-host cost guides). If Greenfield5's transport is
  WebRTC-based, relay fallback is coturn-shaped until proven otherwise.
- **Caveat:** ADOPT is conditional on the transport decision, which this
  pass does not make. If the stack is not WebRTC, this verdict lapses.

### eturnal — ADOPT (alternative relay)

- **What:** STUN/TURN standalone server in Erlang (`processone/eturnal`;
  note: `eturnal/eturnal` 404s — the org path is `processone/`).
  ★341, Apache-2.0, pushed 2026-09-09 (**VERIFIED**).
- **Verdict rationale:** credible maintained alternative to coturn with a
  permissive license; keep as the fallback if coturn's maintenance or
  packaging disappoints at decision time.

### pion/turn — HARVEST PATTERN

- **What:** Go API for building TURN clients and servers (★2.3k, MIT,
  pushed 2026-09-09) (**VERIFIED**, metadata only).
- **Verdict rationale:** a library for embedding TURN behavior in a custom
  server, not an operated relay. Relevant only if Greenfield5 builds its
  own signalling/relay server rather than deploying coturn/eturnal.

### google/nearby (Connections core) — HARVEST PATTERN (+ Direct gap evidence)

- **What:** open-source C++ core of Nearby Connections (plus `dart/`
  bindings): medium-agnostic encrypted P2P sockets over BT/BLE/Wi-Fi with
  bandwidth upgrade (e.g. BT → Wi-Fi). **VERIFIED** (repo ★968, Apache-2.0,
  pushed 2026-09-13; `connections/README.md`; `connections/implementation/`
  with bandwidth-upgrade and encryption runners). Explicitly "not an
  officially supported Google product."
- **The decisive limitation:** the OSS core builds for iOS with **Wi-Fi LAN
  as the only supported medium** (**VERIFIED** verbatim from
  `connections/README.md`: "The only medium supported is Wi-Fi LAN").
  A maintainer states cross-platform fully-offline high-speed transfer
  "most likely won't be possible unless Apple adds support for something
  like Wi-Fi Aware/Direct" (secondary: `google/nearby` discussion #2447).
- **Reuse value:** viable Android↔Android Direct transport option and a
  same-LAN transport experiment (with Dart bindings for a Flutter app);
  cannot deliver offline Android↔iOS video. Its encrypted-upgrade design is
  still worth studying.
- **Verdict rationale:** the repository that proves the Direct-mode gap
  while offering a partial (same-platform / same-LAN) tool.

### android-airplay-server (+ UxPlay) — PROTOTYPE REFERENCE

- **What:** Android app embedding the UxPlay C library over JNI to act as an
  AirPlay 2 receiver (mirroring H.264/HEVC + audio, optional PIN),
  Play/F-Droid-deployed, Android 7.0+, same-subnet senders.
  **VERIFIED** (README: "uses the C-based UxPlay library … with a JNI
  brid[ge]"; ★290, GPL-3.0, pushed 2026-08-23). Canonical UxPlay is
  `FDH2/UxPlay` (★3.1k, GPL-3.0, pushed 2026-09-13; README: "Now developed
  at … FDH2/UxPlay"), v1.74-experimental; `antimof/UxPlay` is a distinct
  object and treated as stale for citation.
- **What it would prove:** iOS→Android screen sharing on a LAN *without*
  writing an iOS sender — the sender uses system Screen Mirroring.
- **Why not production:** (1) GPL-3.0 would copyleft-constrain the
  Greenfield5 Android app; (2) reverse-engineered protocol Apple can break;
  (3) receiver UX (Control Center mirroring, optional PIN) cannot express
  sender-approval-before-content or single-viewer admission without product
  contortions; (4) DRM content unsupported (stated); (5) no path to
  iOS→iOS (an iOS-app AirPlay receiver is **UNKNOWN / REQUIRES
  PROTOTYPE** — backgrounding and review risk unassessed).
- **Verdict rationale:** worth a time-boxed spike if iOS-sender risk must be
  retired early; unsuitable as a dependency.

### Moonlight clients + Sunshine host — HARVEST PATTERN (viewer only)

- **What:** Moonlight (GPL-3.0; Android ★7.1k pushed 2026-09-12, iOS ★1.7k)
  streams low-latency game video from a Sunshine/NVIDIA host; Sunshine
  (GPL-3.0, ★41k) is the self-hosted host. **VERIFIED** (READMEs).
- **Host platforms are desktop OSes** (Windows/macOS/Linux per README
  platform table) (**VERIFIED**); a mobile Sunshine host was not found in
  inspected evidence (**INFERRED** absent; treat residual doubt as
  **UNKNOWN**).
- **Reuse value:** Moonlight's mobile viewers are the best open study
  material for low-latency H.264/HEVC rendering, adaptive bitrate, and
  input-latency discipline on both phone OSes. GPL-3.0 blocks code adoption
  into a store-distributed Greenfield5 app.
- **Verdict rationale:** learn the viewer craft; reuse nothing verbatim.

### mediasoup / pion/webrtc / Galène

- **mediasoup** (★7.4k, ISC, pushed 2026-09-11; metadata only): cutting-edge
  SFU library. More assembly than LiveKit (own signalling, own mobile
  integration via libwebrtc) — **HARVEST PATTERN** as the higher-control
  SFU alternative.
- **pion/webrtc** (★16.8k, MIT, pushed 2026-09-09; metadata only): pure-Go
  WebRTC; powers LiveKit's server. **HARVEST PATTERN** for any custom
  server-side WebRTC work.
- **Galène** (★1.4k, MIT, pushed 2026-09-08; metadata only): Go SFU aimed at
  conferences with web clients. No mobile SDK story found — **REJECT**
  (wrong client shape for a phone-to-phone product).

### PairDrop / Snapdrop — HARVEST PATTERN (light inspection)

- **What:** browser-based P2P sharing: same-LAN discovery plus temporary
  public rooms for Internet transfers (PairDrop README **VERIFIED**,
  ★11.4k, GPL-3.0, pushed 2026-04-22; Snapdrop ★19.7k, GPL-3.0).
  Metadata + README only — implementation not inspected.
- **Reuse value:** the "LAN-first, public-room fallback" product shape
  rhymes with Greenfield5's Local/Internet split; WebRTC data-channel
  usage is the transfer pattern to compare against.
- **Verdict rationale:** pattern only; web/file-oriented and GPL.

### apprtc — PROTOTYPE REFERENCE

- **What:** Google's archived WebRTC video-chat demo with App Engine
  signalling (★4.2k, BSD-3-Clause, archived, last push 2024-04-24)
  (**VERIFIED**, metadata only).
- **Verdict rationale:** the canonical minimal WebRTC-signalling shape for
  early spikes; archived status disqualifies it as a base.

### Briar / Berty / SimpleX — REJECT

- **Briar** (`briar/briar` GitHub mirror of the GitLab primary; GPL-3.0
  **VERIFIED** from `LICENSE.txt`; active): Android-only messaging over
  Tor/Bluetooth/Wi-Fi/mailbox. No iOS app, no realtime video. Pattern note:
  Bluetooth/Wi-Fi transports suit small payloads, not screen video.
- **Berty/Wesh** (★9.3k, pushed 2026-09-11; own README: "still under active
  development", "API will certainly change", "should not be used to
  exchange important data" — secondary via search excerpt, consistent with
  repo description): unhardened P2P messaging; BLE/mDNS offline ideas are
  interesting but carry no video evidence. License state of the
  progressively-opened repos is **UNKNOWN** — another reason not to touch.
- **SimpleX** (★19.4k, AGPL-3.0, pushed 2026-09-13; metadata only):
  relay-based messaging without user identifiers; invite-link pairing is a
  nice shape, but there is no media path to reuse.
- **Verdict rationale:** all three optimize messaging-over-anything for
  text/small payloads; none carries realtime video or fits Greenfield5's
  temporary-session product model.

### Tailscale / Headscale / Nebula / ZeroTier — REJECT

- **Tailscale** (★36.4k, BSD-3-Clause, pushed 2026-09-13) + **Headscale**
  (★43.8k, BSD-3-Clause; self-hosted control server): WireGuard mesh with
  coordination server, identity, and DERP relays. **REJECT:** the
  account/identity + control-plane + standing-server model contradicts
  no-account temporary sessions; embedding a mesh VPN in a consumer
  screen-sharing app is disproportionate machinery. Pattern note: DERP
  (relay fallback) and NAT-traversal discipline are worth studying.
- **Nebula** (★18.3k, MIT, pushed 2026-09-09): overlay network with
  lighthouse discovery and CA-issued certificates. **REJECT:** lighthouse
  PKI issuance has no place in a no-account product; same embedding-weight
  objection.
- **ZeroTier** (★17.1k, pushed 2026-09-03; core MPL-2.0 per `LICENSE.txt`
  **VERIFIED**, plus documented non-free portions) + **libzt** SDK (active,
  pushed 2026-07-30): P2P network with roots/planets and an embeddable
  socket API. **REJECT:** network-join/controller model plus mixed
  licensing; P2P-with-relay design noted as pattern only.
- All four inspected at metadata + license-file level only — sufficient
  because each fails on product-model fit before technical depth matters.

### Frameworks (Flutter / React Native / native) — NO VERDICT (ADR matter)

- `flutter/flutter` (★179k, BSD-3-Clause, pushed 2026-09-13) and
  `react/react-native` (★126.6k, MIT, pushed 2026-09-13) are both active
  and both have a WebRTC screen-sharing plugin path verified above
  (**VERIFIED**, metadata + plugin dossiers).
- This pass deliberately gives no framework verdict: selecting native
  (Kotlin + Swift) vs cross-platform is the application-stack ADR's job,
  and PRODUCT.md's "native app" phrasing needs clarification first (see
  product-owner decision 1).
- What this pass establishes for that later decision: whichever framework
  is chosen, the iOS BUE and Android foreground-service/MediaProjection
  work stays native; the framework choice changes how much *other* code is
  shared, not whether native platform work exists (**INFERRED** from the
  verified plugin architectures — all of them bridge to native capture).

## Platform findings (not GitHub projects)

These constrain every option equally. Sourced secondary unless noted.

- **iOS sender is always ReplayKit, and background/system-wide capture
  always means a Broadcast Upload Extension started from the system
  broadcast picker.** The extension is a separate memory-capped process:
  **VERIFIED** primary via `gh api` from `opentok/opentok-ios-sdk-samples`
  (★198, MIT, archived; `Broadcast-Ext/README.md`): "cap to 450x800 pixels
  at 10fps for VP8 and at 1068x600 pixels at 15fps for H264, which
  effectively consumes less than 50MB memory. The iOS system kills
  extensions if they use more than 50MB." Two integration shapes recur:
  (a) extension ships frames over an App-Group socket to the app's
  peer connection (Jitsi, flutter-webrtc, react-native-webrtc —
  **VERIFIED** file paths above); (b) extension publishes directly to the
  SFU with a token passed via App Group storage (documented LiveKit
  pattern — secondary).
- **Android sender is MediaProjection + foreground service + hardware
  encode**, with OS-version-specific foreground-service-type and consent
  rules (in force since Android 10; partial-sharing and further hardening
  arrived in later releases and postdate some samples). Multiple working
  references
  **VERIFIED** above; exact Android 10–17 behavior matrix is
  **UNKNOWN / REQUIRES PROTOTYPE** per OS version during implementation.
- **No seamless offline Android↔iOS high-bandwidth device-to-device path
  exists.** iOS exposes no Wi-Fi Direct API to apps and Multipeer
  Connectivity is Apple-only; Android cannot speak AWDL; Nearby
  Connections on iOS is Wi-Fi-LAN (+ slow BLE) only — the OSS core's
  README states the iOS medium limit verbatim (**VERIFIED** primary), and
  a maintainer states seamless offline cross-platform transfer is unlikely
  without new Apple APIs (secondary, `google/nearby` discussion #2447).
  Consequence: mixed-platform Direct mode must be hotspot-anchored LAN
  (one phone hosts, the other joins, then Local-mode protocols run) or
  BLE-assisted signalling + hosted connectivity — all
  **UNKNOWN / REQUIRES PROTOTYPE**, none turnkey.
- **Store-handoff deep linking lost its free default.** Firebase Dynamic
  Links shut down 2025-08-25 (secondary, multiple consistent sources);
  native App Links / Universal Links do not do deferred (through-install)
  linking by themselves. PRODUCT.md already hedges ("where the platform
  permits"); the short join code itself is the robust fallback (user
  installs, types code).
- **Latency targets are compatible with the verified stacks, not proven by
  them.** WebRTC sub-second Internet operation and LAN operation far below
  500 ms are the technology's normal operating region (**INFERRED** from
  the nature of the verified deployments, not measured here). The 5-second
  first-frame and ≥98% establishment targets will depend on signalling
  design, TURN capacity, and mobile-network behavior — architecture and
  testing concerns, not research findings.

## Capability coverage

| Capability | Evidence strength | What exists | What is missing |
| :-- | :-- | :-- | :-- |
| Android sender | **Strong** | scrcpy, ScreenStream `webrtc/`+`rtsp/`, LocalScreenShare, LiveKit/RN/FWEbrtc capturers | Version matrix (Android 10–17) tuning |
| iOS sender | **Moderate** | BUE technique proven 4+ ways (LiveKit, Jitsi, FWEbrtc, RN-WebRTC, OpenTok) with file paths | No Greenfield5-fit turnkey module; memory/lifecycle tuning unproven |
| Android viewer | **Strong** | Every WebRTC mobile SDK renders remote video; Moonlight techniques | Nothing structural |
| iOS viewer | **Strong** | Same as Android viewer | Nothing structural |
| Local | **Strong (patterns)** | NSD/mDNS + PIN + TLS/HTTPS shape (LocalSend, KDE, ScreenStream, LocalScreenShare) | Greenfield5's own session/admission assembly |
| Direct | **Weak / gap** | Android↔Android via Nearby/Wi-Fi Direct; iOS↔iOS via Multipeer (platform APIs, secondary) | **Mixed-platform offline video: no credible solution** (see gap 1) |
| Internet | **Strong (options)** | LiveKit SFU; raw WebRTC + coturn; ScreenStreamWeb signalling shape | Greenfield5 session layer; operated capacity |
| Pairing/signalling | **Moderate (patterns)** | Wormhole PAKE design, KDE TLS pairing, LiveKit tokens, PairDrop rooms | Turnkey short-code+link+approval module (see gap 2) |
| NAT traversal/relay | **Strong** | coturn ADOPT, eturnal alt, LiveKit TURN, pion/turn lib | Deployment/capacity decisions |
| Security/session admission | **Moderate** | Transport story strong (DTLS-SRTP/TLS); approval/expiry/single-viewer = custom logic | E2EE-from-server posture (see PO decision 5) |

## Best reusable findings (ranked)

1. **LiveKit mobile screen-share implementations** — `livekit/client-sdk-swift`
   `Sources/LiveKit/Broadcast/` (`LKSampleHandler.swift`,
   `BroadcastScreenCapturer.swift`, `IPC/`); `livekit/client-sdk-android`
   screen capturer; `livekit/client-sdk-flutter` iOS-broadcast support —
   plus the Apache-2.0 Go SFU. First stop for Internet mode.
2. **Jitsi in-repo broadcast extension** — `jitsi/jitsi-meet`
   `ios/app/broadcast-extension/` (`SampleHandler.swift`,
   `SampleUploader.swift`) + handbook socket-bridge contract
   (`RTCAppGroupIdentifier`, `RTCScreenSharingExtension`). Clearest
   BUE→app plumbing tied to a working system.
3. **flutter-webrtc / react-native-webrtc BUE plumbing** —
   `ios/flutter_webrtc/Sources/flutter_webrtc/Broadcast/` and
   `ios/RCTWebRTC/` (`SocketConnection`, `ScreenCapturer*`). Smallest
   permissive-licensed BUE bridges; choice follows the framework ADR.
4. **scrcpy Android video path** — `server/src/main/java/com/genymobile/
   scrcpy/` (`video/`, `device/`, `display/`). Reference for
   MediaProjection→hardware-encode→frame low-latency craft (Apache-2.0).
5. **ScreenStream modules + ScreenStreamWeb** — `mjpeg/`, `rtsp/`,
   `webrtc/` on-device modes and the MIT signalling server. Closest
   Android-sender product prior art.
6. **LocalSend LAN design + store precedent** — discovery + REST/HTTPS
   session shape for Local mode; proves Flutter LAN apps ship on both
   stores (Apache-2.0).
7. **KDE Connect pairing design** — UDP discovery → certificate exchange →
   pinned TLS. Template for account-free Local/Direct admission (GPL —
   reimplement, don't lift).
8. **Magic Wormhole pairing design** — PAKE-bound single-use short codes +
   mailbox rendezvous + transit relay (MIT). Blueprint for the join-code →
   authenticated-session step.
9. **coturn deployment** — the default relay answer (BSD); eturnal as the
   named alternative (Apache-2.0).
10. **OpenTok BUE engineering budget** — 450x800@10 (VP8) / 1068x600@15
    (H.264) under the 50 MB extension ceiling (**VERIFIED** primary).
    Adopt as the initial iOS-sender budget until measured otherwise.
11. **google/nearby Connections core** — Apache-2.0 C++ core + Dart
    bindings; candidate Android↔Android Direct transport and the primary
    citation for the mixed-platform Direct gap.

## Gaps (no credible reusable solution found)

1. **Mixed-platform offline Direct video.** Nothing found delivers
   Android↔iOS screen video with no Internet and no shared LAN. Candidate
   for the first proof-of-concept: hotspot-anchored LAN + Local-mode
   protocols, with manual-join UX where the OS requires it.
2. **Turnkey short-code + link + sender-approval session module.** Pairing
   *designs* abound; a droppable component matching PRODUCT.md §4 does not.
   Greenfield5 must build this (the wormhole/KDE/LiveKit-token shapes bound
   the design space).
3. **Deferred deep link without a third party.** No OSS component preserves
   session context through install; options are a small Greenfield5-owned
   matching service or manual code entry after install (recommended
   default; PRODUCT.md permits it).
4. **Screen-content adaptive-bitrate tuning for phone networks.** The
   verified stacks adapt, but Greenfield5-specific tuning against the
   500 ms / 1 s targets is unmeasured work, not a finding.
5. **E2EE-from-Greenfield5-servers key distribution.** Possible (per-pair
   keys via the pairing step; LiveKit-style E2EE exists) but no verified
   drop-in for Greenfield5's exact session model; needs PO posture first.

## Architecture implications (narrowing, not deciding)

1. **The iOS sender decision is forced in shape, open in detail.** Any
   viable stack includes a native ReplayKit Broadcast Upload Extension and
   one of the two verified integration shapes (App-Group socket bridge vs
   extension-direct publish). This rules out pure-web, VNC-only,
   AirPlay-only-for-iOS→iOS, and any framework story without a native
   extension path — before any ADR is written.
2. **No adoption candidate; plan for assembly.** The integration surface is:
   native capture per OS + viewer per OS + Local/Direct transports +
   Internet SFU/signalling/relay + pairing/session service + store links.
   LiveKit + coturn cover the Internet column; the rest is Greenfield5
   product code guided by the harvested patterns.
3. **WebRTC is the only transport family with mobile sender+viewer,
   NAT-traversal, and relay OSS across all four pairings.** Every custom
   protocol examined fails ≥1 pairing or license gate (RustDesk: iOS send;
   GameStream: mobile host; AirPlay: license + iOS→iOS; VNC-class: latency
   shape, unexamined in depth because no mobile-first candidate surfaced).
   This narrows but does not finalize: choosing WebRTC (and which SFU or
   raw stack) remains the stack ADR's decision, and a custom-UDP design
   would carry a prototype burden this pass found no evidence to retire.
4. **Internet mode implies Greenfield5-operated or contracted services.**
   Short codes, links, and relay fallback cannot be serverless. Local mode
   can and should be serverless (LAN discovery + PIN + TLS). Direct mode
   needs the hotspot-anchored design proven before it constrains anything.
5. **Copyleft is the dominant license risk.** GPL/AGPL cover the nearest
   applications (RustDesk, AirPlay receivers, Moonlight, KDE, wormhole
   alternatives) while the adoptable infrastructure is BSD/Apache/MIT.
   The stack ADR must include a license posture; no GPL/AGPL code enters
   Greenfield5 without a recorded decision (see PO decision 4).
6. **"One native app" needs a recorded reading.** The evidence supports
   either native-two-codebase or cross-platform-with-native-capture; both
   keep the hard platform work native. The ADR cannot credibly compare
   options until the phrase's intent is pinned (see PO decision 1).

## Product-owner decisions (only what genuinely needs judgment)

1. **What does "native app" require?** PRODUCT.md §2/§12 says "one native
   app." Options: (a) truly native codebases (Kotlin + Swift) — maximum
   platform access, duplicated product logic, two skill sets; (b)
   cross-platform shell (Flutter/React Native) with native capture
   modules — one product codebase, plugin-risk on the hardest paths
   (BUE bridge, foreground capture), larger binary. The research removes
   the technical unknown (both shapes are proven with verified BUE paths);
   the remaining call is product/engineering taste: code-sharing vs
   platform-purity. Consequences bind the stack ADR.
2. **Who operates Greenfield5's Internet services, and at what cost
   tolerance?** Internet mode needs rendezvous/signalling + TURN standing
   capacity. Options: (a) self-host OSS (LiveKit + coturn) — full control
   and privacy posture, ops burden, capacity planning; (b) managed
   (e.g. LiveKit Cloud or a TURN provider) — faster start, recurring cost,
   third-party data path; (c) hybrid (managed TURN, self-hosted
   signalling). Consequences: budget, ops staffing, privacy promises, and
   App Store privacy declarations. PRODUCT.md mandates relay fallback but
   is silent on operating model — that silence is the PO's to fill.
3. **Is an AirPlay-assisted iOS→Android LAN path acceptable?** Options:
   (a) pure Greenfield5 capture everywhere — consistent UX, full BUE
   investment up front; (b) allow the Android viewer to act as an AirPlay
   receiver so an iPhone shares via system Screen Mirroring — earlier
   iOS→Android coverage, but inconsistent UX (leaves the app, Control
   Center flow), GPL copyleft consequence, Apple-protocol fragility, and
   no iOS→iOS story. This is a product-shape call, not a technical one.
4. **Copyleft tolerance.** Options: (a) permissive-only in-app
   (BSD/MIT/Apache) + self-hosted AGPL services avoided or isolated —
   simplest App Store posture, excludes the nearest applications as donors;
   (b) allow GPL-family code with compliance (source offers, license
   notices) — widens reuse (KDE protocol code, AirPlay receiver) at legal
   and store-review cost. AGPL self-hosting additionally obligates source
   availability to users. Needs a legal-aware PO answer before any reuse.
5. **How strong is the privacy promise?** PRODUCT.md requires no
   persistence and no content retention, but not encryption-from-
   Greenfield5-servers. Options: (a) transport encryption only
   (DTLS-SRTP/TLS; servers relay but could observe) — simpler, keeps
   server-side adaptation; (b) end-to-end encryption hiding content from
   Greenfield5 infrastructure — stronger promise, key-distribution
   complexity via the pairing step, constrains SFU features. The PO owns
   the promise; architecture owns the mechanism.
6. **Confirm the Direct-mode acceptance reading.** Given no seamless
   offline mixed-platform video path exists, is "Direct = hotspot-anchored
   LAN with manual join where the OS requires it" an acceptable reading of
   "Direct mode works without Internet where the devices have a compatible
   direct transport" — or should mixed-platform Direct expectations be
   narrowed further? Consequences: MVP acceptance scope and the first
   prototype's target.

## Inspection log (this session, 2026-09-13)

Via `gh api` (metadata + README + listings + releases + license files as
noted per dossier): rustdesk/RustDesk, rustdesk/rustdesk-server,
Genymobile/scrcpy, dkrivoruchko/ScreenStream, dkrivoruchko/ScreenStreamWeb,
erTesla/LocalScreenShare-Android, livekit/livekit, livekit/client-sdk-swift,
livekit/client-sdk-android, livekit/client-sdk-flutter, jitsi/jitsi-meet
(+ code search for the broadcast extension), jitsi/jitsi-meet-sdk-samples,
flutter-webrtc/flutter-webrtc, react-native-webrtc/react-native-webrtc,
localsend/localsend, KDE/kdeconnect-android, KDE/kdeconnect-ios,
magic-wormhole/magic-wormhole, psanford/wormhole-william, coturn/coturn,
processone/eturnal, pion/turn, pion/webrtc, versatica/mediasoup,
jech/galene, l7mp/stunner (metadata), google/nearby, FDH2/UxPlay,
antimof/UxPlay (identity check), jqssun/android-airplay-server,
LizardByte/Sunshine, moonlight-stream/moonlight-android,
moonlight-stream/moonlight-ios (metadata), schlagmichdoch/PairDrop,
SnapDrop/snapdrop (metadata), webrtc/apprtc (metadata), briar/briar,
berty/berty (metadata), simplex-chat/simplex-chat (metadata),
tailscale/tailscale (metadata), juanfont/headscale (metadata),
slackhq/nebula (metadata), zerotier/ZeroTierOne, zerotier/libzt (metadata),
flutter/flutter (metadata), react/react-native (metadata),
opentok/opentok-ios-sdk-samples (BUE budget README).
Not-found paths recorded: `eturnal/eturnal` (404; canonical is
`processone/eturnal`), `restund/restund` (404; not pursued — relay
coverage complete without it).

Secondary (`web_search` excerpts): RustDesk official blog (iOS limits),
Jitsi handbook + LiveKit docs + Stream docs (BUE integration), ForaSoft
2026 BUE guide (50 MB corroboration), `google/nearby` discussion #2447
(maintainer Direct-mode statement), Firebase Dynamic Links shutdown
coverage (×3, consistent), TURN comparisons (BlogGeek 2026, WebRTC guides),
Nearby Connections platform docs, Berty status coverage.

## Terminology note

"Local", "Direct", and "Internet" in this document always mean the
PRODUCT.md §3 connection modes (user-selected). "LAN" means the network
technique both Local mode and hotspot-anchored Direct designs run on.

...[truncated 12512 chars]