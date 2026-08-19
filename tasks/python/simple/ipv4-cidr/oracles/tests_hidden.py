from netcheck import is_ipv4, network_contains, parse_cidr

assert is_ipv4("1.2.3.4") is True
assert is_ipv4("0.0.0.0") is True
assert is_ipv4("255.255.255.255") is True
assert is_ipv4("192.168.0.1") is True

assert is_ipv4("256.1.1.1") is False
assert is_ipv4("1.2.3") is False
assert is_ipv4("1.2.3.4.5") is False
assert is_ipv4("1.2.3.a") is False
assert is_ipv4("01.2.3.4") is False
assert is_ipv4(" 1.2.3.4") is False
assert is_ipv4("1.2.3.4 ") is False
assert is_ipv4("") is False
assert is_ipv4("1..2.3") is False

assert parse_cidr("192.168.1.0/24") == ("192.168.1.0", 24)
assert parse_cidr("10.0.0.0/8") == ("10.0.0.0", 8)
assert parse_cidr("0.0.0.0/0") == ("0.0.0.0", 0)
assert parse_cidr("1.2.3.4/32") == ("1.2.3.4", 32)

for bad in ["1.2.3.4", "1.2.3.4/33", "1.2.3.4/", "/24", "1.2.3/8", "1.2.3.4/24/8"]:
    try:
        parse_cidr(bad)
    except ValueError:
        pass
    else:
        raise AssertionError(f"parse_cidr({bad!r}) should raise ValueError")

assert network_contains("192.168.1.0/24", "192.168.1.42") is True
assert network_contains("192.168.1.0/24", "192.168.2.1") is False
assert network_contains("10.0.0.0/8", "10.200.3.4") is True
assert network_contains("10.0.0.0/8", "11.0.0.1") is False
assert network_contains("0.0.0.0/0", "8.8.8.8") is True
assert network_contains("1.2.3.4/32", "1.2.3.4") is True
assert network_contains("1.2.3.4/32", "1.2.3.5") is False

print("ok")
