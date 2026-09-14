//! Session role/state model — the first shared product logic of Greenfield5.
//!
//! Encodes the invariants from `docs/PRODUCT.md` that both native shells must
//! agree on:
//!
//! - every install acts as exactly one [`Role`] per session (sender or viewer,
//!   PRODUCT.md §2);
//! - the user selects one [`ConnectionMode`] per session (PRODUCT.md §3);
//! - exactly one viewer: once a viewer is connected, additional viewers are
//!   rejected (PRODUCT.md §4);
//! - the sender must approve the viewer before screen data flows (PRODUCT.md §4);
//! - screen sharing can stop while the session remains alive, and can resume
//!   (PRODUCT.md §7);
//! - sessions are temporary: [`SessionState::Ended`] is terminal (PRODUCT.md §4).
//!
//! Transport, pairing codes, and media do not exist yet; this module models
//! only the shared state machine they will all defer to. Wire codes on every
//! enum are stable integers reserved for the [`crate::seam`] boundary.

use std::fmt;

/// Which side of the one-sender/one-viewer session this device plays.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum Role {
    /// The device capturing and sharing its own screen.
    Sender = 0,
    /// The device receiving and displaying the sender's screen.
    Viewer = 1,
}

impl Role {
    /// The stable wire code for this role.
    pub fn code(self) -> u8 {
        self as u8
    }

    /// Decodes a wire code; unknown codes are rejected, never guessed.
    pub fn from_code(code: u8) -> Option<Self> {
        match code {
            0 => Some(Role::Sender),
            1 => Some(Role::Viewer),
            _ => None,
        }
    }
}

/// The user-selected connection mode for a session (PRODUCT.md §3).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum ConnectionMode {
    /// Same Wi-Fi/LAN; media stays local, no Internet required.
    Local = 0,
    /// Nearby device-to-device path without an Internet hop.
    Direct = 1,
    /// Anywhere; direct-first with relay fallback (ADR-0005).
    Internet = 2,
}

impl ConnectionMode {
    /// The stable wire code for this mode.
    pub fn code(self) -> u8 {
        self as u8
    }

    /// Decodes a wire code; unknown codes are rejected, never guessed.
    pub fn from_code(code: u8) -> Option<Self> {
        match code {
            0 => Some(ConnectionMode::Local),
            1 => Some(ConnectionMode::Direct),
            2 => Some(ConnectionMode::Internet),
            _ => None,
        }
    }
}

/// Where a session is in its lifecycle.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum SessionState {
    /// Created, nothing started yet.
    Idle = 0,
    /// Sender: pairing has started and the session awaits a viewer.
    AwaitingPeer = 1,
    /// A viewer has joined/requested and sender approval is pending.
    AwaitingApproval = 2,
    /// Approved: screen data may flow (PRODUCT.md §4).
    Active = 3,
    /// Sharing stopped (capture revoked, OS lock, …) but the session is
    /// still alive (PRODUCT.md §7).
    SharingInterrupted = 4,
    /// Terminal: the session is over and its state is not reusable.
    Ended = 5,
}

impl SessionState {
    /// The stable wire code for this state.
    pub fn code(self) -> u8 {
        self as u8
    }

    /// Decodes a wire code; unknown codes are rejected, never guessed.
    pub fn from_code(code: u8) -> Option<Self> {
        match code {
            0 => Some(SessionState::Idle),
            1 => Some(SessionState::AwaitingPeer),
            2 => Some(SessionState::AwaitingApproval),
            3 => Some(SessionState::Active),
            4 => Some(SessionState::SharingInterrupted),
            5 => Some(SessionState::Ended),
            _ => None,
        }
    }
}

/// An event applied to a [`Session`]. Commands are role-checked and
/// state-checked; applying one either moves the state or returns the reason
/// it could not.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
#[repr(u8)]
pub enum SessionCommand {
    /// Sender: open the session for pairing (`Idle -> AwaitingPeer`).
    StartPairing = 0,
    /// Viewer: a join request was sent (`Idle -> AwaitingApproval`).
    RequestJoin = 1,
    /// Sender: a viewer arrived and awaits approval
    /// (`AwaitingPeer -> AwaitingApproval`).
    PeerRequestedJoin = 2,
    /// Sender: approve the waiting viewer (`AwaitingApproval -> Active`).
    ApproveViewer = 3,
    /// Viewer: the sender approved us (`AwaitingApproval -> Active`).
    ApprovalReceived = 4,
    /// Sharing (re)started after an interruption
    /// (`SharingInterrupted -> Active`).
    CaptureStarted = 5,
    /// Sharing stopped while the session lives (`Active -> SharingInterrupted`).
    CaptureStopped = 6,
    /// End the session from any non-terminal state (`-> Ended`).
    End = 7,
}

impl SessionCommand {
    /// The stable wire code for this command.
    pub fn code(self) -> u8 {
        self as u8
    }

    /// Decodes a wire code; unknown codes are rejected, never guessed.
    pub fn from_code(code: u8) -> Option<Self> {
        match code {
            0 => Some(SessionCommand::StartPairing),
            1 => Some(SessionCommand::RequestJoin),
            2 => Some(SessionCommand::PeerRequestedJoin),
            3 => Some(SessionCommand::ApproveViewer),
            4 => Some(SessionCommand::ApprovalReceived),
            5 => Some(SessionCommand::CaptureStarted),
            6 => Some(SessionCommand::CaptureStopped),
            7 => Some(SessionCommand::End),
            _ => None,
        }
    }
}

/// Why a command could not be applied.
///
/// Error precedence (most specific first): [`SessionError::SessionEnded`],
/// then [`SessionError::RoleMismatch`], then
/// [`SessionError::ViewerAlreadyConnected`], then
/// [`SessionError::InvalidTransition`].
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionError {
    /// The command belongs to the other role.
    RoleMismatch {
        /// The role this command requires.
        expected: Role,
    },
    /// The command is not valid in the session's current state.
    InvalidTransition {
        /// The state the session was in.
        state: SessionState,
        /// The command that was rejected.
        command: SessionCommand,
    },
    /// Exactly one viewer per session (PRODUCT.md §4).
    ViewerAlreadyConnected,
    /// The session has ended; ended is terminal.
    SessionEnded,
}

impl fmt::Display for SessionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SessionError::RoleMismatch { expected } => {
                write!(f, "command requires the {expected:?} role")
            }
            SessionError::InvalidTransition { state, command } => {
                write!(f, "{command:?} is not valid in state {state:?}")
            }
            SessionError::ViewerAlreadyConnected => {
                write!(f, "a viewer is already connected; sessions are one-to-one")
            }
            SessionError::SessionEnded => write!(f, "the session has ended; Ended is terminal"),
        }
    }
}

impl std::error::Error for SessionError {}

/// One temporary Greenfield5 session: a role, a connection mode, and the
/// state machine that both shells drive through [`Session::apply`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Session {
    role: Role,
    mode: ConnectionMode,
    state: SessionState,
    viewer_connected: bool,
    viewer_approved: bool,
}

impl Session {
    /// Creates a session in [`SessionState::Idle`] for the given role and mode.
    pub fn new(role: Role, mode: ConnectionMode) -> Self {
        Self {
            role,
            mode,
            state: SessionState::Idle,
            viewer_connected: false,
            viewer_approved: false,
        }
    }

    /// The role this device plays in the session.
    pub fn role(&self) -> Role {
        self.role
    }

    /// The user-selected connection mode.
    pub fn mode(&self) -> ConnectionMode {
        self.mode
    }

    /// The current lifecycle state.
    pub fn state(&self) -> SessionState {
        self.state
    }

    /// Whether the sender has approved the viewer (PRODUCT.md §4).
    pub fn viewer_approved(&self) -> bool {
        self.viewer_approved
    }

    /// Applies a command, returning the new state or the reason it was
    /// rejected. On error the session is unchanged.
    ///
    /// Check order implements the documented error precedence: the terminal
    /// check first, then role, then the one-viewer rule, then state.
    pub fn apply(&mut self, command: SessionCommand) -> Result<SessionState, SessionError> {
        if self.state == SessionState::Ended {
            return Err(SessionError::SessionEnded);
        }
        let next = match command {
            SessionCommand::End => SessionState::Ended,
            SessionCommand::StartPairing => {
                self.require_role(Role::Sender)?;
                self.require_state(SessionState::Idle, command)?;
                SessionState::AwaitingPeer
            }
            SessionCommand::RequestJoin => {
                self.require_role(Role::Viewer)?;
                self.require_state(SessionState::Idle, command)?;
                SessionState::AwaitingApproval
            }
            SessionCommand::PeerRequestedJoin => {
                self.require_role(Role::Sender)?;
                if self.viewer_connected {
                    return Err(SessionError::ViewerAlreadyConnected);
                }
                self.require_state(SessionState::AwaitingPeer, command)?;
                self.viewer_connected = true;
                SessionState::AwaitingApproval
            }
            SessionCommand::ApproveViewer => {
                self.require_role(Role::Sender)?;
                self.require_state(SessionState::AwaitingApproval, command)?;
                self.viewer_approved = true;
                SessionState::Active
            }
            SessionCommand::ApprovalReceived => {
                self.require_role(Role::Viewer)?;
                self.require_state(SessionState::AwaitingApproval, command)?;
                self.viewer_approved = true;
                SessionState::Active
            }
            SessionCommand::CaptureStarted => {
                self.require_state(SessionState::SharingInterrupted, command)?;
                SessionState::Active
            }
            SessionCommand::CaptureStopped => {
                self.require_state(SessionState::Active, command)?;
                SessionState::SharingInterrupted
            }
        };
        self.state = next;
        Ok(next)
    }

    fn require_role(&self, expected: Role) -> Result<(), SessionError> {
        if self.role == expected {
            Ok(())
        } else {
            Err(SessionError::RoleMismatch { expected })
        }
    }

    fn require_state(
        &self,
        expected: SessionState,
        command: SessionCommand,
    ) -> Result<(), SessionError> {
        if self.state == expected {
            Ok(())
        } else {
            Err(SessionError::InvalidTransition {
                state: self.state,
                command,
            })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sender_in(mode: ConnectionMode) -> Session {
        Session::new(Role::Sender, mode)
    }

    fn viewer_in(mode: ConnectionMode) -> Session {
        Session::new(Role::Viewer, mode)
    }

    /// Sender session that has opened pairing: state = AwaitingPeer.
    fn pairing_sender() -> Session {
        let mut s = sender_in(ConnectionMode::Internet);
        s.apply(SessionCommand::StartPairing)
            .expect("start pairing must succeed from Idle");
        s
    }

    /// Sender session with a viewer waiting for approval.
    fn sender_with_waiting_viewer() -> Session {
        let mut s = pairing_sender();
        s.apply(SessionCommand::PeerRequestedJoin)
            .expect("first viewer must be accepted");
        s
    }

    /// Sender session in Active.
    fn active_sender() -> Session {
        let mut s = sender_with_waiting_viewer();
        s.apply(SessionCommand::ApproveViewer)
            .expect("approval must succeed with a waiting viewer");
        s
    }

    /// Viewer session in Active.
    fn active_viewer() -> Session {
        let mut s = viewer_in(ConnectionMode::Local);
        s.apply(SessionCommand::RequestJoin)
            .expect("request join must succeed from Idle");
        s.apply(SessionCommand::ApprovalReceived)
            .expect("approval must be receivable while awaiting approval");
        s
    }

    // --- construction -------------------------------------------------------

    #[test]
    fn new_session_starts_idle_with_its_role_and_mode() {
        let s = sender_in(ConnectionMode::Direct);
        assert_eq!(s.role(), Role::Sender);
        assert_eq!(s.mode(), ConnectionMode::Direct);
        assert_eq!(s.state(), SessionState::Idle);
        assert!(!s.viewer_approved());
    }

    #[test]
    fn new_viewer_session_starts_idle() {
        let s = viewer_in(ConnectionMode::Local);
        assert_eq!(s.role(), Role::Viewer);
        assert_eq!(s.state(), SessionState::Idle);
    }

    // --- happy paths (PRODUCT.md §2/§4) --------------------------------------

    #[test]
    fn sender_journey_reaches_active_only_after_approval() {
        let mut s = sender_in(ConnectionMode::Internet);
        assert_eq!(
            s.apply(SessionCommand::StartPairing),
            Ok(SessionState::AwaitingPeer)
        );
        assert_eq!(
            s.apply(SessionCommand::PeerRequestedJoin),
            Ok(SessionState::AwaitingApproval)
        );
        assert!(!s.viewer_approved(), "approval has not happened yet");
        assert_eq!(
            s.apply(SessionCommand::ApproveViewer),
            Ok(SessionState::Active)
        );
        assert!(s.viewer_approved());
    }

    #[test]
    fn viewer_journey_reaches_active_when_approval_arrives() {
        let mut s = viewer_in(ConnectionMode::Local);
        assert_eq!(
            s.apply(SessionCommand::RequestJoin),
            Ok(SessionState::AwaitingApproval)
        );
        assert_eq!(
            s.apply(SessionCommand::ApprovalReceived),
            Ok(SessionState::Active)
        );
        assert!(s.viewer_approved());
    }

    // --- sharing interruption (PRODUCT.md §7) --------------------------------

    #[test]
    fn sharing_can_stop_while_the_session_lives() {
        let mut s = active_sender();
        assert_eq!(
            s.apply(SessionCommand::CaptureStopped),
            Ok(SessionState::SharingInterrupted)
        );
        assert_ne!(s.state(), SessionState::Ended);
    }

    #[test]
    fn sharing_resumes_after_capture_restarts() {
        let mut s = active_sender();
        s.apply(SessionCommand::CaptureStopped)
            .expect("capture can stop while active");
        assert_eq!(
            s.apply(SessionCommand::CaptureStarted),
            Ok(SessionState::Active)
        );
    }

    #[test]
    fn viewer_side_observes_sharing_stop_and_resume() {
        let mut s = active_viewer();
        assert_eq!(
            s.apply(SessionCommand::CaptureStopped),
            Ok(SessionState::SharingInterrupted)
        );
        assert_eq!(
            s.apply(SessionCommand::CaptureStarted),
            Ok(SessionState::Active)
        );
    }

    // --- terminal state (PRODUCT.md §4: sessions are temporary) --------------

    #[test]
    fn end_is_allowed_from_every_non_ended_state() {
        let mut interrupted = active_sender();
        interrupted
            .apply(SessionCommand::CaptureStopped)
            .expect("interrupt an active session");
        let states = vec![
            // Idle
            sender_in(ConnectionMode::Local),
            // AwaitingPeer
            pairing_sender(),
            // AwaitingApproval
            sender_with_waiting_viewer(),
            // Active
            active_sender(),
            // SharingInterrupted
            interrupted,
        ];

        for mut s in states {
            assert_eq!(s.apply(SessionCommand::End), Ok(SessionState::Ended));
        }
    }

    #[test]
    fn ended_is_terminal_for_every_command() {
        let mut s = active_sender();
        s.apply(SessionCommand::End).expect("end succeeds");
        for command in [
            SessionCommand::StartPairing,
            SessionCommand::RequestJoin,
            SessionCommand::PeerRequestedJoin,
            SessionCommand::ApproveViewer,
            SessionCommand::ApprovalReceived,
            SessionCommand::CaptureStarted,
            SessionCommand::CaptureStopped,
            SessionCommand::End,
        ] {
            assert_eq!(s.apply(command), Err(SessionError::SessionEnded));
        }
    }

    // --- exactly one viewer (PRODUCT.md §4) -----------------------------------

    #[test]
    fn second_viewer_is_rejected_while_one_is_waiting() {
        let mut s = sender_with_waiting_viewer();
        assert_eq!(
            s.apply(SessionCommand::PeerRequestedJoin),
            Err(SessionError::ViewerAlreadyConnected)
        );
        assert_eq!(s.state(), SessionState::AwaitingApproval);
    }

    #[test]
    fn second_viewer_is_rejected_after_approval_too() {
        let mut s = active_sender();
        assert_eq!(
            s.apply(SessionCommand::PeerRequestedJoin),
            Err(SessionError::ViewerAlreadyConnected)
        );
        assert_eq!(s.state(), SessionState::Active);
    }

    // --- approval gate (PRODUCT.md §4) ----------------------------------------

    #[test]
    fn approval_without_a_waiting_viewer_is_rejected() {
        let mut s = sender_in(ConnectionMode::Local);
        assert_eq!(
            s.apply(SessionCommand::ApproveViewer),
            Err(SessionError::InvalidTransition {
                state: SessionState::Idle,
                command: SessionCommand::ApproveViewer,
            })
        );

        let mut pairing = pairing_sender();
        assert_eq!(
            pairing.apply(SessionCommand::ApproveViewer),
            Err(SessionError::InvalidTransition {
                state: SessionState::AwaitingPeer,
                command: SessionCommand::ApproveViewer,
            })
        );
    }

    // --- role guards -----------------------------------------------------------

    #[test]
    fn viewer_cannot_run_sender_commands() {
        let mut s = viewer_in(ConnectionMode::Direct);
        for command in [
            SessionCommand::StartPairing,
            SessionCommand::PeerRequestedJoin,
            SessionCommand::ApproveViewer,
        ] {
            assert_eq!(
                s.apply(command),
                Err(SessionError::RoleMismatch {
                    expected: Role::Sender
                })
            );
        }
        assert_eq!(s.state(), SessionState::Idle);
    }

    #[test]
    fn sender_cannot_run_viewer_commands() {
        let mut s = sender_in(ConnectionMode::Direct);
        for command in [
            SessionCommand::RequestJoin,
            SessionCommand::ApprovalReceived,
        ] {
            assert_eq!(
                s.apply(command),
                Err(SessionError::RoleMismatch {
                    expected: Role::Viewer
                })
            );
        }
        assert_eq!(s.state(), SessionState::Idle);
    }

    #[test]
    fn role_mismatch_is_reported_before_state_problems() {
        // An ended *viewer* session must not see a sender command as merely
        // "wrong state": the role guard has priority over state checks, and
        // only the terminal check outranks both.
        let mut s = viewer_in(ConnectionMode::Local);
        s.apply(SessionCommand::End).expect("end from idle");
        assert_eq!(
            s.apply(SessionCommand::StartPairing),
            Err(SessionError::SessionEnded)
        );
    }

    // --- invalid transitions ---------------------------------------------------

    #[test]
    fn pairing_cannot_start_twice() {
        let mut s = pairing_sender();
        assert_eq!(
            s.apply(SessionCommand::StartPairing),
            Err(SessionError::InvalidTransition {
                state: SessionState::AwaitingPeer,
                command: SessionCommand::StartPairing,
            })
        );
    }

    #[test]
    fn viewer_cannot_request_join_twice() {
        let mut s = viewer_in(ConnectionMode::Internet);
        s.apply(SessionCommand::RequestJoin)
            .expect("first request succeeds");
        assert_eq!(
            s.apply(SessionCommand::RequestJoin),
            Err(SessionError::InvalidTransition {
                state: SessionState::AwaitingApproval,
                command: SessionCommand::RequestJoin,
            })
        );
    }

    #[test]
    fn capture_events_require_a_live_sharing_state() {
        let mut idle = sender_in(ConnectionMode::Local);
        assert_eq!(
            idle.apply(SessionCommand::CaptureStopped),
            Err(SessionError::InvalidTransition {
                state: SessionState::Idle,
                command: SessionCommand::CaptureStopped,
            })
        );

        let mut waiting = sender_with_waiting_viewer();
        assert_eq!(
            waiting.apply(SessionCommand::CaptureStarted),
            Err(SessionError::InvalidTransition {
                state: SessionState::AwaitingApproval,
                command: SessionCommand::CaptureStarted,
            })
        );
    }

    #[test]
    fn rejected_commands_leave_the_session_unchanged() {
        let mut s = active_sender();
        let before = s.state();
        assert!(s.apply(SessionCommand::RequestJoin).is_err());
        assert!(s.apply(SessionCommand::PeerRequestedJoin).is_err());
        assert_eq!(s.state(), before);
    }

    // --- wire codes (seam stability) --------------------------------------------

    #[test]
    fn role_codes_round_trip_and_reject_unknown_codes() {
        for role in [Role::Sender, Role::Viewer] {
            assert_eq!(Role::from_code(role.code()), Some(role));
        }
        assert_eq!(Role::from_code(2), None);
        assert_eq!(Role::from_code(u8::MAX), None);
    }

    #[test]
    fn mode_codes_round_trip_and_reject_unknown_codes() {
        for mode in [
            ConnectionMode::Local,
            ConnectionMode::Direct,
            ConnectionMode::Internet,
        ] {
            assert_eq!(ConnectionMode::from_code(mode.code()), Some(mode));
        }
        assert_eq!(ConnectionMode::from_code(3), None);
    }

    #[test]
    fn state_codes_round_trip_and_reject_unknown_codes() {
        for state in [
            SessionState::Idle,
            SessionState::AwaitingPeer,
            SessionState::AwaitingApproval,
            SessionState::Active,
            SessionState::SharingInterrupted,
            SessionState::Ended,
        ] {
            assert_eq!(SessionState::from_code(state.code()), Some(state));
        }
        assert_eq!(SessionState::from_code(6), None);
    }

    #[test]
    fn command_codes_round_trip_and_reject_unknown_codes() {
        for command in [
            SessionCommand::StartPairing,
            SessionCommand::RequestJoin,
            SessionCommand::PeerRequestedJoin,
            SessionCommand::ApproveViewer,
            SessionCommand::ApprovalReceived,
            SessionCommand::CaptureStarted,
            SessionCommand::CaptureStopped,
            SessionCommand::End,
        ] {
            assert_eq!(SessionCommand::from_code(command.code()), Some(command));
        }
        assert_eq!(SessionCommand::from_code(8), None);
    }

    #[test]
    fn wire_codes_are_distinct_within_each_enum() {
        let state_codes: Vec<u8> = [
            SessionState::Idle,
            SessionState::AwaitingPeer,
            SessionState::AwaitingApproval,
            SessionState::Active,
            SessionState::SharingInterrupted,
            SessionState::Ended,
        ]
        .iter()
        .map(|s| s.code())
        .collect();
        let mut unique = state_codes.clone();
        unique.sort_unstable();
        unique.dedup();
        assert_eq!(state_codes.len(), unique.len());
    }

    #[test]
    fn errors_render_human_readable_messages() {
        let message = SessionError::ViewerAlreadyConnected.to_string();
        assert!(!message.is_empty());
        let message = SessionError::RoleMismatch {
            expected: Role::Sender,
        }
        .to_string();
        assert!(!message.is_empty());
    }
}
