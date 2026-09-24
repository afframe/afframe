# Mutations of the finance model prototype

Each mutation changes one rule in a scratch copy of the prototype and runs the full pipeline. The checks must fail. A to I re-apply report section 8.12 against the current code; J to N are new, one per HIGH fix (J to M) plus the EVIDENCE-1 double count (N); O to Q revert the MONEY-4, MONEY-3 and MONEY-1 fixes to show their regression assertions fail without them. The rounding probe listed in 8.12 is a regression probe in `checks.sql`, not a mutation.

Run one mutation from a scratch copy (PostgreSQL 18 on port 55433, database `demo`):

```sh
mkdir /tmp/mutation && cp docs/research/finance-model-prototype/*.sql /tmp/mutation/
cd /tmp/mutation && patch -p1 < mutation.diff
cat model.sql accounting.sql example.sql checks.sql | PGPASSWORD=demo psql -h localhost -p 55433 -U postgres -d demo -v ON_ERROR_STOP=1 -q
```

Save the diff block of the mutation as `mutation.diff` first. Every run below ended with psql exit status 3 and the first error line shown. The unmutated run passes 146 assertions.

| Mutation | Source | First failure |
| --- | --- | --- |
| A | 8.12 A | `FAILED every cost and revenue stage equals the open remainder of typed records: got 1000.000000, expected 0` |
| B | 8.12 B | `FAILED every cost and revenue stage equals the open remainder of typed records: got 10000.000000, expected 0` |
| C | 8.12 C, stated precisely | `FAILED every cost and revenue stage equals the open remainder of typed records: got 80000.000000, expected 0` |
| D | 8.12 D | `FAILED EVIDENCE-1: company cash forecast, open and settled equal the records: got 154880.0000, expected 0` |
| E | 8.12 E | `FAILED every cost and revenue stage equals the open remainder of typed records: got 4000.000000, expected 0` |
| F | 8.12 F | `FAILED EVIDENCE-1: cash per project and category equals what the records finally owe or bring: got 25410.0000, expected 0` |
| G | 8.12 G | `division by zero` |
| H | 8.12 H | `FAILED advance application to an unapproved invoice has no effect yet: got 4, expected 0` |
| I | 8.12 I | `FAILED the same supplier document was registered twice` |
| J | new, ARCH-1 | `FAILED ARCH-1: payroll without timesheets posts a balanced entry: got -50000.00, expected 0` |
| K | new, ARCH-2 | `FAILED ARCH-2: settled equals bank with document-less lines: got 51640.00, expected 51490.00` |
| L | new, MONEY-2 | `FAILED MONEY-2: a late allocation reaches the ledger bank account: got 50000.00, expected 0` |
| M | new, MONEY-5 | `FAILED MONEY-5: invoice before receipt, committed relieved once: got -10000.00, expected 0` |
| N | new, EVIDENCE-1 probe | `FAILED EVIDENCE-1: cash per project and category equals what the records finally owe or bring: got 67760.0000, expected 0` |
| O | revert, MONEY-4 | `FAILED MONEY-4: no phantom forecast on any project for an order invoiced to a project: got 2420.00, expected 0` |
| P | revert, MONEY-3 | `FAILED MONEY-3: P1 pays its own line: got -605.00, expected -1210` |
| Q | revert, MONEY-1 | `FAILED MONEY-1: 22 Apr as known 22 Apr keeps the first response (committed): got 50000.00, expected 42000` |

## A: 8.12 A

The invoice relieves `incurred` at invoice value instead of the accepted order price.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -608,7 +608,7 @@
 -- actual at invoice price.
 select 'cost', case when sinl.goods_receipt_line_id is null then 'committed' else 'incurred' end,
        pol.project_id, null, pol.category_id,
-       -sinl.quantity * t.unit_price, 1.00,
+       -sinl.amount_net, 1.00,
        sinv.issued_on, a.counts_from, null,
        'supplier_invoice_line', sinl.id
 from supplier_invoice_line sinl
```

Result: `FAILED every cost and revenue stage equals the open remainder of typed records: got 1000.000000, expected 0`

## B: 8.12 B

An order relieves the request at the order price instead of the request estimate.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -542,7 +542,7 @@
 union all
 -- Request fulfilled by an order: relieve expected at the request's estimate.
 select 'cost', 'expected', mr.project_id, null, mrl.category_id,
-       -rf.quantity * mrl.estimated_unit_price, 1.00,
+       -rf.quantity * pol.unit_price, 1.00,
        po.ordered_on, po.recorded_on, null,
        'request_fulfilment', rf.id
 from request_fulfilment rf
```

Result: `FAILED every cost and revenue stage equals the open remainder of typed records: got 10000.000000, expected 0`

## C: 8.12 C, stated precisely

The payroll allocation's relief of the hours (incurred and wage forecast) is emitted once per payment allocation of its payroll run instead of once. March payroll is paid in two transfers, so March hours are relieved twice.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -730,6 +730,7 @@
 join payroll_line pl on pl.id = pc.payroll_line_id
 join payroll_run pr on pr.id = pl.payroll_run_id
 join timesheet_entry te on te.id = pa.timesheet_entry_id
+join payment_allocation pay on pay.payroll_run_id = pr.id
 cross join lateral (
     select hourly_rate from employee_cost_rate
     where employee_id = te.employee_id and valid_from <= te.worked_on
```

Result: `FAILED every cost and revenue stage equals the open remainder of typed records: got 80000.000000, expected 0`

## D: 8.12 D

The approval gate is removed: every supplier invoice counts from registration.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -523,10 +523,7 @@
 -- rejected invoice never counts. After acceptance, disagreement needs a credit note.
 create view supplier_invoice_approval as
 select si.id as supplier_invoice_id,
-       case when not si.requires_approval then si.recorded_on
-            else (select min(r.recorded_on) from invoice_response r
-                  where r.supplier_invoice_id = si.id and r.response_code in ('AP', 'CA'))
-       end as counts_from
+       si.recorded_on as counts_from
 from supplier_invoice si;
 
 -- Procurement: requests, orders, order responses, receipts, supplier invoices, proformas.
```

Result: `FAILED EVIDENCE-1: company cash forecast, open and settled equal the records: got 154880.0000, expected 0`

## E: 8.12 E

A receipt ignores the accepted order price and moves committed to incurred at the ordered price.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -592,7 +592,7 @@
 -- already invoiced (matched to the invoice line) moves nothing: the invoice relieved
 -- the commitment first.
 select 'cost', v.stage, pol.project_id, null, pol.category_id,
-       v.sign * grl.quantity * t.unit_price, 1.00,
+       v.sign * grl.quantity * pol.unit_price, 1.00,
        gr.received_on, gr.recorded_on, null,
        'goods_receipt_line', grl.id
 from goods_receipt_line grl
```

Result: `FAILED every cost and revenue stage equals the open remainder of typed records: got 4000.000000, expected 0`

## F: 8.12 F

An advance application keeps the order advance's forecast relief (no hand-back).

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -959,7 +959,7 @@
     where s.line_type = 'supplier_advance_request' and r.id = s.line_id
 ) x on true
 cross join lateral (values ('forecast'), ('settled')) v(stage)
-where v.stage = 'settled' or x.forecast_on is not null
+where v.stage = 'settled'
 
 union all
 -- Classified bank line with no document: settled cash; actual cost or revenue when
```

Result: `FAILED EVIDENCE-1: cash per project and category equals what the records finally owe or bring: got 25410.0000, expected 0`

## G: 8.12 G

An order advance is spread over the order lines by accepted instead of ordered value.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -838,9 +838,10 @@
     -- Advances are spread over the order lines by ordered value (never zero, even if
     -- the supplier later rejects the order).
     select 'payment_allocation', pa.id, pa.amount, 'purchase_order_line', pol.id,
-           round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
+           round(t.quantity * t.unit_price * (1 + pol.vat_rate), 2)
     from payment_allocation pa
     join purchase_order_line pol on pol.purchase_order_id = pa.purchase_order_id
+    join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
     union all
     -- An advance application reduces the invoice's payable (over its lines) and moves
     -- the advance off its own lines (the order lines or the proforma, spread as the
```

Result: `division by zero`

## H: 8.12 H

An advance application ignores the approval gate of the invoice it is applied to.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -929,7 +929,7 @@
        'advance_application', aa.id || ':' || l.id
 from settlement_line s
 join advance_application aa on s.settlement_type = 'advance_application_open' and aa.id = s.settlement_id
-join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
+left join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id
 join payment_allocation adv on adv.id = aa.advance_allocation_id
 join bank_transaction abt on abt.id = adv.bank_transaction_id
 join supplier_invoice_line l on l.id = s.line_id
@@ -946,7 +946,7 @@
        'advance_application', aa.id || ':' || s.line_id
 from settlement_line s
 join advance_application aa on s.settlement_type = 'advance_application_advance' and aa.id = s.settlement_id
-join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
+left join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id
 join payment_allocation adv on adv.id = aa.advance_allocation_id
 join bank_transaction abt on abt.id = adv.bank_transaction_id
 join lateral (
```

Result: `FAILED advance application to an unapproved invoice has no effect yet: got 4, expected 0`

## I: 8.12 I

The unique supplier document number on `supplier_invoice` is dropped.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -208,8 +208,7 @@
     recorded_on date not null,
     requires_approval boolean not null default false,
     self_billing_agreement_id text references agreement,  -- set when we issued it on the supplier's behalf
-    document_number text not null,          -- the supplier's number (EN 16931 BT-1)
-    unique (counterparty_id, document_number)  -- each received document is registered once
+    document_number text not null           -- the supplier's number (EN 16931 BT-1)
 );
 
 create table supplier_invoice_line (
```

Result: `FAILED the same supplier document was registered twice`

## J: new, ARCH-1

The ledger debits payroll cost only through timesheet allocations (the old rule), so cost lines without hours never post.

```diff
--- orig/accounting.sql
+++ mut/accounting.sql
@@ -77,7 +77,7 @@
     select ne.id, a.code, u.project_id, u.amount, 0
     from new_entry ne
     join payroll_line pl on pl.payroll_run_id = ne.source_id
-    join payroll_cost_unit u on u.payroll_line_id = pl.id and u.amount <> 0
+    join payroll_cost_unit u on u.payroll_line_id = pl.id and u.amount <> 0 and u.unit_type = 'payroll_allocation'
     join account a on a.category_id = u.category_id
     union all
     select ne.id, '331', null, 0, sum(pl.employer_cost)
```

Result: `FAILED ARCH-1: payroll without timesheets posts a balanced entry: got -50000.00, expected 0`

## K: new, ARCH-2

A classified bank line's settled cash is dropped from the projection (the old behaviour for document-less lines).

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -970,7 +970,7 @@
        case v.stage when 'forecast' then e.cost_center_id else c.cost_center_id end,
        case v.stage when 'forecast' then e.category_id else c.category_id end,
        case v.stage
-           when 'settled' then c.amount
+           when 'settled' then 0
            when 'forecast' then -c.amount
            else case cat.family when 'cost' then -c.amount else c.amount end
        end, 1.00,
```

Result: `FAILED ARCH-2: settled equals bank with document-less lines: got 51640.00, expected 51490.00`

## L: new, MONEY-2

Payment allocations are posted only while their bank line has no posted allocation yet (the old once-per-bank-transaction keying).

```diff
--- orig/accounting.sql
+++ mut/accounting.sql
@@ -118,6 +118,8 @@
         select 'payment_allocation:' || pa.id, bt.booked_on, bt.recorded_on, 'payment_allocation', pa.id
         from payment_allocation pa
         join bank_transaction bt on bt.id = pa.bank_transaction_id
+        where not exists (select 1 from journal_entry je join payment_allocation p2 on p2.id = je.source_id
+                          where je.source_type = 'payment_allocation' and p2.bank_transaction_id = pa.bank_transaction_id)
         on conflict (source_type, source_id) do nothing
         returning id, source_id
     )
```

Result: `FAILED MONEY-2: a late allocation reaches the ledger bank account: got 50000.00, expected 0`

## M: new, MONEY-5

A receipt matched to an earlier invoice line still moves committed to incurred.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -600,7 +600,7 @@
 join purchase_order_line pol on pol.id = grl.purchase_order_line_id
 join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
 cross join lateral (values ('committed', -1), ('incurred', 1)) v(stage, sign)
-where not pol.to_stock and grl.supplier_invoice_line_id is null
+where not pol.to_stock
 
 union all
 -- Supplier invoice, once it counts: relieve incurred (after a receipt) or committed
```

Result: `FAILED MONEY-5: invoice before receipt, committed relieved once: got -10000.00, expected 0`

## N: new, EVIDENCE-1 probe

The review's cash double count: invoices for stock orders stop relieving the order's cash forecast. Before this change every assertion passed.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -654,7 +654,7 @@
 left join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
 left join purchase_order po on po.id = pol.purchase_order_id
 cross join lateral (values ('forecast'), ('open')) v(stage)
-where v.stage = 'open' or pol.id is not null
+where v.stage = 'open' or (pol.id is not null and not pol.to_stock)
 
 union all
 -- Supplier advance request (proforma): an open payable, no cost.
```

Result: `FAILED EVIDENCE-1: cash per project and category equals what the records finally owe or bring: got 67760.0000, expected 0`

## O: revert, MONEY-4

Reliefs take project and category from the successor again (supplier invoice cash forecast relief, and sales order relief).

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -637,8 +637,8 @@
 -- Cash: a counting supplier invoice relieves the order forecast (on the order line's
 -- project and category) and opens a payable (on its own).
 select 'cash', v.stage,
-       case v.stage when 'forecast' then pol.project_id else sinl.project_id end, null,
-       case v.stage when 'forecast' then pol.category_id else sinl.category_id end,
+       sinl.project_id, null,
+       sinl.category_id,
        case v.stage
            when 'forecast' then round(sinl.quantity * t.unit_price * (1 + pol.vat_rate), 2)
            else -(sinl.amount_net + sinl.vat_amount)
@@ -786,7 +786,7 @@
 union all
 -- Customer invoice linked to an order line: relieve committed revenue and the
 -- cash forecast at order price, on the order's project and category.
-select v.family, v.stage, so.project_id, null, sol.category_id,
+select v.family, v.stage, cil.project_id, null, cil.category_id,
        case v.family
            when 'revenue' then -cil.quantity * sol.unit_price
            else -round(cil.quantity * sol.unit_price * (1 + sol.vat_rate), 2)
```

Result: `FAILED MONEY-4: no phantom forecast on any project for an order invoiced to a project: got 2420.00, expected 0`

## P: revert, MONEY-3

An advance application no longer moves the advance's settled cash onto the invoice's lines.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -934,7 +934,7 @@
 join bank_transaction abt on abt.id = adv.bank_transaction_id
 join supplier_invoice_line l on l.id = s.line_id
 join supplier_invoice si on si.id = l.supplier_invoice_id
-cross join lateral (values ('open'), ('settled')) v(stage)
+cross join lateral (values ('open')) v(stage)
 
 union all
 -- ...off the advance's own lines. For an order advance, the advance's relief of the
@@ -959,7 +959,7 @@
     where s.line_type = 'supplier_advance_request' and r.id = s.line_id
 ) x on true
 cross join lateral (values ('forecast'), ('settled')) v(stage)
-where v.stage = 'settled' or x.forecast_on is not null
+where v.stage = 'forecast' and x.forecast_on is not null
 
 union all
 -- Classified bank line with no document: settled cash; actual cost or revenue when
```

Result: `FAILED MONEY-3: P1 pays its own line: got -605.00, expected -1210`

## Q: revert, MONEY-1

Only the latest supplier response revalues the order line, from the ordered terms.

```diff
--- orig/model.sql
+++ mut/model.sql
@@ -584,7 +584,7 @@
 join purchase_order po on po.id = pol.purchase_order_id
 join order_response_terms t on t.purchase_order_line_id = pol.id
 cross join lateral (values ('cost', 'committed'), ('cash', 'forecast')) v(family, stage)
-where (t.quantity, t.unit_price) is distinct from (t.previous_quantity, t.previous_unit_price)
+where t.newest = 1 and (t.quantity, t.unit_price) is distinct from (t.previous_quantity, t.previous_unit_price)
   and (v.family = 'cash' or not pol.to_stock)
 
 union all
```

Result: `FAILED MONEY-1: 22 Apr as known 22 Apr keeps the first response (committed): got 50000.00, expected 42000`
