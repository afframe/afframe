# 01. Constraints and evidence

**Covers:** the requirements the design must meet, then what the examined ERP, finance and planning products, the Peppol / UBL / EN 16931 standards and Czech law actually do, with evidence labels and URLs.
**Read it when:** you need to know why a rule exists, or which vendor or law a claim rests on.
Back to the overview: [README.md](README.md). Evidence labels are defined there.

---

## 1. Requirements

**Money outcomes**

- Amounts stay consistent and traceable across plan, commitment, incurred, actual and cash, without double counting.
- No single shared table is assumed up front.
- The design is compared against at least five alternatives, stress-tested, and states what would falsify it ([02](02-alternatives.md), [08](08-falsifiers-and-limits.md)).

**Product structure**

- Every top-level product sells alone. That includes Accounting run without the rest, for example when an external accountant keeps the books.
- Statutory accounting stays separate from management money views.
- FP&A is a first-class product.
- Scope is money only. Project delivery management (tasks, schedule, acceptance) is out of scope.

**Data model**

- No universal relationship graph. Its edges grow with every pair of related records rather than with the real business facts.
- The core is: typed business facts + direct provenance + explicit real allocations + explainable posting + immutable accounting + specialized financial subledgers + rebuildable analytics.
- Bridge tables exist only for real splits, merges, fulfilment, matching and settlement.
- Peppol is a semantic and domain reference, not the internal model ([06](06-peppol-reference-layer.md)).
- The theory in this paper is stated without database columns. Names in backticks refer to the reference model in [05](05-data-model.md), which illustrates the theory and is not a final schema.

---

## 2. ERP, finance and planning products

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
| Odoo 18 | **Timesheets and profitability.** Timesheets are analytic lines, `amount = -unit_amount * hourly_cost`. The profitability panel is built by per-module `_get_profitability_items` overrides chained through `super()`. Budget "Committed" = achieved + unbilled orders (Enterprise). | source + documented | [hr_timesheet.py](https://github.com/odoo/odoo/blob/18.0/addons/hr_timesheet/models/hr_timesheet.py), [sale_project project_project.py](https://github.com/odoo/odoo/blob/18.0/addons/sale_project/models/project_project.py), [Budgets](https://www.odoo.com/documentation/18.0/applications/finance/accounting/reporting/budget.html) |
| ERPNext v15 | **Budget check computed on read.** Open request quantity × rate; order `amount - billed_amt`, where `billed_amt` sums **invoice** amounts. The open order remainder is therefore misstated (under or over) whenever the invoice price differs from the order price. | source | [budget.py](https://github.com/frappe/erpnext/blob/version-15/erpnext/accounts/doctype/budget/budget.py), [purchase_invoice.py](https://github.com/frappe/erpnext/blob/version-15/erpnext/accounts/doctype/purchase_invoice/purchase_invoice.py) |
| Tryton | **Corrections and budgets.** Posted moves are read-only, and cancel creates a negated copy. The budget compares the period's move lines; posted-only is an optional filter; no commitment stage was found. A purchase request's state is derived. | source | [account/move.py](https://github.com/tryton/tryton/blob/main/modules/account/move.py), [account_budget/account.py](https://github.com/tryton/tryton/blob/main/modules/account_budget/account.py) |
| ERP5 | **Generic simulation.** A generic movement and simulation model with divergence testers and solvers (Accept, Adopt, Quantity Split…). Balances are sums of movements. | documented + source | [ERP5 developer](https://www.erp5.com/basic/developer) |
| Anaplan | **Versions.** Versions are a dimension. Before a forecast version's switchover date, data "is the same as for Actual and is read-only". | documented | [Versions](https://help.anaplan.com/versions-19b4391f-5257-40ee-8dfb-36f0ab426c8f) |
| Procore | **Forecast formulas.** Projected Costs = Committed + Direct + Pending changes; Forecast to Complete = Projected Budget − Projected Costs. | documented | [Read a budget](https://support.procore.com/products/online/user-guide/project-level/budget/tutorials/read-a-budget) |
| Agicap, Ramp, Brex, Rillet | **Spend and cash tools.** Forecast, bank actuals and expected transactions (Agicap). Workflow graph, with the ledger kept in the ERP (Ramp, Brex). A GL with ASC 606 (Rillet). Consumption rules were not found. | marketing / documented | [Agicap](https://event.agicap.com/webinar/improve-liquidity-with-AI/), [Ramp workflows](https://engineering.ramp.com/post/workflows), [Ramp accounting](https://support.ramp.com/overview-of-ramp-accounting), [Brex](https://www.brex.com/product/spend-management), [Rillet](https://www.rillet.com/) |

---

## 3. Peppol, UBL, EN 16931 and Czech rules

| Topic | Verified fact | Label | Source |
| --- | --- | --- | --- |
| Peppol post-award profiles | Order Only 3.3, Ordering 3.3, Catalogue 3.1, Despatch Advice 3.1, Punch Out 3.1, Order Agreement 3.0, Message Level Response 3.0, Invoice Response 3.2, Billing 3.0, Advanced Ordering 3.0. Self-Billing 3.0 is a separate specification. Receipt Advice exists only in the Logistics profiles. | documented | [docs.peppol.eu/poacc/upgrade-3](https://docs.peppol.eu/poacc/upgrade-3/), [Self-billing](https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/) |
| Order response | Codes: AB (acknowledged), AP (accepted), RE (rejected), CA (conditionally accepted). "An order response with code CA … must provide order lines". Only CA carries line-level changes. | documented | [OrderResponseCode](https://docs.peppol.eu/poacc/upgrade-3/syntax/OrderResponse/cbc-OrderResponseCode/) |
| Advanced ordering | Order Change comes from the buyer only. Either party may cancel. A seller proposes changes through Order Response Advanced. | documented (paraphrase level) | [Advanced Ordering](https://docs.peppol.eu/poacc/upgrade-3/profiles/65-advanced-ordering/) |
| Order agreement | "The seller creates an order in his ordering system … and sends a copy of the order as an Order agreement to the buyer". This covers purchases made outside the buyer's process. | documented | [Order Agreement](https://docs.peppol.eu/poacc/upgrade-3/profiles/42-orderagreement/) |
| Despatch advice | "The Despatch Advice states what is shipped; the quantity of goods shipped and what is outstanding" (e.g. backorder). | documented | [Despatch Advice](https://docs.peppol.eu/poacc/upgrade-3/profiles/30-despatchadvice/) |
| Invoice types | Billing 3.0 allows 380 plus alternatives, including 383 (debit note) and 386 (prepayment). 384 (corrected invoice, a full replacement) and 389 are marked "(Germany only)" in the Billing 3.0 specification, and rule PEPPOL-EN16931-P0112 allows 326 or 384 "only ... when both buyer and seller are German organizations". Self-billing codes 389, 527 and 261 belong to Self-Billing 3.0. Credit notes use 381, 81, 83, 396 and 532. | documented | [UNCL1001-inv](https://docs.peppol.eu/poacc/billing/3.0/codelist/UNCL1001-inv/), [Billing 3.0](https://docs.peppol.eu/poacc/billing/3.0/bis/) (Germany only, P0112) |
| Invoice references | Project BT-11, contract BT-12, order BT-13, receiving advice BT-15, despatch advice BT-16, invoiced object BT-18, buyer accounting reference BT-19, preceding invoice BT-25. | documented | [Billing 3.0](https://docs.peppol.eu/poacc/billing/3.0/bis/) |
| Self-billing | "A customer issues and sends an invoice in its suppliers name". Codes: 389 (invoice), 527 (debit note), 261 (credit note). Peppol cites VAT Directive Art. 224: "prior agreement and a procedure where the supplier is to accept each invoice". | documented | [Self-billing 3.0](https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/) |
| Invoice response codes | AB, IP, UQ, CA, RE, AP, PD. "Several Invoice Response's can be sent for one invoice". After Rejected or Paid, "no further Invoice Response may be sent". Approved "may only be followed with … Paid". OP-BR111-R012: "The status of invoices shall advance in the following order" AB, IP, UQ, CA, RE, AP, PD; the process may start at any status. | documented | [UNCL4343-T111](https://docs.peppol.eu/poacc/upgrade-3/codelist/UNCL4343-T111/), [Invoice Response](https://docs.peppol.eu/poacc/upgrade-3/profiles/63-invoiceresponse/) |
| Amount rules | BR-CO-10: sum of lines. BR-CO-13: total without VAT = lines − allowances + charges. BR-CO-15: + VAT. BR-CO-16: amount due = total with VAT − paid amount (BT-113) + rounding (BT-114). | documented | [BR-CO-16](https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-16/) |
| Remittance advice | UBL has a RemittanceAdvice document. No Peppol profile was found for it in the Peppol post-award profile list. | documented / not found | [docs.peppol.eu/poacc/upgrade-3](https://docs.peppol.eu/poacc/upgrade-3/) |
| EN 16931-1 | "A new version of the EN 16931-1, a version 2026, was published in May 2026 and consequently the 2017 version … has been formally withdrawn". The 2017 version remains compliant during the migration period. Peppol BIS Billing 3.0 is still built on the 2017 model; no Peppol migration date was found. | official | [EC eInvoicing](https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467108971/Obtaining+a+copy+of+the+European+standard+on+eInvoicing) |
| ViDA, Directive (EU) 2025/516 | Article 5 applies from 1 July 2030 and replaces VAT Directive Art. 218: "invoices shall be issued as electronic invoices" complying with the European standard. Member States may still accept other formats for transactions outside the reporting obligations, and may mandate domestic e-invoicing. | official | [OJ L 2025/516](https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500516) |
| Czech public sector | Act 134/2016 § 221 (effective through § 279(5)): contracting authorities "nesmí odmítnout elektronickou fakturu" that follows the European standard, in UBL 2.1 or CII (from 2019 or 2020 depending on the authority). Separately, Government Resolution 347/2017 makes central state bodies accept ISDOC ≥ 5.2. | official | [mf.gov.cz](https://mf.gov.cz/cs/dane-a-ucetnictvi/elektronicka-fakturace/zakladni-informace), [zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/2016-134) |
| ISDOC | The Czech national e-invoice format, widely used between Czech accounting systems. Current version 6.0.2 (23 March 2022), maintained by the Ministry of the Interior. It is not one of the EN 16931 syntaxes. No Czech Peppol Authority was found. | documented | [isdoc.cz/6.0.2](https://isdoc.cz/6.0.2/) |
| Czech VAT advances | § 20a: "Je-li před uskutečněním zdanitelného plnění přijata úplata, vzniká povinnost přiznat daň … ke dni jejího přijetí" (VAT becomes due on the day an advance is received): official. A proforma (zálohová faktura) is not a tax document: third-party (Czech accounting-software vendors). That an advance creates no tax point under reverse charge is third-party only and needs checking against the law text. | official + third-party | [zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/2004-235) |
| Czech self-billing | § 28(10): another person may issue the tax document "na základě jejich ujednání" (on the basis of their arrangement), which the tax office may ask to be proven; no written form is required. § 29(2)(b) marks the document "vystaveno zákazníkem". Whether self-billing is used with reverse-charge supplies was **not found**, so the worked example self-bills a standard-VAT supply. | official | [zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/2004-235) |
| Disputed received invoices | No Czech rule on booking a disputed received invoice was found in Act 563/1991 or the VAT Act. | not found | [Act 563/1991](https://www.zakonyprolidi.cz/cs/1991-563), [Act 235/2004](https://www.zakonyprolidi.cz/cs/2004-235) |

**Patterns**

1. **Typed documents are authoritative; commitments are derived.** Mature ERPs keep typed documents as the authority and derive commitments from them.
2. **Relief valuation is where products differ.** SAP relieves at the predecessor's amount. ERPNext relieves by invoice value.
3. **Plans live apart from actuals.**
4. **Peppol confirms the same shape across companies.** Its documents are typed, each points to its predecessor, and responses are separate documents with codes that bound their lifecycle. It never uses a universal graph.
5. **Peppol has gaps.** It covers commitments, budgets, payroll, the ledger, bank reconciliation and planning weakly or not at all. Those come from the ERP patterns.

---

## 4. Product boundaries in more vendors

Researched for architecture only: product boundaries and record ownership. Unit4's primary documentation was unreachable, so its row rests on marketing and third-party pages. SAP Business One's help portal did not render, so several of its answers are inferred or third-party.

| Vendor | Who owns invoices and bank | Chart of accounts | Projects | Expenses | Inbound e-invoices | Label | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Oracle Fusion | Payables and Receivables own invoices; Subledger Accounting derives the journal. No GL-only edition found. | The ledger sets the chart for its subledgers. | PPM, a separate pillar (search-derived) | Expenses, processed through Payables (search-derived) | Peppol BIS 3.0 in and out; separate subsystems per channel (search-derived) | documented / search-derived | [Ledgers and subledgers](https://docs.oracle.com/en/cloud/saas/financials/26a/faigl/ledgers-and-subledgers.html) |
| Unit4 ERPx | AP and AR modules, integrated with GL | configurable; mapping not found | Project Management module (budgets, time and expense) | not found | eConnect: Peppol, and PDF via OCR into structured XML, keeping the PDF | marketing / third-party | [Financial management](https://www.unit4.com/products/erp-accounting-software/financial-management) |
| Acumatica | GL, AP, AR, cash and tax sold as one Financials module; GL alone is not sold | GL owns the chart; AP and PO lines default the account from the vendor or item | Project Accounting, a separate module | Advanced Expense Management (claims, corporate cards) | ML/OCR document recognition into AP bills | documented / inferred | [Financial management](https://www.acumatica.com/cloud-erp-software/financial-management/) |
| Xero | The accounting core owns invoices, bills and bank transactions outright. Projects and Expenses link to or create those core records. | One chart in the core; tracking categories are a separate dimension; apps map to the chart when they connect. | Xero Projects, an add-on: tasks, time, budgets, no ledger records of its own | Xero Expenses, an add-on: an approved claim becomes a bill (not re-quoted verbatim) | Hubdoc and apps all create the same core records | documented / partly | [Xero Projects](https://central.xero.com/0/article/About-Xero-Projects), [Chart of accounts](https://central.xero.com/0/article/View-your-chart-of-accounts) |
| SAP Business One | Sales and Purchasing documents own A/R and A/P invoices and generate linked journal entries. One license, not separate products. | Financials owns the chart; G/L account determination maps other modules to it. | Project Management module | not found | not found; partner add-ons | inferred / third-party | [Chart of accounts](https://help.sap.com/saphelp_sbo882/helpdata/en/45/10c6960b9941dfe10000000a1553f6/content.htm), [G/L account determination](https://help.sap.com/doc/saphelp_sbo882/8.82/en-US/45/06b9997d720487e10000000a155369/content.htm) |
| POHODA | The journal is fed from the invoice, bank, cash and stock agendas, all inside the accounting product. A separate internal document (interní doklad) covers postings with no primary document. | Accounting owns the chart; předkontace on each document drives posting. | Zakázky: a tagging dimension with a plan, built in | GLX, a separate product that also runs standalone | ISDOC import, including ISDOC inside PDF | documented | [Účetní deník](https://www.stormware.cz/prirucka-pohoda-online/Ucetnictvi/Ucetni_denik/), [Zakázky](https://www.stormware.cz/prirucka-pohoda-online/fakturace/zakazky/) |
| Money S3/S4/S5 | Invoice and bank agendas plus internal documents, as in POHODA | předkontace on documents | S5 only; not found for S3/S4 | Travel module, tied to payroll | ISDOC and Money's own richer XML: two formats | documented | [Podvojné účetnictví](https://money.cz/vlastnosti/podvojne-ucetnictvi-s3/) |
| ABRA Flexi / Gen | Invoices own a Posting tab that links to their entries. The journal is "a view over the line items of all accounting documents". Internal documents exist. | Accounting owns the chart; předkontace is mandatory before posting; the account can be seen from each document. | Zakázky and projects as linkable dimensions | not found (third-party tools) | ISDOC through the UI, REST and a mailbox, all into one received-invoice record | documented | [Účetní deník](http://podpora.flexibee.eu/cs/articles/4585700-ucetni-denik) |
| Helios iNuvio | The journal shows entries generated from other modules' primary documents. | Kontace: a shared list used across modules | Zakázky, a module; the only module price list found is for Helios Red, a related smaller product | Travel (Doprava), feeding payroll and cash | ISDOC through the rpISDOC plugin | documented | [Účetní deník](https://public.helios.eu/inuvio/doc/cs/index.php?title=%C3%9A%C4%8Detn%C3%AD_den%C3%ADk_-_%C3%9A%C4%8Detnictv%C3%AD) |

**What this shows for the design**

- **Invoices and bank when Accounting is sold alone.** Three patterns exist:
  - Accounting owns invoices outright, and other products create them through it: Xero, and POHODA, whose accounting product contains the invoice agendas. Money, ABRA and Helios sell invoicing and accounting as modules of one suite, with the journal fed from the invoice records.
  - Business modules own invoices, and accounting derives the journal: Oracle and SAP Business One.
  - The two are sold together, so accounting never runs alone: Acumatica.

  None of the examined products was found to sell a ledger alone while leaving invoices to separately sold products. For Oracle and Unit4, this rests on NOT FOUND. The design follows the first pattern with one change: the invoice belongs to its business domain rather than to Accounting, and Accounting sold alone ships the features to register it ([03](03-domains-and-products.md)).
- **Chart of accounts.** Every vendor where it was found (not Unit4) has one chart owned by the ledger, mapped to other records by rules: account determination, předkontace, kontace, item and vendor defaults. ABRA Flexi shows the account from each document. This supports one chart owned by Accounting ([04](04-money-model.md)).
- **Projects.** Oracle (search-derived), Acumatica and Xero sell projects separately, and Helios Red prices Zakázky as a separate module (iNuvio prices were not found); for Unit4 it was not found. POHODA and ABRA treat them as a tagging dimension. Xero Projects owns tasks, time and budgets but no ledger records. That matches the decision that Projects is a product with no records of its own, with the project identity kept on the platform ([03](03-domains-and-products.md)).
- **Expenses.** Oracle, Xero and Acumatica put claims and cards on the finance or payables side. Money and Helios tie travel expenses to payroll. The design puts them on the spend side.
- **E-invoice intake.** Xero converges every source on one set of core records. The Czech tools have one import path per format, ISDOC first. None of them documents EN 16931 as the pivot model. The single intake layer with EN 16931 semantics ([06](06-peppol-reference-layer.md)) is a design choice, not an observed pattern.

---

## 5. Where Sales, CRM, Projects and Documents sit (25 products)

Finto could not be identified. Several products are narrow tools (Abacum, Numeric, Truewind, Concourse, ProcIndex, Cranston, Brex, Ramp) that own no sales records and read an ERP instead.

| Product | Sales documents owned by | CRM | Projects | Documents module | Contacts | Source |
| --- | --- | --- | --- | --- | --- | --- |
| Odoo | `sale` (orders), `account` (invoices); POS has its own order | separate app, no reference to sales orders; a bridge app links them | owns tasks, money via analytic accounts | Enterprise only | one shared `res.partner` | [odoo/odoo 18.0](https://github.com/odoo/odoo/tree/18.0/addons) (source) |
| ERPNext / Frappe | Selling (quotes, orders), Accounts (invoices, also without an order) | built-in module; Frappe CRM is a separate app linked by API | owns projects, tasks, timesheets; no project invoices | generic `File` | shared | [frappe/erpnext](https://github.com/frappe/erpnext/tree/version-15), [frappe/crm](https://github.com/frappe/crm) (source) |
| SAP S/4HANA | SD (quote, order, billing document); FI derives the ledger | separate product (Sales Cloud), hands won deals to SD | PS owns WBS, billing plans, settlement | DMS / HDM: a document info record links files to business objects | one Business Partner | [SAP help](https://help.sap.com/docs/SAP_S4HANA_ON-PREMISE/19d48293097f4a2589433856b034dfa5/641bd0dc16bf406684ca2c614322c15e.html) |
| Dynamics 365 | two chains: D365 Sales and Finance/SCM, synced by dual-write with an ownership field; free-text invoice for no-order and asset sales | D365 Sales owns leads, opportunities and its own quotes and orders | Project Operations owns records | NOT FOUND | two masters, synced | [Dual-write](https://learn.microsoft.com/en-us/dynamics365/fin-ops-core/dev-itpro/data-entities/dual-write/dual-write-overview), [Free-text invoice](https://learn.microsoft.com/en-us/dynamics365/finance/accounts-receivable/create-free-text-invoice-new) |
| NetSuite | one transaction family for CRM, POS, e-commerce, subscriptions and asset disposal | owns leads, opportunities, cases; links to transactions | project is an entity | File Cabinet, linked to any record | one entity master | [Join path](https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_1548805090.html) |
| Workday | Financials (contract, billing schedule, invoice) | none; "works with your CRM application" | basic projects are only worktags | NOT FOUND | NOT FOUND | [Customer contracts](https://doc.workday.com/admin-guide/en-us/financial-management/revenue/customer-contracts-revenue-recognition/dan1370797699971.html) |
| Xero | Accounting (quotes, invoices) | none | owns tasks and time; billing stays in Accounting | Files API, linked to any object | one shared `Contacts` | [Xero OpenAPI](https://raw.githubusercontent.com/XeroAPI/Xero-OpenAPI/master/xero_accounting.yaml) |
| QuickBooks | core (estimate, invoice, sales receipt) | Customer Hub on the shared customer record | a tag and dashboard only | NOT FOUND | one customer record | [Project profitability](https://quickbooks.intuit.com/learn-support/en-us/reports-and-accounting/projects-profitability-reporting) |
| Midday | invoices (customer optional; free-text name allowed) | none | owns tracker projects and entries | Vault | shared `customers` | [schema.ts](https://raw.githubusercontent.com/midday-ai/midday/main/packages/db/src/schema.ts) |
| HELIOS | Obchod (quotes, orders), Fakturace (invoices), POS module | separate module | zakázky as a dimension | NOT FOUND | shared register | [Obchod v iNuviu](https://www.helios.eu/files/obchod-v-inuviu.pdf) |
| Doss | Order Management, for every channel | Relationship Management hands off to it | owns budgets, job costing, milestones | NOT FOUND | inferred shared | [Doss solutions](https://www.doss.com/solutions) |
| Rillet, Campfire | contract and invoice after closed-won | external only | none | attachments | NOT FOUND | [Rillet contract-driven AR](https://info.rillet.com/contract-driven-ar-rillet), [Campfire](https://campfire.ai/) |
| Fineract | loans and savings; accounting derives GL by product mapping | none | none; office and fund are dimensions | `Document` linked to any entity | clients | [apache/fineract](https://github.com/apache/fineract) |
| Airtable | whatever table the builder chooses | a table | a table | attachment fields | one table linked within a base; across bases only by copying | [Linking records](https://support.airtable.com/docs/linking-records-in-airtable) |

**What this shows**

- **Sales documents are not CRM's.** CRM owns relationships and the pipeline before a commitment. A won deal is handed to a sales or order domain. The only exception, Dynamics 365, keeps two full sales chains and needs an ownership field to reconcile them.
- **Sales channels: one family in some suites, split in others.**
  - NetSuite and Midday land CRM deals, tills, e-commerce, subscriptions, one-off invoices to parties outside the CRM and asset sales in one sales document family.
  - Others split: Odoo keeps POS orders in their own model, and Dynamics 365 has free-text invoices not related to a sales order and keeps two chains.
  - One Sales domain for every channel is therefore a design choice, not an observed pattern.
- **Projects is either a dimension (QuickBooks, Workday basic projects, HELIOS) or an owner of delivery records** (SAP, Dynamics, Xero, Odoo, ERPNext, Doss). No product makes Projects own invoices.
- **Documents, where it exists, is one generic file record linked to any record** (Xero, Midday, NetSuite, Fineract).
- **Contacts are usually one shared list.** Split lists (Dynamics, Frappe CRM, Brex, Ramp) need syncing.
- **Private relationship management was not found in any of them** (searched, NOT FOUND).
