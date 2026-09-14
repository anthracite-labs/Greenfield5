//! The narrow native/core seam.
//!
//! This facade is the **only** surface the Android and iOS shells are allowed
//! to consume, and it deliberately speaks in stable `u8` wire codes instead of
//! Rust types: whatever FFI mechanism the bridge follow-up pins (UniFFI is the
//! first candidate — ADR-0005/ADR-0006), it will export exactly this surface,
//! and no UI code will ever depend on transport internals or Rust-side types.
//!
//! Contract:
//!
//! - codes are stable integers; adding a variant never renumbers existing ones;
//! - unknown codes are rejected with [`CoreError`], never guessed;
//! - every operation is synchronous and cheap (state machine only — no I/O);
//! - errors carry stable codes too, so shells can map them to UI without
//!   parsing strings.

use std::fmt;

use crate::session::{ConnectionMode, Role, Session, SessionCommand, SessionError};

/// Everything that can go wrong at the seam, in code-friendly form.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CoreError {
    /// A role code outside the stable set was passed in.
    UnknownRoleCode(u8),
    /// A connection-mode code outside the stable set was passed in.
    UnknownModeCode(u8),
    /// A command code outside the stable set was passed in.
    UnknownCommandCode(u8),
    /// The session state machine rejected the command.
    Session(SessionError),
}

impl fmt::Display for CoreError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CoreError::UnknownRoleCode(code) => write!(f, "unknown role code: {code}"),
            CoreError::UnknownModeCode(code) => write!(f, "unknown connection-mode code: {code}"),
            CoreError::UnknownCommandCode(code) => write!(f, "unknown command code: {code}"),
            CoreError::Session(error) => write!(f, "session rejected the command: {error}"),
        }
    }
}

impl std::error::Error for CoreError {}

impl From<SessionError> for CoreError {
    fn from(error: SessionError) -> Self {
        CoreError::Session(error)
    }
}

/// One live session behind the seam. Opaque to the shells: they hold it by a
/// handle in the future bridge and interact through codes only.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CoreSession {
    session: Session,
}

impl CoreSession {
    /// Starts a session from wire codes. Unknown codes are rejected.
    pub fn start(role_code: u8, mode_code: u8) -> Result<Self, CoreError> {
        let role = Role::from_code(role_code).ok_or(CoreError::UnknownRoleCode(role_code))?;
        let mode =
            ConnectionMode::from_code(mode_code).ok_or(CoreError::UnknownModeCode(mode_code))?;
        Ok(Self {
            session: Session::new(role, mode),
        })
    }

    /// The role code this session was started with.
    pub fn role_code(&self) -> u8 {
        self.session.role().code()
    }

    /// The connection-mode code this session was started with.
    pub fn connection_mode_code(&self) -> u8 {
        self.session.mode().code()
    }

    /// The current session state, as a wire code.
    pub fn state_code(&self) -> u8 {
        self.session.state().code()
    }

    /// Applies a command given as a wire code; returns the new state code.
    pub fn send_command(&mut self, command_code: u8) -> Result<u8, CoreError> {
        let command = SessionCommand::from_code(command_code)
            .ok_or(CoreError::UnknownCommandCode(command_code))?;
        let state = self.session.apply(command)?;
        Ok(state.code())
    }
}

/// The core version string, for shell-side sanity checks against the
/// compiled library ("does this bridge talk to the core I was built for?").
pub fn core_version() -> &'static str {
    crate::version()
}

/// Convenience aliases used by shells once the bridge exists: the canonical
/// wire codes, re-exported so the seam documents the whole vocabulary.
pub mod codes {
    use crate::session::{ConnectionMode, Role};

    /// Wire code: sender role.
    pub const ROLE_SENDER: u8 = Role::Sender as u8;
    /// Wire code: viewer role.
    pub const ROLE_VIEWER: u8 = Role::Viewer as u8;
    /// Wire code: Local connection mode.
    pub const MODE_LOCAL: u8 = ConnectionMode::Local as u8;
    /// Wire code: Direct connection mode.
    pub const MODE_DIRECT: u8 = ConnectionMode::Direct as u8;
    /// Wire code: Internet connection mode.
    pub const MODE_INTERNET: u8 = ConnectionMode::Internet as u8;
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::session::SessionState;

    #[test]
    fn start_accepts_valid_code_pairs() {
        let session = CoreSession::start(codes::ROLE_VIEWER, codes::MODE_LOCAL)
            .expect("viewer/local is a valid pair");
        assert_eq!(session.role_code(), codes::ROLE_VIEWER);
        assert_eq!(session.connection_mode_code(), codes::MODE_LOCAL);
        assert_eq!(session.state_code(), SessionState::Idle.code());
    }

    #[test]
    fn start_rejects_unknown_codes_without_guessing() {
        assert_eq!(
            CoreSession::start(9, codes::MODE_LOCAL),
            Err(CoreError::UnknownRoleCode(9))
        );
        assert_eq!(
            CoreSession::start(codes::ROLE_SENDER, 42),
            Err(CoreError::UnknownModeCode(42))
        );
    }

    #[test]
    fn sender_journey_works_purely_through_codes() {
        let mut session = CoreSession::start(codes::ROLE_SENDER, codes::MODE_INTERNET)
            .expect("sender/internet is a valid pair");
        assert_eq!(
            session.send_command(SessionCommand::StartPairing.code()),
            Ok(SessionState::AwaitingPeer.code())
        );
        assert_eq!(
            session.send_command(SessionCommand::PeerRequestedJoin.code()),
            Ok(SessionState::AwaitingApproval.code())
        );
        assert_eq!(
            session.send_command(SessionCommand::ApproveViewer.code()),
            Ok(SessionState::Active.code())
        );
        assert_eq!(session.state_code(), SessionState::Active.code());
    }

    #[test]
    fn send_command_rejects_unknown_command_codes() {
        let mut session = CoreSession::start(codes::ROLE_SENDER, codes::MODE_DIRECT)
            .expect("sender/direct is a valid pair");
        assert_eq!(
            session.send_command(200),
            Err(CoreError::UnknownCommandCode(200))
        );
        assert_eq!(session.state_code(), SessionState::Idle.code());
    }

    #[test]
    fn session_errors_surface_as_core_errors() {
        let mut session = CoreSession::start(codes::ROLE_VIEWER, codes::MODE_LOCAL)
            .expect("viewer/local is a valid pair");
        assert_eq!(
            session.send_command(SessionCommand::ApproveViewer.code()),
            Err(CoreError::Session(SessionError::RoleMismatch {
                expected: Role::Sender,
            }))
        );
    }

    #[test]
    fn core_version_is_present_and_matches_the_crate() {
        assert_eq!(core_version(), crate::version());
        assert!(!core_version().is_empty());
    }

    #[test]
    fn code_constants_match_the_session_enums() {
        assert_eq!(codes::ROLE_SENDER, Role::Sender.code());
        assert_eq!(codes::ROLE_VIEWER, Role::Viewer.code());
        assert_eq!(codes::MODE_LOCAL, ConnectionMode::Local.code());
        assert_eq!(codes::MODE_DIRECT, ConnectionMode::Direct.code());
        assert_eq!(codes::MODE_INTERNET, ConnectionMode::Internet.code());
    }

    #[test]
    fn errors_render_human_readable_messages() {
        assert!(!CoreError::UnknownRoleCode(7).to_string().is_empty());
        assert!(
            !CoreError::Session(SessionError::SessionEnded)
                .to_string()
                .is_empty()
        );
    }
}
