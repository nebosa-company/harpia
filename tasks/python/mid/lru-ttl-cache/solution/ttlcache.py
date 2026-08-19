"""LRU + TTL cache."""

import time
from collections import OrderedDict

_MISSING = object()


class TTLCache:
    def __init__(self, maxsize, ttl, clock=time.monotonic):
        if maxsize < 1:
            raise ValueError("maxsize must be >= 1")
        if ttl <= 0:
            raise ValueError("ttl must be > 0")
        self.maxsize = maxsize
        self.ttl = ttl
        self._clock = clock
        # key -> (value, stored_at); order = least recently used first
        self._data = OrderedDict()

    def _expired(self, stored_at, now=None):
        if now is None:
            now = self._clock()
        return now - stored_at >= self.ttl

    def _purge(self):
        now = self._clock()
        dead = [k for k, (_, t) in self._data.items() if self._expired(t, now)]
        for k in dead:
            del self._data[k]
        return len(dead)

    def set(self, key, value):
        if key in self._data:
            del self._data[key]
        else:
            if len(self._data) >= self.maxsize:
                self._purge()
            if len(self._data) >= self.maxsize:
                self._data.popitem(last=False)  # evict LRU
        self._data[key] = (value, self._clock())

    def get(self, key, default=None):
        entry = self._data.get(key)
        if entry is None:
            return default
        value, stored_at = entry
        if self._expired(stored_at):
            del self._data[key]
            return default
        self._data.move_to_end(key)  # most recently used
        return value

    def __contains__(self, key):
        entry = self._data.get(key)
        if entry is None:
            return False
        if self._expired(entry[1]):
            del self._data[key]
            return False
        return True

    def pop(self, key, default=None):
        entry = self._data.pop(key, _MISSING)
        if entry is _MISSING:
            return default
        value, stored_at = entry
        if self._expired(stored_at):
            return default
        return value

    def expire(self):
        return self._purge()

    def __len__(self):
        self._purge()
        return len(self._data)

    def keys(self):
        self._purge()
        return list(reversed(self._data.keys()))
