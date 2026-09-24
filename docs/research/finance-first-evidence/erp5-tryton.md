# ERP5 & Tryton: movements, plans vs actuals, analytics, budgets, corrections

Sources fetched: erp5.com/basic/developer, nexedi.com technical note, en.wikibooks.org/wiki/ERP5_Handbook/Magic_Simulations,
docs.tryton.org/latest/, shallow clones of lab.nexedi.com/nexedi/erp5.git (`/tmp/erp5-code`, treeless clone, 1.1G) and
github.com/tryton/tryton.git (`/tmp/tryton-mono`, depth 1, 121M). IEEE paper (Smets-Solanes & Carvalho 2003) is paywalled
(IEEE Xplore / ACM DL); ResearchGate returned HTTP 403; no open-access copy found in the time budget — claims sourced from it
are marked NOT FOUND for verbatim text, though the citation itself is confirmed to exist.

## ERP5

### 1. Unified Business Model (UBM): Resource, Node, Path, Movement, Item
**Status:** CONFIRMED
**Label:** vendor-documented
**URL:** https://www.erp5.com/basic/developer
**Quote:**
> "A resource describes a resource in a business process (e.g. the skill of a person, a currency, a raw material, a product)."
> "A node is a place which can receive amounts of resources and send amounts of resources."
> "A movement describes the movement of an amount of a resource between two nodes at a given time and for a given duration."
> "An item describes a physical instance of a resource"

Also independently confirmed by search-engine summary of Nexedi materials: "The Unified Business Model that ERP5 uses relies on 5 generic concepts: node, resource, movement, item and path" (https://www.nexedi.com/erp5-TechnicalNote.Omit.Input.Omit.Output.In.Inventory.API, paraphrased by fetch tool, underlying page not independently re-verified verbatim for this exact sentence).

**Mechanism:** ERP5 reduces all business objects to 5 abstract classes. A Movement is the atomic fact: quantity of a Resource, from a source Node to a destination Node, over a start/stop time interval. Every domain document (sales order line, invoice line, payslip line, stock move, accounting entry) is ultimately backed by one or more Movement objects, giving one storage/query model for otherwise-separate business facts.

### 2. Simulation: orders → Applied Rule → Simulation Movements → Builders → deliveries; divergence testers/solvers; accounting from simulation
**Status:** CONFIRMED (code-level for Applied Rule / Simulation Movement / Builder / Divergence Tester interfaces); PARTLY (accounting-generated-from-simulation not directly inspected in code, inferred from architecture docs)
**Label:** verified-in-public-source (code)
**URL/paths:**
- `/tmp/erp5-code/product/ERP5/bootstrap/erp5_core/DocumentTemplateItem/portal_components/document.erp5.AppliedRule.py`
- `/tmp/erp5-code/product/ERP5/bootstrap/erp5_core/DocumentTemplateItem/portal_components/document.erp5.SimulationMovement.py`
- `/tmp/erp5-code/product/ERP5/bootstrap/erp5_core/ToolComponentTemplateItem/portal_components/tool.erp5.BuilderTool.py`
- `/tmp/erp5-code/product/ERP5/bootstrap/erp5_core/InterfaceTemplateItem/portal_components/interface.erp5.IDivergenceTester.py`

**Quote (AppliedRule.py docstring):**
```
An applied rule holds a list of simulation movements.
An applied rule points to an instance of Rule ... through the specialise relation.
An applied rule can expand itself (look at its direct parent and take
conclusions on what should be inside).
An applied rule can tell if any of his direct children is divergent (not
consistent with the delivery).
```
**Quote (IDivergenceTester.py):**
```
IDivergenceTester provides methods to test simulation movements
divergence with related delivery movements. ... Movement matching
is required by Rules to decide which simulation movements should
be updated, deleted, or compensated.
```
**Mechanism:** An Order (e.g. Sale Order) is "expanded" by a Rule object into an Applied Rule, which holds child Simulation Movements representing the expected/planned business flow (what should happen: shipment, invoice, payment...). A BuilderTool (`tool.erp5.BuilderTool.py`) turns groups of Simulation Movements into real Delivery documents (Packing List, Invoice) when conditions are met. Divergence Testers compare a Simulation Movement to its related real/delivered Movement on chosen properties (quantity, price, date); if they differ, the pair is "divergent." I did not directly inspect the accounting-generation code path (e.g., an Accounting Rule expanding Simulation Movements into Accounting Transactions) in this session — marking that sub-claim PARTLY/inferred from the architecture (rules are generic and an "Accounting Rule" business template exists per `bt5/` naming conventions seen, e.g. category names referencing accounting rules), not directly read.

The ERP5 Handbook Wikibooks page on "Magic Simulations" (https://en.wikibooks.org/wiki/ERP5_Handbook/Magic_Simulations) exists but is an **unfinished draft** — it states "This page or section is an undeveloped draft or outline," so it corroborates terminology (Applied Rule, Simulation Movement, Delivery Builder, Predicates) but supplies no substantive explanatory text. Marking that document's content as NOT FOUND / PARTLY (terms confirmed, no elaboration).

### 3. Partial delivery / price-change handling via divergence + solver decisions (accept/adopt/split/defer)
**Status:** CONFIRMED
**Label:** verified-in-public-source (code)
**URL/paths:**
- `/tmp/erp5-code/bt5/erp5_configurator_standard_solver/PathTemplateItem/portal_solvers/` — contains `Accept Solver.xml`, `Adopt Solver.xml`, `Automatic Accept Solver`, `Quantity Cancel Solver`, `Quantity Split Move Solver`, `Quantity Split Solver`, `Simple Quantity Split Solver`
- `/tmp/erp5-code/product/ERP5/DeliverySolver/DeliverySolver.py`
- `/tmp/erp5-code/bt5/erp5_base/WorkflowTemplateItem/portal_workflow/solver_process_workflow.xml`, `solver_workflow.xml`

**Quote (DeliverySolver.py):**
```
class DeliverySolver:
  """
    Delivery solver is used to have control of how quantity property is
    accepted into simulation.
    Delivery solver is only used for quantity property.
    Delivery solver is working on movement's quantity and related simulation
    movements' quantities.
    Can be used to:
     * distribute
     * queue (FIFO, LIFO, ...)
     * etc
  """
```
**Mechanism:** Named Solver objects (Accept, Adopt, Quantity Split, Quantity Cancel) are the concrete implementations of the resolution actions on a divergence: "Accept" keeps the delivered/actual value as-is; "Adopt" pushes the actual (delivered) value back into the simulation (updates the plan to match reality — this matches the "decrease quantity and adopt prevision" scenario named in the Wikibooks TOC); "Quantity Split (Move) Solver" splits a movement into matched + unmatched remainder (used for partial delivery, "split and defer" pattern named in the Wikibooks TOC); a `solver_process_workflow` / `solver_workflow` governs the solver's lifecycle. I found the solver names and workflow but did not read the full solver algorithm bodies in this session (time budget) — mechanism above is inferred from names/docstrings, not a full code trace.

### 4. Accounting as movements between accounts (nodes); getInventory sums movements
**Status:** CONFIRMED
**Label:** verified-in-public-source (code) + vendor-documented
**URL/paths:**
- `/tmp/erp5-code/product/ERP5/Document/Resource.py` lines ~382-391
- https://www.nexedi.com/erp5-TechnicalNote.Omit.Input.Omit.Output.In.Inventory.API

**Code excerpt (Resource.py):**
```python
def getInventory(self, **kw):
  """
  Returns inventory
  """
  kw['resource_uid'] = self.getUid()
  portal_simulation = self.getPortalObject().portal_simulation
  return portal_simulation.getInventory(**kw)
```
**Quote (Nexedi tech note, via fetch):**
> "GetInventory API accepts 'omit_input' to take into account only incoming movements and 'omit_output' to take into account only outgoing movement from a node." / "by default, omit_input and omit_output only takes movement where quantity < 0 and quantity > 0, respectivly."

**Mechanism:** There is no stored "balance" field on a Node/account; `getInventory()` on a Resource delegates to the portal-wide `portal_simulation` tool, which sums matching Movement quantities (filtered by node, resource, date range, simulation state, and input/output direction) at query time. Accounts in ERP5 accounting are modeled as Nodes, so an account balance is computed the same way as a warehouse stock balance: by summing movements, not by reading a ledger balance column. `consolidate_node`/`consolidate_section` parameters exist to avoid double-counting movements between nodes within the same group/section (per the tech note).

## Tryton

### 5. account.move / account.move.line, `origin`, posted immutability, cancel = reverse move
**Status:** CONFIRMED
**Label:** verified-in-public-source (code)
**URL/path:** `/tmp/tryton-mono/modules/account/move.py`

**Quote (readonly-when-posted, line 36):**
```python
'readonly': Eval('state') == 'posted',
```
**Quote (origin field, line 119):**
```python
origin = fields.Reference('Origin', selection='get_origin', ...)
```
**Quote (cancel method, ~line 435):**
```python
def cancel(self, default=None, reversal=False):
    'Return a cancel move'
    ...
    default.update(self._cancel_default(reversal=reversal))
    cancel_move, = self.copy([self], default=default)
    return cancel_move
```
And in `_cancel_default`:
```python
default['lines.debit'] = lambda data: data['debit'] * -1
default['lines.credit'] = lambda data: data['credit'] * -1
default['lines.origin'] = lambda data: 'account.move.line,%s' % data['id']
```
**Mechanism:** `account.move` has a `state` field; while `state == 'posted'`, view fields are `readonly` (enforced in the view/state layer, not just UI — `post()` also validates the move is balanced and non-empty via SQL checks before flipping state). `cancel()` doesn't mutate the original move; it creates a new move via `copy()` with debit/credit negated (or swapped, if `reversal=True`), and sets the new lines' `origin` Reference field back to the original `account.move.line` records — so the correction is itself a fully traceable, separate, balanced move rather than an edit.

### 6. Analytic accounting: analytic_account.line from move lines; rules
**Status:** CONFIRMED
**Label:** verified-in-public-source (code)
**URL/path:** `/tmp/tryton-mono/modules/analytic_account/line.py`, `rule.py`

**Quote (line.py):**
```python
move_line = fields.Many2One('account.move.line', 'Account Move Line', ...)
...
def on_change_move_line(self):
    if self.move_line:
        self.date = self.move_line.date
        self.debit = self.move_line.debit
        self.credit = self.move_line.credit
```
**Quote (rule.py):**
```python
class Rule(sequence_ordered(), MatchMixin, AnalyticMixin, ModelSQL, ModelView):
    __name__ = 'analytic_account.rule'
```
**Mechanism:** Each `analytic_account.line` carries a Many2One to the general-ledger `account.move.line` it is analyzing, and mirrors its date/debit/credit (via on-change, i.e. copied at creation time, not a live join). `analytic_account.rule` is a `MatchMixin`-based rule table (sequence-ordered, so first-match-wins) used to auto-assign analytic accounts to lines based on matching criteria (e.g. product/account), rather than fully manual entry. Related modules confirmed present: `analytic_budget`, `analytic_invoice`, `analytic_purchase`, `analytic_sale` (extra finding, see below).

### 7. account_budget: per-account/period budgets, actual comparison, commitment/encumbrance
**Status:** CONFIRMED (budget vs actual); NOT FOUND (commitment/encumbrance concept)
**Label:** verified-in-public-source (code)
**URL/path:** `/tmp/tryton-mono/modules/account_budget/account.py`

**Quote:**
```python
actual_amount = fields.Function(
    Monetary("Actual Amount", ..., help="The total amount booked against the budget line."),
    'get_amount')
...
amount = Sum(Coalesce(line.credit, 0) - Coalesce(line.debit, 0))
```
(from `BudgetLine._get_amount_query`, joining `account.budget.line` to `account.move.line` filtered by account/account_type and `account.period`)

**Mechanism:** `account.budget` has `account.budget.line`s scoped to an account or account type, for a fiscal year, with sub-periods (`account.budget.line.period`). `actual_amount` is a computed (Function) field, not stored — at read time it runs a SQL query summing `credit - debit` from `account.move.line` for the matching account/type and period set, then a `percentage` (ratio field) is derived by dividing actual by `total_amount` (the budgeted figure). This is a strict actuals-vs-budget comparison against *posted general-ledger movements*; I found no distinct "commitment" or "encumbrance" stage (e.g., reserving budget against a purchase order before the invoice/move is posted) anywhere in `account_budget`, `purchase`, or `purchase_request` — searched but did not find a `commitment`/`encumbrance` model or field. Marking that half of claim 7 **NOT FOUND** rather than inferring one exists.

### 8. Stock: stock.move locations, cost price, account_stock_continental / account_stock_anglo_saxon
**Status:** CONFIRMED
**Label:** verified-in-public-source (code)
**URL/path:** `/tmp/tryton-mono/modules/stock/location.py`, `modules/stock/move.py`, module dirs

**Quote (location.py, location `type` selection):**
```python
('supplier', 'Supplier'),
('customer', 'Customer'),
('lost_found', 'Lost and Found'),
('storage', 'Storage'),
('production', 'Production'),
```
with help text: `'supplier': "Used as the source of stock received from suppliers."`, `'customer': "Used as the destination for stock sent to customers."`, `'lost_found': "Used for damages, discrepancies and wastage."`

**Mechanism:** `stock.move` (`modules/stock/move.py`) has `from_location`/`to_location` Many2One fields to `stock.location`, constrained (`check_from_to_locations`) so from != to. Location `type` values (supplier/customer/storage/production/lost_found/...) determine the semantic role of a move (e.g. supplier→storage is a receipt, storage→customer is a shipment). Confirmed module directories exist for both costing conventions: `account_stock_continental` and `account_stock_anglo_saxon`, plus `account_stock_landed_cost`, `account_stock_shipment_cost`, `account_stock_eu`. I did not open the anglo-saxon vs continental accounting code itself in this session to confirm the exact recognition-timing difference (anglo-saxon typically recognizes COGS at shipment via a Cost of Goods Sold / Stock Output account movement, continental defers expense recognition to invoice) — module existence is CONFIRMED; the precise recognition-timing mechanism is **PARTLY** (inferred from module names/standard accounting conventions, not read directly from code this session).

### 9. Projects: project.work, timesheet.line, employee cost_price with dates, project_revenue, payroll link
**Status:** CONFIRMED (cost/revenue computation); NOT FOUND (payroll link)
**Label:** verified-in-public-source (code)
**URL/path:** `/tmp/tryton-mono/modules/timesheet_cost/company.py`, `modules/project_revenue/work.py`

**Quote (timesheet_cost/company.py):**
```python
cost_price = fields.Function(fields.Numeric('Cost Price', ...,
    help="Hourly cost price for this Employee."), 'get_cost_price')
cost_prices = fields.One2Many('company.employee_cost_price', 'employee', ...)
```
**Quote (project_revenue/work.py):**
```python
cost = line.cost_price * Extract('EPOCH', line.duration) / (60 * 60)
...
def _get_revenue(cls, works):
    ...
    revenue = work.list_price * Decimal(str(work.effort_hours))
```
**Mechanism:** `company.employee_cost_price` stores a date-effective sequence of hourly cost prices per employee (unique on employee+date+cost_price); `Employee.get_cost_price()`/`compute_cost_price(date)` looks up the applicable rate for a given date, so historical timesheet costing uses the rate that was valid at the time of work, not today's rate. `project_revenue`'s `Work` class computes `_timesheet_cost` (hours × the employee's date-effective cost_price, joining `timesheet.line`/`timesheet.work`) and `_get_revenue` (list_price × effort_hours or a flat list_price) to derive per-project-task cost and revenue; `Work_Purchase._purchase_cost` adds direct purchase-line costs linked to a work via `purchase.line.work`. I searched for a `payroll` module or any explicit link from `timesheet_cost`/`project_revenue` to a payroll actuals module and found **none** (`find . -type d -iname "payroll*"` returned nothing in this checkout) — marking payroll-actuals link **NOT FOUND**.

### 10. purchase_request: generation, linkage to purchase lines, fulfillment/closure
**Status:** CONFIRMED
**Label:** verified-in-public-source (code)
**URL/path:** `/tmp/tryton-mono/modules/purchase_request/purchase_request.py`

**Quote:**
```python
state = fields.Selection([
    ('draft', "Draft"),
    ('purchased', "Purchased"),
    ('done', "Done"),
    ('cancelled', ...),
    ('exception', "Exception"),
    ], ...)
...
def get_state(self):
    ...
    if <exception condition>:
        return 'exception'
    elif self.purchase_line.purchase.state == 'done':
        return 'done'
    else:
        return 'purchased'
    return 'draft'
```
**Mechanism:** A `purchase.request` starts in `draft`. It has a `purchase_line` link (Many2One, per `get_purchase`/`search_purchase` methods) to an `account.purchase.line`. `get_state()` is a computed function: state becomes `purchased` once a purchase line exists, `done` once that line's parent `purchase.purchase` reaches `state == 'done'`, or `exception` if flagged (and can be explicitly ignored via `exception_ignored`). So a request is not manually closed; its displayed state is *derived* from the linked purchase order's lifecycle, meaning double bookkeeping (request vs actual PO) is avoided by computing rather than duplicating state. `_get_origin`/`get_origin` (classmethods) indicate `purchase.request` also participates in Tryton's generic `origin` Reference pattern, letting other documents point back to the request that caused a purchase.

## Extra findings (drawbacks / adoption / related modules)

1. **ERP5's own Handbook admits its simulation-model documentation is incomplete.** Status: CONFIRMED. Label: vendor-documented. The "Magic Simulations" chapter (https://en.wikibooks.org/wiki/ERP5_Handbook/Magic_Simulations), which is the canonical place this exact mechanism (Applied Rule/Simulation Movement/Builder/divergence/solver) should be explained end-to-end, is marked "This page or section is an undeveloped draft or outline" — i.e., even the vendor-adjacent community handbook could not fully document the mechanism, which is circumstantial evidence for the complexity concern.

2. **Tryton ships separate anglo-saxon vs continental stock-accounting modules rather than one configurable model.** Status: CONFIRMED. Label: verified-in-public-source. `/tmp/tryton-mono/modules/` contains both `account_stock_anglo_saxon` and `account_stock_continental` as distinct installable modules (plus `account_stock_eu`, `account_stock_landed_cost*`, `account_stock_shipment_cost*`), suggesting the two costing/COGS-recognition conventions are different code paths, not one parametrized model — a data point on how much branching real systems need to support both cash/accrual-adjacent conventions relevant to Czech SME accounting choices.

3. **ERP5 exposes a large surface of named Solver types as separate business-template objects** (Accept, Adopt, Automatic Accept, Quantity Cancel, Quantity Split, Quantity Split Move, Simple Quantity Split) rather than a small fixed enum. Status: CONFIRMED. Label: verified-in-public-source. `/tmp/erp5-code/bt5/erp5_configurator_standard_solver/PathTemplateItem/portal_solvers/`. This indicates the generic-movement/divergence approach pushes complexity into a proliferation of solver strategies, each a first-class configurable object with its own workflow (`solver_process_workflow.xml`) — a concrete instance of the "generic model → high configuration surface" tradeoff relevant to our smallest-coherent-model question.

4. **No commitment/encumbrance accounting found in Tryton's budget module.** Status: NOT FOUND (see claim 7). This matters directly for our design question: Tryton's `account_budget` compares budget only to *posted* actuals, not to open purchase orders/commitments — so "budget vs commitment vs actual" as a 3-way comparison is not out-of-the-box in Tryton; a finance-first platform wanting that would need to add it.

5. **No payroll-to-timesheet-cost linkage found in Tryton.** Status: NOT FOUND (see claim 9). `timesheet_cost`/`project_revenue` use a manually maintained `cost_price` table, not a computed link to actual payroll runs — i.e., "cost" in project profitability is a standing rate, not a reconciled actual expense, which is a gap relevant to a "no double counting between plan/commitment/incurred/actual" design goal.

## Not independently verified in this session (time-boxed)
- IEEE IT Professional 2003 paper (Smets-Solanes & Carvalho) full text — paywalled (IEEE Xplore/ACM DL), ResearchGate returned HTTP 403. Citation existence CONFIRMED via search; content claims from it NOT FOUND (no verbatim access).
- Full algorithmic bodies of ERP5 Solver classes (`DeliverySolver.py` beyond docstring, `TargetSolver.py`) — not read line-by-line.
- Whether ERP5 has a distinct "Accounting Rule" that expands Simulation Movements into ledger transactions — inferred from architecture, not directly traced in code this session (PARTLY, claim 2).

---
## Addendum (second review follow-up, 2026-09-24): Tryton's posted filter is optional
**Supersedes the "posted" wording at line 170 (claim 7) and line 245 (extra finding 4: "compares budget only to *posted* actuals").** Tryton main, `modules/account_budget/account.py:259-262`, re-fetched with curl on 2026-09-24:
```python
    posted = fields.Boolean(
        "Posted",
        help="Only include posted moves.")
```
The budget compares the period's move lines, and restricting them to posted moves is an optional flag. The finding that no commitment or encumbrance stage exists still stands. Status: CONFIRMED. Label: source. The second independent review reached the same result (EVIDENCE-1).
