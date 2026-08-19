"""Retry decorator with injectable sleep."""

import functools
import time


def retry(times=3, delay=0.1, backoff=2.0, exceptions=(Exception,), sleep=time.sleep):
    if times < 1:
        raise ValueError("times must be >= 1")

    def decorate(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            wait = delay
            for attempt in range(1, times + 1):
                try:
                    return fn(*args, **kwargs)
                except exceptions:
                    if attempt == times:
                        raise
                    sleep(wait)
                    wait = wait * backoff
            raise AssertionError("unreachable")

        return wrapper

    return decorate
