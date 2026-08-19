"""In-memory caching helpers used by the sync engine.

Entries carry an absolute deadline rather than an age, so a cache can be
driven by an injected clock in tests without any global state.
"""

_SENTINEL = object()


class CacheMiss(Exception):
    """Raised when a cache lookup finds no live entry for a key."""


class TTLCache:
    """A fixed-capacity cache whose entries expire after a fixed time.

    The cache never reads the clock itself: every method that needs the
    current time takes it as a parameter.
    """

    def __init__(self, capacity: int, ttl_seconds: float) -> None:
        """Create a cache holding at most capacity live entries.

        Raises:
            ValueError: if capacity is not a positive integer.
        """
        if capacity <= 0:
            raise ValueError("capacity must be positive")
        self.capacity = capacity
        self.ttl_seconds = ttl_seconds
        self._entries = {}

    def get(self, key: str, now: float) -> str:
        """Return the value stored under key.

        Raises:
            CacheMiss: if the key is absent or its entry has expired.
        """
        entry = self._entries.get(key, _SENTINEL)
        if entry is _SENTINEL or entry[1] <= now:
            raise CacheMiss(key)
        return entry[0]

    def put(self, key: str, value: str, now: float) -> None:
        """Store value under key, evicting the oldest entry when full."""
        if key not in self._entries and len(self._entries) >= self.capacity:
            oldest = min(self._entries, key=lambda k: self._entries[k][1])
            del self._entries[oldest]
        self._entries[key] = (value, self._deadline(now))

    def evict_expired(self, now: float) -> int:
        """Drop every entry whose deadline has passed and return the count."""
        dead = [k for k, v in self._entries.items() if v[1] <= now]
        for key in dead:
            del self._entries[key]
        return len(dead)

    def _deadline(self, now: float) -> float:
        """Internal helper: the expiry stamp for an entry written at now."""
        return now + self.ttl_seconds


def cache_key(namespace: str, identifier: str) -> str:
    """Build a stable cache key from a namespace and an identifier.

    Both components are stripped of surrounding whitespace and joined
    with a colon, so that keys compare equal across callers that format
    their inputs differently.

    Raises:
        ValueError: if either component is empty after stripping.
    """
    ns, ident = namespace.strip(), identifier.strip()
    if not ns or not ident:
        raise ValueError("namespace and identifier must both be non-empty")
    return ns + ":" + ident
