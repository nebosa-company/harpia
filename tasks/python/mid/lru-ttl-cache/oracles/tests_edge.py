from ttlcache import TTLCache


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now


# expiry
clk = FakeClock()
c = TTLCache(maxsize=4, ttl=10.0, clock=clk)
c.set("a", 1)
clk.now = 5.0
c.set("b", 2)
clk.now = 10.0  # a is exactly ttl old -> expired; b is 5s old
assert "a" not in c
assert c.get("a", "gone") == "gone"
assert c.get("b") == 2
assert len(c) == 1

# get does not refresh TTL
clk.now = 12.0
assert c.get("b") == 2  # read at 12; stored at 5
clk.now = 15.0  # now 10s since stored -> expired despite the recent read
assert c.get("b") is None

# set refreshes TTL
c.set("k", 1)
clk.now = 20.0
c.set("k", 2)  # re-stored at 20
clk.now = 29.0
assert c.get("k") == 2

# expire() removes and counts
clk2 = FakeClock()
c2 = TTLCache(maxsize=4, ttl=10.0, clock=clk2)
c2.set("a", 1)
c2.set("b", 2)
clk2.now = 5.0
c2.set("c", 3)
clk2.now = 10.0
assert c2.expire() == 2
assert len(c2) == 1
assert c2.get("c") == 3

# expired entries free room before LRU eviction kicks in
clk3 = FakeClock()
c3 = TTLCache(maxsize=2, ttl=10.0, clock=clk3)
c3.set("old", 1)
clk3.now = 5.0
c3.set("young", 2)
clk3.now = 10.0  # "old" expired
c3.set("new", 3)  # room from the expired entry: "young" must survive
assert "young" in c3
assert "new" in c3

# `in` does not refresh recency
clk4 = FakeClock()
c4 = TTLCache(maxsize=2, ttl=100.0, clock=clk4)
c4.set("a", 1)
c4.set("b", 2)
assert "a" in c4  # must NOT promote a
c4.set("c", 3)  # evicts a (still the LRU)
assert "a" not in c4
assert "b" in c4

# pop
clk5 = FakeClock()
c5 = TTLCache(maxsize=2, ttl=10.0, clock=clk5)
c5.set("a", 1)
assert c5.pop("a") == 1
assert "a" not in c5
assert c5.pop("a", "nope") == "nope"
c5.set("z", 9)
clk5.now = 50.0
assert c5.pop("z", "expired") == "expired"

# constructor validation
for bad in [dict(maxsize=0, ttl=1.0), dict(maxsize=-1, ttl=1.0), dict(maxsize=2, ttl=0.0), dict(maxsize=2, ttl=-5.0)]:
    try:
        TTLCache(**bad)
    except ValueError:
        pass
    else:
        raise AssertionError(f"TTLCache(**{bad}) should raise ValueError")

print("ok")
