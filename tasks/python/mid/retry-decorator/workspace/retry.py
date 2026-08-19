"""Retry decorator. See the project brief for the exact contract."""

import time


def retry(times=3, delay=0.1, backoff=2.0, exceptions=(Exception,), sleep=time.sleep):
    raise NotImplementedError
