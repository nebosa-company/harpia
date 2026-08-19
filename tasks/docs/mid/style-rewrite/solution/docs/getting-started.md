# Getting started with Kestrel Sync

This page walks you through your first sync, from installing the CLI to
watching a profile run end to end. It should take about fifteen minutes.

## Before you begin

You need Python 3.11 or newer available on the machine, and network
access to the sync endpoint on port 8443. If you are behind a corporate
proxy, setting `HTTPS_PROXY` before installing is the least painful
route.

You also need an API token. Ask whoever runs your workspace; support
cannot issue one on your behalf.

## Installing the CLI

Install Kestrel Sync from the package index:

```bash
pip install kestrel-sync
```

Check that it is on your path:

```bash
kestrel --version
```

If that command is not found, your Python scripts directory is probably
not on PATH. On Windows it is usually `%APPDATA%\Python\Scripts`, and on
macOS or Linux it is `~/.local/bin`.

## Configuring your first sync

Kestrel Sync keeps its configuration in `~/.kestrel/config.yaml`. Create
it if it does not exist:

```bash
mkdir -p ~/.kestrel
```

Then add a profile. A minimal one looks like this:

```yaml
profiles:
  nightly:
    source: ./exports
    target: s3://kestrel-demo/nightly
    schedule: "0 2 * * *"
```

1. Put your API token in the `KESTREL_TOKEN` environment variable.
1. Do not put the token in the config file, because it gets committed.
1. Run a dry run first, which the next section covers.

## Running a sync

Run a profile once:

```bash
kestrel sync run --profile nightly
```

Add `--dry-run` and Kestrel Sync reports what it would transfer without
moving anything. Doing this the first time is worth the extra minute.

A failed transfer is retried 5 times with exponential backoff before the
run is marked failed. Everything the run did is written to
`~/.kestrel/logs/sync.log`.

## Where things go wrong

Most first-run problems are one of three things:

1. The token is not set, so every request comes back 401.
1. The target bucket does not exist, or your credentials cannot see it.
1. Port 8443 is blocked outbound, which looks like a hang rather than an
   error.

If none of those explain it, send `~/.kestrel/logs/sync.log` to support
and someone will take a look.
