# 02. Alternatives, stress tests and the common-framework challenge

**Covers:** the six alternatives, the recommended hybrid in eight parts, the four-question comparison, stress tests, and the case for and against one common writable money object, including measured read cost.
**Read it when:** you need to defend the design against "why not one table", "why not NetSuite-style documents" or "why not a planning cube".
Back to the overview: [README.md](README.md).

---

## 1. The alternatives

1. **Generic documents plus a statutory GL** (NetSuite-like). One document table with line links; the ledger is posted from it.
2. **A common writable exposure or movement model** (writable `financial_effects`, SAP 0E, ERP5). The strongest version: every module writes effects through one shared rule library, changes are obsolete + reversal + new (SAP), divergences are resolved by solvers (ERP5), and flows can be rebuilt (SAP One Exposure).
3. **Typed records + links + derived positions.**
   - 3a. Derived **per report**: the join approach, rejected. Its risk is that each report carries its own relief rule. ERPNext's budget check ([01](01-constraints-and-evidence.md)) shows one such rule, relief by invoice value: evidence about relief valuation, not about inconsistency across reports.
   - 3b. Derived **once, into a stage contract**: the core of the recommendation.
4. **Planning cube beside actuals** (Anaplan-like).
5. **Peppol as the internal core.** Rejected by the requirements and by the evidence: Peppol has no commitments, budgets, payroll, ledger derivation, bank reconciliation or planning.
6. **Hybrid (recommended).** The eight parts below.

A variant of 1 deserves a note: **multi-book** (NetSuite) keeps a statutory and a management book over the same transactions. It separates two accounting views of *posted* facts. It does not give requests, orders, time or plans a place, so it answers the consistency requirement only for actuals.

---

## 2. The hybrid in eight parts

1. **Typed records are the only writable truth.**
   - Each business domain owns its record types: opportunity, contract, order, order response, receipt, invoice, invoice response, timesheet, payroll run, bank transaction, advance.
   - A product is a sellable set of features over those records. Adding a product adds features and new linked records. It never moves a record or takes one over.
   - A posted record is never edited. It is reversed or corrected by a new record.
2. **Shared lists.** The platform owns what every domain tags its records with: parties and roles, projects and their milestones, cost centers (střediska), activities (činnosti), categories, items, periods and currencies. The domain map is in [03](03-domains-and-products.md).
3. **Typed fulfilment links.**
   - The domain that performs a fulfilment writes the link at that moment, with a quantity.
   - Links run from request to order, order to receipt, receipt to invoice, invoice to payment, advance to invoice, and payroll to timesheet.
4. **One stage contract** ([04](04-money-model.md)).
   - Cost and revenue move through `expected → committed → incurred → actual`.
   - Cash moves through `forecast → open → settled`.
   - A successor relieves its predecessor at the **predecessor's own valuation**, i.e. at the accepted order terms or the request estimate.
   - A cash relief keeps the **predecessor's cash date**.
5. **A derived, bitemporal position projection.**
   - Each domain contributes one view of rules for its record types. The platform unions them. A view only returns rows for records that exist, so selling fewer products means fewer rows, never different rules.
   - Every entry carries `effective_on` (when it happened) and `recorded_on` (when we learned it), plus the counterparty and the root business document (order, contract or invoice), so per-supplier and per-order reports are one `GROUP BY` too. The reference model ([05](05-data-model.md)) carries neither of the last two yet.
   - It has no writers.
6. **A separate plan store, owned by FP&A:** company, cost-center, activity, project and milestone budgets, forecasts, scenarios and cash plans. FP&A also owns progress estimates and management-only adjustments. Projects is a product over FP&A's project financial control and the shared project and milestone lists, and owns no records.
7. **A separate statutory ledger**, posted from the same typed records. A reconciliation contract ties it to the projection.
   - Accounting owns the chart of accounts and the rule that maps a record line to an account. Both ship with every product, so any record shows where it lands in the chart.
   - Sold alone, Accounting registers invoices and bank statements in the same records the Sales, Procurement and Treasury products use, and payroll recaps in the records the Payroll product uses. A stock purchase carries its "for stock" fact on the invoice line. Its journal entries point to those records.
8. **Peppol / UBL / EN 16931 as the reference domain layer, not the internal schema** ([06](06-peppol-reference-layer.md)).
   - It supplies the missing business vocabulary: party roles, agreements, order and invoice responses, self-billing, prepayments, correction kinds and amount rules.
   - It fixes the boundary for exchanging documents with other companies. One intake layer takes mixed input (Peppol, ISDOC, PDF and scans).

---

## 3. The four questions per alternative

Cells for 1, 2, 3a and 4 are this paper's inference from the evidence in [01](01-constraints-and-evidence.md).

| Question | 1 Generic documents + GL | 2 Writable effects (steelman) | 3a Joins per report | 4 Planning cube | 6 Hybrid |
| --- | --- | --- | --- | --- | --- |
| Where the truth lives | one generic document table; meaning per type in code | typed records **and** the effects table: the truth lives twice | typed records | the cube for plans; actuals imported | typed records only; plans in the plan store |
| How an estimate is replaced or partly fulfilled | per report or per posting rule | each writer writes a relief effect through the shared library | each report recomputes it | not modelled; actuals overwrite the forecast cells | one relief rule over quantity links, derived |
| How users correct mistakes | reverse the document | obsolete + reversal + new effect rows (SAP) | edit the record; reports follow | edit the cell | reverse or correct the record; the projection follows |
| Reports aggregate common dimensions without custom logic | no, link meaning is coded per report | yes | no, per dashboard | yes, for what is in the cube | yes: one `GROUP BY` shape |
| Main risk | weak per-type validation | drift if one writer relieves wrongly; history before activation (SAP 0E) unless rebuilt | the same number computed differently per report | blind to documents and commitments | read cost at scale (section 5) |

---

## 4. Stress tests

Cells for 1, 2, 3a and 4 are inferred from the definitions and the table above. Column 6 is exercised in the worked example ([07](07-worked-example.md)).

| Case | 1 Generic documents + GL | 2 Writable effects | 3a Joins per report | 4 Planning cube | 6 Hybrid (worked example) |
| --- | --- | --- | --- | --- | --- |
| Request → several orders, partial deliveries | per report or per posting rule, over line links | each writer relieves | per report | not modelled | 10 frames → orders for 6 and 2, 1 from stock, 1 open at the 30,000 estimate |
| Changed price (order ≠ estimate, invoice ≠ order, corrective invoice) | per report or per posting rule | each writer | ERPNext misstates the remainder | only the imported actual | relief at the predecessor price; variance lands in `actual` (VB3 +1,000, VB2C +2,000) |
| Supplier accepts less, at a new price | reverse the document | obsolete + reversal + new (SAP); divergence solver (ERP5) | per report | not modelled | PO5 50 × 1,000 → accepted 40 × 1,050: committed 50,000 → 42,000 |
| Invoice disputed or rejected | reverse the document | the writer waits for acceptance, or writes and reverses | per report | not modelled | VB3 counts only from acceptance; the rejected duplicate VB6 never counts |
| Advance before delivery | per posting rule | two writers | per report | cash plan cells only | PO5 advance of 25,410 keeps the order's cash exposure at 50,820 throughout |
| Self-billing | n/a | n/a | n/a | n/a | VB5 issued by us under a self-billing agreement; stages unchanged |
| Services without receipt | per report | each writer | per report | not modelled | the invoice relieves `committed` |
| VAT, both reverse-charge directions | per posting rule | columns needed | per report | only the imported actual | net cost, gross cash, self-assessed VAT nets to zero |
| Stock | per posting rule | natural | per report | only the imported actual | replenishment is not project cost; stock issue at valuation |
| Split payments, payroll in 2 transfers | works (ledger) | works | works | only the imported actual | rounding to the cent; relief once per allocation |
| Timesheet → payroll | per report | payroll writes a true-up | not found | only the imported actual | incurred at 500/h, actual at 550 and 530/h |
| Scenarios | no plan store in the definition | double-count risk if plans share the table | per report | natural: versions are a dimension (Anaplan) | the plan remainder only |
| As reported then | if append-only | if append-only | rebuilt per report | versions; before switchover a forecast equals actual and is read-only (Anaplan) | `effective_on` × `recorded_on`, provided every rule input (rates, probabilities, response terms) is insert-only or versioned |

---

## 5. Challenge to the common-framework preference

The evidence does not forbid one writable object. SAP 0E works, and the steelman alternative 2 produces the same numbers as the hybrid when every writer relieves correctly. What it costs:

- the truth lives twice;
- every writer is responsible for relief.

The real choice is between deriving effects on read and storing them regenerated from the same rule library ([04](04-money-model.md), physical options). The hybrid starts with the first and keeps the second open.

**Measured read cost (the view-or-stored decision).** The view was timed on synthetic volume, on an earlier version of the reference model with fewer view branches than now.

| Volume | `position_entry` rows | One-project summary | Direct project filter |
| --- | --: | --: | --: |
| 20k order → receipt → invoice → payment chains, 10k sales invoices | 220,131 | 0.68 s | 0.34 s |
| 5 × that volume | about 1.1M | 3.8 s | 1.85 s |
| 5 ×, plus 18 foreign-key and project indexes | about 1.1M | 3.26 s | 1.47 s |

- EXPLAIN ANALYZE shows the project filter is not pushed down into the settlement and supplier-invoice branches. A one-project read therefore costs work in proportion to the whole company's history.
- An independent re-run reproduced only the first row (669 ms and 323 ms) and ran no EXPLAIN. The 1.1M rows and the query plan rest on a single run.
- At these timings, a dashboard tile over the full history takes seconds. The production form is therefore likely either the stored projection regenerated per source record (with the equality test) or period-bounded reads over close snapshots. The read-time threshold for switching is not set.

**What the shared layer adds beyond conformed dimensions and typed facts**

- **One relief rule.** SAP and ERPNext produce different numbers from the same documents because they relieve differently.
- **One stage vocabulary.**
- **Two time axes.**
- **A reconciliation boundary** to the ledger.
- **A controlled vocabulary for business outcomes**: order responses, invoice responses, roles and correction kinds, taken from Peppol.

If Afframe only needed budget-vs-ledger reporting, conformed dimensions plus a warehouse would be enough.

**What separates the hybrid from the two rejected designs** (a writable effects table, and joins per report):

- **(a)** Only typed records carry amounts. The projection has no writers.
- **(b)** Relief comes from quantity links captured at the operational moment.
- **(c)** There is one relief rule and one stage vocabulary for all products.
- **(d)** Every entry carries two time axes.
- **(e)** A generic invariant checks that every stage, per project and category, equals the open remainder computed directly from the typed records.

"Drop the layer and regenerate it" is necessary but not enough, because a deterministic writer of a `financial_effects` table would also pass it.
