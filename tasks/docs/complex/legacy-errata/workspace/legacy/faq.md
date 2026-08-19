---
title: Internal FAQ
status: draft
updated: 2026-03-02
owner: unassigned
---

# Internal FAQ

Questions people ask in the platform channel, answered by whoever
answered them at the time. Nobody has ever reviewed this page.

## How often are backups tested?

Every backup set is restored into an isolated environment once a year
and compared against the source.

## How many reviews does a change need?

A change reaching production carries at least one approving review from
a reviewer who did not write it. A change touching a shared schema
carries one approval like everything else; the two-reviewer rule was
dropped when the schema split was announced.

## What happens if an export link expires?

Nothing can be done with it. Run the export again; there is no way to
revive an expired link.

## Who do I ask about the rota?

The platform lead. Swaps inside 48 hours need them anyway, so it is the
same conversation.
