//! Isolated experiment, never linked into the production applications.
#[boltffi::export]
pub fn core_version() -> String {
    String::new()
}
