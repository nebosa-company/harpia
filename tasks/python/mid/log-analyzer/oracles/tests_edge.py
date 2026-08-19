from loganalyzer import error_rate, parse_line, parse_log, top_paths

def L(ip, path, status, size="10"):
    return (
        f'{ip} - - [12/Mar/2024:11:00:00 +0000] '
        f'"GET {path} HTTP/1.1" {status} {size} "-" "test/1.0"'
    )


# error_rate: one 500 among ten entries -> 0.1, regardless of 404s
lines = [L(f"10.0.0.{i}", "/a", 200) for i in range(7)]
lines += [L("10.0.1.1", "/b", 404), L("10.0.1.2", "/c", 404), L("10.0.1.3", "/d", 500)]
entries = parse_log("\n".join(lines))
assert len(entries) == 10
rate = error_rate(entries)
assert abs(rate - 0.1) < 1e-9, rate

# a clean log has rate 0.0 (and must not crash)
clean = parse_log("\n".join(L(f"10.9.0.{i}", "/ok", 200) for i in range(4)))
assert error_rate(clean) == 0.0
assert error_rate([]) == 0.0

# 4xx alone contributes nothing to the 5xx rate
only4xx = parse_log("\n".join([L("1.1.1.1", "/x", 404), L("1.1.1.2", "/y", 403)]))
assert error_rate(only4xx) == 0.0

# "-" sizes may appear anywhere in a big log without breaking parse_log
mixed = parse_log("\n".join([L("2.2.2.2", "/m", 200, "-"), L("2.2.2.3", "/m", 200)]))
assert [e["size"] for e in mixed] == [0, 10]

# top_paths tie-break: equal counts ordered by path ascending
tied = parse_log(
    "\n".join([L("3.3.3.1", "/zebra", 200), L("3.3.3.2", "/apple", 200)])
)
assert top_paths(tied, 5) == [("/apple", 1), ("/zebra", 1)]
assert top_paths(tied, 1) == [("/apple", 1)]
assert top_paths([], 3) == []

# malformed lines still raise ValueError
for bad in ["not a log line", 'x - - [t] "GET /p HTTP/1.1" 12 5 "-" "-"', ""]:
    try:
        parse_line(bad)
    except ValueError:
        pass
    else:
        raise AssertionError(f"parse_line({bad!r}) should raise")

print("ok")
