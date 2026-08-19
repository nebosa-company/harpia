//! A fixed-size worker pool with FIFO dispatch, panic isolation, and
//! graceful shutdown.

/// Fixed-size thread pool. Dropping without `shutdown` is allowed but gives
/// no completion guarantees; call `shutdown` to drain.
pub struct ThreadPool {
    _todo: std::marker::PhantomData<()>,
}

impl ThreadPool {
    /// Spawn `workers` worker threads (`workers >= 1`).
    pub fn new(workers: usize) -> ThreadPool {
        let _ = workers;
        todo!("spawn the workers")
    }

    /// Enqueue a job. FIFO hand-off; callable from multiple threads through
    /// a shared reference.
    pub fn execute<F>(&self, job: F)
    where
        F: FnOnce() + Send + 'static,
    {
        let _ = job;
        todo!("enqueue the job")
    }

    /// Jobs that returned normally so far.
    pub fn completed(&self) -> usize {
        todo!("report completions")
    }

    /// Jobs that panicked so far.
    pub fn panicked(&self) -> usize {
        todo!("report panics")
    }

    /// Graceful shutdown: run every queued job, then join all workers.
    pub fn shutdown(self) {
        todo!("drain and join")
    }
}
