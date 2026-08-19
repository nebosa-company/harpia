from netcheck import is_ipv4, network_contains, parse_cidr

# leading zeros in octets
assert is_ipv4("1.2.3.04") is False
assert is_ipv4("00.0.0.0") is False
assert is_ipv4("0.0.0.0") is True

# signs and floats are not octets
assert is_ipv4("+1.2.3.4") is False
assert is_ipv4("1.2.3.-4") is False
assert is_ipv4("1.2.3.4.") is False

# leading zeros in the prefix
for bad in ["1.2.3.4/00", "1.2.3.4/08", "1.2.3.4/024"]:
    try:
        parse_cidr(bad)
    except ValueError:
        pass
    else:
        raise AssertionError(f"parse_cidr({bad!r}) should raise ValueError")

assert parse_cidr("1.2.3.4/0") == ("1.2.3.4", 0)

# a non-canonical base address: only the top bits matter
assert network_contains("192.168.1.77/24", "192.168.1.200") is True
assert network_contains("192.168.1.77/24", "192.168.0.200") is False

# boundary of a /25
assert network_contains("10.0.0.0/25", "10.0.0.127") is True
assert network_contains("10.0.0.0/25", "10.0.0.128") is False

# invalid arguments raise ValueError
for cidr, ip in [("192.168.1.0/24", "999.1.1.1"), ("bad/24", "1.2.3.4"), ("1.2.3.4/40", "1.2.3.4")]:
    try:
        network_contains(cidr, ip)
    except ValueError:
        pass
    else:
        raise AssertionError(f"network_contains({cidr!r}, {ip!r}) should raise ValueError")

print("ok")
