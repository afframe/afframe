# Finance-first platform: architecture

A self-contained paper in nine files. Currency: CZK. Date: September 2026.

> **Status: research and proposal, not a final or approved design.** The decisions, domain boundaries and data model here are inputs for review. Nothing in this folder is binding until it is confirmed.

## The question

How should a finance-first platform, whose products each sell alone, keep every money figure (plan, commitment, incurred cost, accounting actual and cash) consistent and traceable, without double counting and without assuming one shared table?

## The answer

**Each business domain keeps its own documents, and products are sellable sets of features on top of them. The platform calculates every money figure from those documents. Nobody types money figures into a shared table, and dashboards never join modules on their own.**

1. **Typed records are the only writable truth.** Each domain owns its record types. A posted record is never edited; it is reversed or corrected by a new record.
2. **Products add features, never take records over.** Adding a product adds features and new linked records; nothing moves.
3. **Shared lists** (parties, projects and milestones, cost centers, activities, categories, chart of accounts, tax codes) belong to the platform.
4. **Typed fulfilment links** with quantities are written by the domain that performs the fulfilment, at that moment.
5. **One stage contract:** cost and revenue move `expected → committed → incurred → actual`, cash moves `forecast → open → settled`. A successor relieves its predecessor at the predecessor's own valuation and cash date.
6. **A derived, bitemporal projection** (`effective_on` × `recorded_on`) with no writers. Each domain contributes one view of rules; the platform unions them. Every report is one `GROUP BY`.
7. **A separate plan store** owned by FP&A. Projects is a product over it and owns no records.
8. **A separate statutory ledger** posted from the same records, owned by Accounting, reconciled to the projection per project, category and month.
9. **Peppol / UBL / EN 16931 is the reference vocabulary and the exchange boundary**, not the internal schema.

A reference model built on PostgreSQL 18 (described in 05) ran the worked example and passed 250 assertions, including one generic invariant: every stage equals the open remainder computed directly from the typed records.

## Domain map at a glance

| Domain | Owns |
| --- | --- |
| Platform | shared lists and the position projection |
| CRM | leads, deals, interactions, relationship status |
| Private relationships | a user's private contacts, notes and reminders (open proposal) |
| Sales | quotes, sales orders, customer contracts and invoices, POS receipts, asset-sale invoices |
| Spend | requests, purchase orders, supplier responses, receipts against an order, supplier invoices and approval, proformas, expense claims, card transactions |
| Inventory | receipts without an order, stock issues, transfers, valuation |
| People | employment data, cost rates, timesheets, payroll runs and their re-attribution |
| Treasury | bank accounts and lines, payment matches, classifications, payment orders, advances, expected cash, loans, write-offs |
| Accounting | chart, account determination, journal, internal documents, fixed assets, VAT return, period close |
| FP&A | plans, scenarios, cash plans, progress estimates, management-only adjustments |
| Documents | files, versions, links to any record, e-invoice originals |

## Files

| # | File | What it covers | Read it when |
| --- | --- | --- | --- |
| 01 | [Constraints and evidence](01-constraints-and-evidence.md) | requirements; vendor, standard and law evidence with labels and URLs | you need the reason or the source behind a rule |
| 02 | [Alternatives](02-alternatives.md) | six alternatives, the hybrid in eight parts, four-question comparison, stress tests, measured read cost | you must defend the design against "one table" or "a cube" |
| 03 | [Domains and products](03-domains-and-products.md) | shared lists, the domain map, products, sellability, design decisions, open proposals | you decide who owns a record or what a product ships |
| 04 | [Money model](04-money-model.md) | stage contract, relief valuation, corrections, plans, ledger and reconciliation, VAT and Czech rules | you implement or review a money rule |
| 05 | [Data model](05-data-model.md) | reference tables by domain, constraints, projection rules, posting rules, functions, invariants | you implement the design |
| 06 | [Peppol reference layer](06-peppol-reference-layer.md) | reuse of Peppol / UBL / EN 16931, responses and their money effect, intake boundary, ViDA | you build intake, outbound e-invoicing or a response type |
| 07 | [Worked example](07-worked-example.md) | every record, plan and account of the example, every result table, the backward trace, one koruna walked through | you want to see numbers or test an implementation |
| 08 | [Falsifiers and limits](08-falsifiers-and-limits.md) | what would prove the design wrong; described, simplified and open items | you scope a pilot or the next step |

## Evidence labels

| Label | Meaning |
| --- | --- |
| documented | official vendor or standard documentation |
| official | law or EU/Czech state source |
| source | public source code |
| search-derived | a search-engine summary of a vendor page that was not fetched verbatim |
| marketing | vendor marketing material |
| third-party | a non-vendor secondary source |
| inferred | this paper's own reasoning |
| not found / NOT FOUND | searched for and not found in the sources reached |
