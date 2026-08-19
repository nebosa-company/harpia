from loganalyzer import count_by_status, parse_line, parse_log, top_paths, total_bytes

LINE = (
    '203.0.113.9 - - [12/Mar/2024:10:15:32 +0000] '
    '"GET /index.html HTTP/1.1" 200 5321 '
    '"https://example.org/" "Mozilla/5.0 (Windows NT 10.0)"'
)

e = parse_line(LINE)
assert e["ip"] == "203.0.113.9"
assert e["timestamp"] == "12/Mar/2024:10:15:32 +0000"
assert e["method"] == "GET"
assert e["path"] == "/index.html"
assert e["status"] == 200
assert e["size"] == 5321
assert e["referrer"] == "https://example.org/"
assert e["agent"] == "Mozilla/5.0 (Windows NT 10.0)"

# a "-" size is legitimate and means zero bytes
DASH = (
    '198.51.100.7 - - [12/Mar/2024:10:16:01 +0000] '
    '"HEAD /health HTTP/1.1" 204 - "-" "curl/8.4.0"'
)
e2 = parse_line(DASH)
assert e2["size"] == 0
assert e2["status"] == 204

LOG = "\n".join(
    [
        LINE,
        DASH,
        '10.0.0.1 - - [12/Mar/2024:10:17:00 +0000] "GET /api/users HTTP/1.1" 200 120 "-" "client/1.0"',
        '10.0.0.2 - - [12/Mar/2024:10:17:05 +0000] "GET /api/users HTTP/1.1" 200 118 "-" "client/1.0"',
        "",
        '10.0.0.3 - - [12/Mar/2024:10:17:09 +0000] "GET /api/users HTTP/1.1" 500 42 "-" "client/1.0"',
        '10.0.0.4 - - [12/Mar/2024:10:18:00 +0000] "GET /index.html HTTP/1.1" 200 5321 "-" "Mozilla/5.0"',
        '10.0.0.5 - - [12/Mar/2024:10:18:30 +0000] "POST /login HTTP/1.1" 401 33 "-" "Mozilla/5.0"',
    ]
)
entries = parse_log(LOG)
assert len(entries) == 7  # blank line skipped

assert count_by_status(entries) == {200: 4, 204: 1, 500: 1, 401: 1}
assert total_bytes(entries) == 5321 + 0 + 120 + 118 + 42 + 5321 + 33

# most-requested first
assert top_paths(entries, 2) == [("/api/users", 3), ("/index.html", 2)]
assert top_paths(entries, 10) == [
    ("/api/users", 3),
    ("/index.html", 2),
    ("/health", 1),
    ("/login", 1),
]

print("ok")
