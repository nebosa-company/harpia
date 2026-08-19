"""LRU + TTL cache. See the project brief for the exact contract."""

import time


class TTLCache:
    def __init__(self, maxsize, ttl, clock=time.monotonic):
        raise NotImplementedError
