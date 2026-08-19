"""IPv4 / CIDR validation."""


def _octet_ok(part):
    if not part.isdigit():
        return False
    if len(part) > 1 and part[0] == "0":
        return False
    return 0 <= int(part) <= 255


def is_ipv4(s):
    if not isinstance(s, str):
        return False
    parts = s.split(".")
    return len(parts) == 4 and all(_octet_ok(p) for p in parts)


def parse_cidr(s):
    if not isinstance(s, str) or s.count("/") != 1:
        raise ValueError(f"not a CIDR: {s!r}")
    addr, _, prefix = s.partition("/")
    if not is_ipv4(addr):
        raise ValueError(f"bad address in CIDR: {s!r}")
    if not prefix.isdigit() or (len(prefix) > 1 and prefix[0] == "0"):
        raise ValueError(f"bad prefix in CIDR: {s!r}")
    bits = int(prefix)
    if bits > 32:
        raise ValueError(f"prefix out of range in CIDR: {s!r}")
    return addr, bits


def _to_int(addr):
    a, b, c, d = (int(p) for p in addr.split("."))
    return (a << 24) | (b << 16) | (c << 8) | d


def network_contains(cidr, ip):
    base, bits = parse_cidr(cidr)
    if not is_ipv4(ip):
        raise ValueError(f"bad address: {ip!r}")
    if bits == 0:
        return True
    mask = ((1 << bits) - 1) << (32 - bits)
    return (_to_int(base) & mask) == (_to_int(ip) & mask)
