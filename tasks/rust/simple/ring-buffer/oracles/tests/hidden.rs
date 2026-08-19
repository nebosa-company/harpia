use ring_buffer::RingBuffer;

#[test]
fn push_pop_is_fifo() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(4);
    assert_eq!(rb.push(1), None);
    assert_eq!(rb.push(2), None);
    assert_eq!(rb.push(3), None);
    assert_eq!(rb.pop(), Some(1));
    assert_eq!(rb.pop(), Some(2));
    assert_eq!(rb.pop(), Some(3));
    assert_eq!(rb.pop(), None);
}

#[test]
fn full_push_evicts_oldest() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(2);
    assert_eq!(rb.push(10), None);
    assert_eq!(rb.push(20), None);
    assert_eq!(rb.push(30), Some(10));
    assert_eq!(rb.push(40), Some(20));
    assert_eq!(rb.pop(), Some(30));
    assert_eq!(rb.pop(), Some(40));
}

#[test]
fn accessors_track_state() {
    let mut rb: RingBuffer<u8> = RingBuffer::new(3);
    assert!(rb.is_empty());
    assert!(!rb.is_full());
    assert_eq!(rb.len(), 0);
    assert_eq!(rb.capacity(), 3);
    rb.push(1);
    rb.push(2);
    assert_eq!(rb.len(), 2);
    assert!(!rb.is_empty());
    assert!(!rb.is_full());
    rb.push(3);
    assert!(rb.is_full());
    assert_eq!(rb.capacity(), 3);
}

#[test]
fn peek_does_not_remove() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(2);
    assert_eq!(rb.peek(), None);
    rb.push(5);
    rb.push(6);
    assert_eq!(rb.peek(), Some(&5));
    assert_eq!(rb.len(), 2);
    assert_eq!(rb.pop(), Some(5));
    assert_eq!(rb.peek(), Some(&6));
}

#[test]
fn works_with_owned_types() {
    let mut rb: RingBuffer<String> = RingBuffer::new(2);
    rb.push("alpha".to_string());
    rb.push("beta".to_string());
    let evicted = rb.push("gamma".to_string());
    assert_eq!(evicted.as_deref(), Some("alpha"));
    assert_eq!(rb.pop().as_deref(), Some("beta"));
}
