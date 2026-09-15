use greenfield5_bolt_spike::core_version;

#[test]
fn native_core_version_is_exact() {
    assert_eq!(core_version(), "0.1.0");
}
