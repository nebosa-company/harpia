use ring_buffer::RingBuffer;

#[test]
fn many_wraparounds_stay_fifo() {
    let mut rb: RingBuffer<u32> = RingBuffer::new(3);
    // Model against an unbounded FIFO with front-eviction on overflow.
    let mut model: Vec<u32> = Vec::new();
    for i in 0..50u32 {
        let evicted = rb.push(i);
        model.push(i);
        let expect_evicted = if model.len() > 3 { Some(model.remove(0)) } else { None };
        assert_eq!(evicted, expect_evicted, "push {i}");
        if i % 7 == 3 {
            assert_eq!(rb.pop(), (!model.is_empty()).then(|| model.remove(0)));
        }
    }
    let remaining: Vec<u32> = std::iter::from_fn(|| rb.pop()).collect();
    assert_eq!(remaining, model);
}

#[test]
fn iter_is_oldest_to_newest_after_wrap() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(3);
    for v in [1, 2, 3, 4, 5] {
        rb.push(v);
    }
    let seen: Vec<i32> = rb.iter().copied().collect();
    assert_eq!(seen, vec![3, 4, 5]);
    assert_eq!(rb.len(), 3, "iter must not consume");
}

#[test]
fn clear_resets_and_buffer_is_reusable() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(2);
    rb.push(1);
    rb.push(2);
    rb.clear();
    assert!(rb.is_empty());
    assert_eq!(rb.len(), 0);
    assert_eq!(rb.capacity(), 2);
    assert_eq!(rb.pop(), None);
    assert_eq!(rb.push(9), None);
    assert_eq!(rb.peek(), Some(&9));
}

#[test]
fn capacity_one_buffer() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(1);
    assert_eq!(rb.push(1), None);
    assert!(rb.is_full());
    assert_eq!(rb.push(2), Some(1));
    assert_eq!(rb.push(3), Some(2));
    assert_eq!(rb.pop(), Some(3));
    assert!(rb.is_empty());
}

#[test]
fn iter_on_partial_buffer() {
    let mut rb: RingBuffer<i32> = RingBuffer::new(5);
    rb.push(7);
    rb.push(8);
    let seen: Vec<i32> = rb.iter().copied().collect();
    assert_eq!(seen, vec![7, 8]);
}
