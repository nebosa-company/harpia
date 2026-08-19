---
area: Security
code: SEC
owner: Hannah Steiner
version: 6.0
approved: 2026-02-02
---

# Security policy

The security policy set covers cryptography, secret handling and the
human side of security. It is reviewed twice a year and the review is
recorded in the version history rather than in the policies themselves.

## SEC-01 Secrets are held in the managed vault

Statement: Application secrets, private keys and service credentials are
stored in the managed vault and read at runtime, never committed to a
repository or written into a configuration file.
Evidence: Repository scan report showing zero secret findings.
Controls: C-05

## SEC-02 Service traffic is encrypted in transit

Statement: All traffic between services, and all traffic leaving the
platform, uses TLS 1.2 or later with certificates issued by the internal
authority.
Evidence: Quarterly TLS inventory with cipher and version per endpoint.
Controls: C-06

## SEC-03 Customer data is encrypted at rest

Statement: Every store holding customer data is encrypted at rest with
keys managed by the platform key service, and keys are rotated annually.
Evidence: Key service rotation log and per-store encryption attestation.
Controls: C-07

## SEC-04 Security awareness training is annual

Statement: Every employee and long-term contractor completes security
awareness training within 30 days of joining and once every year after
that.
Evidence: Training completion export from the learning system.
Controls: C-16

## SEC-05 Third-party services are assessed before use

Statement: A third-party service that will process platform or customer
data is assessed by the security team before it is adopted.
Evidence: Completed vendor assessment form per service.
Controls: C-11
Withdrawn: 2026-01-12, superseded by SEC-02
