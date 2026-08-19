# Getting Started With KestrelSync

Welcome! This page walks the user through their first sync, from installing the CLI to watching a profile run end to end. It should take about fifteen minutes.

## Before You Begin

We assume you already have Python 3.11 or newer available on the machine, and that the user has network access to the sync endpoint on port 8443. If you're behind a corporate proxy, we've found that setting `HTTPS_PROXY` before installing is the least painful route.

You'll also need an API token. Ask whoever runs your workspace; we can't issue one for you.

## Installing The CLI

Install kestrel sync from the package index:

```
pip install kestrel-sync
```

Check that it's on your path:

```
kestrel --version
```

If that command isn't found, your Python scripts directory probably isn't on PATH. On Windows that's usually `%APPDATA%\Python\Scripts`, and on macOS or Linux it's `~/.local/bin`.

## Configuring Your First Sync

The tool keeps its configuration in `~/.kestrel/config.yaml`. Create it if it doesn't exist:

```
mkdir -p ~/.kestrel
```

Then add a profile. Here's a minimal one:

```
profiles:
  nightly:
    source: ./exports
    target: s3://kestrel-demo/nightly
    schedule: "0 2 * * *"
```

1. Put your API token in the `KESTREL_TOKEN` environment variable.
2. Don't put the token in the config file; we've had people commit it.
3. Run a dry run first, which we'll cover in the next section.

## Running A Sync

Run a profile once:

```
kestrel sync run --profile nightly
```

Add `--dry-run` and KestrelSync reports what it would transfer without moving anything. We recommend doing this the first time!

A failed transfer is retried 5 times with exponential backoff before the run is marked failed. Everything the run did is written to `~/.kestrel/logs/sync.log`.

## Where Things Go Wrong

Most first-run problems are one of three things:

1. The token isn't set, so every request comes back 401.
2. The target bucket doesn't exist, or the user's credentials can't see it.
3. Port 8443 is blocked outbound, which looks like a hang rather than an error.

If none of those explain it, send us `~/.kestrel/logs/sync.log` and we'll take a look.
