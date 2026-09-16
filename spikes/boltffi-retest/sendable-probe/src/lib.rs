//! Focused probe: an async API whose completion value is an exported class
//! handle. Greenfield5's own session API is class-shaped, so this is the Swift 6
//! boundary that `T: Sendable` (patch 0001) can expose: the completion value
//! crosses a concurrency domain, and upstream issue #778 (exported classes are
//! not `Sendable`) is still open.
//!
//! The class-returning idiom mirrors upstream fixture
//! `boltffi_backend/tests/fixtures/source/exports/kotlin_class_handles.rs`
//! (`pub fn swap(&self, other: Engine) -> Engine`).
//!
//! Nothing here is a Greenfield5 dependency: the crate exists to be generated
//! and type-checked, never to be shipped.

/// An exported class, returned from an async method below.
pub struct Leaf {
    value: u32,
}

#[boltffi::export]
impl Leaf {
    pub fn new(value: u32) -> Self {
        Self { value }
    }

    pub fn value(&self) -> u32 {
        self.value
    }
}

/// Exported class whose async method produces another exported class handle.
pub struct Root {
    seed: u32,
}

#[boltffi::export]
impl Root {
    pub fn new(seed: u32) -> Self {
        Self { seed }
    }

    /// Async completion value is an exported class handle.
    pub async fn make_leaf(&self) -> Leaf {
        Leaf { value: self.seed }
    }
}
