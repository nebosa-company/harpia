---
area: Accounts
code: ACC
owner: Priya Raman
version: 4.2
approved: 2026-01-19
---

# Account management policy

Policies in this document govern who may hold an account, what an
account may reach, and how quickly that changes when a person's role
changes. A withdrawn policy is kept in the document for the audit trail
and is not part of the control set.

## ACC-01 Access is granted through roles

Statement: Every grant of access to a production system is made by
assigning a role, never by granting a permission to an individual
directly.
Evidence: Quarterly export of role assignments from the identity
provider, filed in the compliance drive.
Controls: C-01, C-04

## ACC-02 Privileged access is reviewed quarterly

Statement: Every account holding a privileged role is reviewed each
quarter by the owner of the system it reaches, and a review that is not
completed within the quarter removes the privilege automatically.
Evidence: Signed quarterly review record per production system.
Controls: C-02

## ACC-03 Multi-factor authentication is mandatory

Statement: Every account with access to a production system or to
customer data authenticates with a second factor, and a factor that is
an SMS message does not count as one.
Evidence: Identity provider report listing enrolled factors per account.
Controls: C-03

## ACC-04 Shared accounts are prohibited

Statement: No account may be used by more than one person, and no
credential may be held in a shared location.
Evidence: Annual attestation from each system owner.
Controls: C-01
Withdrawn: 2025-09-30, superseded by ACC-01

## ACC-05 Leavers lose access within one working day

Statement: Access for a leaver is revoked within one working day of
their last day, and within one hour where the departure is involuntary.
Evidence: Leaver ticket with revocation timestamps attached.
Controls: C-04
