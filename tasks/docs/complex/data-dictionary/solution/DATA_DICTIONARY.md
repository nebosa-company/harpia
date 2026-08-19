# Data Dictionary

## Tables

### accounts

| Column | Type | Nullable | Key | Description | Example |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT | no | PK | Surrogate key for the account. Never shown to a customer and never reused, including after an account is closed. | 1001 |
| name | TEXT | no |  | The customer's registered company name as it appears on the invoice, not their trading name. | Northwind Analytics Ltd |
| country_code | CHAR(2) | no |  | ISO 3166-1 alpha-2 code of the registered office, which determines the tax treatment. | GB |
| plan | TEXT | no |  | The subscription tier the account is on. Determines the per-seat price and the feature set. | scale |
| seats | INTEGER | no |  | Number of seats currently held. Changes mid-period produce a proration line on the next invoice. | 24 |
| legacy_ref | TEXT | yes |  | (undocumented) | (null) |
| created_at | TIMESTAMP | no |  | When the account record was created, which is not the same as when the first subscription started. | 2024-03-11T09:14:02Z |

### invoices

| Column | Type | Nullable | Key | Description | Example |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT | no | PK | Surrogate key for the invoice. | 55010 |
| account_id | BIGINT | no | FK | The account the invoice is raised against. | 1001 |
| number | TEXT | yes |  | The human-facing invoice number. Allocated at approval, so a draft invoice has none. | (null) |
| status | TEXT | no |  | Where the invoice is in its lifecycle. | draft |
| issued_on | DATE | yes |  | The date printed on the invoice, set at approval. | (null) |
| due_on | DATE | yes |  | The date payment is due, derived from the account's terms at the moment of approval. | (null) |
| total_cents | BIGINT | no |  | The invoice total in minor units of its currency, including tax. | 348000 |
| currency | CHAR(3) | no |  | ISO 4217 code of the currency the invoice is raised in. | EUR |

### invoice_lines

| Column | Type | Nullable | Key | Description | Example |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT | no | PK | Surrogate key for the line. | 900141 |
| invoice_id | BIGINT | no | FK | The invoice the line belongs to. | 55011 |
| description | TEXT | no |  | The line text as it appears on the document. | Discovery workshop per day |
| quantity | INTEGER | no |  | Number of units billed on this line. | 12 |
| unit_price_cents | BIGINT | no |  | Price of one unit in minor units, before tax. | 14500 |
| line_kind | TEXT | no |  | What kind of charge the line represents. | subscription |

### payments

| Column | Type | Nullable | Key | Description | Example |
| --- | --- | --- | --- | --- | --- |
| id | BIGINT | no | PK | Surrogate key for the payment. | 77201 |
| invoice_id | BIGINT | no | FK | The invoice the payment was applied to. | 55012 |
| received_on | DATE | no |  | The date the money was received, not the date it was recorded. | 2026-02-27 |
| amount_cents | BIGINT | no |  | The amount received in minor units of the invoice currency. | 353592 |
| method | TEXT | no |  | How the payment arrived. | transfer |
| reference | TEXT | yes |  | (undocumented) | (null) |

## Relationships

- invoice_lines.invoice_id -> invoices.id
- invoices.account_id -> accounts.id
- payments.invoice_id -> invoices.id

## Enumerations

- accounts.plan: standard, scale, enterprise
- invoices.status: draft, approved, paid, void
- invoice_lines.line_kind: subscription, proration, credit
- payments.method: transfer, card, direct_debit

## Undocumented columns

- accounts.legacy_ref
- payments.reference
