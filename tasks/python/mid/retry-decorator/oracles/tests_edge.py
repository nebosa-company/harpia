from retry import retry

# metadata preserved
sleeps = []


@retry(times=2, delay=1.0, sleep=sleeps.append)
def fetch_data(url):
    """Fetch a thing."""
    return url.upper()


assert fetch_data.__name__ == "fetch_data"
assert fetch_data.__doc__ == "Fetch a thing."
assert fetch_data("abc") == "ABC"

# times=1 means a single attempt and no sleeping
sleeps = []
calls = []


@retry(times=1, delay=1.0, sleep=sleeps.append)
def always_fails():
    calls.append(1)
    raise ValueError("nope")


try:
    always_fails()
except ValueError:
    pass
else:
    raise AssertionError("should raise after the single attempt")
assert len(calls) == 1
assert sleeps == []

# subclass exceptions match
sleeps = []


class MyError(ValueError):
    pass


attempts = []


@retry(times=2, delay=0.5, exceptions=(ValueError,), sleep=sleeps.append)
def raises_subclass():
    attempts.append(1)
    raise MyError("sub")


try:
    raises_subclass()
except MyError:
    pass
assert len(attempts) == 2
assert sleeps == [0.5]

# keyword arguments forwarded on retries too
state = {"n": 0}


def sometimes(a, *, b):
    state["n"] += 1
    if state["n"] < 3:
        raise RuntimeError("again")
    return (a, b)


sleeps = []
wrapped = retry(times=5, delay=2.0, backoff=1.0, sleep=sleeps.append)(sometimes)
assert wrapped(7, b=8) == (7, 8)
assert sleeps == [2.0, 2.0]

# invalid times rejected at factory call time
try:
    retry(times=0)
except ValueError:
    pass
else:
    raise AssertionError("times=0 should raise ValueError")

try:
    retry(times=-2)
except ValueError:
    pass
else:
    raise AssertionError("times=-2 should raise ValueError")

print("ok")
