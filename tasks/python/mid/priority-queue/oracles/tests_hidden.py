from taskqueue import TaskQueue

# priority ordering, higher first
q = TaskQueue()
q.add("low", 1)
q.add("high", 9)
q.add("mid", 5)
assert len(q) == 3
assert q.peek() == "high"
assert q.pop() == "high"
assert q.pop() == "mid"
assert q.pop() == "low"
assert len(q) == 0

# FIFO within a priority level
q = TaskQueue()
for name in ["a", "b", "c"]:
    q.add(name)  # default priority 0
assert q.pop_all() == ["a", "b", "c"]

# interleaved adds and pops keep both orders
q = TaskQueue()
q.add("a", 0)
q.add("urgent1", 10)
assert q.pop() == "urgent1"
q.add("b", 0)
q.add("urgent2", 10)
q.add("c", 0)
assert q.pop() == "urgent2"
assert q.pop() == "a"
assert q.pop() == "b"
assert q.pop() == "c"

# duplicate names are distinct pending tasks
q = TaskQueue()
q.add("job", 1)
q.add("job", 1)
q.add("job", 5)
assert len(q) == 3
assert q.pop_all() == ["job", "job", "job"]

# peek does not remove
q = TaskQueue()
q.add("only")
assert q.peek() == "only"
assert q.peek() == "only"
assert len(q) == 1
assert q.pop() == "only"

print("ok")
