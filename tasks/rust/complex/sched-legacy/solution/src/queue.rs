//! Run-order policy for the tasks selected in one tick.

/// Order a tick's runnable tasks for execution: most urgent first, ties by
/// ascending id. Takes (priority, id) pairs, returns ids in run order.
pub fn run_order(mut ready: Vec<(u8, u32)>) -> Vec<u32> {
    ready.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)));
    ready.into_iter().map(|(_, id)| id).collect()
}
