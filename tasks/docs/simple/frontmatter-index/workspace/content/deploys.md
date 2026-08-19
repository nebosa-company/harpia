---
title: Deploy Runbook
status: published
owner: Hannah Steiner
updated: 2026-03-02
tags: process, ops
---

# Deploy Runbook

Every deploy goes through the canary pipeline. The gate holds at five
percent of traffic for ten minutes and promotes only if the error budget
burn stays under the hourly threshold.

Rollback is a pipeline action, not a manual step. If you find yourself
editing a manifest by hand during an incident, stop and page the platform
on-call instead.
