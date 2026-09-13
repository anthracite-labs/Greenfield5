# Product

**Status: defined for MVP discovery.**

Greenfield5 is a simple mobile screen-sharing app that lets two phones connect
and share one device's screen with the other. One native app works as sender or
viewer across Android and iOS, using local Wi-Fi, nearby peer-to-peer
connectivity, or the Internet, without requiring accounts or remote control.

The authoritative discovery record is GitHub Issue #3. This document
consolidates the product-owner decisions accepted there. It intentionally does
not choose implementation frameworks, transport libraries, signalling stacks,
relay products, hosting, databases, or backend languages; those belong to the
architecture phase.

## 1. Problem and users

### Problem

People often need to show what is happening on one phone to another person on a
second phone, but existing options are frequently heavier than the task: meeting
apps, remote-support suites, video calls aimed at the device, or screen
recordings sent after the fact.

Greenfield5 solves the narrower problem: establish a temporary one-to-one mobile
screen-sharing session quickly, with the sender remaining in control of their
own device.

### Primary user

Greenfield5 is for general consumers. Technical support, family help, and
show-and-tell are valid use cases, but the product is not a managed support
platform or collaboration suite.

### Current alternatives / workaround

Users currently rely on meeting or screen-sharing apps, remote-support apps,
video calls, or recorded screenshots/video. Greenfield5 aims to reduce that to a
small phone-to-phone flow with no account requirement.

## 2. Core product model

- One Greenfield5 app is installed on both devices.
- Every install can act as either **sender** or **viewer**.
- Supported pairings are:
  - Android -> Android
  - Android -> iOS
  - iOS -> Android
  - iOS -> iOS
- Each MVP session has exactly **one sender and one viewer**.
- The home screen exposes two primary actions:
  - **Share My Screen**
  - **View a Screen**
- The sender remains in control of the device at all times.
- Greenfield5 is **view/guide, not remote control**.

## 3. Connection modes

The user explicitly chooses one of three product-level connection modes. The
implementation of each mode is an architecture decision to be made later.

### Local

- Both devices are on the same Wi-Fi/LAN.
- The media path should remain local instead of unnecessarily traversing Internet
  infrastructure.
- Internet access is not required.

### Direct

- Nearby device-to-device communication without relying on an Internet path.
- Direct mode is available only where the two devices/platforms support a
  compatible direct transport.
- Internet access is not required when a compatible direct path exists.

### Internet

- The devices may be anywhere with Internet connectivity.
- Direct peer-to-peer connectivity is preferred where possible.
- If NAT, firewall, CGNAT, or similar network conditions prevent a direct path,
  Greenfield5 automatically falls back to relay rather than failing the session.

## 4. Pairing and session admission

- No account is required for sender or viewer.
- A session is temporary.
- Internet/session invitations use a short join code plus a shareable link.
- QR joining is out of scope for MVP.
- An unused join code expires after **10 minutes**.
- The viewer may provide a temporary display name for the current session.
- Possession of a code/link alone does not reveal the screen.
- The sender must approve the viewer before screen data is shown.
- Once one viewer is connected, additional viewers are rejected.
- If a session link is opened without Greenfield5 installed, store handoff should
  preserve enough session context to continue joining where the platform permits.
- No session history is retained as a product feature.

## 5. Screen-sharing behavior

- Greenfield5 respects the screen-sharing choices and privacy controls exposed by
  each OS rather than pretending Android and iOS are identical.
- On Android, the user's system choice of single-app versus full-display capture
  is respected.
- Screen sharing should continue while the sender leaves Greenfield5 and uses
  other apps, subject to platform capture rules.
- Each new sharing session obtains fresh OS capture authorization where required.
- Greenfield5 never attempts to bypass protected or secure content. Protected
  areas may appear blank or otherwise unavailable while the session remains
  alive.
- Video quality adapts to available network conditions.
- Viewer orientation follows sender orientation automatically.
- Greenfield5 provides its own obvious active-sharing state and Stop action in
  addition to mandatory OS indicators.

## 6. Audio

- Screen sharing works without microphone permission.
- Microphone/voice is optional and activated only when the user chooses it and
  grants permission.
- Device/app audio is optional and best-effort only where the OS and source app
  permit capture.
- Greenfield5 does not promise that every app's internal audio can be captured.

## 7. Lock, revoke, and recovery behavior

The Greenfield5 session lifecycle is distinct from the OS screen-capture
lifecycle.

- Locking the sender's phone does not intentionally terminate the Greenfield5
  connection.
- If the OS stops screen capture on lock, the viewer remains connected where
  possible and sees a clear stopped/locked state.
- After unlock, screen sharing resumes automatically only if the existing OS
  capture authorization is still valid.
- If the OS invalidated the capture session, Greenfield5 requests only the
  minimum re-authorization the OS requires; it does not add an extra product
  confirmation step.
- If capture is revoked or otherwise stops mid-session, the room may remain alive
  and clearly report that screen sharing has stopped.

## 8. Permissions

Permissions are progressive and feature-triggered.

- Do not request screen capture, microphone, or unrelated sensitive permissions
  on first launch merely because the app may use them later.
- Do not request Android AccessibilityService for remote control.
- Do not depend on general notification permission as a product feature in MVP.
  Mandatory Android foreground-service notification behavior still applies while
  active capture requires it.
- Do not request camera permission for QR scanning because QR joining is not part
  of MVP.

## 9. Data and privacy contract

Greenfield5 follows a minimal-retention model.

### Content

- Screen/video frames are transmitted for the active session but are **never
  persisted by Greenfield5**.
- Microphone audio and device/app audio are transmitted when enabled but are
  **never persisted by Greenfield5**.
- There is no built-in recording feature in MVP.

### Temporary session data

- Join codes are temporary and become invalid when expired or when the session
  lifecycle ends.
- Temporary viewer display names are session-scoped.
- No account profile or product session history is stored.

### Operational diagnostics

Minimal operational diagnostics may include non-content information such as
error codes, timestamps, app/OS version, and coarse connection mode when needed
for reliability, abuse prevention, or security. Operational telemetry must not
contain captured screen or audio content and must not become a hidden session
history product.

## 10. Explicit non-goals for MVP

The following are out of scope:

- remote touch/control of the sender device;
- Android AccessibilityService-based control;
- unattended access;
- browser viewer;
- separate sender and viewer apps;
- multiple simultaneous viewers;
- sender-visible pointer overlays;
- annotations/drawing;
- built-in recording;
- account system;
- session history;
- QR pairing;
- collaboration rooms, meetings, or managed support-console features.

## 11. Platform and distribution constraints

- Distribution target: **Google Play** and **Apple App Store**.
- Minimum supported Android version: **Android 10+**.
- Minimum supported iOS version: **iOS 16+**.
- Current-platform requirement: Android 17 and iOS 26 must be fully supported,
  subject to their native capture/security rules.
- Platform capability differences are acceptable where the OSes expose different
  APIs or privacy boundaries; the user-facing product promise should remain as
  consistent as practical.

## 12. MVP acceptance boundary

V1 is considered usable only when all of the following product capabilities are
present for supported platform/device combinations:

- one native app can act as sender or viewer;
- Android <-> Android screen sharing;
- Android <-> iOS screen sharing;
- iOS <-> iOS screen sharing;
- exactly one sender and one viewer per session;
- `Share My Screen` and `View a Screen` primary flows;
- user-selectable Local, Direct, and Internet modes;
- Local mode works without Internet;
- Direct mode works without Internet where the devices have a compatible direct
  transport;
- Internet mode prefers direct connectivity and falls back to relay when needed;
- temporary join code and shareable-link joining;
- sender approval before the viewer sees screen content;
- screen sharing continues while the sender navigates other apps where the OS
  permits it;
- optional microphone/voice;
- optional best-effort device/app audio;
- adaptive video quality;
- automatic orientation handling;
- no accounts, remote control, recording, session history, annotations, or QR
  requirement.

## 13. Success criteria

Under supported conditions, V1 targets:

- **>=98%** successful session establishment;
- first usable screen frame within **5 seconds after sender approval**;
- typical Local/Direct viewing latency below **500 ms**;
- typical Internet viewing latency below **1 second** where network conditions
  permit;
- recovery from temporary network disruption without unnecessarily ending the
  entire session.

"Supported conditions" means the participating devices meet the supported OS
floor, required user permissions are granted, the selected connection mode has
the network capability it requires, and any required Greenfield5 service is
operational.

These are product targets and acceptance measures, not commitments to a
particular protocol or infrastructure implementation.

## 14. Architecture boundary

Discovery does **not** select:

- mobile framework or language;
- real-time media/WebRTC library;
- signalling protocol or service;
- STUN/TURN/relay implementation or provider;
- codec policy;
- end-to-end encryption/key-distribution implementation;
- backend language/framework;
- database;
- hosting platform;
- observability vendor.

Those decisions must be researched and recorded during the architecture phase,
with material technical choices captured as ADRs before implementation is
allowed.

## Discovery source

Product decisions were captured and reconciled in GitHub Issue #3. If an older
issue comment conflicts with this document, later product-owner corrections and
the final authoritative discovery checkpoint in Issue #3 take precedence.
