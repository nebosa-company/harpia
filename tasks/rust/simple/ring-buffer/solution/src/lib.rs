//! Fixed-capacity FIFO ring buffer that evicts its oldest element when full.

use std::collections::VecDeque;

/// A FIFO buffer holding at most `capacity` elements; pushing into a full
/// buffer evicts (and returns) the oldest element.
pub struct RingBuffer<T> {
    buf: VecDeque<T>,
    cap: usize,
}

impl<T> RingBuffer<T> {
    /// An empty buffer with room for `capacity` elements (`capacity >= 1`).
    pub fn new(capacity: usize) -> Self {
        RingBuffer { buf: VecDeque::with_capacity(capacity), cap: capacity }
    }

    /// Append `value`; if the buffer was full, evict and return the oldest.
    pub fn push(&mut self, value: T) -> Option<T> {
        let evicted = if self.buf.len() == self.cap { self.buf.pop_front() } else { None };
        self.buf.push_back(value);
        evicted
    }

    /// Remove and return the oldest element.
    pub fn pop(&mut self) -> Option<T> {
        self.buf.pop_front()
    }

    /// The oldest element, if any.
    pub fn peek(&self) -> Option<&T> {
        self.buf.front()
    }

    /// Number of elements currently stored.
    pub fn len(&self) -> usize {
        self.buf.len()
    }

    /// Whether the buffer holds no elements.
    pub fn is_empty(&self) -> bool {
        self.buf.is_empty()
    }

    /// Whether the buffer is at capacity.
    pub fn is_full(&self) -> bool {
        self.buf.len() == self.cap
    }

    /// The fixed capacity.
    pub fn capacity(&self) -> usize {
        self.cap
    }

    /// Drop every element, keeping the capacity.
    pub fn clear(&mut self) {
        self.buf.clear();
    }

    /// Iterate the elements from oldest to newest.
    pub fn iter(&self) -> impl Iterator<Item = &T> {
        self.buf.iter()
    }
}
