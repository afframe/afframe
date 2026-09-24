# Finance-first platform: final architecture

Research answer to `finance-first-erp-research-brief.md`, extended with the Peppol / UBL / EN 16931 research from the earlier conversation. Date: 2026-09-24. Currency: CZK.

What comes with this report:

- **Evidence**: one file per source group, each claim with a quote and a URL. See [`finance-first-evidence/`](finance-first-evidence/).
- **A runnable model and a worked example**: [`finance-model-prototype/`](finance-model-prototype/). It runs on PostgreSQL 18, and all 146 assertions pass.
- **Independent review**: three critical review rounds. The first found four money defects. The second found three more in advance handling and one design gap. All of these are fixed, and each is now a regression check. A third round reviewed an earlier design for selling Accounting alone, in which Accounting kept its own copy of documents. Hleb's ruling that products add features rather than take records over replaced that design (6.8), and the problems it found went with it. A third, independent review (ten Opus agents, five lenses, each finding adversarially verified) found 51 confirmed issues; the money and model issues are fixed with a regression check each, and the report issues are corrected (section 11 lists what is only partly fixed). Seventeen deliberate rule mutations (A to Q) each make the checks fail (section 8.12, exact diffs in [`mutations.md`](finance-model-prototype/mutations.md)).

**Evidence labels** used throughout:

| Label | Meaning |
| --- | --- |
| documented | official vendor or standard documentation |
| official | law or EU/Czech state source |
| source | public source code |
| search-derived | a search-engine summary of a vendor page that was not fetched verbatim |
| marketing | vendor marketing material |
| third-party | a non-vendor secondary source |
| inferred | this report's own reasoning |

---

## 1. The answer

**Each business domain keeps its own documents, and products are sellable sets of features on top of them. The platform calculates every money figure from those documents. Nobody types money figures into a shared table, and dashboards never join modules on their own.**

The model has eight parts:

1. **Typed records are the only writable truth.**
   - Each business domain owns its record types: opportunity, contract, order, order response, receipt, invoice, invoice response, timesheet, payroll run, bank transaction, advance.
   - A product is a sellable set of features over those records. Adding a product adds features and new linked records. It never moves a record or takes one over.
   - A posted record is never edited. It is reversed or corrected by a new record.
2. **Shared lists.** The platform owns what every domain tags its records with: parties and roles, projects, cost centers (střediska), activities (činnosti), categories, items, periods and currencies. The domains are CRM, Private relationships, Sales, Spend, Inventory, People, Treasury, Accounting, FP&A and Documents; the full domain map, covering every part the brief names, is in section 10.
3. **Typed fulfilment links.**
   - The domain that performs a fulfilment writes the link at that moment, with a quantity.
   - Links run from request to order, order to receipt, receipt to invoice, invoice to payment, advance to invoice, and payroll to timesheet.
4. **One stage contract.**
   - Cost and revenue move through `expected → committed → incurred → actual`.
   - Cash moves through `forecast → open → settled`.
   - A successor relieves its predecessor at the **predecessor's own valuation**, i.e. at the accepted order terms or the request estimate.
   - A cash relief keeps the **predecessor's cash date**.
5. **A derived, bitemporal position projection.**
   - Each domain contributes one view of rules for its record types. The platform unions them. A view only returns rows for records that exist, so selling fewer products means fewer rows, never different rules.
   - Every entry carries `effective_on` (when it happened) and `recorded_on` (when we learned it), plus the counterparty and the root business document (order, contract or invoice), so per-supplier and per-order reports are one `GROUP BY` too. The prototype carries neither of the last two yet.
   - It has no writers.
6. **A separate plan store, owned by FP&A:** company, cost-center, activity and project budgets, forecasts, scenarios and cash plans. Projects is a product over FP&A's project financial control and owns no records.
7. **A separate statutory ledger**, posted from the same typed records. A reconciliation contract ties it to the projection.
   - Accounting owns the chart of accounts and the rule that maps a record line to an account. Both ship with every product, so any record shows where it lands in the chart.
   - Sold alone, Accounting registers invoices and bank statements in the same records the Sales, Procurement and Treasury products use. Its journal entries point to those records.
8. **Peppol / UBL / EN 16931 as the reference domain layer, not the internal schema.**
   - It supplies the missing business vocabulary: party roles, agreements, order and invoice responses, self-billing, prepayments, correction kinds and amount rules.
   - It fixes the boundary for exchanging documents with other companies. One intake layer takes mixed input (Peppol, ISDOC, PDF and scans) and maps every format to EN 16931 semantics, then to the owning domain's typed record. From 1 July 2030 ViDA makes EN 16931 e-invoices the default for all invoices, and the recipient may no longer refuse them (new Art. 232). Member States may still accept other formats outside the reporting obligations; no Czech domestic mandate was found.

**What separates this from the two rejected designs:**

- **(a)** Only typed records carry amounts. The projection has no writers.
- **(b)** Relief comes from quantity links captured at the operational moment.
- **(c)** There is one relief rule and one stage vocabulary for all products.
- **(d)** Every entry carries two time axes.
- **(e)** A generic invariant checks that every stage, per project, equals the open remainder computed directly from the typed records.

"Drop the layer and regenerate it" is necessary but not enough, because a deterministic writer of a `financial_effects` table would also pass it.

---

## 2. Constraints this answer respects

**From the brief:**

- Consistent, traceable amounts across plan, commitment, incurred, actual and cash, without double counting.
- No assumed single table.
- Five alternatives, stress tests, falsifiers.

**From the product-structure conversation:**

- Every top-level product sells alone, including Accounting run without the rest (e.g. when an external accountant keeps the books).
- Statutory accounting stays separate from management money views.
- FP&A is first-class.
- Money scope only.

**From the data-model conversation** (line numbers refer to the transcript file):

| Line | Decision |
| --- | --- |
| 780 | Rejected: a universal relationship graph, because edges grow with every pair of related records rather than with the real business facts. |
| 1081 | Accepted: "typed records + direct provenance + bridge tables only for real many-to-many + posting context + specialised subledgers". This report keeps that core. |
| 4824 | Peppol is a semantic and domain reference, not the internal model. Section 7 is built on this. |
| 2992 | Asked for a theoretical paper without DB columns. Sections 1 to 7 carry the theory; names in backticks point to the prototype as evidence and are not a schema proposal. The prototype exists because the later brief asked for "a small technical model" and a worked example. Treating the earlier instruction as superseded by that brief is an assumption. |
| 2992 | Asked for one more verification round before anything is final. Done: the critical review, generic invariants and mutation tests. |

---

## 3. What the examined products and standards actually do

### 3.1 ERP, finance and planning products

Full quotes are in [`finance-first-evidence/`](finance-first-evidence/).

| Product | Mechanism relevant here | Label | Source |
| --- | --- | --- | --- |
| SAP S/4HANA Cloud | **Commitments.** Requisitions and orders create commitments in prediction ledger 0E. Follow-on documents reduce them with new negative entries. Document numbers `PA…` keep them apart from GAAP entries. | documented | [Predictive Commitments Management](https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/60d6187546b343569423c2a06b6a5c57.html?locale=en-US) |
| SAP | **Relief at the predecessor's own amount.** Requisition → order: the requisition is relieved at its own amount (EUR 100) and the order is booked at its own amount (EUR 120). A change is recorded as obsolete + reversal + new entry. | documented | [PR to PO example](https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/a01315ea9245454aa85a2ec3389400b9.html?locale=en-US), [PR change](https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/686e7e459ad548e1b97611a3777291e1.html?locale=en-US) |
| SAP | **Commitments only cover recent documents.** They are processed only for documents created after activation; older ones "aren't supported". *Inferred:* the stored deltas are not rebuilt from history. | documented + inferred | as row 1 |
| SAP | **One Exposure (cash forecast).** Requisitions and orders lead to "forecasted cash that is adjusted by subsequent invoicing processes". It uses net plus non-deductible tax, and flows can be rebuilt. | documented | [One Exposure MM](https://help.sap.com/docs/SAP_S4HANA_CLOUD/186460fdc35a4b64a713da9bb00deb1e/27fbca0f32da40d39bb66ef161008d27.html?locale=en-US) |
| SAP | **Predictions and plan data.** Sales orders create predictive entries, which actual postings reduce. Plan data sits in ACDOCP, "single source of truth for plan data". | documented | [Predictive Accounting](https://help.sap.com/docs/SAP_S4HANA_CLOUD/0fa84c9d9c634132b7c4abb9ffdd8f06/c78ce92ab96346f7ab2722b79756ffc1.html?locale=en-US), [Planning](https://help.sap.com/docs/SAP_S4HANA_CLOUD/1cbcff7ccd35405ab445b223c1ab1588/f900a12c7abf4c91957478cd6f6e48e8.html?locale=en-US) |
| Dynamics 365 Finance | **Budget remaining** = budget − actuals − encumbrances − pre-encumbrances. These are tracked in `BudgetSourceTracking`. Private-sector budget reservations (encumbrances) "aren't documents", unlike general budget reservations. | documented | [Budget analysis report](https://learn.microsoft.com/en-us/dynamics365/finance/public-sector/budget-analysis-report), [Budget control](https://learn.microsoft.com/en-us/dynamics365/finance/budgeting/budget-control-overview-configuration), [General budget reservations](https://learn.microsoft.com/en-us/dynamics365/finance/public-sector/general-budget-reservations) |
| Dynamics 365 | **Cash flow forecasting** reads orders "not yet invoiced" and open AR/AP. It warns that project forecasts transferred to budgets would be "counted two times". | documented | [Cash flow forecasting](https://learn.microsoft.com/en-us/dynamics365/finance/cash-bank-management/cash-flow-forecasting) |
| NetSuite | **One transaction record family.** Transactions share Transaction / TransactionLine / TransactionAccountingLine (documented). That posting and non-posting transactions share it, and the line links, are confirmed by third parties only. | documented / third-party | [Join path](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_1548805090.html) |
| Odoo 18 | **Timesheets and profitability.** Timesheets are analytic lines, `amount = -unit_amount * hourly_cost`. The profitability panel is built by per-module `_get_profitability_items`. Budget "Committed" = achieved + unbilled orders (Enterprise). | source + documented | `hr_timesheet.py`, `sale_project/models/project_project.py`, [Budgets](https://www.odoo.com/documentation/18.0/applications/finance/accounting/reporting/budget.html) |
| ERPNext v15 | **Budget check computed on read.** Open request quantity × rate; order `amount - billed_amt`, where `billed_amt` sums **invoice** amounts. The open order remainder is therefore misstated (under or over) whenever the invoice price differs from the order price. | source | `budget.py`, `purchase_invoice.py` |
| Tryton | **Corrections and budgets.** Posted moves are read-only, and cancel creates a negated copy. The budget compares the period's move lines; posted-only is an optional filter; no commitment stage was found. A purchase request's state is derived. | source | `account/move.py`, `account_budget/account.py` |
| ERP5 | **Generic simulation.** A generic movement and simulation model with divergence testers and solvers (Accept, Adopt, Quantity Split…). Balances are sums of movements. | documented + source | [ERP5 developer](https://www.erp5.com/basic/developer) |
| Anaplan | **Versions.** Versions are a dimension. Before a forecast version's switchover date, data "is the same as for Actual and is read-only". | documented | [Versions](https://help.anaplan.com/versions-19b4391f-5257-40ee-8dfb-36f0ab426c8f) |
| Procore | **Forecast formulas.** Projected Costs = Committed + Direct + Pending changes; Forecast to Complete = Projected Budget − Projected Costs. | documented | [Read a budget](https://support.procore.com/products/online/user-guide/project-level/budget/tutorials/read-a-budget) |
| Agicap, Ramp, Brex, Rillet | **Spend and cash tools.** Forecast, bank actuals and expected transactions (Agicap). Workflow graph, with the ledger kept in the ERP (Ramp, Brex). A GL with ASC 606 (Rillet). Consumption rules were not found. | marketing / documented | `cash-spend-tools.md` |

### 3.2 Peppol, UBL, EN 16931 and Czech rules

Details are in `peppol-ordering-ubl.md`, `peppol-billing-en16931.md` and `cz-einvoicing-vat.md`.

| Topic | Verified fact | Label | Source |
| --- | --- | --- | --- |
| Peppol post-award profiles | Order Only 3.3, Ordering 3.3, Catalogue 3.1, Despatch Advice 3.1, Punch Out 3.1, Order Agreement 3.0, Message Level Response 3.0, Invoice Response 3.2, Billing 3.0, Advanced Ordering 3.0. Self-Billing 3.0 is a separate specification. Receipt Advice exists only in the Logistics profiles. | documented | [docs.peppol.eu/poacc/upgrade-3](https://docs.peppol.eu/poacc/upgrade-3/), [Self-billing](https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/) |
| Order response | Codes: AB (acknowledged), AP (accepted), RE (rejected), CA (conditionally accepted). "An order response with code CA … must provide order lines". Only CA carries line-level changes. | documented | [OrderResponseCode](https://docs.peppol.eu/poacc/upgrade-3/syntax/OrderResponse/cbc-OrderResponseCode/) |
| Advanced ordering | Order Change comes from the buyer only. Either party may cancel. A seller proposes changes through Order Response Advanced. | documented (paraphrase level) | [Advanced Ordering](https://docs.peppol.eu/poacc/upgrade-3/profiles/65-advanced-ordering/) |
| Order agreement | "The seller creates an order in his ordering system … and sends a copy of the order as an Order agreement to the buyer". This covers purchases made outside the buyer's process. | documented | [Order Agreement](https://docs.peppol.eu/poacc/upgrade-3/profiles/42-orderagreement/) |
| Despatch advice | "The Despatch Advice states what is shipped; the quantity of goods shipped and what is outstanding" (e.g. backorder). | documented | [Despatch Advice](https://docs.peppol.eu/poacc/upgrade-3/profiles/30-despatchadvice/) |
| Invoice types | Billing 3.0 allows 380 plus alternatives, including 383 (debit note) and 386 (prepayment). 384 (corrected invoice, a full replacement) and 389 are marked "Germany only" in Billing 3.0; self-billing codes 389, 527 and 261 belong to Self-Billing 3.0. Credit notes use 381, 81, 83, 396 and 532. | documented | [UNCL1001-inv](https://docs.peppol.eu/poacc/billing/3.0/codelist/UNCL1001-inv/) |
| Invoice references | Project BT-11, contract BT-12, order BT-13, receiving advice BT-15, despatch advice BT-16, invoiced object BT-18, buyer accounting reference BT-19, preceding invoice BT-25. | documented | [Billing 3.0](https://docs.peppol.eu/poacc/billing/3.0/bis/) |
| Self-billing | "A customer issues and sends an invoice in its suppliers name". Codes: 389 (invoice), 527 (debit note), 261 (credit note). Peppol cites VAT Directive Art. 224: "prior agreement and a procedure where the supplier is to accept each invoice". | documented | [Self-billing 3.0](https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/) |
| Invoice response codes | AB, IP, UQ, CA, RE, AP, PD. "Several Invoice Response's can be sent for one invoice". After Rejected or Paid, "no further Invoice Response may be sent". Approved "may only be followed with … Paid". OP-BR111-R012: "The status of invoices shall advance in the following order" AB, IP, UQ, CA, RE, AP, PD; the process may start at any status. | documented | [UNCL4343-T111](https://docs.peppol.eu/poacc/upgrade-3/codelist/UNCL4343-T111/), [Invoice Response](https://docs.peppol.eu/poacc/upgrade-3/profiles/63-invoiceresponse/) |
| Amount rules | BR-CO-10: sum of lines. BR-CO-13: total without VAT = lines − allowances + charges. BR-CO-15: + VAT. BR-CO-16: amount due = total with VAT − paid amount (BT-113) + rounding (BT-114). | documented | [BR-CO-16](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-16/) |
| Remittance advice | UBL has a RemittanceAdvice document. No Peppol profile was found for it. | documented / not found | `peppol-billing-en16931.md` |
| EN 16931-1 | "A new version of the EN 16931-1, a version 2026, was published in May 2026 and consequently the 2017 version … has been formally withdrawn". The 2017 version remains compliant during the migration period. Peppol BIS Billing 3.0 is still built on the 2017 model; no Peppol migration date was found. | official | [EC eInvoicing](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467108971/Obtaining+a+copy+of+the+European+standard+on+eInvoicing) |
| ViDA, Directive (EU) 2025/516 | Article 5 applies from 1 July 2030 and replaces VAT Directive Art. 218: "invoices shall be issued as electronic invoices" complying with the European standard. Member States may still accept other formats for transactions outside the reporting obligations, and may mandate domestic e-invoicing. | official | [OJ L 2025/516](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500516) |
| Czech public sector | Act 134/2016 § 221 (effective through § 279(5)): contracting authorities "nesmí odmítnout elektronickou fakturu" that follows the European standard, in UBL 2.1 or CII (from 2019 or 2020 depending on the authority). Separately, Government Resolution 347/2017 makes central state bodies accept ISDOC ≥ 5.2. | official | [mf.gov.cz](https://mf.gov.cz/cs/dane-a-ucetnictvi/elektronicka-fakturace/zakladni-informace), [zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/2016-134) |
| ISDOC | The Czech national e-invoice format, widely used between Czech accounting systems. Current version 6.0.2 (23 March 2022), maintained by the Ministry of the Interior. It is not one of the EN 16931 syntaxes. No Czech Peppol Authority was found. | documented | [isdoc.cz/6.0.2](https://isdoc.cz/6.0.2/) |
| Czech VAT advances | § 20a: "Je-li před uskutečněním zdanitelného plnění přijata úplata, vzniká povinnost přiznat daň … ke dni jejího přijetí" (VAT becomes due on the day an advance is received): official. A proforma (zálohová faktura) is not a tax document: third-party. That an advance creates no tax point under reverse charge is third-party only and needs checking against the law text. | official + third-party | `cz-einvoicing-vat.md` |
| Czech self-billing | § 28(10): another person may issue the tax document "na základě jejich ujednání" (on the basis of their arrangement), which the tax office may ask to be proven; no written form is required. § 29(2)(b) marks the document "vystaveno zákazníkem". Whether self-billing is used with reverse-charge supplies was **not found**, so the example self-bills a standard-VAT supply. | official | [zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/2004-235) |
| Disputed received invoices | No Czech rule on booking a disputed received invoice was found in Act 563/1991 or the VAT Act. | not found | `cz-einvoicing-vat.md` |

**Patterns:**

1. **Typed documents are authoritative; commitments are derived.** Mature ERPs keep typed documents as the authority and derive commitments from them.
2. **Relief valuation is where products differ.** SAP relieves at the predecessor's amount. ERPNext relieves by invoice value.
3. **Plans live apart from actuals.**
4. **Peppol confirms the same shape across companies.** Its documents are typed, each points to its predecessor, and responses are separate documents with codes that bound their lifecycle. It never uses a universal graph.
5. **Peppol has gaps.** It covers commitments, budgets, payroll, the ledger, bank reconciliation and planning weakly or not at all. Those come from the ERP patterns.

### 3.3 Product boundaries in more vendors

These are the vendors Hleb chose, researched for architecture only: product boundaries and record ownership. Evidence files:

- [`oracle-unit4-acumatica.md`](finance-first-evidence/oracle-unit4-acumatica.md)
- [`xero-sap-b1.md`](finance-first-evidence/xero-sap-b1.md)
- [`cz-erp-tools.md`](finance-first-evidence/cz-erp-tools.md)

Unit4's primary documentation was unreachable, so its row rests on marketing and third-party pages. SAP Business One's help portal did not render, so several of its answers are inferred or third-party.

| Vendor | Who owns invoices and bank | Chart of accounts | Projects | Expenses | Inbound e-invoices | Label |
| --- | --- | --- | --- | --- | --- | --- |
| Oracle Fusion | Payables and Receivables own invoices; Subledger Accounting derives the journal. No GL-only edition found. | The ledger sets the chart for its subledgers. | PPM, a separate pillar (search-derived) | Expenses, processed through Payables (search-derived) | Peppol BIS 3.0 in and out; separate subsystems per channel (search-derived) | documented / search-derived |
| Unit4 ERPx | AP and AR modules, integrated with GL | configurable; mapping not found | Project Management module (budgets, time and expense) | not found | eConnect: Peppol, and PDF via OCR into structured XML, keeping the PDF | marketing / third-party |
| Acumatica | GL, AP, AR, cash and tax sold as one Financials module; GL alone is not sold | GL owns the chart; AP and PO lines default the account from the vendor or item | Project Accounting, a separate module | Advanced Expense Management (claims, corporate cards) | ML/OCR document recognition into AP bills | documented / inferred |
| Xero | The accounting core owns invoices, bills and bank transactions outright. Projects and Expenses link to or create those core records. | One chart in the core; tracking categories are a separate dimension; apps map to the chart when they connect. | Xero Projects, an add-on: tasks, time, budgets, no ledger records of its own | Xero Expenses, an add-on: an approved claim becomes a bill (not re-quoted verbatim) | Hubdoc and apps all create the same core records | documented / partly |
| SAP Business One | Sales and Purchasing documents own A/R and A/P invoices and generate linked journal entries. One license, not separate products. | Financials owns the chart; G/L account determination maps other modules to it. | Project Management module | not found | not found; partner add-ons | inferred / third-party |
| POHODA | The journal is fed from the invoice, bank, cash and stock agendas, all inside the accounting product. A separate internal document (interní doklad) covers postings with no primary document. | Accounting owns the chart; předkontace on each document drives posting. | Zakázky: a tagging dimension with a plan, built in | GLX, a separate product that also runs standalone | ISDOC import, including ISDOC inside PDF | documented |
| Money S3/S4/S5 | Invoice and bank agendas plus internal documents, as in POHODA | předkontace on documents | S5 only; not found for S3/S4 | Travel module, tied to payroll | ISDOC and Money's own richer XML: two formats | documented |
| ABRA Flexi / Gen | Invoices own a Posting tab that links to their entries. The journal is "a view over the line items of all accounting documents". Internal documents exist. | Accounting owns the chart; předkontace is mandatory before posting; the account can be seen from each document. | Zakázky and projects as linkable dimensions | not found (third-party tools) | ISDOC through the UI, REST and a mailbox, all into one received-invoice record | documented |
| Helios iNuvio | The journal shows entries generated from other modules' primary documents. | Kontace: a shared list used across modules | Zakázky, a separately priced module | Travel (Doprava), feeding payroll and cash | ISDOC through the rpISDOC plugin | documented |

**What this shows for Afframe's rulings:**

- **Invoices and bank when Accounting is sold alone.** Three patterns exist:
  - Accounting owns invoices outright, and other products create them through it: Xero, and POHODA, whose accounting product contains the invoice agendas. Money, ABRA and Helios sell invoicing and accounting as modules of one suite, with the journal fed from the invoice records.
  - Business modules own invoices, and accounting derives the journal: Oracle and SAP Business One.
  - The two are sold together, so accounting never runs alone: Acumatica.

  None of the examined products was found to sell a ledger alone while leaving invoices to separately sold products. For Oracle and Unit4, this rests on NOT FOUND. Section 6.8 follows the first pattern, with one change: the invoice belongs to its business domain rather than to Accounting, and Accounting sold alone ships the features to register it.
- **Chart of accounts.** Every vendor where it was found (not Unit4) has one chart owned by the ledger, mapped to other records by rules: account determination, předkontace, kontace, item and vendor defaults. ABRA Flexi shows the account from each document. This supports the ruling in 6.6.
- **Projects.** Oracle (search-derived), Acumatica, Xero and Helios (a separately priced Zakázky module) sell projects separately; for Unit4 it was not found. POHODA and ABRA treat them as a tagging dimension. Xero Projects owns tasks, time and budgets but no ledger records. That matches ruling D1 with the project identity kept on the platform.
- **Expenses.** Oracle, Xero and Acumatica put claims and cards on the finance or payables side. Money and Helios tie travel expenses to payroll. Hleb's ruling puts them on the spend side.
- **E-invoice intake.** Xero converges every source on one set of core records. The Czech tools have one import path per format, ISDOC first. None of them documents EN 16931 as the pivot model. Section 7.7's single intake layer with EN 16931 semantics is a design choice, not an observed pattern.


### 3.4 Where Sales, CRM, Projects and Documents sit (25 products)

Evidence: [`module-evidence/`](module-evidence/), one file per group, each claim labelled. Finto could not be identified. Several products are narrow tools (Abacum, Numeric, Truewind, Concourse, ProcIndex, Cranston, Brex, Ramp) that own no sales records and read an ERP instead.

| Product | Sales documents owned by | CRM | Projects | Documents module | Contacts |
| --- | --- | --- | --- | --- | --- |
| Odoo | `sale` (orders), `account` (invoices); POS has its own order | separate app, no reference to sales orders; a bridge app links them | owns tasks, money via analytic accounts | Enterprise only | one shared `res.partner` |
| ERPNext / Frappe | Selling (quotes, orders), Accounts (invoices, also without an order) | built-in module; Frappe CRM is a separate app linked by API | owns projects, tasks, timesheets; no project invoices | generic `File` | shared |
| SAP S/4HANA | SD (quote, order, billing document); FI derives the ledger | separate product (Sales Cloud), hands won deals to SD | PS owns WBS, billing plans, settlement | NOT FOUND | one Business Partner |
| Dynamics 365 | two chains: D365 Sales and Finance/SCM, synced by dual-write with an ownership field; free-text invoice for no-order and asset sales | D365 Sales owns leads, opportunities and its own quotes and orders | Project Operations owns records | NOT FOUND | two masters, synced |
| NetSuite | one transaction family for CRM, POS, e-commerce, subscriptions and asset disposal | owns leads, opportunities, cases; links to transactions | project is an entity | File Cabinet, linked to any record | one entity master |
| Workday | Financials (contract, billing schedule, invoice) | none; "works with your CRM application" | basic projects are only worktags | NOT FOUND | NOT FOUND |
| Xero | Accounting (quotes, invoices) | none | owns tasks and time; billing stays in Accounting | Files API, linked to any object | one shared `Contacts` |
| QuickBooks | core (estimate, invoice, sales receipt) | Customer Hub on the shared customer record | a tag and dashboard only | NOT FOUND | one customer record |
| Midday | invoices (customer optional; free-text name allowed) | none | owns tracker projects and entries | Vault | shared `customers` |
| HELIOS | Obchod (quotes, orders), Fakturace (invoices), POS module | separate module | zakázky as a dimension | NOT FOUND | shared register |
| Doss | Order Management, for every channel | Relationship Management hands off to it | owns budgets, job costing, milestones | NOT FOUND | inferred shared |
| Rillet, Campfire | contract and invoice after closed-won | external only | none | attachments | NOT FOUND |
| Fineract | loans and savings; accounting derives GL by product mapping | none | none; office and fund are dimensions | `Document` linked to any entity | clients |
| Airtable | whatever table the builder chooses | a table | a table | attachment fields | one table linked within a base; across bases only by copying |

**What this shows:**

- **Sales documents are not CRM's.** CRM owns relationships and the pipeline before a commitment. A won deal is handed to a sales or order domain. The only exception, Dynamics 365, keeps two full sales chains and needs an ownership field to reconcile them.
- **Every sales channel lands in one sales document family.** CRM deals, tills, e-commerce, subscriptions, one-off invoices to parties that are not in the CRM, and asset sales (NetSuite, Dynamics, Midday, ERPNext).
- **Projects is either a dimension (QuickBooks, Workday basic projects, HELIOS) or an owner of delivery records** (SAP, Dynamics, Xero, Odoo, ERPNext, Doss). No product makes Projects own invoices.
- **Documents, where it exists, is one generic file record linked to any record** (Xero, Midday, NetSuite, Fineract).
- **Contacts are usually one shared list.** Split lists (Dynamics, Frappe CRM, Brex, Ramp) need syncing.
- **Private relationship management exists in none of them.**

---

## 4. The alternatives

1. **Generic documents plus a statutory GL** (NetSuite-like). One document table with line links; the ledger is posted from it.
2. **A common writable exposure or movement model** (writable `financial_effects`, SAP 0E, ERP5). The strongest version: every module writes effects through one shared rule library, changes are obsolete + reversal + new (SAP), divergences are resolved by solvers (ERP5), and flows can be rebuilt (SAP One Exposure).
3. **Typed records + links + derived positions.**
   - Derived **per report**: the rejected join approach. ERPNext's per-check valuation shows why.
   - Derived **once, into a stage contract**: the recommendation.
4. **Planning cube beside actuals** (Anaplan-like).
5. **Peppol as the internal core.** Rejected by Hleb (line 4824) and by the evidence: Peppol has no commitments, budgets, payroll, ledger derivation, bank reconciliation or planning.
6. **Hybrid (recommended).** The eight parts in section 1.

A variant of 1 deserves a note: **multi-book** (NetSuite) keeps a statutory and a management book over the same transactions. It separates two accounting views of *posted* facts; it does not give requests, orders, time or plans a place, so it answers R3 only for actuals.

**The brief's four questions per alternative** (cells for 1, 2, 3a and 4 are this report's inference from the evidence in 3.1):

| Question | 1 Generic documents + GL | 2 Writable effects (steelman) | 3a Joins per report | 4 Planning cube | 6 Hybrid |
| --- | --- | --- | --- | --- | --- |
| Where the truth lives | one generic document table; meaning per type in code | typed records **and** the effects table: the truth lives twice | typed records | the cube for plans; actuals imported | typed records only; plans in the plan store |
| How an estimate is replaced or partly fulfilled | per report or per posting rule | each writer writes a relief effect through the shared library | each report recomputes it | not modelled; actuals overwrite the forecast cells | one relief rule over quantity links, derived |
| How users correct mistakes | reverse the document | obsolete + reversal + new effect rows (SAP) | edit the record; reports follow | edit the cell | reverse or correct the record; the projection follows |
| Reports aggregate common dimensions without custom logic | no, link meaning is coded per report | yes | no, per dashboard | yes, for what is in the cube | yes: one `GROUP BY` shape |
| Main risk | weak per-type validation | drift if one writer relieves wrongly; history before activation (SAP 0E) unless rebuilt | the same number computed differently per report | blind to documents and commitments | read cost at scale (6.9) |

**Stress tests: alternative 2 vs 3a vs 6** (cells for 2 and 3a are inferred; 6 is built in the prototype)

| Case | 2 Writable effects | 3a Joins per report | 6 Hybrid (prototype) |
| --- | --- | --- | --- |
| Request → several orders, partial deliveries | each writer relieves | per report | 10 frames → orders for 6 and 2, 1 from stock, 1 open at the 30,000 estimate |
| Changed price (order ≠ estimate, invoice ≠ order, corrective invoice) | each writer | ERPNext misstates the remainder | relief at the predecessor price; variance lands in `actual` (VB3 +1,000, VB2C +2,000) |
| Supplier accepts less, at a new price | obsolete + reversal + new (SAP); divergence solver (ERP5) | per report | PO5 50 × 1,000 → accepted 40 × 1,050: committed 50,000 → 42,000 |
| Invoice disputed or rejected | the writer waits for acceptance, or writes and reverses | per report | VB3 counts only from acceptance; the rejected duplicate VB6 never counts |
| Advance before delivery | two writers | per report | PO5 advance of 25,410 keeps the order's cash exposure at 50,820 throughout |
| Self-billing | n/a | n/a | VB5 issued by us under a self-billing agreement; stages unchanged |
| Services without receipt | each writer | per report | the invoice relieves `committed` |
| VAT, both reverse-charge directions | columns needed | per report | net cost, gross cash, self-assessed VAT nets to zero |
| Stock | natural | per report | replenishment is not project cost; stock issue at valuation |
| Split payments, payroll in 2 transfers | works | works | rounding to the cent; relief once per allocation |
| Timesheet → payroll | payroll writes a true-up | not found | incurred at 500/h, actual at 550 and 530/h |
| Scenarios | double-count risk if plans share the table | per report | the plan remainder only |
| As reported then | if append-only | rebuilt per report | `effective_on` × `recorded_on`, provided every rule input (rates, probabilities, response terms) is insert-only or versioned |

---

## 5. Challenge to the common-framework preference

The evidence does not forbid one writable object: SAP 0E works, and the steelman alternative 2 produces the same numbers as the hybrid when every writer relieves correctly. What it costs is that the truth lives twice, and every writer is responsible for relief. The real choice is between deriving effects on read and storing them regenerated from the same rule library (6.9); the hybrid starts with the first and keeps the second open.

What the shared layer adds beyond conformed dimensions and typed facts:

- **One relief rule.** SAP and ERPNext produce different numbers from the same documents because they relieve differently.
- **One stage vocabulary.**
- **Two time axes.**
- **A reconciliation boundary** to the ledger.
- **A controlled vocabulary for business outcomes**: order responses, invoice responses, roles and correction kinds, taken from Peppol.

If Afframe only needed budget-vs-ledger reporting, conformed dimensions plus a warehouse would be enough.

---

## 6. The model in detail

### 6.1 Records and owners

Owners are business domains, not products. A product is a sellable set of features over domain records (6.8).

| Part | Owner | Prototype |
| --- | --- | --- |
| Shared lists | Platform | `project`, `cost_center`, `category`, `counterparty`, `employee`; activities (činnosti) not built |
| Agreements (contracts, framework, self-billing) | Sales domain (customer side), spend domain (supplier side, self-billing) | `agreement` (the prototype has no side column, so only self-billing rows can be attributed) |
| Typed records: CRM | CRM | `opportunity`, `opportunity_outcome` |
| Typed records: Sales | Sales domain | `sales_order_line`, `customer_invoice_line` |
| Typed records: spend | Spend domain (expense claims and card transactions: not built) | `material_request_line`, `purchase_order_line`, `order_response(_line)`, `goods_receipt_line`, `supplier_invoice_line`, `invoice_response`, `supplier_advance_request` (proforma) |
| Typed records: Inventory | Inventory | `goods_receipt_line` without an order, `stock_issue_line` |
| Typed records: People | People | `timesheet_entry`, `payroll_run`, `payroll_cost_line` (payroll cost, with or without timesheets), `payroll_allocation` (re-attribution by time) |
| Typed records: Treasury | Treasury domain | `bank_account`, `bank_transaction`, `payment_allocation` (invoice, payroll, order or proforma advance), `bank_line_classification` (lines with no document: fees, interest, taxes, loans, own transfers), `expected_cash`, `advance_application` |
| Typed records: Accounting | Accounting | `internal_document(_line)`: opening balance, depreciation, accruals, WIP, FX, VAT settlement |
| Stage rules | Each domain, for its own records; always active | `position_crm`, `position_sales`, `position_procurement`, `position_inventory`, `position_people`, `position_treasury`, `position_accounting` |
| Helpers | Spend and Treasury domains | `order_response_terms` (each response re-values from the previous terms), `purchase_order_line_terms`, `supplier_invoice_approval` (when an invoice counts), `settlement_line` (splits with largest-remainder rounding) |
| Projection | Platform | `position_entry` (union of the domain views) |
| Plans (every budget, forecast, scenario and cash plan) | FP&A | `plan_version`, `plan_line` (optional project, optional cost center, family P&L or cash) |
| Ledger, chart, tax | Accounting | `account` (chart and category mapping), `journal_entry` (always from a source record), `journal_line`, `post_to_ledger` |

A successor's rule reads its predecessor's price. That coupling only produces rows when both records exist. Each link table belongs to the successor's domain.

### 6.2 Stage contract

**Cost**

| Stage | Created by | Relieved by |
| --- | --- | --- |
| expected | request line | order line or stock issue (at the request estimate) |
| committed | order line, not for stock | order response (to the accepted terms); goods receipt; services invoice (at accepted terms) |
| incurred | goods receipt; timesheet | counting supplier invoice (at accepted terms); payroll allocation |
| actual | counting supplier invoice (not for stock); stock issue; payroll allocation | never, only reversed |

**Revenue**

| Stage | Created by | Relieved by |
| --- | --- | --- |
| expected | opportunity (with probability) | opportunity outcome |
| committed | sales order line | customer invoice linked to it |
| actual | every customer invoice line | never, only reversed |

**Cash**

| Stage | Created by | Relieved by |
| --- | --- | --- |
| forecast | order lines (including stock), order response, sales order lines, timesheets | counting invoices; payroll allocation; advance paid (handed back when the advance is applied) |
| open | counting invoices; payroll allocation; advance application reduces it | settlement |
| settled | bank settlement of invoices, payroll or advances | never |

**What "counting" means:** a supplier invoice counts from registration, or, when it needs approval, from our first AP or CA invoice response. RE is terminal and allowed only before acceptance. Payments and advance applications count only against counting invoices.

These are **our own policy rules**, stricter than Peppol. Peppol only forbids responses after RE or PD, and anything other than PD after AP. Counting a CA ("conditionally accepted") invoice at full value is one such policy. These are workflow rules; the prototype's choices are samples, not architecture.

**Asserted in `checks.sql`:**

- **Cost and revenue stages.** Every stage per project equals the open remainder computed directly from typed records.
- **Cash.** Settled equals the bank. Open equals unpaid counting documents and payroll.
- **Fulfilment** never exceeds the obligation: requested, accepted, received and billed quantities.
- **Settlement** never exceeds the debt; any excess must be a recorded advance.
- **Advance applications** never exceed the advance, and apply only to counting invoices.
- **Request links** never exceed the quantity the supplier accepted.
- **Order responses** come before any receipt or invoice on the order.

### 6.3 Relief valuation

A successor relieves *linked quantity × predecessor price* and books its own amount in its own stage. The variance sits in the later stage.

- **Price.** "Predecessor price" means the accepted order terms after the supplier's response, not the original order price.
- **Accepted terms are current state.** Only the latest response counts. The checks therefore require every response to come before any receipt or invoice. A change after partial delivery needs versioned terms, i.e. a re-valuation entry dated by the change: SAP's obsolete + reversal + new pattern. Not built.
- **A cut order line.** When a response cuts an order line below the request quantity linked to it, Procurement must write a negative fulfilment so the difference returns to the request. The check enforces links ≤ accepted quantity, but the negative-fulfilment record is not built.
- **Advances.** An advance is spread over its order lines by ordered value, so a later rejection can't zero the basis. If the order is rejected or the advance exceeds the final invoice, the remainder shows as a forecast refund. A dedicated "unapplied advance" record is not built.
- **Example.** A request for 10 frames at 30,000, then an order for 6 at 32,000: `expected` −180,000, `committed` +192,000. The 4 frames still open stay at 30,000.
- **Closure.** A request or order closure record relieves the rest (described, not exercised).
- **Rejected quantities.** A quantity rejected at receipt stays committed until the order is changed or cancelled.
- **Stale remainders** need a closure policy, which is a workflow rule.

### 6.4 Corrections

The correction kinds follow the Peppol paper's taxonomy.

| Correction | Record | Stage effect | Prototype |
| --- | --- | --- | --- |
| Order change (buyer) or accepted change (seller) | order response / order change | committed re-valued to the new accepted terms | PO5 via CA response |
| Order cancellation | cancellation or closure | remaining committed relieved | described |
| Return after acceptance | negative receipt | incurred back to committed, or cancelled | described |
| Credit note / debit note / Czech corrective tax document (381, 383; ISDOC 2, 3) | new invoice document linked to the original | actual ± difference | VB2C +2,000 |
| Corrected invoice 384 (full replacement) | reversal of the original + the replacement document | actual replaced | described |
| Posted operational record wrong | reversal + new record | automatic | TS6 → TS6R + TS7 |
| Accounting reversal | new journal entry | ledger only | `post_to_ledger` inserts only |
| Settlement reversal / reapplication | reversal allocation | open ↔ settled | described |
| Bank reinterpretation | new allocation; the bank record is never changed | open ↔ settled | described |
| Correction into a closed period | reversal dated in the first open period | aligned with the ledger | described |
| Projection rule wrong | fix the rule and regenerate; published figures come from period-close snapshots | none | described |

**Czech law.** Act 563/1991 § 35(3), in force in 2026, requires the person, the moment, and the content before and after a correction to be determinable, and § 11(1)(f) requires a signature record of the responsible person. The architecture therefore records `recorded_on` as a timestamp and the actor (a person, or the system plus the approving person) on every record, response, reversal and journal entry. The prototype uses dates and no actor. A new Accounting Act takes effect no earlier than 1 January 2027 ([MF ČR](https://mf.gov.cz/cs/dane-a-ucetnictvi/ucetnictvi/nova-ucetni-legislativa-soukromeho-a-verejneho-sek/casto-kladene-dotazy-k-nove-ucetni-legislative/faq-k-ucetnictvi-soukromeho-a-verejneho-sektoru)).

### 6.5 Plans, forecasts, scenarios

- **Plan versions** are budget, forecast or scenario, on the same dimensions as positions.
- **Consumed:**
  - cost = expected + committed + incurred + actual
  - revenue = committed + actual (pipeline is not consumed)
- **Remaining plan** = max(plan − consumed, 0). **Estimate at completion** = consumed + remaining plan.
- **Scenarios** move only the uncommitted remainder.
- **Sample policy.** Automatic consumption hides cost underruns and revenue losses. A manager's cost-to-complete would be a different writer of the same plan lines.
- **Owner.** FP&A owns every plan, including project budgets. Projects is a product over FP&A's project financial control and the shared project list, so a project budget exists once.
- **Period.** Project control compares whole-life figures. Opex needs a period-bounded variant.

### 6.6 Ledger and reconciliation

- **Posting.**
  - Accounting posts from typed records only, and posts supplier invoices when they count.
  - Advances are booked Dr 314 / Cr 221, and their application Dr 321 / Cr 314. VAT on advances is not modelled.
  - Czech law says nothing explicit about booking a disputed received invoice, so posting on registration versus on approval is a workflow policy. The prototype posts on approval.
- **Reconciliation.** For each project (or none) × category × month, projection `actual` must equal the ledger. Reason codes cover:
  - posting timing
  - ledger-only accruals
  - work in progress

  `incurred` never reconciles, by design.
- **Chart of accounts.** One chart for every product, owned by Accounting.
  - Every typed record line carries a category. Accounting's account determination maps it (plus record facts such as "for stock") to an account.
  - The chart and the determination rules are reference data. They ship with every product and are read-only outside Accounting, so any record can show which account it will hit.
  - Each journal entry points back to its source record (`source_type`, `source_id`).
  - Only Accounting edits the chart and only Accounting posts, so the statutory books stay separate from management views.
  - This concrete form is this report's proposal.
  - **Built:** the category mapping in `account` and the trace from a journal entry back to its source.
  - **Not built:** one determination function shared by posting and by record views. `post_to_ledger` still hardcodes 112, 311, 314, 321, 331 and 343.
- **Actual-source rule.** Each actual amount has one source record. Documents held in Afframe feed `actual`. Imported external ledger lines feed `actual` only when no Afframe document carries the same source reference: the other party's identity (its VAT ID in practice) plus the document number.

### 6.7 VAT and Czech rules

| Rule | Status and effect in the model |
| --- | --- |
| **Rates** (§ 47): 21 % and 12 % | verified |
| **Reverse charge** (§ 92e), CZ-CPA 41 to 43 between VAT payers | verified. Both directions in the example: our fit-out sales carry no VAT; the subcontractor invoice VB4 carries no VAT, and we self-assess 18,900 and deduct it in the same entry. |
| **Deduction** (§§ 72, 73): from the period in which the tax document is held | VB1, dated 31 March and received 3 April, belongs to the April return. A separate VAT claim date is needed; it is not in the prototype. |
| **Advances** (§ 20a): VAT is due when an advance is received (official). The proforma is not a tax document, and there is no tax point under reverse charge (both third-party only). | the prototype models the advance's cash and ledger effect, not its VAT timing |
| **Self-billing** (§ 28(10)): an arrangement (ujednání) that must be provable on request, no written form required (official). VAT Directive Art. 224 also requires a procedure where the supplier accepts each self-billed invoice; the architecture expresses that as the supplier's response on the self-billed invoice (not built). | modelled as an `agreement` of kind `self_billing` and checked. Not used for reverse-charge supplies because that combination was not verified. |
| **Model conventions** | cost and revenue are net + non-deductible VAT; cash is gross; deductible VAT is company-level. SAP's net cash is an alternative policy. |

### 6.8 Sellability

- Every domain contributes a view for its own records only. Selling another product adds features and records, never rules, and never moves a record.
- Cash is company-wide, and project is a filter.
- **Spend and employee expenses** belong to the spend domain, not to People. An expense claim or a card transaction is a spend cost record, and Treasury settles it (repays the employee or clears the card statement). The Treasury line only settles; it never carries the cost a second time. People keeps timesheets and payroll. Not built.
- **Tax** (VAT returns, control statement) is part of Accounting.

**Domains own records, products add features.**

Each domain owns its record types:

- the spend domain owns supplier invoices
- the Sales domain owns customer invoices
- the Treasury domain owns bank transactions
- Accounting owns the ledger and the chart

A product is a sellable set of features over those records. Records never move between products. Installing a product never takes a record over. It adds features, and new record types that link to the existing records.

- **Accounting sold alone** ships the minimum it needs from other domains:
  - registering received and issued invoices, importing bank statements, and matching payments
  - on the same supplier invoice, customer invoice and bank records the other products use
  - its journal entries point to those records (`source_type`, `source_id`)
  - without Procurement there is no approval feature, so an invoice counts from registration
- **Adding Procurement** adds requests, orders, supplier responses, receipts and invoice approval.
  - New invoices link to orders and receipts.
  - Invoices registered earlier stay exactly as they are, with their payments and journal entries.
  - Adding Sales or Treasury works the same way: sales orders; payment orders, advances and the cash forecast.
- **One source per amount.** Each document kind has one record type, so an invoice exists once whichever products are sold. The prototype refuses the same supplier document number from the same supplier twice, and our own invoice numbers are unique.
- **Evidence (3.3).**
  - Xero works this way: its Projects and Expenses add-ons link to or create the same core invoice and bank records.
  - The Czech tools keep invoice and bank agendas in one product and feed the journal from them. ABRA Flexi calls the journal "a view over the line items of all accounting documents".
  - Oracle and SAP Business One separate business documents from the journal, but do not sell the journal alone.
- **Czech law.** The invoice stays the business record, and the journal entry links to it.
  - Act 563/1991 § 11(1) lets the facts of one accounting document sit in several accounting records, and "in these cases the accounting record and the accounting document must contain an identifier by which their link can be unambiguously determined" ([zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/1991-563), official, version in force in 2026).
  - A new Accounting Act is planned (6.4), so the citation must be rechecked against it.
- **Contracts** stay in the Sales and spend domains. Accounting does not need them to post.
- **Built and checked** (`checks.sql`):
  - An invoice with no order or receipt is exactly what Accounting sold alone produces. CI3 in the worked example is one: it counts once, posts and reconciles to the ledger.
  - The VX1 probe is a supplier invoice without an order that still takes an advance.
  - Registering a supplier's document number a second time is refused by a constraint (mutation I).

### 6.9 Physical options

| Option | Drift | Cost | Notes |
| --- | --- | --- | --- |
| View (prototype) | none | read cost | simplest |
| Stored, regenerated per source record | none if CI tests hold | write path | equality test plus generic invariant |
| Period-close snapshot | none | small | needed for "as published" |

---

## 7. Peppol / UBL / EN 16931 as the reference domain layer

### 7.1 How it is reused

Following Hleb's rule (line 4824), Peppol is used to find **which business facts, roles, outcomes and dependencies must exist**, not to shape tables or limit the platform to what fits in a message. Each concept is used in one of four ways:

- **Adopted as a record type**: order response, invoice response, self-billing, advance.
- **Adopted as a controlled vocabulary**: response codes, invoice type codes, party roles, reference kinds.
- **Adopted as validation**: the EN 16931 amount rules.
- **Recorded as an external boundary**: ISDOC and Peppol documents map to and from typed records. A document being valid externally never means it is approved internally.

### 7.2 Domain map

The domain groups come from the Peppol paper; the owners are this report's proposal.

| Domain (paper) | Owner proposal | In prototype | Peppol / UBL reference |
| --- | --- | --- | --- |
| Identity and governance: parties, roles, periods, currencies, audit, validation profiles | Platform | parties, agreement kinds | party roles, EN 16931 rules |
| Market and sourcing: opportunities, RFQ, quotations | CRM (sell side), Procurement (buy side) | opportunities | UBL RFQ/Quotation; pre-award is outside Peppol post-award |
| Catalogue and offering | Platform reference data | item text only | Catalogue 3.1 with response |
| Agreement: contracts, framework, call-offs, self-billing | Sales domain (customer side), spend domain (supplier side) | self-billing agreement | Order Agreement 3.0, Self-billing 3.0 |
| Ordering: orders, responses, changes, cancellations | Sales, Procurement | order + CA response | Ordering 3.3, Advanced Ordering 3.0 |
| Operations: projects, work, milestones, acceptance | Sales (billing milestones), People (time), FP&A (project financial control); delivery management is out of scope | timesheets | weak in Peppol |
| Fulfilment: despatch, receipt, rejects, returns | Inventory / Procurement | receipts | Despatch Advice 3.1; Receipt Advice in Logistics |
| Logistics | Out of scope for now | none | Logistics profiles |
| Billing: invoices, credit and debit notes, self-billing, disputes | Sales domain (issued), spend domain (received); Accounting sold alone registers them in the same records (6.8) | invoices, corrective document, invoice responses | Billing 3.0, Self-billing 3.0, Invoice Response 3.2 |
| Financial control: budgets, reservations, commitments | FP&A (budgets) + projection (commitments) | plan store, stages | not in Peppol |
| Accounting | Accounting | ledger | not in Peppol |
| Receivables and payables | Accounting (subledger) + projection (`open`) | open stage | invoice due data, BT-113 |
| Settlement: payments, advances, offsets, write-offs | Treasury | allocations, advance application | UBL RemittanceAdvice (no Peppol profile) |
| Treasury: expected cash, payment orders, bank, reconciliation | Treasury | forecast and settled stages | not in Peppol |
| Planning | FP&A | plans, scenarios | not in Peppol |
| Attribution and analytics | Platform projection + FP&A | projection, reports | BT-19 buyer accounting reference, BT-11 project |

### 7.3 Party roles

UBL / Peppol names the roles:

- Ordering: Buyer (`BuyerCustomerParty`), Seller (`SellerSupplierParty`), Originator, Delivery party / consignee.
- Billing: Accounting customer / supplier, Payee (e.g. factoring), Tax representative.

**Rule:** a party's identity is platform data; its role is per document.

- **Built:** the self-billing issuer. VB5 is issued by us under agreement AG-B, and the check requires a valid agreement (Czech § 28 requirement).
- **Described:**
  - a payee different from the seller (factoring)
  - a payer different from the customer (a parent company pays)
  - an originator different from the buyer
  - a delivery party different from the buyer

### 7.4 Link types

The paper's 13 dependency types map to implementation as follows.

| Dependency | Implementation |
| --- | --- |
| Predecessor | foreign key on the successor line: receipt → order line; invoice → receipt or order line; invoice → sales order line |
| Fulfilment | `request_fulfilment`, receipt quantity |
| Claim | invoice lines |
| Match | **implicit**: the invoice line's foreign key to receipt or order, plus the invoice response. There is no separate match record. |
| Allocation | `payroll_allocation`, `settlement_line` (largest remainder) |
| Derivation | stage rules (projection), posting rules (ledger) |
| Correction | `reverses_id`, `corrects_line_id`, order response |
| Settlement | `payment_allocation`, `advance_application` |
| Reconciliation | **implicit**: bank ↔ allocation via `payment_allocation`; projection ↔ ledger as a check, not a record |
| Agreement | `agreement` (self-billing built; contract and framework described) |
| Role | per-document role columns (issuer built; others described) |
| Attribution | project and category on lines (direct), payroll allocation (allocated) |
| Inference | **not stored as fact**. Suggested matches must stay separate until confirmed. |

Transitive ancestry (e.g. invoice → contract through the order) is derived, never stored. That is Hleb's line 780 rule.

### 7.5 Responses and business outcomes → money effects

| Peppol concept | Money effect | Prototype |
| --- | --- | --- |
| Order response AB | none | allowed code |
| Order response AP | none; the order stands as sent | default when there is no response |
| Order response CA (lines changed) | committed and cash forecast re-valued to the accepted quantity and price; later receipts and invoices relieve at accepted terms. `order_response_line` mirrors the Peppol CA line structure. That is our choice, not a requirement. | PO5: 50,000 → 42,000 |
| Order response RE | committed and forecast relieved in full | allowed code |
| Order change / cancellation (Advanced Ordering) | same as a response / closure | described |
| Order agreement (seller records an order made outside our process) | creates the order and commitment at the agreed terms | described |
| Despatch advice (outstanding quantity) | no money stage; could move forecast dates | described |
| Receipt with rejected quantity | only the accepted quantity counts; the rest stays committed | described |
| Invoice response UQ / IP / AB | the invoice does not count yet (when approval is required) | VB3 queried on 6 April |
| Invoice response AP / CA | the invoice counts from this moment: relief, actual, open, ledger | VB3 counts from 12 April |
| Invoice response RE (terminal) | never counts; the supplier must issue a credit note if anything was posted | VB6 duplicate, no effect anywhere |
| Invoice response PD | information only; payment facts come from the bank | allowed code |
| Invoice response ordering (OP-BR111-R012, R004, R005) | none; an exchange rule for outbound responses, separate from the internal counting policy | not enforced |
| Prepayment invoice 386 / paid amount BT-113 | 386 is the advance request (Czech zálohová faktura, not a tax document). Advance paid → settled, and relieves the order forecast; the final invoice's open amount is reduced by the applied advance (BR-CO-16) | PO5: advance 25,410, VB7 50,820, balance 25,410 |
| Czech tax document for a received payment (daňový doklad při přijetí platby, ISDOC type 5) | no EN 16931 type code; needs a national extension. A typed record on the Sales side (advances received) and the spend side (advances paid) that carries base and VAT per rate, feeds VAT but not cost or revenue `actual`, and is deducted per rate on the final invoice | described, not built |
| Self-billed invoice 389 / credit note 261 | stages unchanged; issuer role and agreement required | VB5 |
| Credit note 381, debit note 383, Czech corrective tax document (opravný daňový doklad, ISDOC types 2 and 3) | difference documents (6.4) | VB2C |
| Corrected invoice 384 (Germany only in Peppol) | a full replacement: reverse the original and register the replacement | described |
| Remittance advice (UBL only) | explains a payment's split, i.e. input for `payment_allocation` | described |

### 7.6 EN 16931 rules applied internally

Apply BR-CO-10, BR-CO-13, BR-CO-15 and BR-CO-16 to every invoice, whether exchanged or not:

- line sum
- total without VAT = lines − allowances + charges
- + VAT
- amount due = total with VAT − paid amount + rounding

The prototype has no document-level allowances, charges or rounding, so these are specified here but not exercised.

EN 16931-1 was revised in May 2026, and the 2017 version stays compliant during migration. Validation profiles should carry their version (paper: "specification versions" under Identity and governance).

### 7.7 External boundary: ISDOC, Peppol, ViDA

- **ISDOC** 6.0.2 is the Czech national format in daily use between accounting systems. Contracting authorities must accept EN 16931 e-invoices in UBL 2.1 or CII (Act 134/2016 § 221); central state bodies also accept ISDOC ≥ 5.2 (Government Resolution 347/2017).
- **ViDA.** From 1 July 2030, new VAT Directive Art. 218 makes electronic invoices to the European standard the default for all invoices; Member States may still accept other formats for transactions outside the reporting obligations. New Art. 232: EN 16931 invoices "shall not be subject to acceptance by the recipient", so the intake layer must accept them technically. No Czech domestic B2B mandate was found.
- **Mixed input.** One intake layer handles every inbound source: Peppol (UBL, CII), ISDOC, other national XML, e-mailed PDF and scans.
  - Each format maps to EN 16931 semantics (the BT business terms) **plus a declared Czech extension** at the boundary: document kind (including ISDOC types 1 to 7), taxed-advance deductions per rate with their reference, the reverse-charge commodity code, the source document's UUID and the channel. Simplified documents may be incomplete, with the missing terms marked. From there it maps to the typed record of the owning domain, whichever products are sold.
  - EN 16931 is the boundary vocabulary, not the internal schema (line 4824).
  - The original file is kept as evidence in the Documents domain. Each document is registered once (6.8).
  - **Registration key.** Received documents: the issuer's legal-entity identifier (IČO or a foreign equivalent, not the VAT ID, which a VAT group shares) plus the document number normalised as the tax office does (case-folded, separators and leading zeros removed), with the original number stored verbatim for the control statement. A same-issuer, same-amount, same-date document with a different number form is a suspected duplicate for review, not a conflict. Issued documents: issuer plus number, so a customer that self-bills us can be registered. The prototype keys on counterparty plus raw number only.
  - Fields extracted from PDF or scans are inferred until a person or a rule confirms them. That needs the suggestion store listed as not built in 7.9.
  - Outbound runs the other way: typed record → EN 16931 semantics → Peppol or ISDOC.
- **Rule.** Inbound and outbound documents map to and from typed records at the boundary. An inbound invoice creates a supplier invoice that still needs our acceptance (external validity ≠ internal approval). A Message Level Response (technical receipt) is not an Invoice Response (business decision).

### 7.8 What Peppol does not cover

These come from the ERP patterns in 3.1 and from the prototype, not from Peppol: commitments and relief, budgets, payroll costing, ledger derivation, bank reconciliation, the cash forecast, planning, management allocation and project costing. Remittance has no Peppol profile.

### 7.9 The Peppol paper's 12 invariants vs this model

| Invariant (paper) | Status here |
| --- | --- |
| Every business fact has one authoritative domain | designed (6.1); in the prototype `agreement` has no side column |
| Accounting results are explainable through an approved source | built: journal `source_type`/`source_id`; invoices post when they count |
| Posted accounting is not silently mutated | built (insert-only posting) |
| A correction identifies what it corrects | built (`reverses_id`, `corrects_line_id`, response → order) |
| Splits and merges conserve quantity and money, with explicit rounding | asserted (largest-remainder rounding probe) |
| Fulfilment cannot exceed the obligation without an accepted exception | asserted (requests, orders, receipts, request links ≤ accepted); **no exception record type**, so the check simply fails |
| Settlement cannot exceed the obligation without a recorded advance or unapplied amount | asserted (invoices, advances) |
| Analytical projections are not transactional authorities | built (view, no writers) |
| Inferred relationships are distinguishable | **not built**: no inferred links are stored; a suggestion store is needed if matching is automated |
| Every combined fact declares its stage and grain | built (`family`, `stage`, `source_type`) |
| Replaced or fulfilled stages are not counted as open | asserted (generic invariant) |
| External message validity ≠ internal approval | built (invoice approval gate, order commitment follows acceptance) |

---

## 8. Worked example

Every number below is copied from `checks.sql` output on PostgreSQL 18.6. The run ends with `ALL ASSERTIONS PASSED` (146 assertions, including regression probes run in rolled-back transactions).

### 8.1 Stored records (project P1, fit-out for Client X; CZK)

| Record | Content | Dates (effective / recorded) |
| --- | --- | --- |
| OPP1, OPP2 | inquiries: 1,000,000 at 0.60 (won → SO1); 150,000 at 0.50 (still open) | 02-02 (won 03-05); 04-10 |
| SO1 | milestones 400,000 / 300,000 / 300,000; reverse charge | 03-05 |
| CI1, CI2, CI3 | M1 400,000; M2 300,000; extra works 50,000 without an order line | 03-31, 04-30, 05-25 |
| MR1 | 10 steel frames at an estimated 30,000 | 03-10 |
| PO1, PO2 | Supplier A 6 at 32,000; Supplier B 2 at 29,000 (21 % VAT) | 03-12, 03-20 |
| PO3 | Subcontractor C: 100 % of partition works at 1,500 per %, reverse charge | 03-25 |
| PO4 | Supplier B: 2 frames **for stock** at 28,000 | 05-18 |
| PO5 + OR5 | Supplier A: 50 m² insulation at 1,000, 14-day terms; **response CA: 40 m² at 1,050** | 04-20; 04-21 |
| ISS1 | 1 frame from stock at 27,500 | 04-20 |
| request_fulfilment | MR1 → PO1 6, PO2 2, ISS1 1; 1 frame still open | |
| GR1…GR5 | PO1 4 + 2; PO2 2; PO4 2 into stock; PO5 40 m² | 03-25, 04-08, 04-02, 05-20, 05-10 |
| VB1 | 4 × 32,000 + 26,880 VAT | 03-31 / **04-03** |
| VB2, VB2C | 2 × 32,000; corrective +2,000 + 420 VAT | 04-15; 04-28 |
| VB3 | 2 × **29,500** against an order at 29,000; **needs approval: UQ 04-06, AP 04-12** | 04-05 |
| VB4 | subcontract 60 % = 90,000, no VAT (self-assessed 18,900), no receipt | 04-30 / 05-04 |
| VB5 | stock purchase 56,000 + 11,760 VAT, **self-billed by us** under agreement AG-B | 05-22 |
| VB6 | duplicate of VB2 from Supplier A, **rejected (RE 05-27)** | 05-25 / 05-26 |
| VB7 | PO5: 40 × 1,050 = 42,000 + 8,820 VAT, due 05-26 | 05-12 |
| BT5, AA1, BT6 | advance 25,410 (50 % of accepted gross 50,820) paid 04-25; applied to VB7 on 05-12; balance 25,410 paid 05-26 | |
| TS1…TS7 | E1 at 500/h: P1 40 h (Mar), 80 h (Apr), 6 h (May); internal 80 h; P2 120 h; TS6 reversed and rebooked on P2 | |
| Payroll | March 88,000 (550/h) paid in 2 transfers; April 84,800 (530/h) | |
| BT1, BT2, BT3 | +550,000 (CI1 + part of CI2); −234,740 (VB1 + VB2 + VB2C); −40,000 (part of VB3) | 05-20, 05-15, 05-05 |
| B1, S1 | budget: revenue 1,000,000; materials 350,000; subcontracting 150,000; labour 120,000. Scenario S1: labour +25 % | |

### 8.2 Positions for P1 on 31 May 2026

| family | category | expected | weighted | committed | incurred | actual | forecast | open | settled |
| --- | --- | --: | --: | --: | --: | --: | --: | --: | --: |
| cost | materials | 30,000 | 30,000 | 0 | 0 | 322,500 | | | |
| cost | subcontracting | | | 60,000 | | 90,000 | | | |
| cost | labour | | | | 3,000 | 64,400 | | | |
| revenue | revenue | 150,000 | 75,000 | 300,000 | | 750,000 | | | |
| cash | materials | | | | | | 0 | −31,390 | −325,560 |
| cash | subcontracting | | | | | | −60,000 | −90,000 | |
| cash | labour | | | | | | −3,000 | 0 | −64,400 |
| cash | revenue | | | | | | 300,000 | 200,000 | 550,000 |

Materials across all stages come to 352,500, with no unit counted twice:

| Item | Amount |
| --- | --: |
| 6 frames × 32,000 | 192,000 |
| corrective invoice VB2C | 2,000 |
| 2 frames × 29,500 | 59,000 |
| 1 frame from stock | 27,500 |
| 40 m² insulation × 1,050 | 42,000 |
| 1 frame still open at the 30,000 estimate | 30,000 |
| **Total** | **352,500** |

### 8.3 Budget control and estimate at completion

| category | plan | consumed | available | remaining plan | EAC (B1) | EAC (S1) |
| --- | --: | --: | --: | --: | --: | --: |
| revenue | 1,000,000 | 1,050,000 | −50,000 | 0 | 1,050,000 | 1,050,000 |
| materials | 350,000 | 352,500 | −2,500 | 0 | 352,500 | 352,500 |
| subcontracting | 150,000 | 150,000 | 0 | 0 | 150,000 | 150,000 |
| labour | 120,000 | 67,400 | 52,600 | 52,600 | 120,000 | 150,000 (remaining 82,600) |

The supplier's price change on PO5 shows up as a materials overrun of 2,500 before any invoice arrives.

### 8.4 Project P&L (management)

| revenue actual | cost actual | cost incurred, not booked | margin to date | margin at completion (B1) |
| --: | --: | --: | --: | --: |
| 750,000 | 476,900 | 3,000 | 270,100 | 427,500 |

### 8.5 Budget vs actual by month

| category | month | budget | actual | incurred |
| --- | --- | --: | --: | --: |
| labour | 03 / 04 / 05 | 40,000 each | 22,000 / 42,400 / 0 | 0 / 0 / 3,000 |
| materials | 03 / 04 / 05 | 200,000 / 150,000 / 0 | 128,000 / 152,500 / 42,000 | 0 |
| subcontracting | 04 / 05 | 100,000 / 50,000 | 90,000 / 0 | 0 |
| revenue | 03 / 04 / 05 | 400,000 / 300,000 / 300,000 | 400,000 / 300,000 / 50,000 | |

### 8.6 "What was committed on 31 March?"

| view of March, P1 cost | expected | committed | incurred | actual |
| --- | --: | --: | --: | --: |
| as reported on 31 March | 60,000 | 272,000 (materials 122,000 + subcontract 150,000) | 148,000 | 0 |
| as known on 31 May | 60,000 | 272,000 | 0 | 150,000 (VB1 128,000 + payroll 22,000) |

### 8.7 Responses in time

- **PO5 committed.** 50,000 as known on 20 April (as ordered). 42,000 from 21 April (as accepted).
- **P1 materials incurred on 10 April.** 122,000 as known on 10 April: GR2 and GR3, because VB3 was under query. 64,000 as known on 12 April, after VB3 was accepted.
- **VB6 (rejected).** Zero positions and zero ledger entries.

### 8.8 Cash by cash date

| month | stage | P1 | company |
| --- | --- | --: | --: |
| 2026-04 | settled (includes the PO5 advance, −25,410) | −47,410 | −113,410 |
| 2026-05 | settled | 207,450 | 165,050 |
| 2026-05 | open: CI2 150,000; VB3 −31,390 and VB4 −90,000, both overdue | 28,610 | 28,610 |
| 2026-05 | forecast: subcontract remainder | −60,000 | −60,000 |
| 2026-06 | open: CI3 50,000; VB5 −67,760 (company only) | 50,000 | −17,760 |
| 2026-06 | forecast: M3 300,000; May hours −3,000 (P1), −4,000 (P2) | 297,000 | 293,000 |

- **Company settled** = 51,640, which equals the bank movements. Ledger bank = 551,640.
- **PO5's total cash exposure** is −50,820 on 30 April (advance paid, rest forecast) and on 31 May (all settled). The advance never double-counts.

### 8.9 Statutory ledger

| account | balance |
| --- | --: |
| 112 Material in stock | 138,500 |
| 221 Bank accounts | 551,640 |
| 311 Trade receivables | 200,000 |
| 314 Advances paid | 0 |
| 321 Trade payables | −189,150 |
| 331 Payroll liabilities (simplified) | 0 |
| 343 VAT (reverse charge nets to zero) | 73,710 |
| 501 Material consumed | 322,500 |
| 518 Services: subcontracted works | 90,000 |
| 521 Personnel costs (simplified) | 172,800 |
| 602 Revenue from services | −750,000 |
| 701 Opening balance account | −610,000 |

Account codes follow Czech chart groups and are illustrative only.

### 8.10 Reconciliation: management actuals vs ledger

Every row has zero difference:

| project | category | month | amount |
| --- | --- | --- | --: |
| none | labour | April | 42,400 |
| P1 | labour | March | 22,000 |
| P1 | labour | April | 42,400 |
| P1 | materials | March | 128,000 |
| P1 | materials | April | 152,500 |
| P1 | materials | May | 42,000 |
| P1 | revenue | March | 400,000 |
| P1 | revenue | April | 300,000 |
| P1 | revenue | May | 50,000 |
| P1 | subcontracting | April | 90,000 |
| P2 | labour | March | 66,000 |

### 8.11 Timesheet correction

P1 labour incurred in May: 7,000 as known on 27 May, 3,000 after the reversal on 28 May.

### 8.12 The checks have teeth

Exact diffs and outputs: [`mutations.md`](finance-model-prototype/mutations.md). D and F are now caught first by the independent cash check, and C is stated precisely, so their first failures differ from the earlier version of this report.

| Mutation | Caught by |
| --- | --- |
| A: invoice relieves `incurred` at invoice value | generic invariant, off by 1,000 |
| B: order relieves the request at order price | generic invariant, off by 10,000 |
| C: wage forecast and incurred relieved once per payroll payment | generic invariant, off by 80,000 |
| D: approval gate removed | company cash check, off by 154,880 |
| E: receipt ignores the accepted order price | generic invariant, off by 4,000 |
| F: advance application keeps its forecast relief | cash per project and category, off by 25,410 |
| G: advance spread by accepted instead of ordered value | projection fails with division by zero on a rejected order |
| H: advance application ignores the approval gate | the probe on an unapproved invoice finds the application counted |
| I: unique supplier document number dropped | VB1's number is accepted a second time |
| J: payroll cost posted only through timesheets | payroll without timesheets leaves the entry 50,000 out of balance |
| K: bank lines with no document ignored | settled 51,640 against a bank of 51,490 |
| L: payment matches posted once per bank line | a late match never reaches the ledger bank account (50,000) |
| M: invoice before receipt relieves committed twice | committed −10,000 instead of 0 |
| N: stock-order invoices stop relieving the cash forecast (the review's double count) | cash per project and category, off by 67,760 |
| O: reliefs take project and category from the successor | phantom forecast of 2,420 on another project |
| P: advance application leaves settled cash on the advance | P1 pays −605 instead of −1,210 on its own line |
| Q: only the latest supplier response re-values the order | as known on 22 April: committed 50,000 instead of 42,000 |
| (rounding probe) | 100 paid over three lines of 100 settles to the cent |

---

## 9. What would falsify this

1. **Important reports don't fit** `GROUP BY` over (family, stage, dimensions, dates) plus plan lines.
2. **Users don't capture links** (invoice to receipt or order) at the operational moment.
3. **The view is too slow**, and incremental maintenance grows as complex as a writable effects table.
4. **Pilot data won't reconcile** to the ledger without manual adjustments (work in progress 121/611, accruals, VAT coefficient).
5. **Controllers need frequent manual adjustments**, and the adjustment record grows into a general journal.
6. **Buyers never combine products.**
7. **An e-invoice exchange requirement** (ISDOC, Peppol, ViDA) cannot map onto typed records without losing a document-level meaning the ledger needs.
8. **Products sold alone need conflicting states on the shared invoice.** For example, a feature in one product needs the invoice to behave in a way that another product's feature forbids, and one record cannot serve both without per-product copies.
9. **Project money needs records that are not plans and not domain facts**, for example a project-level record that no existing domain can own, so Projects would need records after all.

---

## 10. The final architecture and Hleb's rulings

**Shared lists** (platform, not sold). Every domain tags its records with them, and none of them belongs to one product:

- parties (companies and people) and their roles
- projects (zakázky)
- cost centers (střediska)
- activities (činnosti)
- categories, items, periods, currencies
- the chart of accounts and the tax codes (rate, regime, VAT return and control-statement mapping), which Accounting owns and ships read-only to every product
- parties carry their IČO and DIČ

**Domains.** Each domain owns its records. The last column says what a product built on the domain needs from other domains in order to sell alone.

| Domain | Records it owns | Links to other domains | Money it contributes | To sell alone it also needs |
| --- | --- | --- | --- | --- |
| **CRM** | leads, deals, activities, communication log, relationship status | party; a won deal hands off to a Sales quote or order (Sales writes the link) | expected revenue (deal × probability) | nothing beyond the shared lists |
| **Private relationships** (proposal) | private contacts, notes and reminders owned by one user and invisible to the company | optional link from a private contact to a shared party | none | nothing |
| **Sales** | quotes, sales orders (including billing milestones), customer contracts, customer invoices and credit notes, till (POS) receipts, invoices for sold assets | deal (CRM), project, asset (Accounting), settlement (Treasury) | committed revenue, actual revenue, open cash | bank lines to mark invoices paid (Treasury records, basic import feature) |
| **Spend** | requests, purchase orders, supplier responses, goods receipts, supplier invoices and approval, supplier advance requests (proformas), expense claims, card transactions, supplier contracts | request → order → receipt → invoice; project, cost center; settlement (Treasury) | expected, committed, incurred and actual cost; forecast and open cash | bank lines to mark invoices paid |
| **Inventory** | stock receipts (with or without an order), issues, transfers, valuation | receipt ↔ order line (optional); issue → project or cost center | stock is an asset until issued; an issue is actual cost | nothing |
| **People** | employees, employment contracts, timesheets, payroll runs with their own cost lines, time-based re-attribution of payroll cost | timesheet → project, cost center, activity; payroll → bank (Treasury) | incurred labour (hours × rate), actual labour (payroll cost lines), open payroll liabilities | nothing |
| **Treasury** | bank accounts, statement lines, payment matches to any open item, classification of lines with no document (fees, interest, taxes, insurance, loans, own transfers), payment orders, advances, expected-cash items, loans | any open item in Sales, Spend, People or Accounting | settled cash, own forecast items | nothing |
| **Accounting** | account determination, journal entries, internal documents (opening balance, depreciation, accruals, FX, WIP, VAT settlement), fixed asset register, VAT return and control statement, period close | every journal entry points to its source record | the statutory ledger; internal documents with a management category also count as actual | registering invoices and importing bank statements on the Sales, Spend and Treasury records (6.8) |
| **FP&A** | plan versions (budget, forecast, scenario) on any shared list, cash plans, project financial control (budget, P&L, cash flow, forecast at completion, WIP, extra costs, variance), period review | reads the projection; never writes actuals | the plan side of every comparison | nothing: plans stand alone; actuals appear when other products are used |
| **Documents** | files and their versions, links from any record to its files, the archive of e-invoice originals and scans used by intake | any record in any domain | none; it is the evidence behind every money record | nothing |

**Products** (sellable feature bundles over the domains; adding one never moves a record): CRM, Private relationships, Sales, Procurement, Inventory, Payroll and timesheets (People), Treasury, Accounting, Budgeting (FP&A), Projects, Documents.

- **Projects** is a product built on FP&A's project financial control, the shared project list and the records every domain tags with a project. It owns no records of its own.
- **Cost centers and activities** are shared lists planned in FP&A. They are not projects.

**Derived:** the position projection (all money figures), period-close snapshots, the reconciliation to the ledger, and the backward trace from any journal line to its source record, order, quote and CRM deal (transcript line 501).

**Proposals in this revision** (Hleb can overrule):

1. Documents is a generic file record linked to any record, the pattern in Xero Files, Midday Vault, NetSuite File Cabinet and Fineract (3.4).
2. Private relationships are user-owned private contacts with an optional link to a shared party. None of the 25 products examined has this (3.4).
3. The column "to sell alone it also needs" for every product.
4. Sales documents belong to a Sales domain, not to CRM. CRM owns relationships and pipeline and hands a won deal to Sales. This is the pattern in every suite examined except Dynamics 365 (3.4).

**Rulings (2026-09-24):**

| # | Ruling | Where it lands |
| --- | --- | --- |
| D1 | Projects is a sellable product. Afframe watches projects in money terms: cash flow, P&L, milestones with their sales and expenses, WIP, extra costs. | Projects is a product over FP&A's project financial control and the shared project list. It owns no records (domain map above). |
| S1 | Cost centers (střediska) and activities (činnosti) are not projects. | Shared lists, planned in FP&A |
| D2 | Spend is part of Procurement and Treasury. There is no Spend product. | 6.8 |
| D3 | One chart connected to everything, owned by Accounting. | 6.6 |
| D4 | Research more vendors. | 3.3 |
| D5 | Expenses are not People. Tax is Accounting. | Expense claims and cards sit on the spend side (6.8). |
| D6 | Accounting owns accounting, the spend side owns spend documents, Sales owns sales documents. Products add features; they never take records over. | 6.8 (built and checked) |
| F11 | Input is mixed; be strong on Peppol. | 7.7 |

**Out of scope, as workflow rather than architecture:**

- remaining plan
- revenue timing
- labour date
- conditionally accepted and disputed invoices
- stale commitments
- VAT in cash
- order amendments
- books kept externally
- projection and scenario storage

The architecture only has to express each one as a domain's stage or posting rule, without changing the stage contract. Where the prototype needed a rule, it uses a sample policy and names it where it appears.

---

## 11. Limits

**Built and checked:** everything in 8.1 and the invariants in 6.2 and 7.9.

**Described, not exercised:**

- order change and cancellation documents; order agreement; closures
- receipt rejects and returns
- despatch advice dates
- payee and payer roles other than buyer and seller
- customer-side advances, VAT timing on advances, and credit-note offsets (the mechanism exists: `advance_application`)
- initiated payments (payment orders); loans as records (a loan payment is a classified bank line)
- remittance advice; retention (zádržné)
- closed-period corrections (WIP is an internal document, exercised in a probe)
- VAT claim date; non-deductible VAT
- EN 16931 allowances, charges and rounding
- multi-currency (rule: relieve at the predecessor's rate, FX to `actual`)
- management adjustments; period-close snapshots
- plan spreading; the period-bounded opex check
- stored-projection equality test; a suggestion store for inferred matches
- project delivery management (tasks, schedule, progress, acceptance): out of scope, Afframe watches project money only
- expense claims and card transactions on the spend side
- account determination as one function shared by posting and by record views
- the intake layer: format mappings, OCR, keeping the originals

**Simplifications:**

- Each supplier response re-values the order from the previous terms, so past reads stay stable; responses must still precede fulfilment (checked).
- A cut order line must be returned to its request by a negative fulfilment. The check exists; the record doesn't.
- Rejected orders and over-advances leave the remainder as a forecast refund. There is no unapplied-advance record.
- Whether a self-billed invoice should ever need our approval is open.
- Payroll uses one cost account and one liability account.
- One account per management category (`unique (category_id)` on `account`). Real Czech charts map several accounts to one category, so account determination will need more facts than the category.

**Partly fixed from the independent review:**

- MONEY-1: employee cost rates have no recorded date, so a rate edited later still changes past reads.
- MONEY-8: the independent cash check works per project and category, not per cash-date bucket.
- REDTEAM-1: an invoice registered with no link and then received counts the cost twice, and no check catches it. Linking the invoice to the receipt at registration (falsifier 2) is what prevents it.
- ARCH-5: what the Projects product ships when sold alone is defined in section 10; the Projects screens are not built.
- STANDARDS-1, 3, 4, 5, 10, ARCH-11, REDTEAM-8: the requirements are stated (7.5, 7.7, 6.4, section 10, section 1); the prototype does not carry them yet (advance tax documents, the Czech intake extension, the normalised registration key, timestamps and actors, tax codes, counterparty and root document in the projection).

**Not reviewed again:** the fixes from the second critical review round (advance handling), and the fixes from the independent review.

**Not verified:**

- Czech self-billing under reverse charge.
- The booking of disputed invoices.
- Peppol line-level changeable fields.
- A Peppol MLR primary page.
- SAP activity price revaluation.
- D365 partial relief valuation.
- NetSuite link fields.
- Agicap, Ramp and Brex consumption rules.
- Odoo Enterprise budget code.

**Not rebuilt:** the "20+ reference list" is in none of the files provided.

---

## Appendix: run the prototype

```bash
cd docs/research/finance-model-prototype
docker run -d --name finmodel-demo -e POSTGRES_PASSWORD=demo -e POSTGRES_DB=demo -p 55432:5432 postgres:18
cat model.sql accounting.sql example.sql checks.sql | PGPASSWORD=demo psql -h localhost -p 55432 -U postgres -d demo -v ON_ERROR_STOP=1 -q
docker rm -f finmodel-demo
```
