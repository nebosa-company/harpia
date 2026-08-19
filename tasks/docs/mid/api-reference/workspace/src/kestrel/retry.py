"""Retry scheduling for transient transfer failures.

Nothing in here sleeps or reads the clock; the functions only decide how
long a caller should wait and whether another attempt is worth making.
"""

_RETRYABLE = (408, 429, 500, 502, 503, 504)


class RetryExhausted(Exception):
    """Raised when every permitted attempt has failed."""


def backoff_delays(attempts: int, base: float = 0.5, cap: float = 30.0) -> list:
    """Return the delay in seconds to wait before each retry.

    The first retry waits base seconds and each subsequent delay doubles,
    up to cap. An attempts count of zero or one produces no delays at all
    because there is nothing to wait for.

    Raises:
        ValueError: if attempts is negative or base is not positive.
    """
    if attempts < 0:
        raise ValueError("attempts must not be negative")
    if base <= 0:
        raise ValueError("base must be positive")
    out = []
    delay = base
    for _ in range(max(0, attempts - 1)):
        out.append(min(delay, cap))
        delay *= 2
    return out


def total_wait(attempts: int, base: float = 0.5, cap: float = 30.0) -> float:
    """Return the total time spent waiting across every retry."""
    return sum(backoff_delays(attempts, base, cap))


def should_retry(status: int) -> bool:
    """Report whether an HTTP status code is worth another attempt."""
    return status in _RETRYABLE
