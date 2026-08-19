//! taskd: a deterministic, logical-clock task scheduler with priorities,
//! dependencies, and recurring tasks.

mod queue;
mod scheduler;
mod task;

pub use scheduler::Scheduler;
pub use task::{SchedError, TaskSpec, TaskState};
