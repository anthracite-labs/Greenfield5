use greenfield5_bolt_spike::*;

#[test]
fn native_core_version_is_exact() {
    assert_eq!(core_version(), "0.1.0");
}

#[test]
fn sender_viewer_and_rejection_contract() {
    let sender = GreenfieldSession::new(Role::Sender, ConnectionMode::Internet);
    assert_eq!(sender.state_code(), 0);
    assert_eq!(sender.apply(SessionCommand::StartPairing).unwrap(), SessionState::AwaitingPeer);
    assert_eq!(sender.send_command(2).unwrap(), 2);
    assert_eq!(sender.send_command(2), Err(BridgeError::ViewerAlreadyConnected));
    assert_eq!(sender.send_command(3).unwrap(), 3);
    assert!(sender.viewer_approved());
    assert_eq!(sender.send_command(255), Err(BridgeError::UnknownCommandCode { code: 255 }));
    assert_eq!(sender.state_code(), 3);
    let viewer = GreenfieldSession::from_codes(1, 0).unwrap();
    assert_eq!(viewer.send_command(1).unwrap(), 2);
    assert_eq!(viewer.send_command(4).unwrap(), 3);
    assert!(matches!(GreenfieldSession::from_codes(255, 0), Err(BridgeError::UnknownRoleCode { code: 255 })));
    assert!(matches!(GreenfieldSession::from_codes(0, 255), Err(BridgeError::UnknownModeCode { code: 255 })));
}

#[test]
fn mixed_layout_round_trip() {
    let input = LayoutProbe { flag: 7, wide: 0x1122334455667788, short: 0x3344, text: "layout".into() };
    assert_eq!(round_trip(input.clone()), input);
}

#[test]
fn native_stream_capacity_drop_and_stop() {
    let probe = EventProbe::new();
    let stream = probe.events_batch();
    assert_eq!(probe.produce(100), 8);
    assert_eq!(probe.produced(), 100);
    assert_eq!(probe.dropped(), 92);
    for sequence in 0..8 { assert_eq!(stream.pop_event(), Some(sequence)); }
    assert_eq!(stream.pop_event(), None);
    probe.stop();
    assert!(!stream.is_active());
}
