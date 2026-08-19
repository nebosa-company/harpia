//! The scheduler proper: a logical clock over a table of tasks.

use crate::queue;
use crate::task::{SchedError, TaskSpec, TaskState};
use std::collections::BTreeMap;

struct Task {
    spec: TaskSpec,
    state: TaskState,
    /// Next scheduled tick (advances for recurring tasks).
    run_at: u64,
}

/// Deterministic logical-clock scheduler.
pub struct Scheduler {
    tasks: BTreeMap<u32, Task>,
    now: u64,
    log: Vec<(u64, u32)>,
}

impl Scheduler {
    /// A scheduler at tick 0 with no tasks.
    pub fn new() -> Scheduler {
        Scheduler { tasks: BTreeMap::new(), now: 0, log: Vec::new() }
    }

    /// The current tick.
    pub fn now(&self) -> u64 {
        self.now
    }

    /// The full run log: (tick, task id) in execution order.
    pub fn log(&self) -> &[(u64, u32)] {
        &self.log
    }

    /// State of a task, if submitted.
    pub fn state(&self, id: u32) -> Option<TaskState> {
        self.tasks.get(&id).map(|t| t.state)
    }

    /// Submit a task. Dependencies must already be submitted.
    pub fn submit(&mut self, spec: TaskSpec) -> Result<(), SchedError> {
        if self.tasks.contains_key(&spec.id) {
            return Err(SchedError::DuplicateId(spec.id));
        }
        for &dep in &spec.deps {
            if !self.tasks.contains_key(&dep) {
                return Err(SchedError::UnknownDep { task: spec.id, dep });
            }
        }
        let run_at = spec.run_at;
        self.tasks.insert(spec.id, Task { spec, state: TaskState::Pending, run_at });
        Ok(())
    }

    fn deps_done(&self, deps: &[u32]) -> bool {
        deps.iter()
            .all(|d| matches!(self.tasks.get(d).map(|t| t.state), Some(TaskState::Done)))
    }

    /// Mark one task as executed at the current tick.
    fn finish(&mut self, id: u32) {
        let now = self.now;
        let task = self.tasks.get_mut(&id).expect("ran an unknown task");
        match task.spec.every {
            Some(every) => {
                // Recurring: stay Pending, schedule the next run.
                task.run_at = now + every;
            }
            None => task.state = TaskState::Done,
        }
    }

    /// Advance the clock one tick and run everything due. Returns the ids
    /// run this tick, in execution order.
    pub fn tick(&mut self) -> Vec<u32> {
        self.now += 1;
        let mut ran: Vec<(u8, u32)> = Vec::new();
        let ids: Vec<u32> = self.tasks.keys().copied().collect();
        for id in ids {
            let (due, priority) = {
                let task = &self.tasks[&id];
                (
                    task.state == TaskState::Pending
                        && task.run_at <= self.now
                        && self.deps_done(&task.spec.deps),
                    task.spec.priority,
                )
            };
            if due {
                self.finish(id);
                ran.push((priority, id));
            }
        }
        let order = queue::run_order(ran);
        for &id in &order {
            self.log.push((self.now, id));
        }
        order
    }

    /// Tick until no task is Pending or `max_ticks` is spent; returns the
    /// concatenated run ids.
    pub fn run_until_idle(&mut self, max_ticks: u64) -> Vec<u32> {
        let mut all = Vec::new();
        for _ in 0..max_ticks {
            if !self.tasks.values().any(|t| t.state == TaskState::Pending) {
                break;
            }
            all.extend(self.tick());
        }
        all
    }
}

impl Default for Scheduler {
    fn default() -> Self {
        Scheduler::new()
    }
}
