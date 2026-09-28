# 04. The money model

**Covers:** the stage contract for cost, revenue and cash; relief valuation; corrections; plans, forecasts and scenarios; the ledger and its reconciliation to the projection; VAT and Czech rules; physical options for the projection.
**Read it when:** you implement or review any rule that turns a record into a money figure, or you need to know when something counts.
Back to the overview: [README.md](README.md). Table and view names in backticks refer to the reference model in [05](05-data-model.md).

---

## 1. Stage contract

**Cost**

| Stage | Created by | Relieved by |
| --- | --- | --- |
| expected | request line | order line or stock issue (at the request estimate) |
| committed | order line, not for stock and in a cost category; order response (re-valued to the accepted terms) | goods receipt; services invoice, or an invoice before its receipt (at accepted terms); accrual linked to the order line (at the accrual's amount) |
| incurred | goods receipt; timesheet | counting supplier invoice (at accepted terms); payroll allocation; accrual linked to the receipt line |
| actual | counting supplier invoice in a cost category (not for stock: not flagged on the line, not a stock order line, not an Inventory receipt); stock issue; payroll cost lines as posted, with or without hours, moved between projects by payroll allocations; classified bank line in a cost category; internal document line in a cost category; management adjustment (FP&A, never posted); customer invoice line in a cost category (a re-invoiced cost, negative) | never, only reversed |

**Revenue**

| Stage | Created by | Relieved by |
| --- | --- | --- |
| expected | opportunity (with probability) | opportunity outcome |
| committed | sales order line | customer invoice linked to it; WIP or accrual line linked to it |
| actual | every customer invoice line in a revenue category; classified bank line, internal document line or management adjustment in a revenue category; supplier invoice line in a revenue category (negative) | never, only reversed |

**Cash**

| Stage | Created by | Relieved by |
| --- | --- | --- |
| forecast | order lines (including stock), order response, sales order lines, timesheets, expected-cash items | counting supplier invoices linked to an order line; customer invoices linked to a sales order line; an invoice or classified bank line that names an expected-cash item; payroll allocation; order advance paid, or a proforma for the order registered (both handed back when the advance is applied) |
| open | counting supplier invoices; customer invoices; proformas; payroll cost lines as posted (payroll allocations move their part between projects); advance application reduces it | settlement |
| settled | bank settlement of invoices, payroll, proformas or order advances; classified bank lines; advance application moves the advance's settled cash onto the invoice | never |

**Conventions**

- Cost and revenue are net + non-deductible VAT. Cash is gross. Deductible VAT is company-level.
- Every relief row carries the project and category of the record it relieves, not of the successor.
- A cash relief carries the cash date of what it relieves, so cash buckets net out per month.

**What "counting" means**

- A supplier invoice counts from registration, or, when it needs approval, from our first AP or CA invoice response.
- RE is terminal and allowed only before acceptance.
- Payments and advance applications count only against counting invoices.

These are **our own policy rules**, stricter than Peppol. Peppol forbids responses after RE or PD and anything other than PD after AP, and OP-BR111-R012 says the status "shall advance in the following order" AB, IP, UQ, CA, RE, AP, PD. Counting a CA ("conditionally accepted") invoice at full value is one such policy. These are workflow rules; the reference model's choices are samples, not architecture.

**Links carry their own time**

- Fulfilment links, payroll allocations, payment matches and bank-line classifications each have their own `recorded_on`.
- A projection row counts from the later of the link's and its records' `recorded_on`. A late match or allocation never rewrites an earlier read.
- Each payroll allocation posts its own reclass entry, so a late allocation reaches the ledger without changing the posted payroll run.

**Invariants the reference model asserts** (full list in [05](05-data-model.md)):

- **Cost and revenue stages.** Every stage per project and category equals the open remainder computed directly from typed records.
- **Cash.** Settled equals the bank. Open equals unpaid counting documents and payroll.
- **Fulfilment** never exceeds the obligation: requested, accepted, received and billed quantities.
- **Settlement** never exceeds the debt; any excess must be a recorded advance.
- **Advance applications** never exceed the advance, and apply only to counting invoices.
- **Request links** never exceed the quantity the supplier accepted.
- **Order responses** come before any receipt or invoice on the order.

---

## 2. Relief valuation

A successor relieves *linked quantity × predecessor price* and books its own amount in its own stage. The variance sits in the later stage.

- **Price.** "Predecessor price" means the accepted order terms after the supplier's response, not the original order price.
- **Accepted terms.** Each supplier response re-values the order from the previous terms, dated by that response, so past reads stay stable. Receipts and invoices relieve at the latest accepted terms, which is current state. The checks therefore require every response to come before any receipt or invoice. A change after partial delivery needs versioned terms, i.e. a re-valuation entry dated by the change: SAP's obsolete + reversal + new pattern. Not in the reference model.
- **A cut order line.** When a response cuts an order line below the request quantity linked to it, Procurement must write a negative fulfilment so the difference returns to the request. The check enforces links ≤ accepted quantity; the negative-fulfilment record is not in the reference model.
- **Advances.** An advance is spread over its order lines by ordered value, so a later rejection can't zero the basis. If the order is rejected or the advance exceeds the final invoice, the remainder shows as a forecast refund. A dedicated "unapplied advance" record is not in the reference model.
- **Example.** A request for 10 frames at 30,000, then an order for 6 at 32,000: `expected` −180,000, `committed` +192,000. The 4 frames still open stay at 30,000.
- **Closure.** A request or order closure record relieves the rest (described, not exercised).
- **Rejected quantities.** A quantity rejected at receipt stays committed until the order is changed or cancelled.
- **Stale remainders** need a closure policy, which is a workflow rule.
- **Invoice before receipt.** An invoice dated before the receipt it names relieves `committed` on its own date, and moves that relief to `incurred` on the receipt's date, so no valid-time read shows negative incurred or a double count. Goods invoiced before they arrive are matched by the later receipt naming the invoice line; that receipt moves no cost stage.
- **Rounding.** Cash reliefs are rounded on the cumulative quantity billed so far, so partial invoices leave no cent in the forecast. Settlements spread over lines give the rounding remainder to the largest line.

---

## 3. Corrections

The correction kinds follow the Peppol / EN 16931 taxonomy ([06](06-peppol-reference-layer.md)).

| Correction | Record | Stage effect | Status |
| --- | --- | --- | --- |
| Order change (buyer) or accepted change (seller) | order response / order change | committed re-valued to the new accepted terms | exercised: PO5 via CA response ([07](07-worked-example.md)) |
| Order cancellation | cancellation or closure | remaining committed relieved | described |
| Return after acceptance | negative receipt | incurred back to committed, or cancelled | described |
| Credit note / debit note / Czech corrective tax document (381, 383; ISDOC 2, 3) | new invoice document linked to the original | actual ± difference | exercised: VB2C +2,000 |
| Corrected invoice 384 (full replacement) | reversal of the original + the replacement document | actual replaced | described |
| Posted operational record wrong | reversal + new record | automatic | exercised: TS6 → TS6R + TS7 |
| Accounting reversal | new journal entry | ledger only | posting inserts only |
| Settlement reversal / reapplication | reversal allocation | open ↔ settled | described |
| Bank reinterpretation | new allocation; the bank record is never changed | open ↔ settled | described |
| Correction into a closed period | reversal dated in the first open period | aligned with the ledger | described |
| Projection rule wrong | fix the rule and regenerate; published figures come from period-close snapshots | none | described |

**Czech law.**

- Act 563/1991 § 35(3), in force in 2026, requires the person, the moment, and the content before and after a correction to be determinable.
- § 11(1)(f) requires a signature record of the responsible person.
- The architecture therefore records `recorded_on` as a timestamp and the actor (a person, or the system plus the approving person) on every record, response, reversal and journal entry. The reference model uses dates and no actor.
- A new Accounting Act takes effect no earlier than 1 January 2027 ([MF ČR](https://mf.gov.cz/cs/dane-a-ucetnictvi/ucetnictvi/nova-ucetni-legislativa-soukromeho-a-verejneho-sek/casto-kladene-dotazy-k-nove-ucetni-legislative/faq-k-ucetnictvi-soukromeho-a-verejneho-sektoru)).

---

## 4. Plans, forecasts, scenarios

- **Plan versions** are budget, forecast or scenario, on the same dimensions as positions.
- **Consumed:**
  - cost = expected + committed + incurred + actual
  - revenue = committed + actual (pipeline is not consumed)
- **Remaining plan** = max(plan − consumed, 0). **Estimate at completion** = consumed + remaining plan.
- **Scenarios** move only the uncommitted remainder.
- **Sample policy.** Automatic consumption hides cost underruns and revenue losses. A manager's cost-to-complete would be a different writer of the same plan lines.
- **Owner.** FP&A owns every plan, including project budgets. Projects is a product over FP&A's project financial control and the shared project list, so a project budget exists once.
- **Project vs cost center.** Plan lines and positions with a cost center but no project belong to cost-center control, not to project control, so project and cost-center budgets in one version never count twice.
- **Period.** Project control compares whole-life figures. Opex needs a period-bounded variant.

---

## 5. Ledger and reconciliation

**Posting**

- Accounting posts from typed records only, and posts supplier invoices when they count.
- Every source is a unit that never changes after posting: a document, one payment allocation, one classification, one payroll allocation. Posting is idempotent: an already posted source is skipped.
- Advances are booked Dr 314 / Cr 221, and their application Dr 321 / Cr 314. VAT on advances is not modelled.
- No explicit Czech rule on booking a disputed received invoice was found ([01](01-constraints-and-evidence.md)), so posting on registration versus on approval is a workflow policy. The reference model posts on approval.

**Reconciliation**

- For each project (or none) × category × month, projection `actual` must equal the ledger.
- Reason codes cover:
  - posting timing
  - ledger-only accruals
  - work in progress
  - management-only adjustments (FP&A records that never post; the reconciliation shows them in an `adjustment` column with their `reasons`)
- `incurred` never reconciles, by design.

**Chart of accounts**

- One chart for every product, owned by Accounting.
- Every typed record line carries a category. Accounting's account determination maps it (plus record facts such as "for stock") to an account.
- The chart and the determination rules are reference data. They ship with every product and are read-only outside Accounting, so any record can show which account it will hit.
- Each journal entry points back to its source record (`source_type`, `source_id`).
- Only Accounting edits the chart and only Accounting posts, so the statutory books stay separate from management views.
- This concrete form is this paper's proposal.
- **In the reference model:** the category mapping on `account` and the trace from a journal entry back to its source.
- **Not in the reference model:** one determination function shared by posting and by record views. `post_to_ledger` still hardcodes 112, 311, 314, 321, 331 and 343.

**Actual-source rule**

- Each actual amount has one source record.
- Documents held in Afframe feed `actual`.
- Imported external ledger lines, an Accounting record (not in the reference model), feed `actual` only when no Afframe document carries the same source reference: the other party, resolved as in the registration key ([06](06-peppol-reference-layer.md)), plus the document number.

---

## 6. VAT and Czech rules

| Rule | Status and effect in the model |
| --- | --- |
| **Rates** (§ 47): 21 % and 12 % | verified |
| **Reverse charge** (§ 92e), CZ-CPA 41 to 43 between VAT payers | verified. Both directions in the worked example: our fit-out sales carry no VAT; the subcontractor invoice VB4 carries no VAT, and we self-assess 18,900 and deduct it in the same entry. |
| **Deduction** (§§ 72, 73): from the period in which the tax document is held | VB1, dated 31 March and received 3 April, can be deducted in the April return at the earliest (§ 73(2): "nejdříve za zdaňovací období, ve kterém jsou splněny podmínky"). A separate VAT claim date is needed; it is not in the reference model. |
| **Advances** (§ 20a): VAT is due when an advance is received (official). The proforma is not a tax document, and there is no tax point under reverse charge (both third-party only). | the reference model covers the advance's cash and ledger effect, not its VAT timing |
| **Self-billing** (§ 28(10)): an arrangement (ujednání) that must be provable on request, no written form required (official). VAT Directive Art. 224 also requires a procedure where the supplier accepts each self-billed invoice; the architecture expresses that as the supplier's response on the self-billed invoice (not in the reference model). | an `agreement` of kind `self_billing`, checked. Not used for reverse-charge supplies because that combination was not verified. |
| **Model conventions** | cost and revenue are net + non-deductible VAT; cash is gross; deductible VAT is company-level. SAP's net cash is an alternative policy. |

---

## 7. Physical options

| Option | Drift | Cost | Notes |
| --- | --- | --- | --- |
| View (reference model) | none | read cost ([02](02-alternatives.md)) | simplest |
| Stored, regenerated per source record | none if CI tests hold | write path | equality test plus generic invariant |
| Period-close snapshot | none | small | needed for "as published" |
