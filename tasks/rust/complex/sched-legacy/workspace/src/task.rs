//! Task descriptions and lifecycle states.

/// What a caller submits to the scheduler.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaskSpec {
    /// Unique task id.
    pub id: u32,
    /// Human-readable label (not interpreted).
    pub name: String,
    /// Higher value = more urgent.
    pub priority: u8,
    /// Earliest tick at which the task may run.
    pub run_at: u64,
    /// Ids of tasks that must be Done before this one runs. Every id must
    /// already be submitted.
    pub deps: Vec<u32>,
    /// Recurring interval; None = one-shot.
    pub every: Option<u64>,
}

/// Lifecycle state of a submitted task.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskState {
    /// Waiting to run (also the state between runs of a recurring task).
    Pending,
    /// Finished (one-shot tasks only).
    Done,
}

/// Submission errors.
#[derive(Debug, PartialEq, Eq)]
pub enum SchedError {
    /// A task with this id already exists.
    DuplicateId(u32),
    /// A dependency references an id that was never submitted.
    UnknownDep { task: u32, dep: u32 },
}
