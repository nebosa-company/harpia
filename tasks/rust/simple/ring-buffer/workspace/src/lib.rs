//! Fixed-capacity FIFO ring buffer that evicts its oldest element when full.

/// A FIFO buffer holding at most `capacity` elements; pushing into a full
/// buffer evicts (and returns) the oldest element.
pub struct RingBuffer<T> {
    _marker: std::marker::PhantomData<T>,
}

impl<T> RingBuffer<T> {
    /// An empty buffer with room for `capacity` elements (`capacity >= 1`).
    pub fn new(capacity: usize) -> Self {
        let _ = capacity;
        todo!("create the buffer")
    }

    /// Append `value`; if the buffer was full, evict and return the oldest.
    pub fn push(&mut self, value: T) -> Option<T> {
        let _ = value;
        todo!("push a value")
    }

    /// Remove and return the oldest element.
    pub fn pop(&mut self) -> Option<T> {
        todo!("pop the oldest value")
    }

    /// The oldest element, if any.
    pub fn peek(&self) -> Option<&T> {
        todo!("peek at the oldest value")
    }

    /// Number of elements currently stored.
    pub fn len(&self) -> usize {
        todo!("report the length")
    }

    /// Whether the buffer holds no elements.
    pub fn is_empty(&self) -> bool {
        todo!("report emptiness")
    }

    /// Whether the buffer is at capacity.
    pub fn is_full(&self) -> bool {
        todo!("report fullness")
    }

    /// The fixed capacity.
    pub fn capacity(&self) -> usize {
        todo!("report the capacity")
    }

    /// Drop every element, keeping the capacity.
    pub fn clear(&mut self) {
        todo!("clear the buffer")
    }

    /// Iterate the elements from oldest to newest.
    pub fn iter(&self) -> impl Iterator<Item = &T> {
        std::iter::empty()
    }
}
