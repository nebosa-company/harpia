use taskd::{Scheduler, TaskSpec, TaskState};

fn spec(id: u32, priority: u8, run_at: u64, deps: Vec<u32>, every: Option<u64>) -> TaskSpec {
    TaskSpec { id, name: format!("task-{id}"), priority, run_at, deps, every }
}

#[test]
fn cancel_a_pending_task() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 2, vec![], None)).unwrap();
    assert_eq!(s.cancel(1), vec![1]);
    assert_eq!(s.state(1), Some(TaskState::Cancelled));
    assert!(s.run_until_idle(10).is_empty(), "cancelled tasks never run");
    assert!(s.log().is_empty());
}

#[test]
fn cancel_cascades_transitively() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(3, 5, 1, vec![2], None)).unwrap();
    s.submit(spec(4, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(5, 5, 1, vec![], None)).unwrap();
    assert_eq!(s.cancel(1), vec![1, 2, 3, 4], "sorted, transitive, complete");
    assert_eq!(s.state(3), Some(TaskState::Cancelled));
    assert_eq!(s.state(5), Some(TaskState::Pending), "unrelated task untouched");
    assert_eq!(s.run_until_idle(10), vec![5]);
}

#[test]
fn cancel_mid_chain_spares_the_root() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(3, 5, 1, vec![2], None)).unwrap();
    assert_eq!(s.cancel(2), vec![2, 3]);
    assert_eq!(s.state(1), Some(TaskState::Pending));
    assert_eq!(s.run_until_idle(10), vec![1], "root still runs");
}

#[test]
fn cancel_done_cancelled_or_unknown_is_a_no_op() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    s.run_until_idle(10);
    assert_eq!(s.state(1), Some(TaskState::Done));
    assert_eq!(s.cancel(1), Vec::<u32>::new(), "done tasks cannot be cancelled");
    assert_eq!(s.state(2), Some(TaskState::Done), "no cascade from a no-op");
    assert_eq!(s.cancel(99), Vec::<u32>::new());

    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 5, vec![], None)).unwrap();
    assert_eq!(s.cancel(1), vec![1]);
    assert_eq!(s.cancel(1), Vec::<u32>::new(), "second cancel is a no-op");
}

#[test]
fn task_depending_on_a_cancelled_task_stays_pending() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    assert_eq!(s.cancel(1), vec![1]);
    // Submitted AFTER the cascade: not cancelled, but never due either.
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    assert!(s.run_until_idle(10).is_empty());
    assert_eq!(s.state(2), Some(TaskState::Pending));
    assert_eq!(s.now(), 10, "budget is spent on the stuck task");
}

#[test]
fn cancel_stops_a_recurring_task() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], Some(2))).unwrap();
    s.tick(); // runs at 1
    s.tick();
    s.tick(); // runs at 3
    assert_eq!(s.log(), &[(1, 1), (3, 1)]);
    assert_eq!(s.cancel(1), vec![1], "recurring tasks are pending between runs");
    for _ in 0..5 {
        s.tick();
    }
    assert_eq!(s.log().len(), 2, "no runs after cancellation");
    assert_eq!(s.state(1), Some(TaskState::Cancelled));
}

#[test]
fn cancelled_dependency_blocks_but_does_not_cancel_later_wave() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(3, 9, 1, vec![], None)).unwrap();
    assert_eq!(s.cancel(2), vec![2], "leaf cancel has no cascade");
    assert_eq!(s.tick(), vec![3, 1], "others run in priority order");
    assert_eq!(s.state(2), Some(TaskState::Cancelled));
}

#[test]
fn diamond_cascade_counts_each_task_once() {
    let mut s = Scheduler::new();
    s.submit(spec(1, 5, 1, vec![], None)).unwrap();
    s.submit(spec(2, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(3, 5, 1, vec![1], None)).unwrap();
    s.submit(spec(4, 5, 1, vec![2, 3], None)).unwrap();
    assert_eq!(s.cancel(1), vec![1, 2, 3, 4]);
}
