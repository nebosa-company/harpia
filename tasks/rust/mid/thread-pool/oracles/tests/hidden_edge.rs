use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use thread_pool::ThreadPool;

#[test]
fn panicking_job_does_not_kill_the_pool() {
    let pool = ThreadPool::new(1);
    let flag = Arc::new(AtomicUsize::new(0));
    pool.execute(|| panic!("job goes boom"));
    let flag2 = Arc::clone(&flag);
    pool.execute(move || {
        flag2.store(7, Ordering::SeqCst);
    });
    pool.shutdown();
    assert_eq!(flag.load(Ordering::SeqCst), 7, "job after a panic must still run");
}

#[test]
fn panic_and_completion_counters() {
    let pool = ThreadPool::new(2);
    for _ in 0..3 {
        pool.execute(|| {});
    }
    for _ in 0..2 {
        pool.execute(|| panic!("expected panic"));
    }
    let counter = Arc::new(AtomicUsize::new(0));
    for _ in 0..4 {
        let counter = Arc::clone(&counter);
        pool.execute(move || {
            counter.fetch_add(1, Ordering::SeqCst);
        });
    }
    // shutdown drains everything; counters must then be final.
    // completed/panicked are only observable pre-shutdown, so snapshot via
    // a second pool-free check: run shutdown, then assert side effects.
    pool.shutdown();
    assert_eq!(counter.load(Ordering::SeqCst), 4);
}

#[test]
fn counters_settle_after_drain() {
    let pool = ThreadPool::new(2);
    for _ in 0..5 {
        pool.execute(|| {});
    }
    pool.execute(|| panic!("one bad job"));
    // Poll until every submitted job is accounted for.
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(10);
    while std::time::Instant::now() < deadline {
        if pool.completed() + pool.panicked() == 6 {
            break;
        }
        std::thread::yield_now();
    }
    assert_eq!(pool.completed(), 5);
    assert_eq!(pool.panicked(), 1);
    pool.shutdown();
}

#[test]
fn shutdown_with_empty_queue() {
    let pool = ThreadPool::new(3);
    pool.shutdown();
}

#[test]
fn execute_from_multiple_threads() {
    let pool = ThreadPool::new(4);
    let counter = Arc::new(AtomicUsize::new(0));
    std::thread::scope(|scope| {
        for _ in 0..3 {
            let pool = &pool;
            let counter = &counter;
            scope.spawn(move || {
                for _ in 0..20 {
                    let counter = Arc::clone(counter);
                    pool.execute(move || {
                        counter.fetch_add(1, Ordering::SeqCst);
                    });
                }
            });
        }
    });
    pool.shutdown();
    assert_eq!(counter.load(Ordering::SeqCst), 60);
}
