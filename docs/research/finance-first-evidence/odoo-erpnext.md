# Odoo 18 / Frappe-ERPNext: analytic lines, timesheets, project profitability, budgets, payments, stock valuation

Method: cloned `odoo/odoo` branch `18.0` and `frappe/erpnext` branch `version-15` with sparse checkout into `/tmp/odoo` and `/tmp/erpnext`; grepped source; fetched two brief URLs plus supporting Odoo doc pages. No Russian sources used. Repo HEAD used: `origin/18.0` commit `2b2db7047fb7d51a720de75b236a9690044c7966` (odoo); erpnext version-15 default branch tip at fetch time.

## 0. Brief URLs summarized

**Odoo project profitability doc** (`https://www.odoo.com/documentation/18.0/applications/services/project/project_management/project_profitability.html`, vendor-documented):
Profitability = Revenues (timesheets by invoicing policy, materials from SOs, customer invoices, subscriptions, down payments, reinvoiced expenses) vs Costs (employee timesheet cost, purchase orders, product costs from stock moves, submitted/approved expenses, vendor bills, manufacturing orders, other analytic-account costs). Three columns: Expected / To invoice-To bill / Invoiced-Billed. Records must be linked to the project's analytic account to appear; a timesheet line can appear in both revenue (customer rate) and cost (wage) sides. No budget discussion on this page.

**ERPNext purchase-cycle-ledger-impact doc** (`https://docs.frappe.io/erpnext/purchase-cycle-ledger-impact`, vendor-documented):
Purchase Receipt: Debit Stock In Hand / Credit Stock Received But Not Billed (SRBNB). Purchase Invoice (against the receipt): Debit SRBNB / Credit Accounts Payable. SRBNB is described as a clearing account letting receipt and invoice post on different dates without losing the receipt-created liability; it nets to zero once both documents are submitted.

---

## Odoo 18

### 1. Analytic lines are the shared record; timesheets ARE analytic lines
Status: CONFIRMED. Label: verified-in-public-source.
File: `/tmp/odoo/addons/hr_timesheet/models/hr_timesheet.py:14-15`
```python
class AccountAnalyticLine(models.Model):
    _inherit = 'account.analytic.line'
```
Base model at `/tmp/odoo/addons/analytic/models/analytic_line.py:161-162` (`_name = 'account.analytic.line'`). Amount formula, same file lines 397-399:
```python
cost = timesheet._hourly_cost()
amount = -timesheet.unit_amount * cost
```
Mechanism: a timesheet row is literally an `account.analytic.line` record (no separate timesheet table); `amount` is negative (a cost) = -(hours × employee hourly cost), confirming the claim exactly.

### 2. Timesheet cost uses employee hourly_cost; no automatic true-up vs payroll actual
Status: PARTLY (cost source confirmed; payroll true-up NOT FOUND in public code — Payroll is Enterprise so absence of code is not conclusive).
File: `/tmp/odoo/addons/hr_timesheet/models/hr_timesheet.py:428-430`
```python
def _hourly_cost(self):
    self.ensure_one()
    return self.employee_id.hourly_cost or 0.0
```
No reference to `hr.payroll`, `hr.payslip`, or payroll cost anywhere in the community `hr_timesheet` module (grep found none). Since `hr_payroll` is Enterprise-only and not in this repo, we cannot confirm or refute whether Enterprise payroll ever writes back to `account.analytic.line.amount`; treat as NOT FOUND rather than assumed absent.

### 3. Project profitability sections and per-module `_get_profitability_items` overrides
Status: CONFIRMED. Label: verified-in-public-source.
Base hook: `/tmp/odoo/addons/project/models/project_project.py:899` `def _get_profitability_items(self, with_action=True)`.
Overrides found (grep across sparse checkout):
- `/tmp/odoo/addons/sale_timesheet/models/project_project.py:408` `_get_profitability_items_from_aal` and `:528-530` `_get_profitability_items` calling `super()` then adding timesheet/AAL-based revenue+cost items.
- `/tmp/odoo/addons/sale_project/models/project_project.py:759-778`:
```python
def _get_profitability_items(self, with_action=True):
    profitability_items = super()._get_profitability_items(with_action)
    ...
    self._add_invoice_items(domain, profitability_items, with_action=with_action)
    self._add_purchase_items(profitability_items, with_action=with_action)
    return profitability_items
```
`_add_purchase_items` (same file, feeding vendor-bill stat button `action_open_project_vendor_bills` at line 861) is how purchase orders / vendor bills enter the "costs" side. No dedicated override was found directly inside `addons/purchase` or `addons/hr_expense` in this checkout — they are wired through `sale_project`'s `_add_purchase_items`/`_add_invoice_items` helpers rather than separate `_inherit` classes in those addons (contradicts the assumption that purchase/hr_expense each carry their own override; mechanism is centralized in `sale_project`). Labels/sequences for "Materials", "Other Services", "Cost of Goods Sold" defined at `sale_project/models/project_project.py:509-524`.

### 4. Budgets: planned/committed/achieved
Status: PARTLY (docs CONFIRMED; code NOT FOUND — module is Enterprise-only, not in community repo).
Doc: `https://www.odoo.com/documentation/18.0/applications/finance/accounting/reporting/budget.html` (vendor-documented):
> "The Achieved amount reflects the current result according to the items of confirmed journal entries for the associated analytic account."
> "the Committed amount displays the full value of the Achieved amount, plus any confirmed purchase orders that have not yet been billed."
Mechanism per docs: committed = achieved (posted journal entries) + confirmed-but-unbilled PO value; once a PO is billed, its value moves from "unbilled PO" into "achieved" (confirmed journal entry), so it is not counted twice — but this de-duplication logic could not be verified in source because `account_budget`/budget models are not present in `odoo/odoo` (grepped whole `addons/` tree via `git ls-tree` on `18.0`: no `budget` directory), confirmed also via GitHub directory listing fetch showing no `account_budget` folder. Community Odoo 18 does not ship budgeting; it is an Enterprise app not in this public repo, so the double-counting mechanism is NOT FOUND in accessible source, only asserted in docs.

### 5. Analytic distribution (JSON) + multiple analytic plans
Status: CONFIRMED. Label: verified-in-public-source.
File: `/tmp/odoo/addons/account/models/account_move_line.py:396-398`
```python
analytic_distribution = fields.Json(
    inverse="_inverse_analytic_distribution",
)
```
Multiple plans model exists at `/tmp/odoo/addons/analytic/models/analytic_plan.py` (`account.analytic.plan`), referenced by `_get_all_plans()` used in `hr_timesheet.py:388-390` when validating a timesheet's analytic account belongs to the "project plan". Confirms JSON distribution field plus a distinct analytic-plan model supporting multiple concurrent plans.

### 6. Corrections: reversal / credit note / reset-to-draft, blocked by lock dates or hash
Status: CONFIRMED. Label: verified-in-public-source.
File: `/tmp/odoo/addons/account/models/account_move.py:5605-5619` (`button_draft`):
```python
def button_draft(self):
    if any(move.state not in ('cancel', 'posted') for move in self):
        raise UserError(...)
    self._check_draftable()
    self.line_ids.analytic_line_ids.with_context(skip_analytic_sync=True).unlink()
    ...
    self.state = 'draft'
```
Reversal entry point: `_reverse_moves` at line 5030. Lock-date enforcement: `_check_fiscal_lock_dates` (line 2540) called from write/post paths; inalterable-hash integrity fields tracked at line 329 (`inalterable_hash`) and enforced at line 3426-3427 (`violated_fields = set(vals).intersection(move._get_integrity_hash_fields() + ['inalterable_hash']); if move.inalterable_hash and violated_fields: ...`). Mechanism: reset-to-draft is allowed by default (removes analytic lines, drops reconciliation) but is blocked once fiscal lock dates apply or once a move is hash-secured (`inalterable_hash` set, e.g. after official sequencing) — matching the claim precisely.

### 7. Stock valuation layers: receipt = asset, cost recognized on delivery
Status: CONFIRMED (model structure); Label: verified-in-public-source.
File: `/tmp/odoo/addons/stock_account/models/stock_valuation_layer.py:12-39` — `stock.valuation.layer` has `quantity`, `unit_cost`, `value`, `remaining_qty`, `remaining_value`, links to `stock_move_id`, `account_move_id` (journal entry), `account_move_line_id`. `remaining_qty`/`remaining_value` fields are exactly the mechanism for tracking un-consumed asset value that gets drawn down as stock is delivered/consumed (FIFO/AVCO layering). Full delivery-side cost recognition logic lives in `stock_account` valuation methods not fully pulled in this sparse checkout pass (time-boxed); structural claim confirmed, delivery-cost-recognition code path not individually quoted — treat that finer detail as PARTLY.

---

## ERPNext (version-15)

### 8. Budget check aggregates requested (MR) + ordered (PO) + actual, avoiding double count
Status: CONFIRMED. Label: verified-in-public-source.
File: `/tmp/erpnext/erpnext/accounts/doctype/budget/budget.py`
Requested (MR not yet ordered), lines 399-403:
```sql
select ifnull((sum(child.stock_qty - child.ordered_qty) * rate), 0) as amount
from `tabMaterial Request Item` child, `tabMaterial Request` parent where parent.name = child.parent and
child.item_code = %s and parent.docstatus = 1 and child.stock_qty > child.ordered_qty and {} and
parent.material_request_type = 'Purchase' and parent.status != 'Stopped'
```
Ordered (PO not yet billed), lines 411-417:
```sql
select ifnull(sum(child.amount - child.billed_amt), 0) as amount
from `tabPurchase Order Item` child, `tabPurchase Order` parent where
parent.name = child.parent and child.item_code = %s and parent.docstatus = 1 and child.amount > child.billed_amt
and parent.status != 'Closed' and {condition}
```
Aggregation for the check, `compare_expense_with_budget` (lines 263-269): `total_expense = args.actual_expense + amount` where `amount` is `requested_amount + ordered_amount` for a Material Request check or `ordered_amount` alone for a PO check. Actions Stop/Warn/Ignore read from `action_if_annual_budget_exceeded[_on_mr|_on_po]` fields (lines 34-39). Mechanism confirming no double counting: `stock_qty - child.ordered_qty` subtracts the portion of an MR already converted into a PO, and `child.amount - child.billed_amt` subtracts the portion of a PO already invoiced — so as a requisition/order progresses further downstream, its earlier-stage "requested"/"ordered" contribution shrinks to exactly offset the newly recognized later-stage amount, while `actual_expense` (from GL) captures billed amounts once posted.

### 9. GL Entry / Stock Ledger Entry / Payment Ledger Entry and allocation
Status: CONFIRMED. Label: verified-in-public-source.
Payment Ledger Entry fields, `/tmp/erpnext/erpnext/accounts/doctype/payment_ledger_entry/payment_ledger_entry.py` (auto-generated type block):
```python
against_voucher_no: DF.DynamicLink | None
against_voucher_type: DF.Link | None
amount: DF.Currency
amount_in_account_currency: DF.Currency
delinked: DF.Check
voucher_no: DF.DynamicLink | None
voucher_type: DF.Link | None
```
Payment Entry allocation via child table `references` with `allocated_amount`, validated in `/tmp/erpnext/erpnext/accounts/doctype/payment_entry/payment_entry.py:284-300` (`validate_allocated_amount`, comparing `d.allocated_amount` to `d.outstanding_amount` per reference row) — one Payment Entry can carry many `references` rows, each pointing at a different invoice, splitting the payment across them.
Outstanding computation: `/tmp/erpnext/erpnext/accounts/utils.py:1949-1975` `update_voucher_outstanding()` queries `Payment Ledger Entry` via `QueryPaymentLedger().get_voucher_outstandings(...)` and writes the result back to `ref_doc.outstanding_amount`. Mechanism: outstanding is not stored/derived from GL Entry directly but summed from Payment Ledger Entry rows (invoice amount rows plus negative payment-allocation rows keyed by `against_voucher_*`); `delinked` marks PLE rows that have been unlinked (e.g. after unreconciling) so they no longer count.

### 10. Perpetual inventory: PR debits stock asset / credits SRBNB; PI clears it
Status: CONFIRMED. Label: verified-in-public-source.
File: `/tmp/erpnext/erpnext/stock/doctype/purchase_receipt/purchase_receipt.py:493-521` (`make_stock_received_but_not_billed_entry`):
```python
account = (
    warehouse_account[item.from_warehouse]["account"] if item.from_warehouse else stock_asset_rbnb
)
...
self.add_gl_entry(
    gl_entries=gl_entries,
    account=account,
    ...
    debit=-1 * flt(outgoing_amount, ...),
    credit=0.0,
    ...
)
```
Provisional/SRBNB account resolved at line 301 `self.get_company_default("default_provisional_account")` and line 715/774 `self.get_company_default("stock_received_but_not_billed")`. Cancellation on the Purchase Invoice side flags the linked receipt's GL rows `is_cancelled = 1` (see claim 12) rather than reversing them independently, tying the two documents together.

### 11. Accounting Dimensions
Status: CONFIRMED. Label: verified-in-public-source.
File: `/tmp/erpnext/erpnext/accounts/doctype/accounting_dimension/accounting_dimension.py:87-90`
```python
make_dimension_in_accounting_doctypes(doc=self)
```
`AccountingDimension` doctype (fields `document_type`, `fieldname`, `label`, `dimension_defaults` table) creates a custom field via `create_custom_field` (imported at top) on every accounting-relevant doctype, and `get_accounting_dimensions()` (line 245) is consumed elsewhere (e.g. `budget.py` imports `get_accounting_dimensions` to extend the default `project`/`cost_center` budget-against dimensions with custom ones).

### 12. Corrections: cancel = reversal GL entries + `is_cancelled`; amend = new doc
Status: CONFIRMED. Label: verified-in-public-source.
Reversal: `/tmp/erpnext/erpnext/accounts/general_ledger.py:664-698` `make_reverse_gl_entries()`:
```python
"""
Get original gl entries of the voucher
and make reverse gl entries by swapping debit and credit
"""
...
.where(gl_entry.is_cancelled == 0)
...
create_payment_ledger_entry(gl_entries, cancel=1, ...)
```
Flag-based cross-document cancellation: `/tmp/erpnext/erpnext/accounts/doctype/purchase_invoice/purchase_invoice.py:916-925` sets `gle.is_cancelled = 1` on the related Purchase Receipt's GL rows when the invoice is cancelled. Amendment: `amended_from: DF.Link | None` field present on Purchase Invoice (line 88) and Budget (line 42), the standard Frappe amend-as-new-document pattern (new doc, `-1` suffix naming, linked via `amended_from`) rather than in-place edits of submitted docs.

### 13. Timesheet costing rate vs Salary Slip true-up
Status: NOT FOUND (in erpnext core scope). Label: n/a.
`/tmp/erpnext/erpnext/projects/doctype/timesheet/timesheet.py` defines `costing_rate`/`billing_rate`/`costing_amount` (lines 296-310) sourced from an "Activity Cost"/employee rate lookup, but no reference to `Salary Slip` appears in this file or elsewhere in the sparse-checked `erpnext` tree. Salary-Slip-from-Timesheet functionality lives in the separate `frappe/hrms` repository, which was out of scope for this pass — cannot confirm or refute a project-cost true-up from actual payroll; mark NOT FOUND rather than assume either way.

---

## Extra findings (up to 5)

1. **Odoo timesheet↔analytic sync guard**: `button_draft` explicitly deletes `analytic_line_ids` with `skip_analytic_sync=True` context (`account_move.py:5613`), showing Odoo treats analytic lines as a derived/regenerated artifact of posted moves, not an independent ledger — resetting to draft destroys and (on repost) regenerates them.
2. **Odoo budget module absence**: confirmed via `git ls-tree -d --name-only origin/18.0 -- addons/` (empty budget match) and a GitHub directory-listing fetch that budgeting in Odoo 18 Community has no visible module; the documented feature is Enterprise (`account_budget` is not in `odoo/odoo`, only in the private `odoo/enterprise` repo, which is inaccessible here).
3. **ERPNext PLE `delinked` field**: (`payment_ledger_entry.py`) provides an explicit "soft-unlink" flag for reconciliation reversal, separate from GL Entry's `is_cancelled`, i.e. ERPNext keeps two independent correction mechanisms — one for the accounting ledger (GL Entry reversal/cancel) and one for the payment-matching ledger (PLE delink).
4. **ERPNext exception-approver override**: `compare_expense_with_budget` (`budget.py:283-286`) downgrades a "Stop" action to "Warn" if the acting user holds `Company.exception_budget_approver_role`, i.e. budget enforcement is a soft/hard gate configurable per company with an approver bypass — relevant for a "requested/committed/actual" model that needs override traceability.
5. **Odoo `_split_amount_fname` override**: `hr_timesheet.py:406-409` returns `'unit_amount'` instead of `'amount'` for split/allocation operations when a timesheet has a project, signalling that downstream code treats quantity (hours) as the canonical split unit and derives money, reinforcing that `account.analytic.line.amount` is a computed/dependent field, not an independently editable source of truth.

## File paths referenced
- Odoo clone: `/tmp/odoo` (sparse: `addons/{analytic,hr_timesheet,project,sale_project,sale_timesheet,purchase,hr_expense,stock_account,account}`).
- ERPNext clone: `/tmp/erpnext` (sparse: `erpnext/accounts/{doctype/budget,doctype/payment_ledger_entry,doctype/payment_entry,doctype/gl_entry,doctype/purchase_invoice,doctype/accounting_dimension,general_ledger.py,utils.py}`, `erpnext/controllers/accounts_controller.py`, `erpnext/stock/doctype/purchase_receipt`, `erpnext/projects/doctype/timesheet`).
- This report: `/home/vercel-sandbox/afframe/.context/research/odoo-erpnext.md`
