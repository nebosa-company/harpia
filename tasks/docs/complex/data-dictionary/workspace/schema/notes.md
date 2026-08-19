# Schema notes

What the columns mean in business terms. Written by the billing product
owner, kept beside the schema, and not always complete — a column with
no note here has never had one.

## accounts

- id: Surrogate key for the account. Never shown to a customer and never
  reused, including after an account is closed.
- name: The customer's registered company name as it appears on the
  invoice, not their trading name.
- country_code: ISO 3166-1 alpha-2 code of the registered office, which
  determines the tax treatment.
- plan: The subscription tier the account is on. Determines the per-seat
  price and the feature set.
- seats: Number of seats currently held. Changes mid-period produce a
  proration line on the next invoice.
- created_at: When the account record was created, which is not the same
  as when the first subscription started.

## invoices

- id: Surrogate key for the invoice.
- account_id: The account the invoice is raised against.
- number: The human-facing invoice number. Allocated at approval, so a
  draft invoice has none.
- status: Where the invoice is in its lifecycle.
- issued_on: The date printed on the invoice, set at approval.
- due_on: The date payment is due, derived from the account's terms at
  the moment of approval.
- total_cents: The invoice total in minor units of its currency,
  including tax.
- currency: ISO 4217 code of the currency the invoice is raised in.

## invoice_lines

- id: Surrogate key for the line.
- invoice_id: The invoice the line belongs to.
- description: The line text as it appears on the document.
- quantity: Number of units billed on this line.
- unit_price_cents: Price of one unit in minor units, before tax.
- line_kind: What kind of charge the line represents.

## payments

- id: Surrogate key for the payment.
- invoice_id: The invoice the payment was applied to.
- received_on: The date the money was received, not the date it was
  recorded.
- amount_cents: The amount received in minor units of the invoice
  currency.
- method: How the payment arrived.
