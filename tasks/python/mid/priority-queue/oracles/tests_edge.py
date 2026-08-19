from taskqueue import TaskQueue

# empty queue raises IndexError
q = TaskQueue()
for op in (q.pop, q.peek):
    try:
        op()
    except IndexError:
        pass
    else:
        raise AssertionError("empty queue op should raise IndexError")

# negative priorities sort below the default
q = TaskQueue()
q.add("later", -5)
q.add("normal")  # 0
q.add("soon", 3)
assert q.pop_all() == ["soon", "normal", "later"]

# cancel removes the frontmost instance of the name
q = TaskQueue()
q.add("x", 1)
q.add("x", 5)
q.add("y", 3)
assert q.cancel("x") is True  # removes the priority-5 instance
assert q.pop() == "y"
assert q.pop() == "x"  # the priority-1 instance remains
assert q.cancel("x") is False
assert q.cancel("ghost") is False

# cancel must not disturb FIFO order of the survivors
q = TaskQueue()
q.add("a")
q.add("victim")
q.add("b")
q.add("c")
assert q.cancel("victim") is True
assert q.pop_all() == ["a", "b", "c"]

# len reflects cancels; clear empties
q = TaskQueue()
q.add("a")
q.add("b", 2)
assert len(q) == 2
q.cancel("a")
assert len(q) == 1
q.clear()
assert len(q) == 0
assert q.pop_all() == []
try:
    q.peek()
except IndexError:
    pass
else:
    raise AssertionError("cleared queue should be empty")

# FIFO holds across a long mixed sequence
q = TaskQueue()
for i in range(20):
    q.add(f"t{i}", i % 3)
drained = q.pop_all()
expected = [f"t{i}" for i in range(2, 20, 3)] + [f"t{i}" for i in range(1, 20, 3)] + [
    f"t{i}" for i in range(0, 20, 3)
]
assert drained == expected, (drained, expected)

print("ok")
