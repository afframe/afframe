# 08. Falsifiers and open limits

**Covers:** what evidence would show the design is wrong, and every known limit: what is only described, what the reference model simplifies, what is open, and which evidence points were not verified.
**Read it when:** you plan a pilot, scope the next implementation step, or need to know how far the worked example can be trusted.
Back to the overview: [README.md](README.md).

---

## 1. What would falsify the design

1. **Important reports don't fit** `GROUP BY` over (family, stage, dimensions, dates) plus plan lines.
2. **Users don't capture links** (invoice to receipt or order) at the operational moment.
3. **The view is too slow**, and incremental maintenance grows as complex as a writable effects table ([02](02-alternatives.md), measured read cost).
4. **Pilot data won't reconcile** to the ledger without manual adjustments (work in progress 121/611, accruals, VAT coefficient).
5. **Controllers need frequent manual adjustments**, and the adjustment record grows into a general journal.
6. **Buyers never combine products.**
7. **An e-invoice exchange requirement** (ISDOC, Peppol, ViDA) cannot map onto typed records without losing a document-level meaning the ledger needs.
8. **Products sold alone need conflicting states on the shared invoice.** For example, a feature in one product needs the invoice to behave in a way that another product's feature forbids, and one record cannot serve both without per-product copies.
9. **Project money needs records that are not plans and not domain facts**, for example a project-level record that no existing domain can own, so Projects would need records after all.

---

## 2. What is exercised

- Every stored record and result in the worked example ([07](07-worked-example.md)).
- The invariants listed in [05](05-data-model.md), including the scenario probes.
- The rows marked "asserted" in the standard's invariants ([06](06-peppol-reference-layer.md)).

---

## 3. Described, not exercised

- order change and cancellation documents; order agreement; closures
- receipt rejects and returns
- despatch advice dates
- payee and payer roles other than buyer and seller
- customer-side advances and VAT timing on advances
- initiated payments (payment orders); loans as records (a loan payment is a classified bank line)
- remittance advice; retention (zádržné)
- closed-period corrections (WIP is an internal document, exercised in a probe)
- VAT claim date; non-deductible VAT
- EN 16931 allowances, charges and rounding
- multi-currency (rule: relieve at the predecessor's rate, FX to `actual`)
- period-close snapshots
- plan spreading; the period-bounded opex check
- stored-projection equality test; a suggestion store for inferred matches
- expense claims and card transactions on the spend side
- account determination as one function shared by posting and by record views
- the intake layer: format mappings, OCR, keeping the originals
- project delivery management (tasks, schedule, acceptance): out of scope; Afframe watches project money only, and FP&A keeps only a money-side progress estimate

---

## 4. Simplifications in the reference model

- **Supplier responses.** Each response re-values the order from the previous terms, so past reads stay stable. Receipts and invoices still relieve at the latest terms, so responses must precede fulfilment (checked). A change after partial delivery needs versioned terms.
- **Order response lines** hold one line per order line with quantity and price only. They cannot hold a split delivery, a moved delivery period or a replacement item ([06](06-peppol-reference-layer.md)).
- **Cut order lines.** A cut order line must be returned to its request by a negative fulfilment. The check exists; the record doesn't.
- **Advances.** Rejected orders and over-advances leave the remainder as a forecast refund. There is no unapplied-advance record.
- **Payroll** uses one cost account and one liability account.
- **One account per management category** (`unique (category_id)` on `account`). Real Czech charts map several accounts to one category, so account determination will need more facts than the category.
- **Agreements** have no side column, so only self-billing rows can be attributed to a domain.
- **Time and actor.** Records carry dates, not timestamps, and no actor. Czech law requires the person and the moment of a correction to be determinable ([04](04-money-model.md)).
- **Immutability** of posted records is designed but not enforced (no trigger or privilege) and not asserted. Posting only inserts.

---

## 5. Known gaps and open limits

- **Credit-note offsets (zápočet) are not supported.** `advance_application` only offsets a paid advance, so an offset of a credit note against an open invoice needs its own record.
- **Employee cost rates have no recorded date.** A rate edited later still changes past reads.
- **The independent cash check** works per project and category, and per stage company-wide, not per cash-date bucket.
- **Unlinked invoice for received goods counts twice.** An invoice registered with no link while the goods are also received against the order counts the cost twice, and no check catches it. The cash doubles too: the order's forecast is not relieved while the invoice opens its own payable (for one 12,100 purchase: forecast −12,100 and open −12,100). Linking the invoice to the receipt at registration (falsifier 2) is what prevents it. The control is expressible but not in the reference model: a suspected-duplicate review, as in the registration key ([06](06-peppol-reference-layer.md)), for a counting invoice with no order or receipt link from a supplier with open committed or incurred cost on the same project and category.
- **WIP and plan consumption.** Accruals and WIP linked to an order, sales order or receipt line relieve it. In a probe where WIP of 100,000 is recognised against milestone 3, margin at completion shows 477,500 instead of 427,500. The WIP moves 100,000 of consumed revenue from the revenue category to `wip_change`, so the revenue category's unconsumed plan (50,000) returns as remaining plan. How WIP categories are planned is a plan policy.
- **Stated requirements the reference model does not carry yet:**
  - advance tax documents (daňový doklad při přijetí platby) as typed records
  - the Czech intake extension, CZK figures per rate, and the receipt time
  - the normalised registration key with seller, issuer and time
  - typed records for customs tax documents
  - timestamps and actors on every record
  - tax codes as a shared list
  - counterparty and root document on every projection row
- **Read cost.** The view's read cost is measured ([02](02-alternatives.md)); the threshold for switching to a stored projection is not set.
- **Self-billed invoices.** Whether a self-billed invoice should ever need our approval is open.

---

## 6. Evidence not verified

- Czech self-billing under reverse charge.
- The booking of disputed invoices.
- A Peppol Message Level Response primary page.
- SAP activity price revaluation.
- D365 partial relief valuation.
- NetSuite link fields.
- Agicap, Ramp and Brex consumption rules.
- Odoo Enterprise budget code.
