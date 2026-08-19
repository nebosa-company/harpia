"""Access-log analysis for "combined" format logs.

Line shape:

    IP - - [TIMESTAMP] "METHOD PATH PROTOCOL" STATUS SIZE "REFERRER" "AGENT"

SIZE is a byte count or "-" (no body; counts as 0).
"""

import re

_LINE = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<timestamp>[^\]]+)\] '
    r'"(?P<method>\S+) (?P<path>\S+) (?P<protocol>[^"]+)" '
    r'(?P<status>\d{3}) (?P<size>\S+) '
    r'"(?P<referrer>[^"]*)" "(?P<agent>[^"]*)"$'
)


def parse_line(line):
    """Parse one log line into a dict (ip, timestamp, method, path, status,
    size, referrer, agent). Raises ValueError if the line is malformed."""
    m = _LINE.match(line)
    if m is None:
        raise ValueError(f"malformed log line: {line!r}")
    return {
        "ip": m.group("ip"),
        "timestamp": m.group("timestamp"),
        "method": m.group("method"),
        "path": m.group("path"),
        "status": int(m.group("status")),
        "size": int(m.group("size")),
        "referrer": m.group("referrer"),
        "agent": m.group("agent"),
    }


def parse_log(text):
    """Parse a whole log document, skipping blank lines."""
    return [parse_line(line) for line in text.splitlines() if line.strip()]


def count_by_status(entries):
    """Map status code -> number of entries with that status."""
    counts = {}
    for entry in entries:
        counts[entry["status"]] = counts.get(entry["status"], 0) + 1
    return counts


def top_paths(entries, n):
    """The n most-requested (path, count) pairs, most-requested first;
    ties broken by path ascending."""
    counts = {}
    for entry in entries:
        counts[entry["path"]] = counts.get(entry["path"], 0) + 1
    ranked = sorted(counts.items(), key=lambda kv: (kv[1], kv[0]))
    return ranked[:n]


def error_rate(entries):
    """Fraction of all entries with a 5xx status, in [0, 1]; 0.0 when
    there are no entries."""
    errors = [e for e in entries if e["status"] >= 500]
    considered = [e for e in entries if e["status"] >= 400]
    return len(errors) / len(considered)


def total_bytes(entries):
    """Total bytes across entries."""
    return sum(e["size"] for e in entries)
