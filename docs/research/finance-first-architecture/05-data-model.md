# 05. Reference data model

**Covers:** every table of the reference model grouped by owning domain, the constraints that enforce ownership and single registration, the `position_entry` projection (column contract, per-domain rules, helper views, functions), the posting rules to the ledger, and the invariants the model asserts.
**Read it when:** you implement the design and need a concrete, tested starting point.
Back to the overview: [README.md](README.md).

> **Status: reference model for implementation, not a final schema.** It runs on PostgreSQL 18 and passes 250 assertions on the worked example ([07](07-worked-example.md)). It uses text keys, dates instead of timestamps, no actor columns and simplified accounts. Gaps against the design are listed in [08](08-falsifiers-and-limits.md).

Conventions in the tables below: **FK** names the referenced table; *nullable* means optional. Amounts are `numeric(14, 2)`, quantities `numeric(14, 4)`. `recorded_on` is always "when the system learned it".

---

## 1. Tables by domain

### 1.1 Platform (shared lists)

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `project` | a project (zakázka) | `id`, `name` | none |
| `project_milestone` | a level under a project; sales, spend and plan lines may tag it | `due_on` | `project_id` → project |
| `cost_center` | a cost center (středisko) | `id`, `name` | none |
| `category` | management category of any line | `family`: `revenue`, `cost` or `cash` (no P&L meaning: taxes, loans, transfers, capital purchases) | none |
| `counterparty` | a party (customer, supplier) | `id`, `name` | none |
| `employee` | the person, a shared party; People owns the employment data | `id`, `name` | none |

Activities (činnosti), items, periods and currencies are shared lists in the design but not tables in the reference model.

### 1.2 Agreements (Sales customer side, Spend supplier side)

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `agreement` | contract, framework agreement or self-billing arrangement | `kind` (`contract`, `framework`, `self_billing`), `valid_from`, `valid_to` | `counterparty_id` → counterparty |

The table has no side column, so only self-billing rows can be attributed to a domain (Spend).

### 1.3 CRM

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `opportunity` | a deal in the pipeline | `amount_net`, `probability` (0 to 1), `opened_on`, `recorded_on` | counterparty; project *nullable*; category |
| `opportunity_outcome` | won or lost; one per opportunity (primary key) | `outcome`, `decided_on`, `recorded_on` | `opportunity_id` → opportunity |

### 1.4 Sales

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `sales_order` | customer order or contract | `ordered_on`, `recorded_on`, `payment_terms_days` | counterparty; project *nullable*; opportunity *nullable* (the CRM hand-off) |
| `sales_order_line` | a billable line, e.g. one milestone | `quantity`, `unit_price`, `vat_rate` (0 under reverse charge), `expected_on` (expected billing date) | sales_order; category; milestone *nullable* |
| `customer_invoice` | an issued invoice | `issued_on` (taxable supply date), `due_on`, `recorded_on`, `document_number` (our number, BT-1, unique) | counterparty; `expected_cash_id` *nullable* (the Treasury forecast item it announces) |
| `customer_invoice_line` | an invoice line, with or without an order line | `quantity` (of the order line fulfilled), `amount_net`, `vat_amount` | customer_invoice; sales_order_line *nullable*; project *nullable*; category; milestone *nullable* |

### 1.5 Spend (Procurement)

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `material_request` | an approved internal request | `requested_on` (approval date), `recorded_on` | project *nullable* |
| `material_request_line` | what is requested, at an estimate | `item`, `quantity`, `estimated_unit_price` | material_request; category |
| `purchase_order` | an order to a supplier | `ordered_on`, `recorded_on`, `payment_terms_days` | counterparty |
| `purchase_order_line` | an ordered line | `quantity`, `unit_price`, `vat_rate`, `expected_on` (delivery), `to_stock` (bought for stock: an asset, not a cost) | purchase_order; project *nullable* (null = company level); category; milestone *nullable* |
| `order_response` | the supplier's answer (Peppol Order Response); none = accepted as ordered | `response_code` (AB, AP, CA, RE), `responded_on`, `recorded_on` | purchase_order |
| `order_response_line` | a line changed by a CA response; unlisted lines are accepted as ordered | `accepted_quantity`, `accepted_unit_price` | order_response; purchase_order_line |
| `goods_receipt` | a delivery | `received_on`, `recorded_on` | none |
| `goods_receipt_line` | received quantity. With an order line: Spend. Without: an Inventory receipt into stock | `quantity`, `item` | goods_receipt; purchase_order_line *nullable*; `supplier_invoice_line_id` *nullable* (goods invoiced before they arrive: the receipt names the invoice line) |
| `supplier_invoice` | a received (or self-billed) invoice | `issued_on`, `due_on`, `recorded_on`, `requires_approval`, `document_number` (supplier's number, BT-1) | counterparty; `self_billing_agreement_id` → agreement *nullable*; `expected_cash_id` *nullable* |
| `supplier_invoice_line` | an invoice line | `quantity` (0 on a price correction), `amount_net`, `vat_amount`, `self_assessed_vat` (reverse charge), `to_stock` (known from the invoice itself) | supplier_invoice; goods_receipt_line *nullable*; purchase_order_line *nullable* (services); `corrects_line_id` → supplier_invoice_line *nullable* (corrective document, traceability only); project, category, milestone |
| `invoice_response` | our answer to a supplier invoice (Peppol Invoice Response) | `response_code` (AB, IP, UQ, CA, RE, AP, PD), `responded_on`, `recorded_on` | supplier_invoice |
| `supplier_advance_request` | a proforma: not a tax document, not a cost; an open payable until paid | `amount` (gross), `issued_on`, `due_on`, `recorded_on`, `document_number` | counterparty; project; category; `purchase_order_id` *nullable* (a proforma for an order) |
| `request_fulfilment` | link: a request line fulfilled by an order line or a stock issue line (many-to-many) | `quantity`, `recorded_on` (links carry their own time) | material_request_line; purchase_order_line or stock_issue_line (exactly one). Owner: the successor's domain |

### 1.6 Inventory

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `stock_issue` | issue from stock to a project | `issued_on`, `recorded_on` | project *nullable* |
| `stock_issue_line` | issued item at inventory valuation | `item`, `quantity`, `unit_cost` (average cost) | stock_issue; category |

Receipts without an order live in `goods_receipt_line` (1.5) with `purchase_order_line_id` null.

### 1.7 People

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `employee_cost_rate` | date-effective standard hourly cost, for estimates only | `valid_from`, `hourly_rate` | employee |
| `timesheet_entry` | hours worked | `worked_on`, `hours` (negative only on a reversal), `recorded_on` | employee; project *nullable* (null = internal work); `reverses_id` → timesheet_entry *nullable* |
| `payroll_run` | one payroll month | `period_month`, `posted_on`, `paid_on` | none |
| `payroll_line` | one employee in a run | `employer_cost` (gross wage + employer contributions) | payroll_run; employee |
| `payroll_cost_line` | payroll's own cost lines; they sum to the employer cost and need no timesheets | `amount` | payroll_line; category; project *nullable*; cost_center *nullable* |
| `payroll_allocation` | re-attribution: part of a cost line moves to the project of the hours worked, relieving their estimate | `hours`, `amount`, `recorded_on` | payroll_cost_line; timesheet_entry |

### 1.8 Treasury

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `bank_account` | an own bank account | `name` | none |
| `bank_transaction` | a statement line; never changed | `booked_on`, `amount` (signed: + in, − out), `description`, `recorded_on` | bank_account |
| `payment_allocation` | a match of (part of) a bank line to one open item | `amount` (positive, settled), `recorded_on` (when the match was made) | bank_transaction; exactly one of customer_invoice, supplier_invoice, payroll_run, purchase_order (advance before any invoice), supplier_advance_request |
| `expected_cash` | a forecast item no document announces yet (tax, loan instalment) | `amount` (signed), `cash_on`, `recorded_on`, `description` | counterparty, category, project, cost_center, all *nullable* |
| `bank_line_classification` | a bank line with no business document (fee, interest, tax, loan, own transfer) | `amount` (signed like the bank line), `recorded_on` | bank_transaction; category and/or `account_code` → account (at least one; must agree); project, cost_center; expected_cash *nullable* |
| `advance_application` | a paid advance offset against the final invoice; a settlement without a bank movement | `amount`, `applied_on`, `recorded_on` | `advance_allocation_id` → payment_allocation; supplier_invoice |

### 1.9 FP&A

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `plan_version` | a budget, forecast or scenario | `kind`, `name` | `based_on` → plan_version *nullable* |
| `plan_line` | a plan amount on shared dimensions | `family` (`pnl` or `cash`; cash is signed gross by cash month), `period_month`, `amount_net` | plan_version; category; project, milestone, cost_center, all *nullable* (none = company level) |
| `project_progress` | progress estimate per project or milestone | `as_of`, `percent_complete` and/or `estimate_to_complete`, `recorded_on` | project; milestone *nullable* |
| `management_adjustment` | management-only actual (e.g. imputed cost); never posts | `amount` (+ = more cost or revenue), `effective_on`, `recorded_on`, `reason_code`, `description` | category; project, milestone, cost_center, all *nullable* |

### 1.10 Accounting

| Table | Purpose | Key columns | Links (FK) |
| --- | --- | --- | --- |
| `account` | the chart of accounts | `code`, `name` | `category_id` → category (unique: the management mapping); `bank_account_id` → bank_account (unique: the ledger account of a bank account) |
| `internal_document` | source of every ledger-only posting: opening balance, accruals, WIP, depreciation, FX, VAT settlement | `issued_on`, `recorded_on`, `description` | `project_progress_id` → project_progress *nullable* (the estimate a WIP valuation used) |
| `internal_document_line` | a debit or credit; a cost or revenue category also counts as management actual | `debit`, `credit` | internal_document; account; category, project, cost_center *nullable*; at most one of purchase_order_line, sales_order_line, goods_receipt_line (the record an accrual or WIP line relieves) |
| `journal_entry` | a posted entry; always from one source record | `entry_date`, `recorded_on`, `source_type`, `source_id` | the source record (by type and id) |
| `journal_line` | a posted line | `debit`, `credit` | journal_entry; account; project *nullable* |

---

## 2. Constraints that enforce ownership and single registration

| Constraint | Effect |
| --- | --- |
| `supplier_invoice` unique (`counterparty_id`, `document_number`) | a received document is registered once, whichever product registers it |
| `customer_invoice.document_number` unique | our own numbers are unique |
| `supplier_advance_request` unique (`counterparty_id`, `document_number`) | a proforma is registered once |
| `journal_entry` unique (`source_type`, `source_id`) | one entry per source record; posting is idempotent |
| `opportunity_outcome` primary key `opportunity_id` | one outcome per deal |
| `order_response_line` primary key (response, order line) | one changed line per order line per response |
| `payment_allocation`: exactly one target | a match settles one kind of open item |
| `request_fulfilment`: exactly one of order line or stock issue line | one successor per link |
| `supplier_invoice_line`: at most one of receipt line or order line | one predecessor per invoice line |
| `goods_receipt_line`: order line or item | an order-less receipt still names what came in |
| `internal_document_line`: at most one linked record | an accrual relieves one record |
| `bank_line_classification`: category or account; FK (`account_code`, `category_id`) → `account` (`code`, `category_id`) | a classification's account and category must agree |
| `account.category_id` unique, `account.bank_account_id` unique | one account per category (a simplification, see [08](08-falsifiers-and-limits.md)); one ledger account per bank account |
| `plan_line` unique nulls not distinct (version, family, project, milestone, cost center, category, month) | one plan cell per dimension combination |
| check constraints on `category.family`, response codes, `plan_version.kind`, `probability`, `project_progress` (percent or estimate required) | closed vocabularies |

---

## 3. The projection

### 3.1 Column contract of `position_entry`

| Column | Meaning |
| --- | --- |
| `family` | `cost`, `revenue` (net, positive = cost or revenue) or `cash` (gross, signed: + in, − out) |
| `stage` | cost and revenue: `expected`, `committed`, `incurred`, `actual`. Cash: `forecast`, `open`, `settled` |
| `project_id`, `milestone_id`, `cost_center_id` | nullable dimensions; company-level items stay in the projection |
| `category_id` | management category |
| `amount` | rounded to 2 decimals |
| `probability` | 1.00, except expected revenue (the opportunity's probability) |
| `effective_on` | valid time: when it happened |
| `recorded_on` | transaction time: when the system knew it |
| `cash_on` | cash date for `family = cash`; null otherwise |
| `source_type`, `source_id` | the record (or link) that produced the row; a composite id for per-line spreads |

Nobody writes to it. It is the union of eight domain views: `position_crm`, `position_sales`, `position_procurement`, `position_inventory`, `position_people`, `position_treasury`, `position_accounting`, `position_fpa`.

### 3.2 Helper views and their rules

| View | Owner | Rule |
| --- | --- | --- |
| `order_response_terms` | Spend | For each order line and each decisive response (not AB): the accepted quantity and price (RE gives quantity 0; an unlisted line keeps the order terms), the terms it replaced (previous response or the order), and which response is newest. |
| `purchase_order_line_terms` | Spend | The accepted terms of each order line after the latest decisive response, or the order terms when there is none. |
| `supplier_invoice_approval` | Spend | `counts_from` = `recorded_on` when no approval is required; otherwise the `recorded_on` of the first AP or CA response; null (never counts) otherwise. |
| `settlement_line` | Treasury | Spreads each settlement over the lines it settles, proportional to line gross; the rounding remainder goes to the largest line. Targets: invoice lines, payroll cost lines, proformas, order lines (advances, by ordered gross), and for advance applications the invoice lines, the advance's own lines and, for a proforma for an order, the order lines. |
| `payroll_cost_unit` | People | Payroll cost as attributed, in recorded order: each cost line in full at the run's `posted_on`; each allocation as a pair (− on the cost line's project, + on the hours' project) at the later of its own and the run's recorded time. |

### 3.3 What each domain view emits

Sign conventions: cost and revenue positive = more cost or revenue; cash signed. "Terms price" = accepted price from `purchase_order_line_terms`. "Counting" = `counts_from` is not null; rows then use `counts_from` (or later) as `recorded_on`.

**`position_crm`**

| Record | family / stage | Amount | effective_on / recorded_on |
| --- | --- | --- | --- |
| opportunity | revenue / expected | + `amount_net`, with `probability` | opened_on / recorded_on |
| opportunity_outcome (won or lost) | revenue / expected | − `amount_net` | decided_on / recorded_on |

**`position_sales`**

| Record | family / stage | Amount | Dates |
| --- | --- | --- | --- |
| sales_order_line | revenue / committed | + qty × price | ordered_on |
| sales_order_line | cash / forecast | + gross | cash_on = expected_on + terms |
| customer_invoice_line linked to an order line | revenue / committed | − qty × order price, on the order's project and category | issued_on / recorded_on |
| same | cash / forecast | − gross at order price, rounded on cumulative quantity invoiced | cash_on = order line's cash date |
| every customer_invoice_line | family of its category / actual | revenue: + `amount_net`; cost category: − `amount_net` (re-invoiced cost); none for a cash category | issued_on |
| same | cash / open | + gross | cash_on = due_on |
| customer_invoice naming an expected-cash item | cash / forecast | − invoice gross, on the item's dimensions | cash_on = item's cash_on |

**`position_procurement`**

| Record | family / stage | Amount | Dates and conditions |
| --- | --- | --- | --- |
| material_request_line | cost / expected | + qty × estimate | requested_on |
| request_fulfilment by an order line | cost / expected | − linked qty × estimate | ordered_on / later of link and order |
| purchase_order_line | cost / committed | + qty × price | only a cost category and not to_stock |
| purchase_order_line | cash / forecast | − gross | every line, including stock and capital; cash_on = expected_on + terms |
| order_response (per line whose terms change) | cost / committed | + new terms − previous terms | responded_on / response recorded_on; same conditions as the order line |
| same | cash / forecast | previous gross − new gross | order line's cash date |
| goods_receipt_line with an order line, not matched to an invoice | cost / committed − and incurred + | qty × terms price | received_on; cost category, not stock |
| counting supplier_invoice_line on an order line | cost / incurred − (after a receipt) or committed − (services, or invoice dated before the receipt) | qty × terms price, on the order line's project and category | issued_on / counts_from; when the receipt is later than the invoice date, also committed + and incurred − on the receipt's date |
| counting supplier_invoice_line | family of its category / actual | cost: + `amount_net`; revenue: − `amount_net` | issued_on / counts_from; none when for stock (line flag, stock order line, or an Inventory receipt) or a cash category |
| same, linked to an order line | cash / forecast | + gross at terms price, rounded on cumulative quantity billed, on the order line's dimensions | order line's cash date |
| same | cash / open | − gross | cash_on = due_on |
| supplier_advance_request | cash / open | − amount | cash_on = due_on |
| supplier_advance_request for an order | cash / forecast | + amount spread over the order lines by ordered gross (largest remainder) | each order line's cash date |
| counting supplier_invoice naming an expected-cash item | cash / forecast | + invoice gross, on the item's dimensions | item's cash_on |

**`position_inventory`**

| Record | family / stage | Amount | Dates |
| --- | --- | --- | --- |
| request_fulfilment by a stock issue line | cost / expected | − linked qty × estimate | issued_on / later of link and issue |
| stock_issue_line | cost / actual | + qty × unit_cost | issued_on |

Receipts into stock never touch cost stages.

**`position_people`**

| Record | family / stage | Amount | Dates |
| --- | --- | --- | --- |
| timesheet_entry | cost / incurred | + hours × standard rate | worked_on |
| same | cash / forecast | − hours × standard rate | cash_on = 12th of the next month (assumed payday) |
| payroll_allocation | cost / incurred | − allocated hours × standard rate | period end / later of allocation and run posting |
| same | cash / forecast | + same | the hours' cash date |
| payroll_cost_unit (cost line or allocation pair) | cost / actual | + amount | period end / unit's recorded_on |
| same | cash / open | − amount | cash_on = paid_on |

**`position_treasury`**

| Record | family / stage | Amount | Dates |
| --- | --- | --- | --- |
| payment_allocation to an invoice, payroll run or proforma (per settled line) | cash / open and settled | open: reverses the line's share at its due date; settled: + share signed by direction (in for customers, out otherwise) | booked_on / later of match and bank line; settled cash_on = booked_on |
| payroll allocation overlapping a payment | cash / open and settled | moves the overlapping part from the cost line's project to the hours' project | once both are recorded |
| payment_allocation to an order (advance) | cash / forecast + and settled − | the share per order line | forecast at the order line's cash date; settled at booked_on |
| advance_application, once the invoice counts | cash / open + and settled − on the invoice lines | the share per invoice line | applied_on; settled at the advance's bank date |
| same, on the advance's own lines | cash / settled + (and forecast − for an order advance) | hands the advance's settled cash and forecast relief back | as above |
| same, for a proforma for an order | cash / forecast − on the order lines | hands the proforma's forecast relief back | order line's cash date |
| bank_line_classification | cash / settled | + amount | booked_on |
| same, P&L category | family of the category / actual | cost: − amount; revenue: + amount | booked_on |
| same, naming an expected-cash item | cash / forecast | − amount on the item's dimensions | item's cash_on |
| expected_cash | cash / forecast | + amount | effective and recorded on its recorded_on; cash_on |

**`position_accounting`**

| Record | family / stage | Amount | Dates |
| --- | --- | --- | --- |
| internal_document_line, P&L category | family / actual | cost: debit − credit; revenue: credit − debit | issued_on / recorded_on |
| same, linked to an order line or sales order line | family / committed | − the same amount, on the linked record's project and category | as above |
| same, linked to a receipt line | cost / incurred | − the same amount | as above |

A reversal of the internal document restores the relieved amount.

**`position_fpa`**

| Record | family / stage | Amount | Dates |
| --- | --- | --- | --- |
| management_adjustment, P&L category | family / actual | + amount | effective_on / recorded_on |

### 3.4 Key functions

| Function | Formula |
| --- | --- |
| `position_as_of(valid_on, known_on)` | rows of `position_entry` where `effective_on ≤ valid_on` and `recorded_on ≤ known_on` |
| `position_summary(valid_on, known_on)` | per family, project, category: Σ amount per stage; `expected_weighted` = Σ amount × probability over `expected` |
| `project_control(plan_version, valid_on, known_on)` | plan = Σ P&L plan lines of the version, excluding lines with a cost center but no project; positions filtered the same way. consumed: cost = expected + committed + incurred + actual; revenue = committed + incurred + actual. available = plan − consumed. remaining_plan = max(plan − consumed, 0). estimate_at_completion = consumed + remaining_plan |

---

## 4. Posting rules (`post_to_ledger`)

Idempotent: a source already in `journal_entry` is skipped. Every entry carries its source's own `recorded_on`. The expense or revenue account is the one mapped to the line's category.

| Source | Entry date / recorded | Dr | Cr |
| --- | --- | --- | --- |
| supplier_invoice, once it counts | issued_on / counts_from | category account per line (112 when for stock: line flag, stock order line, or Inventory receipt); 343 input VAT; 343 self-assessed VAT | 343 self-assessed VAT; 321 gross |
| stock_issue | issued_on | category account (on the project) | 112 |
| payroll_run | period end / posted_on | category account per cost line (on its project or none) | 331 total employer cost |
| payroll_allocation | period end / later of allocation and run posting | category account on the hours' project | same account on the cost line's project |
| customer_invoice | issued_on | 311 gross | category account per line (on its project); 343 output VAT |
| payment_allocation (one entry each) | booked_on / later of match and bank line | 321 (supplier invoice), 331 (payroll), 314 (order or proforma advance), or the bank account (customer invoice) | 311 (customer invoice) or the bank account |
| bank_line_classification | booked_on | bank account if inflow, otherwise the named account or the category's account | the other side |
| internal_document | issued_on | lines as entered | lines as entered |
| advance_application, once the invoice counts | applied_on | 321 | 314 |

Management adjustments never post.

---

## 5. Invariants asserted

All run on the worked example; scenario probes run in rolled-back transactions. Any failure aborts the run.

**Stage invariants**

- Every cost and revenue stage, per project and category, equals the open remainder of the typed records computed directly (quantity not yet passed on, at the record's own price). Whether an invoice counts is recomputed from invoice responses, not taken from the helper view.
- The generic invariant holds after each probe: payroll without timesheets, late payroll allocation, invoice before receipt, accruals and WIP, capital purchases, a stock purchase registered by Accounting alone, a management adjustment, company-level records, an order invoiced on another category.
- P1 materials stages sum to the most advanced amount of each unit, with no unit counted twice.
- An internal-document line relieves only a commitment of its own family.

**Cash invariants**

- Settled equals the bank movements.
- Open equals unpaid counting documents and payroll: customer invoices − counting supplier invoices − payroll cost − proformas, net of payments and applied advances.
- An independent recomputation from raw records (without the helper views) equals the projection per project and category, and per stage company-wide.
- Reliefs carry the relieved item's cash date: P1 forecast and open net to the expected amount in each month.
- An advance never changes the order's total cash exposure; nothing is left in forecast or open once settled.
- A proforma for an order: the order's cash is counted once at every step; proformas for an order never exceed its gross.
- Expected cash is never relieved beyond its amount; expected cash, invoice and payment count a receipt once.
- Rounding: a payment spread over lines settles to the cent; a fully invoiced order leaves no cent in the forecast.
- Reliefs use the relieved record's project and category: no phantom forecast on another project.
- An advance on a two-project order, applied to one line's invoice: each project pays its own line.

**Fulfilment and settlement guards**

- Requests: fulfilled ≤ requested. Request links ≤ accepted order quantity.
- Orders: received ≤ accepted; billed ≤ accepted; unmatched receipts + invoices without receipt ≤ accepted. A receipt matched to an invoice line matches a counting invoice of the same order line, up to its quantity. Per receipt: billed ≤ received.
- Supplier invoices: payments + applied advances ≤ gross. Customer invoices: payments ≤ gross.
- Hours allocated ≤ hours worked; invoiced ≤ sales order; payroll paid ≤ payroll owed; proforma paid ≤ proforma amount (each guard is also shown to catch its violating case).
- Order responses precede any receipt or invoice on the order.
- Advance applications never exceed the advance and apply only to counting invoices. Payments only settle counting invoices.
- Rejection is terminal, only before acceptance, only under approval. A rejected invoice has no positions and no ledger entry.
- Self-billed invoices have a valid self-billing agreement with that supplier.
- The same supplier document number is refused a second time.

**Reconciliation and ledger**

- Management actual equals the ledger per project (or none), category and month; management-only adjustments show as named reconciling items with their reason codes.
- The ledger balances, and every journal entry balances. Bank account 221 = 551,640; VAT 343 = 73,710 (reverse charge nets to zero).
- Every bank line is fully matched or classified; each bank account's ledger account moves exactly with its bank lines, also after a late allocation.
- A bank line classified to a P&L account carries that account's category; a mismatched account and category are refused.
- Every journal entry points to an existing source record; the opening balance is an internal document; internal-document lines carry their account's category; no internal-document line duplicates payroll cost for a month with a payroll run.
- Payroll cost lines sum to the employer cost; allocations never exceed their cost line.
- Management adjustments and P&L plan lines use cost or revenue categories. A milestone tag belongs to the line's project.
- Capital purchases are never cost; they post to the asset account and are open payables or forecast cash.

**Bitemporal and as-known reads**

- 31 March as reported vs as known on 31 May differ exactly by the late invoice and March payroll.
- PO5 committed is 50,000 as known on 20 April and 42,000 from 21 April. A second supplier response does not rewrite what was known before it.
- VB3 counts only from its acceptance on 12 April.
- A late payment match leaves an earlier read unchanged, counts from its own date, and reaches the ledger on its own date.
- A late payroll allocation leaves earlier reads unchanged; the posted payroll run entry is unchanged; the allocation is its own ledger entry on its own date.
- An invoice dated before its receipt never shows negative incurred or a double count.
- A timesheet reversal changes the as-known read from its recorded date.

**Backward trace**

- P1's milestone-1 revenue journal line (CI1, account 602) traces to one order, SO1, and to CRM opportunity OPP1.
