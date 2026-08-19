import os
import subprocess
import sys

PY = sys.executable


def run(*args):
    return subprocess.run(
        [PY, "rot13.py", *args], capture_output=True, text=True, timeout=30
    )


# basic transform
with open("cli_in.txt", "w", encoding="utf-8", newline="") as f:
    f.write("Hello, World!\n")
r = run("cli_in.txt", "cli_out.txt")
assert r.returncode == 0, (r.returncode, r.stdout, r.stderr)
assert r.stdout == ""
with open("cli_out.txt", "r", encoding="utf-8", newline="") as f:
    assert f.read() == "Uryyb, Jbeyq!\n"

# CRLF endings preserved byte-for-byte
with open("cli_crlf.txt", "wb") as f:
    f.write(b"One\r\nTwo\r\n")
r = run("cli_crlf.txt", "cli_crlf_out.txt")
assert r.returncode == 0, (r.returncode, r.stderr)
with open("cli_crlf_out.txt", "rb") as f:
    assert f.read() == b"Bar\r\nGjb\r\n"

# UTF-8 content survives
with open("cli_utf8.txt", "w", encoding="utf-8", newline="") as f:
    f.write("café zebra\n")
r = run("cli_utf8.txt", "cli_utf8_out.txt")
assert r.returncode == 0, (r.returncode, r.stderr)
with open("cli_utf8_out.txt", "r", encoding="utf-8", newline="") as f:
    assert f.read() == "pnsé mroen\n"

# wrong argument count
for args in [[], ["only_one.txt"], ["a.txt", "b.txt", "c.txt"]]:
    r = run(*args)
    assert r.returncode == 2, (args, r.returncode)
    assert r.stderr.strip() != ""

# missing input file
missing = "no_such_file_here.txt"
assert not os.path.exists(missing)
r = run(missing, "unused_out.txt")
assert r.returncode == 2, (r.returncode, r.stdout, r.stderr)
assert missing in r.stderr

print("ok")
