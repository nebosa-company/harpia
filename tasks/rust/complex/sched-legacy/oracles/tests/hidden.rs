use taskd::{SchedError, Scheduler, TaskSpec, TaskState};

fn spec(id: u32, priority: u8, run_at: u64, deps: Vec<u32>, every: Option<u64>) -> TaskSpec {
    TaskSpec { id, name: format!("task-{id}"), priority, run_at, deps, every }
}

#[test]
fn priority_orders_execution_within_a_tick() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 1, 1, vec![], None)).unwrap();
    s.submit(spec(2, 9, 1, vec![], None)).unwrap();
    s.submit(spec(3, 5, 1, vec![], None)).unwrap();
    assert_eq!(s.tick(), vec![2, 3, 1], "higher priority first");
    assert_eq!(s.log(), &[(1, 2), (1, 3), (1, 1)]);
}

#[test]
fn priority_ties_break_by_ascending_id() {
    let mut s = Scheduler::new();
    s.submit(spec(30, 4, 1, vec![], None)).unwrap();
    s.submit(spec(10, 4, 1, vec![], None)).unwrap();
    s.submit(spec(20, 4, 1, vec![], None)).unwrap();
    assert_eq!(s.tick(), vec![10, 20, 30]);
}

#[test]
fn dependents_wait_one_tick_regardless_of_id_order() {
    // dependent has the HIGHER id
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    assert_eq!(s.tick(), vec![1], "tick 1: only the dependency");
    assert_eq!(s.tick(), vec![2], "tick 2: the dependent");

    // dependent has the LOWER id
    let mut s = Scheduler::new();
    s.submit(spec(2, 5, 1, vec![], None)).unwrap();
    s.submit(spec(1, 5, 1, vec![2], None)).unwrap();
    assert_eq!(s.tick(), vec![2]);
    assert_eq!(s.tick(), vec![1]);
}

#[test]
fn dependent_never_precedes_its_dependency_in_the_log() {
    // High-priority dependent of a low-priority dependency.
    let mut s = Scheduler::new();
    s.submit(spec(1, 9, 1, vec![], None)).unwrap();
    s.submit(spec(2, 1, 1, vec![1], None)).unwrap();
    let all = s.run_until_idle(10);
    assert_eq!(all, vec![1, 2]);
    assert_eq!(s.log(), &[(1, 1), (2, 2)], "one tick per dependency level");
}

#[test]
fn chains_take_one_tick_per_level() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(3, 5, 1, vec![2], None)).unwrap();
    s.submit(spec(4, 5, 1, vec![3], None)).unwrap();
    let all = s.run_until_idle(20);
    assert_eq!(all, vec![1, 2, 3, 4]);
    assert_eq!(s.log(), &[(1, 1), (2, 2), (3, 3), (4, 4)]);
    assert_eq!(s.now(), 4, "one productive tick per level, no idle tick");
}

#[test]
fn run_at_gates_execution() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 3, vec![], None)).unwrap();
    assert_eq!(s.tick(), Vec::<u32>::new());
    assert_eq!(s.tick(), Vec::<u32>::new());
    assert_eq!(s.tick(), vec![1]);
    assert_eq!(s.state(1), Some(TaskState::Done));
}

#[test]
fn recurring_task_unobstructed_keeps_cadence() {
    let mut s = Scheduler::new();
    s.submit(spec(7, 5, 3, vec![], Some(5))).unwrap();
    for _ in 0..15 {
        s.tick();
    }
    assert_eq!(s.log(), &[(3, 7), (8, 7), (13, 7)]);
    assert_eq!(s.state(7), Some(TaskState::Pending), "recurring stays pending");
}

#[test]
fn recurring_task_delayed_by_dependency_does_not_drift() {
    // Dep id 2 submitted first; recurring task id 1 depends on it, so the
    // scan order cannot mask the timing.
    let mut s = Scheduler::new();
    s.submit(spec(2, 5, 4, vec![], None)).unwrap();
    s.submit(spec(1, 5, 3, vec![2], Some(5))).unwrap();
    for _ in 0..15 {
        s.tick();
    }
    let runs_of_1: Vec<(u64, u32)> =
        s.log().iter().copied().filter(|&(_, id)| id == 1).collect();
    assert_eq!(
        runs_of_1,
        vec![(5, 1), (8, 1), (13, 1)],
        "first run delayed to 5, later runs anchored at 8, 13"
    );
}

#[test]
fn recurring_task_delayed_with_dependent_id_after_dep() {
    // Same shape, ids reversed: dep id 1, recurring id 2.
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 4, vec![], None)).unwrap();
    s.submit(spec(2, 5, 3, vec![1], Some(5))).unwrap();
    for _ in 0..15 {
        s.tick();
    }
    let runs_of_2: Vec<(u64, u32)> =
        s.log().iter().copied().filter(|&(_, id)| id == 2).collect();
    assert_eq!(runs_of_2, vec![(5, 2), (8, 2), (13, 2)]);
}

#[test]
fn submit_validation() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    assert_eq!(
        s.submit(spec(1, 5, 1, vec![], None)),
        Err(SchedError::DuplicateId(1))
    );
    assert_eq!(
        s.submit(spec(2, 5, 1, vec![99], None)),
        Err(SchedError::UnknownDep { task: 2, dep: 99 })
    );
    assert_eq!(s.state(2), None, "rejected task is not recorded");
}

#[test]
fn every_one_runs_every_tick() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], Some(1))).unwrap();
    assert_eq!(s.tick(), vec![1]);
    assert_eq!(s.tick(), vec![1]);
    assert_eq!(s.tick(), vec![1]);
    assert_eq!(s.log().len(), 3);
}

#[test]
fn mixed_wave_ordering() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 2, 1, vec![], None)).unwrap();
    s.submit(spec(2, 8, 2, vec![], None)).unwrap();
    s.submit(spec(3, 8, 1, vec![], None)).unwrap();
    s.submit(spec(4, 2, 2, vec![], None)).unwrap();
    assert_eq!(s.tick(), vec![3, 1]);
    assert_eq!(s.tick(), vec![2, 4]);
    assert_eq!(s.now(), 2);
}
