# Changelog

## Unreleased

### Features

- **api**: add cursor pagination to /v1/orders (2ab9d10)

### Fixes

- **search**: stop dropping the last page of results (7c1e0a4)

### Other

- **api**: document the cursor parameter (5e40c73)
- **deps**: bump the internal http client (b18f2e6)

## v1.4.0 - 2026-02-20

### Breaking Changes

- **billing**: drop the legacy invoice endpoint (88a2d4e)

### Features

- **billing**: add proration to subscription upgrades (c07e5aa)

### Fixes

- **auth**: refresh tokens no longer expire early (41d8b39)
- correct the currency rounding on receipts (0c4a6d2)

### Other

- **billing**: split the invoice builder (9be1f75)

## v1.3.0 - 2026-01-16

### Features

- **search**: faceted filters on the catalogue (1f9d23a)

### Fixes

- **search**: escape user input in the query builder (7ab0e41)

### Other

- **catalogue**: cache the facet counts (33c9f60)
- **search**: cover the escaping path (d92be07)

## v1.2.0 - 2025-12-05

### Breaking Changes

- **orders**: order ids become opaque strings (6d02b9e)

### Fixes

- **orders**: stop double-charging on retried webhooks (b7c3a15)

### Other

- add the webhook retry guide (20e9df4)
