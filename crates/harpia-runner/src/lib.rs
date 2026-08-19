//! Trial orchestration: one sandbox directory per trial, a worker pool sized
//! by `--jobs`, hard wall-clock kills, and every result written to the store
//! before the round moves on.

pub mod audit;
pub mod content;
pub mod contamination;
pub mod round;
pub mod tasks;
pub mod trial;
pub mod toolchain;
pub mod validate;

pub fn to_slash(p: &std::path::Path) -> String {
    p.to_string_lossy().replace('\\', "/")
}
