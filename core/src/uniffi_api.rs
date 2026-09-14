//! UniFFI bridge for Greenfield5 core.
//!
//! This module exposes the existing session state machine via UniFFI
//! proc-macros, pinned at 0.32.1 (mozilla/uniffi-rs tags v0.32.1 35a47433,
//! v0.32.0 5c7b739). It delegates to `crate::session` and `crate::seam`
//! without expanding session semantics — the stable u8 wire codes remain
//! the underlying contract.
//!
//! The API is intentionally narrow: native UI depends on this bridge only,
//! never on transport internals (which do not exist yet).

use std::sync::{Arc, Mutex};

use crate::seam::CoreError;
use crate::session::{
    ConnectionMode as CoreMode, Role as CoreRole, Session,
    SessionCommand as CoreCommand, SessionError, SessionState as CoreState,
};

/// Role of this device in a one-sender/one-viewer session.
#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq, Hash)]
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
#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq, Hash)]
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
#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq, Hash)]
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
#[derive(uniffi::Enum, Clone, Copy, Debug, PartialEq, Eq, Hash)]
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

/// Errors surfaced through the UniFFI bridge.
///
/// This flattens `seam::CoreError` and `session::SessionError` into a single
/// UniFFI-compatible error enum, preserving stable semantics.
#[derive(Debug, thiserror::Error, uniffi::Error, Clone, Copy, PartialEq, Eq)]
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
            CoreError::UnknownRoleCode(code) => {
                BridgeError::UnknownRoleCode { code }
            }
            CoreError::UnknownModeCode(code) => {
                BridgeError::UnknownModeCode { code }
            }
            CoreError::UnknownCommandCode(code) => {
                BridgeError::UnknownCommandCode { code }
            }
            CoreError::Session(se) => se.into(),
        }
    }
}

impl From<SessionError> for BridgeError {
    fn from(e: SessionError) -> Self {
        match e {
            SessionError::RoleMismatch { expected } => {
                BridgeError::RoleMismatch {
                    expected: expected.into(),
                }
            }
            SessionError::InvalidTransition { state, command } => {
                BridgeError::InvalidTransition {
                    state: state.into(),
                    command: command.into(),
                }
            }
            SessionError::ViewerAlreadyConnected => {
                BridgeError::ViewerAlreadyConnected
            }
            SessionError::SessionEnded => BridgeError::SessionEnded,
        }
    }
}

/// One live session behind the UniFFI bridge.
///
/// Opaque to shells: they hold it by Arc handle and interact through typed
/// enums, not u8 codes (though u8-code methods remain for backwards compat
/// with the existing seam).
#[derive(uniffi::Object, Debug)]
pub struct GreenfieldSession {
    inner: Mutex<Session>,
}

#[uniffi::export]
impl GreenfieldSession {
    /// Creates a new session for the given role and mode.
    #[uniffi::constructor]
    pub fn new(role: Role, mode: ConnectionMode) -> Arc<Self> {
        let session = Session::new(role.into(), mode.into());
        Arc::new(Self {
            inner: Mutex::new(session),
        })
    }

    /// Creates a session from stable u8 wire codes (seam compatibility).
    #[uniffi::constructor]
    pub fn from_codes(
        role_code: u8,
        mode_code: u8,
    ) -> Result<Arc<Self>, BridgeError> {
        let role = CoreRole::from_code(role_code)
            .ok_or(BridgeError::UnknownRoleCode { code: role_code })?;
        let mode = CoreMode::from_code(mode_code)
            .ok_or(BridgeError::UnknownModeCode { code: mode_code })?;
        let session = Session::new(role, mode);
        Ok(Arc::new(Self {
            inner: Mutex::new(session),
        }))
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
    pub fn apply(
        &self,
        command: SessionCommand,
    ) -> Result<SessionState, BridgeError> {
        let mut guard = self
            .inner
            .lock()
            .expect("session lock poisoned");
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
    pub fn send_command(
        &self,
        command_code: u8,
    ) -> Result<u8, BridgeError> {
        let command = CoreCommand::from_code(command_code)
            .ok_or(BridgeError::UnknownCommandCode {
                code: command_code,
            })?;
        let mut guard = self
            .inner
            .lock()
            .expect("session lock poisoned");
        let state = guard.apply(command)?;
        Ok(state.code())
    }
}

/// Core version string for shell-side sanity checks.
#[uniffi::export]
pub fn core_version() -> String {
    crate::version().to_string()
}

/// Convenience: role wire codes matching `seam::codes`.
#[uniffi::export]
pub fn role_sender_code() -> u8 {
    CoreRole::Sender.code()
}

/// Viewer role wire code.
#[uniffi::export]
pub fn role_viewer_code() -> u8 {
    CoreRole::Viewer.code()
}

/// Local mode wire code.
#[uniffi::export]
pub fn mode_local_code() -> u8 {
    CoreMode::Local.code()
}

/// Direct mode wire code.
#[uniffi::export]
pub fn mode_direct_code() -> u8 {
    CoreMode::Direct.code()
}

/// Internet mode wire code.
#[uniffi::export]
pub fn mode_internet_code() -> u8 {
    CoreMode::Internet.code()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn new_session_via_uniffi_api_starts_idle() {
        let session =
            GreenfieldSession::new(Role::Sender, ConnectionMode::Internet);
        assert_eq!(session.role(), Role::Sender);
        assert_eq!(session.mode(), ConnectionMode::Internet);
        assert_eq!(session.state(), SessionState::Idle);
        assert!(!session.viewer_approved());
    }

    #[test]
    fn typed_apply_journey_reaches_active() {
        let session =
            GreenfieldSession::new(Role::Sender, ConnectionMode::Local);
        assert_eq!(
            session.apply(SessionCommand::StartPairing).unwrap(),
            SessionState::AwaitingPeer
        );
        assert_eq!(
            session
                .apply(SessionCommand::PeerRequestedJoin)
                .unwrap(),
            SessionState::AwaitingApproval
        );
        assert_eq!(
            session.apply(SessionCommand::ApproveViewer).unwrap(),
            SessionState::Active
        );
        assert!(session.viewer_approved());
    }

    #[test]
    fn from_codes_rejects_unknown() {
        assert!(GreenfieldSession::from_codes(9, 0).is_err());
        assert!(GreenfieldSession::from_codes(0, 42).is_err());
    }

    #[test]
    fn send_command_via_code_works() {
        let session = GreenfieldSession::from_codes(0, 2).unwrap();
        let code = session.send_command(0).unwrap(); // StartPairing
        assert_eq!(code, SessionState::AwaitingPeer as u8);
    }

    #[test]
    fn bridge_error_maps_role_mismatch() {
        let session =
            GreenfieldSession::new(Role::Viewer, ConnectionMode::Local);
        let err = session
            .apply(SessionCommand::ApproveViewer)
            .unwrap_err();
        assert_eq!(
            err,
            BridgeError::RoleMismatch {
                expected: Role::Sender
            }
        );
    }

    #[test]
    fn core_version_is_non_empty() {
        assert!(!core_version().is_empty());
    }

    #[test]
    fn wire_code_helpers_match_core() {
        assert_eq!(role_sender_code(), CoreRole::Sender.code());
        assert_eq!(role_viewer_code(), CoreRole::Viewer.code());
        assert_eq!(mode_local_code(), CoreMode::Local.code());
        assert_eq!(mode_direct_code(), CoreMode::Direct.code());
        assert_eq!(mode_internet_code(), CoreMode::Internet.code());
    }
}
