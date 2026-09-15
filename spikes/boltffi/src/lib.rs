//! Isolated candidate; same product implementation files, no semantic clone.
#[path = "../../../core/src/session.rs"]
#[deny(unsafe_code)]
pub mod session;
#[path = "../../../core/src/seam.rs"]
#[deny(unsafe_code)]
pub mod seam;

pub fn version() -> &'static str { env!("CARGO_PKG_VERSION") }

use std::sync::Mutex;

use crate::seam::CoreError;
use crate::session::{
    ConnectionMode as CoreMode, Role as CoreRole, Session, SessionCommand as CoreCommand,
    SessionError, SessionState as CoreState,
};

/// Role of this device in a one-sender/one-viewer session.
#[boltffi::data]
#[derive( Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Role {
    Sender,
    Viewer,
}

impl From<CoreRole> for Role {
    fn from(r: CoreRole) -> Self {
        match r {
            CoreRole::Sender => Role::Sender,
            CoreRole::Viewer => Role::Viewer,
        }
    }
}

impl From<Role> for CoreRole {
    fn from(r: Role) -> Self {
        match r {
            Role::Sender => CoreRole::Sender,
            Role::Viewer => CoreRole::Viewer,
        }
    }
}

/// User-selected connection mode.
#[boltffi::data]
#[derive( Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ConnectionMode {
    Local,
    Direct,
    Internet,
}

impl From<CoreMode> for ConnectionMode {
    fn from(m: CoreMode) -> Self {
        match m {
            CoreMode::Local => ConnectionMode::Local,
            CoreMode::Direct => ConnectionMode::Direct,
            CoreMode::Internet => ConnectionMode::Internet,
        }
    }
}

impl From<ConnectionMode> for CoreMode {
    fn from(m: ConnectionMode) -> Self {
        match m {
            ConnectionMode::Local => CoreMode::Local,
            ConnectionMode::Direct => CoreMode::Direct,
            ConnectionMode::Internet => CoreMode::Internet,
        }
    }
}

/// Lifecycle state of a session.
#[boltffi::data]
#[derive( Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum SessionState {
    Idle,
    AwaitingPeer,
    AwaitingApproval,
    Active,
    SharingInterrupted,
    Ended,
}

impl From<CoreState> for SessionState {
    fn from(s: CoreState) -> Self {
        match s {
            CoreState::Idle => SessionState::Idle,
            CoreState::AwaitingPeer => SessionState::AwaitingPeer,
            CoreState::AwaitingApproval => SessionState::AwaitingApproval,
            CoreState::Active => SessionState::Active,
            CoreState::SharingInterrupted => SessionState::SharingInterrupted,
            CoreState::Ended => SessionState::Ended,
        }
    }
}

impl From<SessionState> for CoreState {
    fn from(s: SessionState) -> Self {
        match s {
            SessionState::Idle => CoreState::Idle,
            SessionState::AwaitingPeer => CoreState::AwaitingPeer,
            SessionState::AwaitingApproval => CoreState::AwaitingApproval,
            SessionState::Active => CoreState::Active,
            SessionState::SharingInterrupted => CoreState::SharingInterrupted,
            SessionState::Ended => CoreState::Ended,
        }
    }
}

/// Command applied to a session.
#[boltffi::data]
#[derive( Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum SessionCommand {
    StartPairing,
    RequestJoin,
    PeerRequestedJoin,
    ApproveViewer,
    ApprovalReceived,
    CaptureStarted,
    CaptureStopped,
    End,
}

impl From<CoreCommand> for SessionCommand {
    fn from(c: CoreCommand) -> Self {
        match c {
            CoreCommand::StartPairing => SessionCommand::StartPairing,
            CoreCommand::RequestJoin => SessionCommand::RequestJoin,
            CoreCommand::PeerRequestedJoin => SessionCommand::PeerRequestedJoin,
            CoreCommand::ApproveViewer => SessionCommand::ApproveViewer,
            CoreCommand::ApprovalReceived => SessionCommand::ApprovalReceived,
            CoreCommand::CaptureStarted => SessionCommand::CaptureStarted,
            CoreCommand::CaptureStopped => SessionCommand::CaptureStopped,
            CoreCommand::End => SessionCommand::End,
        }
    }
}

impl From<SessionCommand> for CoreCommand {
    fn from(c: SessionCommand) -> Self {
        match c {
            SessionCommand::StartPairing => CoreCommand::StartPairing,
            SessionCommand::RequestJoin => CoreCommand::RequestJoin,
            SessionCommand::PeerRequestedJoin => CoreCommand::PeerRequestedJoin,
            SessionCommand::ApproveViewer => CoreCommand::ApproveViewer,
            SessionCommand::ApprovalReceived => CoreCommand::ApprovalReceived,
            SessionCommand::CaptureStarted => CoreCommand::CaptureStarted,
            SessionCommand::CaptureStopped => CoreCommand::CaptureStopped,
            SessionCommand::End => CoreCommand::End,
        }
    }
}

/// Errors surfaced through the BoltFFI bridge.
///
/// This flattens `seam::CoreError` and `session::SessionError` into a single
/// candidate error enum, preserving stable semantics.
#[boltffi::error]
#[derive(Debug, thiserror::Error, Clone, Copy, PartialEq, Eq)]
pub enum BridgeError {
    #[error("unknown role code: {code}")]
    UnknownRoleCode { code: u8 },
    #[error("unknown connection-mode code: {code}")]
    UnknownModeCode { code: u8 },
    #[error("unknown command code: {code}")]
    UnknownCommandCode { code: u8 },
    #[error("command requires the {expected:?} role")]
    RoleMismatch { expected: Role },
    #[error("command {command:?} is not valid in state {state:?}")]
    InvalidTransition {
        state: SessionState,
        command: SessionCommand,
    },
    #[error("a viewer is already connected; sessions are one-to-one")]
    ViewerAlreadyConnected,
    #[error("the session has ended; Ended is terminal")]
    SessionEnded,
}

impl From<CoreError> for BridgeError {
    fn from(e: CoreError) -> Self {
        match e {
            CoreError::UnknownRoleCode(code) => BridgeError::UnknownRoleCode { code },
            CoreError::UnknownModeCode(code) => BridgeError::UnknownModeCode { code },
            CoreError::UnknownCommandCode(code) => BridgeError::UnknownCommandCode { code },
            CoreError::Session(se) => se.into(),
        }
    }
}

impl From<SessionError> for BridgeError {
    fn from(e: SessionError) -> Self {
        match e {
            SessionError::RoleMismatch { expected } => BridgeError::RoleMismatch {
                expected: expected.into(),
            },
            SessionError::InvalidTransition { state, command } => BridgeError::InvalidTransition {
                state: state.into(),
                command: command.into(),
            },
            SessionError::ViewerAlreadyConnected => BridgeError::ViewerAlreadyConnected,
            SessionError::SessionEnded => BridgeError::SessionEnded,
        }
    }
}

/// One live session behind the BoltFFI bridge.
///
/// Opaque to shells: they hold it by generated handle and interact through typed
/// enums, not u8 codes (though u8-code methods remain for backwards compat
/// with the existing seam).
#[derive(Debug)]
pub struct GreenfieldSession {
    inner: Mutex<Session>,
}

#[boltffi::export]
impl GreenfieldSession {
    /// Creates a new session for the given role and mode.
    pub fn new(role: Role, mode: ConnectionMode) -> Self {
        let session = Session::new(role.into(), mode.into());
        Self {
            inner: Mutex::new(session),
        }
    }

    /// Creates a session from stable u8 wire codes (seam compatibility).
    pub fn from_codes(role_code: u8, mode_code: u8) -> Result<Self, BridgeError> {
        let role = CoreRole::from_code(role_code)
            .ok_or(BridgeError::UnknownRoleCode { code: role_code })?;
        let mode = CoreMode::from_code(mode_code)
            .ok_or(BridgeError::UnknownModeCode { code: mode_code })?;
        let session = Session::new(role, mode);
        Ok(Self {
            inner: Mutex::new(session),
        })
    }

    /// Current role.
    pub fn role(&self) -> Role {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .role()
            .into()
    }

    /// Current connection mode.
    pub fn mode(&self) -> ConnectionMode {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .mode()
            .into()
    }

    /// Current lifecycle state.
    pub fn state(&self) -> SessionState {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .state()
            .into()
    }

    /// Whether viewer has been approved.
    pub fn viewer_approved(&self) -> bool {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .viewer_approved()
    }

    /// Applies a typed command, returning new state.
    pub fn apply(&self, command: SessionCommand) -> Result<SessionState, BridgeError> {
        let mut guard = self.inner.lock().expect("session lock poisoned");
        let state = guard.apply(command.into())?;
        Ok(state.into())
    }

    /// Stable role code (seam compat).
    pub fn role_code(&self) -> u8 {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .role()
            .code()
    }

    /// Stable connection-mode code (seam compat).
    pub fn connection_mode_code(&self) -> u8 {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .mode()
            .code()
    }

    /// Stable state code (seam compat).
    pub fn state_code(&self) -> u8 {
        self.inner
            .lock()
            .expect("session lock poisoned")
            .state()
            .code()
    }

    /// Applies a command given as stable u8 wire code (seam compat).
    pub fn send_command(&self, command_code: u8) -> Result<u8, BridgeError> {
        let command = CoreCommand::from_code(command_code)
            .ok_or(BridgeError::UnknownCommandCode { code: command_code })?;
        let mut guard = self.inner.lock().expect("session lock poisoned");
        let state = guard.apply(command)?;
        Ok(state.code())
    }
}

/// Core version string for shell-side sanity checks.
#[boltffi::export]
pub fn core_version() -> String {
    crate::version().to_string()
}

/// Convenience: role wire codes matching `seam::codes`.
#[boltffi::export]
pub fn role_sender_code() -> u8 {
    CoreRole::Sender.code()
}

/// Viewer role wire code.
#[boltffi::export]
pub fn role_viewer_code() -> u8 {
    CoreRole::Viewer.code()
}

/// Local mode wire code.
#[boltffi::export]
pub fn mode_local_code() -> u8 {
    CoreMode::Local.code()
}

/// Direct mode wire code.
#[boltffi::export]
pub fn mode_direct_code() -> u8 {
    CoreMode::Direct.code()
}

/// Internet mode wire code.
#[boltffi::export]
pub fn mode_internet_code() -> u8 {
    CoreMode::Internet.code()
}


#[boltffi::data]
#[derive(Clone, Debug, PartialEq)]
pub struct LayoutProbe {
    pub flag: u8,
    pub wide: u64,
    pub short: u16,
    pub text: String,
}

#[boltffi::export]
pub fn round_trip(value: LayoutProbe) -> LayoutProbe { value }

use std::sync::{Arc, atomic::{AtomicBool, AtomicU32, Ordering}};
use std::task::{Context, Poll, Waker};
use std::pin::Pin;
use std::future::Future;

pub struct AsyncProbe {
    released: AtomicBool,
    active: AtomicU32,
    waker: Mutex<Option<Waker>>,
}
struct WaitGuard<'a>(&'a AsyncProbe);
impl Drop for WaitGuard<'_> {
    fn drop(&mut self) { self.0.active.fetch_sub(1, Ordering::SeqCst); }
}
struct Gate<'a>(&'a AsyncProbe);
impl Future for Gate<'_> {
    type Output = ();
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
        let mut waker = self.0.waker.lock().expect("probe waker lock");
        if self.0.released.load(Ordering::SeqCst) { Poll::Ready(()) }
        else { *waker = Some(cx.waker().clone()); Poll::Pending }
    }
}
#[boltffi::export]
impl AsyncProbe {
    pub fn new() -> Self {
        Self { released: AtomicBool::new(false), active: AtomicU32::new(0), waker: Mutex::new(None) }
    }
    pub fn active(&self) -> u32 { self.active.load(Ordering::SeqCst) }
    pub fn release(&self) {
        self.released.store(true, Ordering::SeqCst);
        if let Some(waker) = self.waker.lock().expect("probe waker lock").take() { waker.wake(); }
    }
    pub async fn wait_value(&self, sequence: u32, fail: bool) -> Result<u32, BridgeError> {
        self.active.fetch_add(1, Ordering::SeqCst);
        let _guard = WaitGuard(self);
        Gate(self).await;
        if fail { Err(BridgeError::SessionEnded) } else { Ok(sequence) }
    }
    pub fn hold(&self, milliseconds: u32) -> u32 {
        self.active.fetch_add(1, Ordering::SeqCst);
        let _guard = WaitGuard(self);
        std::thread::sleep(std::time::Duration::from_millis(u64::from(milliseconds.min(100))));
        42
    }
}

pub struct EventProbe {
    subscription: Arc<boltffi::EventSubscription<u32>>,
    produced: AtomicU32,
    dropped: AtomicU32,
}
#[boltffi::export]
impl EventProbe {
    pub fn new() -> Self {
        Self { subscription: Arc::new(boltffi::EventSubscription::new(8)), produced: AtomicU32::new(0), dropped: AtomicU32::new(0) }
    }
    #[boltffi::ffi_stream(item = u32)]
    pub fn events(&self) -> Arc<boltffi::EventSubscription<u32>> { self.subscription.clone() }
    #[boltffi::ffi_stream(item = u32, mode = "batch")]
    pub fn events_batch(&self) -> Arc<boltffi::EventSubscription<u32>> { self.subscription.clone() }
    pub fn produce(&self, count: u32) -> u32 {
        let mut accepted = 0;
        for _ in 0..count.min(100_000) {
            let sequence = self.produced.fetch_add(1, Ordering::SeqCst);
            if self.subscription.push_event(sequence) { accepted += 1; }
            else { self.dropped.fetch_add(1, Ordering::SeqCst); }
        }
        accepted
    }
    pub fn produced(&self) -> u32 { self.produced.load(Ordering::SeqCst) }
    pub fn dropped(&self) -> u32 { self.dropped.load(Ordering::SeqCst) }
    pub fn stop(&self) { self.subscription.unsubscribe(); }
    pub fn is_active(&self) -> bool { self.subscription.is_active() }
}
