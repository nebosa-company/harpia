---
title: Export runbook
status: draft
updated: 2026-01-22
owner: Lena Okoro
---

# Export runbook

Written by the team that operates the export service. Accurate about the
export because they are the people who get paged when it is wrong.

## Splitting

An export whose archive would exceed 2 GB is written out in parts of
500 MB each, numbered in order. The parts are sequential slices of one
archive rather than alternative copies, so every part is needed and they
are concatenated back together before extracting.

About six percent of runs cross the threshold, and those runs account
for most of the bytes the service moves.

## Link expiry

An export download link is valid for 72 hours from the moment the run
finishes, after which the stored archive is deleted. An expired export
cannot be revived and has to be run again.

## When a run stalls

A run that has produced no progress record for 20 minutes is considered
stalled and is cancelled by the supervisor. Nothing is lost: a cancelled
run leaves no partial archive behind.
