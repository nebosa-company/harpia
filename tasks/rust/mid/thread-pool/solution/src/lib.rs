//! A fixed-size worker pool with FIFO dispatch, panic isolation, and
//! graceful shutdown.

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread::JoinHandle;

type Job = Box<dyn FnOnce() + Send + 'static>;

struct Shared {
    completed: AtomicUsize,
    panicked: AtomicUsize,
}

/// Fixed-size thread pool. Dropping without `shutdown` is allowed but gives
/// no completion guarantees; call `shutdown` to drain.
pub struct ThreadPool {
    sender: Option<mpsc::Sender<Job>>,
    workers: Vec<JoinHandle<()>>,
    shared: Arc<Shared>,
}

impl ThreadPool {
    /// Spawn `workers` worker threads (`workers >= 1`).
    pub fn new(workers: usize) -> ThreadPool {
        let (sender, receiver) = mpsc::channel::<Job>();
        let receiver = Arc::new(Mutex::new(receiver));
        let shared = Arc::new(Shared {
            completed: AtomicUsize::new(0),
            panicked: AtomicUsize::new(0),
        });
        let handles = (0..workers)
            .map(|_| {
                let receiver = Arc::clone(&receiver);
                let shared = Arc::clone(&shared);
                std::thread::spawn(move || loop {
                    let job = match receiver.lock().expect("receiver lock").recv() {
                        Ok(job) => job,
                        Err(_) => break, // channel closed: shutdown
                    };
                    match catch_unwind(AssertUnwindSafe(job)) {
                        Ok(()) => shared.completed.fetch_add(1, Ordering::SeqCst),
                        Err(_) => shared.panicked.fetch_add(1, Ordering::SeqCst),
                    };
                })
            })
            .collect();
        ThreadPool { sender: Some(sender), workers: handles, shared }
    }

    /// Enqueue a job.
    pub fn execute<F>(&self, job: F)
    where
        F: FnOnce() + Send + 'static,
    {
        self.sender
            .as_ref()
            .expect("pool is live")
            .send(Box::new(job))
            .expect("workers alive");
    }

    /// Jobs that returned normally so far.
    pub fn completed(&self) -> usize {
        self.shared.completed.load(Ordering::SeqCst)
    }

    /// Jobs that panicked so far.
    pub fn panicked(&self) -> usize {
        self.shared.panicked.load(Ordering::SeqCst)
    }

    /// Graceful shutdown: run every queued job, then join all workers.
    pub fn shutdown(mut self) {
        drop(self.sender.take()); // closes the channel; workers drain then exit
        for handle in self.workers.drain(..) {
            let _ = handle.join();
        }
    }
}
