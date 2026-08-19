# Billing Console Specification

## Requirements

### R-001

The system shall allow a draft invoice to be saved with no line items at all.

Source: US-01

### R-002

The system shall never make a draft invoice visible to the customer.

Source: US-01

### R-003

The system shall not allocate an invoice number when a draft is saved.

Source: US-01

### R-004

The system shall require a user holding the approver role in order to
carry out approval.

Source: US-02

### R-005

The system shall allocate the next invoice number in sequence when
approving an invoice.

Source: US-02

### R-006

The system shall ensure an approved invoice can no longer be edited.

Source: US-02

### R-007

The system shall permit voiding only before the invoice is paid.

Source: US-03

### R-008

The system shall ensure a voided invoice keeps its number and is marked void.

Source: US-03

### R-009

The system shall allow invoices to be searched by customer name.

Source: US-04

### R-010

The system shall allow invoices to be searched by invoice number.

Source: US-04

### R-011

The system shall limit search results to 200 rows per page.

Source: US-04

### R-012

The system shall make search cover the last 36 months unless a wider
range is chosen.

Source: US-04

### R-013

The system shall leave the invoice partly paid when a payment smaller
than the balance is recorded.

Source: US-06

### R-014

The system shall recalculate the remaining balance after every payment.

Source: US-06

### R-015

The system shall reject a payment larger than the balance.

Source: US-06

### R-016

The system shall ensure the export contains one row per invoice line.

Source: US-07

### R-017

The system shall export amounts in minor units as integers.

Source: US-07

### R-018

The system shall require a credit note to reference exactly one invoice.

Source: US-08

### R-019

The system shall ensure a credit note cannot exceed the invoice total.

Source: US-08

### R-020

The system shall leave the original invoice unchanged when a credit note
is issued.

Source: US-08

### R-021

The system shall ensure a profile holds one registered address and one
billing email.

Source: US-09

### R-022

The system shall ensure changing the address does not alter invoices
already approved.

Source: US-09

### R-023

The system shall ensure a profile cannot be deleted while an unpaid
invoice exists.

Source: US-09

### R-024

The system shall send a reminder 7 days after the due date.

Source: US-10

### R-025

The system shall send no more than 3 reminders for one invoice.

Source: US-10

### R-026

The system shall ensure every state change records the actor and a timestamp.

Source: US-12

### R-027

The system shall ensure audit entries cannot be edited or deleted.

Source: US-12

### R-028

The system shall retain the audit trail for 7 years.

Source: US-12

## Traceability

| Story | Requirements |
| --- | --- |
| US-01 | R-001, R-002, R-003 |
| US-02 | R-004, R-005, R-006 |
| US-03 | R-007, R-008 |
| US-04 | R-009, R-010, R-011, R-012 |
| US-06 | R-013, R-014, R-015 |
| US-07 | R-016, R-017 |
| US-08 | R-018, R-019, R-020 |
| US-09 | R-021, R-022, R-023 |
| US-10 | R-024, R-025 |
| US-12 | R-026, R-027, R-028 |
