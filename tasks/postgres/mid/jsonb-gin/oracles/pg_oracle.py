"""Per-run PostgreSQL sandbox driver.

Creates a throwaway database with a name no concurrent run can collide with,
applies the files under test in order, then the assertion scripts, and drops
the database again no matter how any of that turned out. Exit status is 0
only when every step succeeded.

    python pg_oracle.py --apply schema.sql --apply seed.sql --assert check.sql
"""

import os
import subprocess
import sys
import time

PSQL_CANDIDATES = [
    r"C:\Program Files\PostgreSQL\16\bin\psql.exe",
    r"C:\Program Files\PostgreSQL\15\bin\psql.exe",
    r"/usr/bin/psql",
    "psql",
]


def psql_path():
    override = os.environ.get("HARPIA_PSQL")
    if override:
        return override
    for cand in PSQL_CANDIDATES[:-1]:
        if os.path.isfile(cand):
            return cand
    return PSQL_CANDIDATES[-1]


def env():
    e = dict(os.environ)
    e.setdefault("PGHOST", "127.0.0.1")
    e.setdefault("PGPORT", "5432")
    e.setdefault("PGUSER", "postgres")
    e.setdefault("PGPASSWORD", "postgres")
    e["PGCLIENTENCODING"] = "UTF8"
    return e


def run(args, label):
    """Run psql; return (ok, combined output)."""
    try:
        p = subprocess.run(
            [psql_path(), "-X", "-q", "-v", "ON_ERROR_STOP=1"] + args,
            env=env(),
            capture_output=True,
            text=True,
            errors="replace",
        )
    except OSError as exc:
        return False, "%s: cannot start psql: %s" % (label, exc)
    out = (p.stdout or "") + (p.stderr or "")
    return p.returncode == 0, out


def unique_db():
    return "hpg_%d_%s" % (os.getpid(), os.urandom(5).hex())


def create(db):
    # Concurrent CREATE DATABASE calls serialize on the template; a couple of
    # retries keeps parallel trials from tripping over each other.
    last = ""
    for attempt in range(4):
        ok, out = run(["-d", "postgres", "-c", 'CREATE DATABASE "%s"' % db], "createdb")
        if ok:
            return True, ""
        last = out
        time.sleep(0.4 * (attempt + 1))
    return False, last


def drop(db):
    run(["-d", "postgres", "-c", 'DROP DATABASE IF EXISTS "%s" WITH (FORCE)' % db], "dropdb")


def parse_argv(argv):
    apply_files, assert_files = [], []
    i = 0
    while i < len(argv):
        flag = argv[i]
        if flag in ("--apply", "--assert") and i + 1 < len(argv):
            (apply_files if flag == "--apply" else assert_files).append(argv[i + 1])
            i += 2
        else:
            sys.stderr.write("bad argument: %s\n" % flag)
            sys.exit(2)
    return apply_files, assert_files


def main():
    apply_files, assert_files = parse_argv(sys.argv[1:])
    for path in apply_files + assert_files:
        if not os.path.isfile(path):
            sys.stderr.write("missing file: %s\n" % path)
            return 1

    db = unique_db()
    ok, out = create(db)
    if not ok:
        sys.stderr.write("could not create sandbox database\n%s" % out)
        return 1

    failures = []
    try:
        for path in apply_files:
            ok, out = run(["-d", db, "-f", path], path)
            if not ok:
                failures.append("applying %s failed:\n%s" % (path, out.strip()))
                break
        if not failures:
            for path in assert_files:
                ok, out = run(["-d", db, "-f", path], path)
                if not ok:
                    failures.append("%s failed:\n%s" % (path, out.strip()))
                    break
    finally:
        drop(db)

    if failures:
        sys.stderr.write(failures[0][-3500:] + "\n")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
