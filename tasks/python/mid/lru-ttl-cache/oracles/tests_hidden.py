from ttlcache import TTLCache


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


clk = FakeClock()
c = TTLCache(maxsize=2, ttl=10.0, clock=clk)

# basic set/get
c.set("a", 1)
c.set("b", 2)
assert c.get("a") == 1
assert c.get("b") == 2
assert len(c) == 2
assert "a" in c
assert "missing" not in c
assert c.get("missing") is None
assert c.get("missing", 42) == 42

# LRU eviction: "a" was just read... order is b older; make a the LRU:
c.get("b")  # recency: b most recent, a least
c.set("c", 3)  # evicts a
assert "a" not in c
assert c.get("a") is None
assert c.get("b") == 2
assert c.get("c") == 3

# get refreshes recency: touch b, then insert d -> c is evicted
c.get("b")
c.set("d", 4)
assert "c" not in c
assert "b" in c
assert "d" in c

# replace updates value and recency
clk2 = FakeClock()
c2 = TTLCache(maxsize=2, ttl=10.0, clock=clk2)
c2.set("x", 1)
c2.set("y", 2)
c2.set("x", 100)  # x becomes most recent
c2.set("z", 3)  # evicts y
assert c2.get("x") == 100
assert "y" not in c2
assert c2.get("z") == 3

# keys(): most recently used first
clk3 = FakeClock()
c3 = TTLCache(maxsize=3, ttl=10.0, clock=clk3)
c3.set("p", 1)
c3.set("q", 2)
c3.set("r", 3)
assert c3.keys() == ["r", "q", "p"]
c3.get("p")
assert c3.keys() == ["p", "r", "q"]

print("ok")
