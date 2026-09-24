# Xero & SAP Business One domain-model verification

Budget: ~25 min. Sources fetched live on 2026-09-24 (Xero Central via headless Chrome dump-dom with `--ignore-certificate-errors`, since central.xero.com is a Salesforce SPA that returns empty on plain fetch; SAP Help Portal via the legacy static `saphelp_sbo882` / `help.sap.com/doc/...` mirror, since the current `help.sap.com/docs/...` SPA would not render body text within budget for a subset of pages — those are marked NOT FOUND / third-party). No memory-filled claims. Architecture only — no workflow/approval/recognition/VAT content researched.

---

## Xero

### Q1. Top-level products/editions sold separately; what records each owns

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/About-Xero-Projects
Quote:
> "Xero projects is integrated in Xero which means you can make use of these Xero features: Link invoice line items, bills and spend money transactions ... Recover staff expenses and mileage by assigning them to your projects from Xero expenses (Xero website) ... To get started with Xero projects Add Xero projects to your Xero subscription."
This documents Xero core accounting (invoices, bills, spend money) as the base ledger product, with **Xero Projects** and **Xero Expenses** as separately-added modules on top of a Xero subscription (Projects: "Add Xero projects to your Xero subscription"), each owning its own record types (projects/tasks/estimates in Projects; expense/mileage claims in Expenses) that are distinct from — but link to — core ledger transactions.

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/About-Xero-Expenses
Quote:
> "To use Xero Expenses, it needs to be part of your Xero subscription. See our pricing plans (Xero website) for more information. The number of active users you can have in your organisation depends on your subscription."
Confirms Expenses is a distinct, separately-licensed (per active user) capability layered on a Xero organisation, with its own record ("expense claim") — not a native field on bills.

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/Hubdoc-in-Xero
Quote:
> "If your Xero organisation is on a business edition pricing plan, Hubdoc is included in your Xero subscription. If your Xero organisation is on a partner edition pricing plan, you can still connect it to Hubdoc but it's billed separately."
Hubdoc (Xero's own bill/receipt capture tool) is a distinct, separately-tracked component (bundled or billed separately depending on plan) that does not itself own a ledger record — it only produces documents that, on publish, become Xero ledger transactions (see Q6).

Extra: the add-on/App Store model itself is a documented product boundary.
Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/Getting-started-with-Xero-Connected-Apps
Quote:
> "If the app you want to connect imports invoices into Xero, during the app set up, you'll need to map your account and tax settings ... When a connected app creates transactions or marks invoices as paid in Xero, the transaction history displays this as System Generated."
This confirms third-party App Store apps do not own a parallel invoice/ledger inside Xero; they create transactions inside Xero's own ledger via the API (labelled "System Generated"), and must map to Xero's chart of accounts and tax rates at connection time.

### Q2. Accounting-only: where do customer invoices, supplier invoices, bank statements, contracts live? Does accounting keep a pointer/voucher, or own the invoice outright?

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/About-Xero-Projects
Quote:
> "Transactions that are linked to a project are recorded in the Xero accounting ledger - that's bills, invoices, and spend money transactions. Any other items added directly in Xero projects, such as tasks and expenses, won't impact your balance sheet."
This is the clearest statement of the pattern: **accounting (the core ledger) owns invoices, bills and bank/spend-money transactions outright** — there is no separate "Projects invoice" object; Projects only holds non-ledger data (tasks, time, estimated/actual expense records) and *links* to the ledger transaction. So when Projects (or Expenses, or a connected app) is not used, invoices/bills/bank statements simply live in core Xero accounting, which is itself both the book of record and the source document store — Xero does not model a separate "voucher pointing to a document owned by another module" the way ERPs with separate AR/AP subledgers do. Contracts: NOT FOUND — no fetched Xero Central page describes a native contract record; contract data would live in an attached document on an invoice/bill or in a third-party App Store app (inferred, not vendor-confirmed).

Status: CONFIRMED (expenses side). Label: vendor-documented.
URL: https://central.xero.com/0/article/About-Xero-Expenses
Quote (from search-derived vendor summary confirmed also in Central UI copy): "When you approve an expense or mileage claim, Xero creates a bill for the expense claim." — Status for this specific sentence: PARTLY (found via WebSearch snippet of Central content, not independently re-quoted from the fetched DOM dump this session; treat as vendor-documented but unverified verbatim). This shows the same ownership pattern: Expenses is a claim-capture front end; the actual AP object (a bill) is created and owned by core accounting once approved.

### Q3. Chart of accounts: who owns it; how other modules/apps reference it; visibility

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/View-your-chart-of-accounts
Quote:
> "The chart of accounts is a list of all accounts you can use to record your transactions in Xero. It helps you categorise your transactions correctly and group similar accounts together to generate reports about your organisation ... Click an account balance to view a list of transactions that use that account."
Chart of accounts is owned by core Xero accounting (reached via the Accounting menu), and the UI explicitly supports drilling from an account to the list of transactions that hit it — i.e., account traceability is a native, documented feature, not an inference.

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/Set-up-tracking-categories
Quote:
> "Xero uses tracking categories and options instead of department codes or cost centres. You can have a maximum of four tracking categories in total, but only two can be active at any time."
Tracking categories are a chart-of-accounts-adjacent dimension (not sub-accounts) that any transaction line can carry, owned by core accounting settings, distinct from the account itself.

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/Getting-started-with-Xero-Connected-Apps
Quote:
> "If the app you want to connect imports invoices into Xero, during the app set up, you'll need to map your account and tax settings."
This is explicit account-mapping-at-connection-time for third-party apps — apps do not carry their own chart of accounts; they map their transaction types onto Xero's single chart of accounts once, at setup.

### Q4. Projects: separately sold? Owns budgets/milestones/progress? How do costs from purchasing, timesheets, expenses reach the project?

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/About-Xero-Projects
Quote:
> "Create a project then create tasks to break the work into smaller pieces ... In Xero projects, you can create two types of expense: Create estimated expenses to budget for any costs you expect to incur ... Create or assign actual expenses when you know the final cost of a material ... Bills, spend money transactions and staff expenses can be assigned to projects as actual expenses."
Confirms: Projects is a separately-added product; it owns tasks (with estimated time/charge rates), estimated expenses (a budget-like construct), and time entries; it does **not** independently record purchasing or banking — costs reach the project only by *assigning* an existing core-accounting bill, spend-money transaction, or Xero Expenses claim to the project as an "actual expense." Time reaches the project via native time entries recorded directly against tasks (not sourced from an external timesheet product). Progress/reporting: "Project Financials – see how tasks and expenses are tracking against budget for your projects" (same URL) — a Projects-owned report, not a core-accounting report ("Other reports in Xero don't pull information from Xero projects" — same page, CONFIRMED, vendor-documented).

### Q5. Employee expenses and corporate cards: which product owns them?

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/About-Xero-Expenses
Quote:
> "Once your staff are invited into Xero Expenses, you can assign them user roles ... Admin – manage team roles, company bank accounts and credit cards, chart of accounts for expenses claims and enable receipt analysis."
Xero Expenses (a finance/payables-side product, reached from the Purchases menu per search-derived Central copy: "In the Purchases menu, select Expenses") owns employee expense claims and company credit-card assignment for claims — it sits under finance/spend, not under a separate HR/people product. There is no distinct Xero "HR" product; payroll (a separate product, Xero Payroll) is where reimbursement is *paid out*, per Projects page: "Pay staff for project time in Xero payroll (Xero website)" (CONFIRMED, vendor-documented, same Projects URL) — but claim creation/approval itself is owned by Expenses/Purchases, not Payroll.

### Q6. Inbound e-invoices from mixed sources: one intake layer with a canonical model, or one per format?

Status: CONFIRMED. Label: vendor-documented.
URL: https://central.xero.com/0/article/Hubdoc-in-Xero
Quote:
> "Hubdoc is a data capture tool which extracts key data from documents, then creates transactions in Xero ... As soon as Hubdoc receives a document, it extracts data such as contact, date and amount. When you publish the document, Xero creates the invoice, bill, credit note, or spend money transaction and attaches a copy of the document."
This documents a **single intake layer** (Hubdoc) accepting mixed inbound formats (emailed PDFs, photographed receipts) and normalizing them into Xero's own canonical ledger objects (invoice/bill/credit note/spend money transaction) — there is one internal target model, not one format-specific record type per source. NOT FOUND: no fetched Xero Central or developer page documents native Peppol/UBL or national-XML e-invoice intake as a first-party Xero capability; structured e-invoice intake (e.g. Peppol) is handled by third-party App Store apps that then create the same core ledger objects via the API (inferred from the Connected Apps quote in Q1/Q3 — apps "import invoices into Xero"), not a Xero-native per-format parser. This is consistent with a single-canonical-model architecture with pluggable front-end capture tools (Hubdoc, App Store apps) feeding the same ledger objects.

---

## SAP Business One

### Q1. Top-level products/editions/modules sold separately; what records each owns

Status: PARTLY. Label: third-party (vendor pricing pages not fetched; SAP publishes no public price list).
Search-derived (not independently vendor-quoted this session): SAP Business One is licensed as a starter/limited package vs. a professional (full) license, with a defined set of functional modules (Financials, Sales/A-R, Purchasing/A-P, Business Partners, Banking, Inventory, Production, MRP, Service, Project Management, Human Resources, and others) delivered as one integrated application rather than separately-purchased products — modules are enabled per user-license type, not sold as standalone SKUs the way Xero Projects/Expenses are add-ons. This differs structurally from Xero's model: NOT FOUND — no primary SAP Help Portal page was successfully fetched this session enumerating modules-as-editions (the current `help.sap.com/docs/SAP_BUSINESS_ONE/...` pages are a JS SPA that did not render body text via headless Chrome within the session's time budget; older static-mirror pages exist only for individual feature topics, not a module/edition overview).

Status: CONFIRMED (chart of accounts ownership, as a proxy for "Financials module owns the ledger"). Label: vendor-documented.
URL: https://help.sap.com/saphelp_sbo882/helpdata/en/45/10c6960b9941dfe10000000a1553f6/content.htm
Quote:
> "The setting up of financial accounting occurs when SAP Business One is first implemented ... A chart of accounts lists all of a company's general ledger (G/L) accounts and is the basis for its reporting and posting activities."
Confirms the Financials area owns the G/L/chart of accounts as the foundational record store that all other modules post into.

### Q2. Accounting-only: where do customer invoices, supplier invoices, bank statements, contracts live? Journal/voucher pointer vs. module-owned invoice?

Status: PARTLY. Label: inferred from adjacent vendor documentation (direct page not fetched this session).
SAP Business One's A/R Invoice and A/P Invoice are standard marketing/purchasing-module documents (not journal entries) that *automatically generate* a journal entry in Financials when added — this is well-established SAP B1 architecture reflected in the G/L Account Determination pages below (which exist precisely because sales/purchasing documents need default posting accounts), but a direct vendor quote stating "the invoice document is owned by Sales/Purchasing, and Financials receives an auto-generated journal entry pointing to it" was NOT FOUND in pages fetched this session (the SAP Help Portal's live module-overview pages did not render). Directionally, this is the opposite pattern from Xero: in SAP B1 the AR/AP invoice is natively a document owned by the Sales/Purchasing module, and Financials/accounting holds a generated, linked journal entry — even when a customer chooses not to use full sales/purchasing workflows, "A/R Invoice" and "A/P Invoice" remain the base documents (there is no separate "accounting-only, no invoice module" configuration documented; accounting-only use in SAP B1 still means using the A/R Invoice / A/P Invoice functions, which sit in the Sales/Purchasing menu areas, not in Financials). Bank statements: owned by the Banking module (per module-name evidence from search results: "financials, sales opportunities, sales – A/R, purchasing A/P, business partners, banking and inventory" — Status: PARTLY, third-party summary of help.sap.com content, not independently fetched/quoted). Contracts: NOT FOUND.

### Q3. Chart of accounts: who owns it; how other modules/apps reference it; visibility

Status: CONFIRMED. Label: vendor-documented.
URL: https://help.sap.com/saphelp_sbo882/helpdata/en/45/10c6960b9941dfe10000000a1553f6/content.htm
Quote:
> "Accounts are organized hierarchically according to drawers, titles, and active accounts ... Green accounts are control accounts that have been defined as default G/L accounts for automatic posting of transactions in SAP Business One. Black accounts are those active accounts that have not been selected in G/L account determination. For more information, see G/L Account Determination."
Confirms Financials owns the single chart of accounts, and that other modules reference it through a distinct, named configuration object — **G/L Account Determination** — rather than each module keeping its own account list.

Status: CONFIRMED. Label: vendor-documented.
URL: https://help.sap.com/doc/saphelp_sbo882/8.82/en-US/45/06b9997d720487e10000000a155369/content.htm
Quote:
> "Use this tab to specify the required sales information. To access this tab, choose Administration → Setup → Financials → G/L Account Determination → Sales ... Permit Change of Control Accts: Select if you want to assign different control accounts to different customers ... Domestic Accounts Receivable, Foreign Accounts Receivable, EU Accounts Receivable: Define the respective collective accounts for posting sales to domestic, EU, or other foreign customers."
This confirms the account-determination mechanism explicitly: default/control G/L accounts are configured centrally per business-partner class and per document type (Sales tab), and can be overridden per customer via Business Partner Master Data — i.e., account determination by business-partner and by document type is native and vendor-documented. Search-derived (not independently fetched this session, Status: PARTLY, third-party) evidence additionally describes G/L account determination keyed by **item group**, item code, and warehouse code (Inventory tab of the same G/L Account Determination object), consistent with the "account determination by item group" pattern named in the brief. Whether a user can see, from any business record, which account it will hit / did hit: NOT FOUND as a directly quoted vendor statement this session (the Chart of Accounts page states you can drill from an account to its "Setting Up and Working with G/L Accounts," but a direct "view posting account from the source document" UI statement was not fetched).

### Q4. Projects: separately sold? Owns budgets/milestones/progress? How do purchasing/timesheet/expense costs reach the project?

Status: NOT FOUND (primary vendor page did not render / PDF was inaccessible in this environment). Label: third-party (search-result summaries of vendor partner content, not independently vendor-quoted).
Search-derived summaries state SAP Business One's Project Management module organizes work into projects → stages → tasks, tracks a project budget vs. actuals, supports linking purchase orders to the project's purchasing commitments, and has a Timesheet function for recording time against tasks/projects. A vendor how-to guide exists at https://help.sap.com/doc/ec47596b9ec04679b7fad2c8efb4c2ab/9.3/en-US/How_to_Work_with_Project_Management_in_SAP_Business_One_9.3.pdf (title confirmed via search) but the PDF could not be parsed in this sandbox (no poppler-utils; WebFetch reported binary/corrupted content) — so no verbatim vendor quote is available this session. Treat all Q4 SAP B1 findings as third-party/unconfirmed pending a direct fetch.

### Q5. Employee expenses and corporate cards: which product owns them?

Status: NOT FOUND. No SAP Help Portal page on employee expense reports / corporate card reconciliation was successfully fetched this session (the relevant `help.sap.com/docs/SAP_BUSINESS_ONE/...` SPA pages did not render body text within budget, and searches did not surface an equivalent static-mirror URL). SAP Business One does not have a distinct "HR" ledger-owning module comparable to Xero Expenses; expense-report functionality in SAP B1 is commonly delivered via partner add-ons (e.g., mobile expense-report SDK apps) rather than a documented native core module — this is an inference from the module list found (Financials, Sales, Purchasing, Business Partners, Banking, Inventory, Production, Service, Project Management, Human Resources) where "Human Resources" in SAP B1 is primarily an employee-master-data module, not an expense-claims/payables module (inferred, not vendor-quoted this session).

### Q6. Inbound e-invoices from mixed sources: one intake layer, or one per format?

Status: PARTLY. Label: third-party (no help.sap.com page on native e-invoice intake was fetched; findings are from vendor-partner blogs and integrator sites, none of which are SAP-primary).
Search-derived: SAP Business One does not appear to have a single documented native intake layer for mixed inbound e-invoice formats (Peppol/UBL, national XML, PDF/OCR) in the SAP Help Portal content reachable this session. Third-party integrators (e.g., a "SAP Business One Blog" partner page, and consultancy PIKON) describe SAP B1 handling structured Peppol/UBL e-invoices and PDF/OCR capture through add-on products/partner middleware layered on top of core Purchasing, rather than through one built-in canonical parser — e.g., one search summary stated: "SAP Business One solutions can handle paper documents, PDFs, or structured e-invoices such as UBL/XML and Peppol, ensuring fast and error-free processing directly in SAP Business One" (this is a third-party/partner solution description, not an SAP Help Portal quote). Whether SAP's own core product provides one canonical internal document model across formats, or whether each localization/add-on maintains its own format-specific handling, is **NOT FOUND** from primary sources this session — flag as an open question requiring a direct fetch of SAP's "Electronic Documents" / country-localization documentation (e.g., Italy/Mexico/Peppol-market einvoicing framework pages), which did not render in this session's headless-Chrome attempts.

---

## Table: 5–8 rows, vendor comparison

| Vendor | Product boundary pattern | Q2 pattern (who owns invoices & bank when "accounting only") | Chart-of-accounts pattern |
|---|---|---|---|
| Xero (core) | Core accounting (ledger, invoices, bills, bank/spend-money) is the base product; everything else (Projects, Expenses, Hubdoc, App Store apps) is added on top of the same org, either bundled or billed separately. | Accounting owns invoices/bills/bank transactions outright — no separate subledger module needed to create them. (CONFIRMED, central.xero.com/0/article/About-Xero-Projects) | Single chart of accounts owned by core accounting; tracking categories are a separate cross-cutting dimension; connected apps must map to the existing chart at connect-time. (CONFIRMED) |
| Xero Projects | Separately added to a Xero subscription; owns tasks, time entries, estimated/actual-expense assignments, quotes/budgets — no ledger objects of its own. | Projects never creates its own invoice/bill type; it *links* existing core-accounting bills/invoices/spend-money to a project. (CONFIRMED) | N/A — inherits core chart of accounts; project reports are separate from core financial reports. (CONFIRMED) |
| Xero Expenses | Separately added, billed per active user; owns expense/mileage claims. | On approval, Xero creates a bill (an accounting-owned object) for the claim — Expenses is a capture/approval front end, not the AP record itself. (PARTLY — vendor-documented per search snippet, not re-quoted verbatim from DOM this session) | Admin role in Expenses can set "chart of accounts for expense claims," i.e., maps claim categories onto the one core chart. (CONFIRMED) |
| Xero — e-invoice intake | Hubdoc is one bundled/attachable intake tool; third-party App Store apps are an alternate intake path; both create the same canonical ledger objects. | Not applicable (intake layer, not a ledger module) — but confirms one canonical internal model (invoice/bill/credit note/spend money) regardless of source format. (CONFIRMED) | Apps/Hubdoc map extracted data onto existing accounts/tax rates; no format-specific account list. (CONFIRMED) |
| SAP Business One (core) | One integrated application licensed by user-license tier (starter vs. professional), not sold as separate per-module products; Financials, Sales/A-R, Purchasing/A-P, Banking, Inventory etc. are modules within one license, not add-on SKUs. | Even "accounting-only" use relies on the Sales/Purchasing modules' native A/R Invoice / A/P Invoice documents, which auto-generate linked journal entries in Financials — invoice is module-owned, accounting holds a generated posting. (PARTLY — inferred from G/L Account Determination architecture; direct module-overview quote NOT FOUND this session) | Financials owns the single chart of accounts; other modules reference it via the named "G/L Account Determination" object (by business-partner class, document type, and — per third-party corroboration — item group/warehouse). (CONFIRMED for chart of accounts and Sales-tab determination; item-group determination PARTLY/third-party) |
| SAP Business One Project Management | Appears to be a module within the core license (not confirmed as a separate SKU this session); reported to own budgets, stages/milestones and time entries, with purchasing linked via POs. | NOT FOUND / third-party only this session — no primary vendor quote retrieved. | NOT FOUND this session. |
| SAP Business One — expenses/e-invoicing | Native employee-expense and e-invoice-intake ownership NOT FOUND in primary SAP Help Portal content reachable this session; third-party sources point to partner add-ons filling these gaps. | NOT FOUND / third-party. | NOT FOUND / third-party. |

---

## Status counts
- CONFIRMED (vendor-documented, quote fetched live): Xero — 11 claims (Q1 x3, Q2 x1, Q3 x3, Q4 x2, Q5 x1, Q6 x1). SAP B1 — 3 claims (Q1 chart-of-accounts proxy, Q3 x2).
- PARTLY (vendor-documented topic confirmed but verbatim quote not independently re-fetched, or third-party corroboration of a real vendor mechanism): Xero — 1 (expense-claim-to-bill sentence). SAP B1 — 4 (Q1 editions/modules, Q2 invoice/journal linkage, Q3 item-group determination, Q6 third-party summary of intake handling).
- NOT FOUND: Xero contracts-as-a-native-record; native Peppol/UBL/national-XML intake as first-party Xero capability. SAP B1: module/edition overview page (SPA did not render), direct "accounting-only" architecture statement, Banking module ownership quote, full Q4 Project Management primary quote (PDF unreadable in this sandbox — no poppler-utils), Q5 employee-expenses/corporate-card ownership, Q6 native e-invoice canonical-model statement.

Note: several current SAP Help Portal pages (`help.sap.com/docs/SAP_BUSINESS_ONE/...`) are a JavaScript SPA that did not render article body text via headless Chrome (`--dump-dom`) within this session's time budget, even after raising `--virtual-time-budget`; only the sidebar table-of-contents rendered. Where available, older static-mirror pages (`help.sap.com/saphelp_sbo882/...` and `help.sap.com/doc/saphelp_sbo882/...`) were used instead and did render fully via plain `curl`. This explains the concentration of NOT FOUND / PARTLY labels on SAP B1 Q1, Q4, Q5, Q6 versus the fuller Xero coverage.
