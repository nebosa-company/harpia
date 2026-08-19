use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::time::{Duration, Instant};
use thread_pool::ThreadPool;

fn wait_until(deadline_secs: u64, mut done: impl FnMut() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(deadline_secs);
    while Instant::now() < deadline {
        if done() {
            return;
        }
        std::thread::yield_now();
    }
    panic!("condition not reached within {deadline_secs}s");
}

#[test]
fn all_jobs_run_before_shutdown_returns() {
    let pool = ThreadPool::new(4);
    let counter = Arc::new(AtomicUsize::new(0));
    for _ in 0..100 {
        let counter = Arc::clone(&counter);
        pool.execute(move || {
            counter.fetch_add(1, Ordering::SeqCst);
        });
    }
    pool.shutdown();
    assert_eq!(counter.load(Ordering::SeqCst), 100);
}

#[test]
fn shutdown_drains_the_queue() {
    let pool = ThreadPool::new(2);
    let seen = Arc::new(Mutex::new(Vec::new()));
    for i in 0..50 {
        let seen = Arc::clone(&seen);
        pool.execute(move || {
            seen.lock().unwrap().push(i);
        });
    }
    pool.shutdown(); // immediate shutdown must still run all 50
    let mut got = seen.lock().unwrap().clone();
    got.sort();
    assert_eq!(got, (0..50).collect::<Vec<_>>());
}

#[test]
fn completed_counter_is_observable_through_shared_ref() {
    let pool = ThreadPool::new(3);
    assert_eq!(pool.completed(), 0);
    assert_eq!(pool.panicked(), 0);
    for _ in 0..25 {
        pool.execute(|| {});
    }
    wait_until(10, || pool.completed() == 25);
    assert_eq!(pool.panicked(), 0);
    pool.shutdown();
}

#[test]
fn jobs_run_off_the_calling_thread() {
    let pool = ThreadPool::new(1);
    let caller = std::thread::current().id();
    let (tx, rx) = mpsc::channel();
    pool.execute(move || {
        tx.send(std::thread::current().id()).unwrap();
    });
    let worker = rx.recv_timeout(Duration::from_secs(10)).expect("job ran");
    assert_ne!(worker, caller);
    pool.shutdown();
}

#[test]
fn single_worker_runs_jobs_in_fifo_order() {
    let pool = ThreadPool::new(1);
    let order = Arc::new(Mutex::new(Vec::new()));
    for i in 0..20 {
        let order = Arc::clone(&order);
        pool.execute(move || {
            order.lock().unwrap().push(i);
        });
    }
    pool.shutdown();
    assert_eq!(*order.lock().unwrap(), (0..20).collect::<Vec<_>>());
}

#[test]
fn four_workers_run_four_jobs_concurrently() {
    let pool = ThreadPool::new(4);
    let barrier = Arc::new(std::sync::Barrier::new(4));
    let (tx, rx) = mpsc::channel();
    for _ in 0..4 {
        let barrier = Arc::clone(&barrier);
        let tx = tx.clone();
        pool.execute(move || {
            // Only proceeds if all four jobs are running at once.
            barrier.wait();
            tx.send(()).unwrap();
        });
    }
    for _ in 0..4 {
        rx.recv_timeout(Duration::from_secs(10))
            .expect("jobs did not run concurrently on 4 workers");
    }
    pool.shutdown();
}
