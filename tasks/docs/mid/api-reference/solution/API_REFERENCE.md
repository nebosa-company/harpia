# Kestrel API Reference

## kestrel.cache

### CacheMiss

`CacheMiss()`

Raised when a cache lookup finds no live entry for a key.

- Parameters: none
- Returns: n/a
- Raises: none

### TTLCache

`TTLCache(capacity: int, ttl_seconds: float)`

A fixed-capacity cache whose entries expire after a fixed time.

- Parameters: capacity (int), ttl_seconds (float)
- Returns: n/a
- Raises: ValueError

### TTLCache.get

`TTLCache.get(key: str, now: float) -> str`

Return the value stored under key.

- Parameters: key (str), now (float)
- Returns: str
- Raises: CacheMiss

### TTLCache.put

`TTLCache.put(key: str, value: str, now: float) -> None`

Store value under key, evicting the oldest entry when full.

- Parameters: key (str), value (str), now (float)
- Returns: None
- Raises: none

### TTLCache.evict_expired

`TTLCache.evict_expired(now: float) -> int`

Drop every entry whose deadline has passed and return the count.

- Parameters: now (float)
- Returns: int
- Raises: none

### cache_key

`cache_key(namespace: str, identifier: str) -> str`

Build a stable cache key from a namespace and an identifier.

- Parameters: namespace (str), identifier (str)
- Returns: str
- Raises: ValueError

## kestrel.paths

### PathOutsideRoot

`PathOutsideRoot()`

Raised when a candidate path resolves outside its configured root.

- Parameters: none
- Returns: n/a
- Raises: none

### normalise

`normalise(path: str) -> str`

Return path with separators unified and redundant parts removed.

- Parameters: path (str)
- Returns: str
- Raises: none

### is_within

`is_within(root: str, candidate: str) -> bool`

Report whether candidate resolves to a location under root.

- Parameters: root (str), candidate (str)
- Returns: bool
- Raises: none

### PathPolicy

`PathPolicy(root: str, extensions: tuple)`

A root directory together with the file extensions it accepts.

- Parameters: root (str), extensions (tuple)
- Returns: n/a
- Raises: none

### PathPolicy.check

`PathPolicy.check(candidate: str) -> str`

Return the normalised candidate when the policy accepts it.

- Parameters: candidate (str)
- Returns: str
- Raises: PathOutsideRoot, ValueError

### PathPolicy.describe

`PathPolicy.describe() -> str`

Return a one-line human-readable summary of the policy.

- Parameters: none
- Returns: str
- Raises: none

## kestrel.retry

### RetryExhausted

`RetryExhausted()`

Raised when every permitted attempt has failed.

- Parameters: none
- Returns: n/a
- Raises: none

### backoff_delays

`backoff_delays(attempts: int, base: float = 0.5, cap: float = 30.0) -> list`

Return the delay in seconds to wait before each retry.

- Parameters: attempts (int), base (float), cap (float)
- Returns: list
- Raises: ValueError

### total_wait

`total_wait(attempts: int, base: float = 0.5, cap: float = 30.0) -> float`

Return the total time spent waiting across every retry.

- Parameters: attempts (int), base (float), cap (float)
- Returns: float
- Raises: none

### should_retry

`should_retry(status: int) -> bool`

Report whether an HTTP status code is worth another attempt.

- Parameters: status (int)
- Returns: bool
- Raises: none
