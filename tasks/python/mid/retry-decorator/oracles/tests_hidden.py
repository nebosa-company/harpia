from retry import retry


class Flaky:
    """Fails `failures` times, then returns a value."""

    def __init__(self, failures, exc=RuntimeError):
        self.failures = failures
        self.exc = exc
        self.calls = 0

    def __call__(self, *args, **kwargs):
        self.calls += 1
        if self.calls <= self.failures:
            raise self.exc(f"boom {self.calls}")
        return ("ok", args, kwargs)


# success on the first attempt: no sleeping
sleeps = []
f = Flaky(0)
wrapped = retry(times=3, delay=1.0, backoff=3.0, sleep=sleeps.append)(f)
assert wrapped(1, 2, k=3) == ("ok", (1, 2), {"k": 3})
assert f.calls == 1
assert sleeps == []

# two failures then success: waits are delay, delay*backoff
sleeps = []
f = Flaky(2)
wrapped = retry(times=3, delay=1.0, backoff=3.0, sleep=sleeps.append)(f)
assert wrapped("x") == ("ok", ("x",), {})
assert f.calls == 3
assert sleeps == [1.0, 3.0]

# exhaustion re-raises the last exception; times-1 sleeps
sleeps = []
f = Flaky(99)
wrapped = retry(times=4, delay=1.0, backoff=2.0, sleep=sleeps.append)(f)
try:
    wrapped()
except RuntimeError as e:
    assert "boom 4" in str(e)
else:
    raise AssertionError("exhausted retries should re-raise")
assert f.calls == 4
assert sleeps == [1.0, 2.0, 4.0]

# non-matching exceptions propagate immediately
sleeps = []
f = Flaky(5, exc=KeyError)
wrapped = retry(times=3, delay=1.0, exceptions=(ValueError,), sleep=sleeps.append)(f)
try:
    wrapped()
except KeyError:
    pass
else:
    raise AssertionError("non-matching exception must propagate")
assert f.calls == 1
assert sleeps == []

print("ok")
