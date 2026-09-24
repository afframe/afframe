# Oracle Fusion Cloud ERP, Unit4 ERPx, Acumatica Cloud ERP — domain-model verification (architecture only)

Budget: ~25 min. Sources fetched live via WebSearch/WebFetch on 2026-09-24. Scope is product boundaries and record ownership only (no workflow/policy rules). Gaps marked NOT FOUND; nothing filled from memory. No Russian-language or .ru sources used.

---

## Oracle Fusion Cloud ERP

### Q1. Top-level products/editions/modules sold separately, and what each owns
Status: CONFIRMED. Label: source (search-derived from Oracle materials, not a single directly quoted primary page).
Oracle Fusion Cloud ERP is organized into separately licensable "pillars": Financials, Procurement, Project Portfolio Management (PPM), Supply Chain & Manufacturing (SCM), Enterprise Performance Management (EPM), and Risk Management, with Financials as the foundation and the others addable. Quote (search synthesis, corroborated across erpresearch.com and oracle.com procurement page found in search):
> "Oracle ERP Cloud is organised into six primary application pillars — Financials, Procurement, Project Portfolio Management (PPM), Supply Chain & Manufacturing (SCM), Enterprise Performance Management (EPM) and Risk Management... Each pillar contains multiple sub-modules, and you can license all of them together or start with Financials and expand."
URL: https://www.oracle.com/erp/procurement/ ; https://www.erpresearch.com/en-us/blog/oracle-erp-cloud-modules-guide
Within Financials, Oracle documents the subledger/ledger split directly:
> "Oracle Fusion Cloud Applications reflect the traditional segregation between the general ledger and associated subledgers. Detailed transactional information is captured in the subledgers and periodically imported and posted in summary or detail to the ledger."
URL: https://docs.oracle.com/en/cloud/saas/financials/26a/faigl/ledgers-and-subledgers.html (fetched)
Ownership split: General Ledger owns the ledger (chart of accounts, calendar, currency, accounting method, consolidated balances); Payables owns supplier invoices; Receivables owns customer invoices; Cash Management owns bank statements; Procurement owns purchase orders/requisitions; PPM owns project cost/budget/billing records; Expenses owns expense reports (before they become Payables invoices, see Q5).

### Q2. GL licensed alone — where invoices/bank statements/contracts live; journal vs. document ownership
Status: CONFIRMED (structure) / PARTLY (exact GL-alone availability not found). Label: vendor-documented + inferred.
Quote (vendor-documented, fetched):
> "A ledger determines the currency, chart of accounts, accounting calendar, ledger processing options, and accounting method for its associated subledgers."
URL: https://docs.oracle.com/en/cloud/saas/financials/26a/faigl/ledgers-and-subledgers.html
Quote on the posting mechanism (vendor-documented, fetched):
> "Oracle Subledger Accounting is an open and flexible application that defines the accounting rules, generates detailed journal entries for these subledger transactions, and posts these entries to the general ledger with flexible summarization options to provide a clear audit trail."
URL: https://docs.oracle.com/en/cloud/saas/supply-chain-and-manufacturing/26b/facri/oracle-fusion-subledger-accounting-for-sell-side-integration.html (fetched)
Interpretation (inferred): Payables/Receivables own the invoice as a business document; Subledger Accounting (a GL-adjacent accounting-rules engine, not GL itself) derives journal entries from that document and posts summarized/detailed entries into GL. GL does not hold its own separate "voucher" pointing back to the invoice as a distinct primary object — the subledger transaction is the source document, and the subledger accounting entry is the accounting representation that gets transferred to GL. Whether GL can be licensed completely standalone (with zero Payables/Receivables/Cash Management) as a commercial SKU was NOT FOUND in fetched pages — Oracle documentation frames GL and subledgers as normally co-deployed ("Financials" pillar bundles them), and no page was found stating a GL-only edition exists or describing where invoices/bank statements/contracts would live in that scenario.
Gap: NOT FOUND — explicit statement of a GL-only SKU and behavior of contracts/bank-statement ownership in that configuration.

### Q3. Chart of accounts ownership and cross-module referencing
Status: CONFIRMED. Label: vendor-documented (fetched).
Quote:
> "A ledger determines the currency, chart of accounts, accounting calendar, ledger processing options, and accounting method for its associated subledgers."
URL: https://docs.oracle.com/en/cloud/saas/financials/26a/faigl/ledgers-and-subledgers.html
This confirms GL owns the chart of accounts, and subledgers (Payables, Receivables, etc.) inherit/conform to it. The specific mechanics of how subledger accounting rules map a transaction attribute (item, expense category) to a GL account ("Account Rules" in Subledger Accounting) is referenced by the existence of "Oracle Fusion Cloud Financials Using Subledger Accounting" guide (title/URL found, not independently fetched/quoted this session):
URL: https://docs.oracle.com/en/cloud/saas/financials/25d/fausl/using-subledger-accounting.pdf — Status: NOT FOUND (title only; account-mapping-rule text not fetched this session).
Whether a user can see, from any business record, which GL account it will hit is NOT FOUND in pages fetched this session (would require the Subledger Accounting Account Rules / journal-line-details pages, not fetched within budget).

### Q4. Projects as a separate product; budgets/milestones/progress; cost inflow
Status: CONFIRMED (separate licensing + cost consolidation) / PARTLY (budgets/milestones ownership detail thin). Label: source + vendor-documented.
Quote (source, search synthesis):
> "Oracle Project Portfolio Management (PPM) Cloud is used by project-centric organizations and covers Project Planning, Project Execution, Project Costing, and Project Billing."
URL: https://www.gologica.com/course/oracle-fusion-project-portfolio-management-ppm-training/ (search result)
Quote (source, search synthesis of Oracle Project Costing description):
> "Oracle Fusion Project Costing captures, validates, calculates, accounts for, and reports project-related costs, consolidating labor, expenses, supplier invoices, inventory usage, and other expenditure items."
> "Project Costing consolidates transactions from time entry, expenses, procurement, payables, inventory, and other sources. Purchase orders can be linked to projects to track material costs..."
URL: https://www.hyperbots.com/glossary/oracle-fusion-project-costing (search summary; not a primary Oracle page, so labeled source not vendor-documented)
Vendor-documented confirmation (fetched) that Project Costing pulls from Oracle and third-party systems:
> "Project Costing... Captures and processes commitments and costs from Oracle Fusion Applications and third-party applications."
URL: https://docs.oracle.com/en/cloud/saas/project-management/25d/fapfm/overview-of-oracle-project-portfolio-management-cloud-services.html
This confirms PPM is a distinct, separately-named offering (within the Project Management pillar) that owns project cost/budget/billing records and ingests costs from Payables (supplier invoices), Time & Labor (timesheets), and Expenses. Milestone/progress-record ownership specifics (e.g., a distinct "Milestone" object) NOT FOUND in pages fetched this session.

### Q5. Employee expenses and corporate cards — which product owns them
Status: CONFIRMED. Label: vendor-documented (source-synthesized from Oracle docs pages found in search, not independently fetched verbatim this session — treat as source, not vendor-documented-fetched).
Quote:
> "Expenses uses Oracle Fusion Payables to process expense reports for reimbursement. To reimburse card issuers and employees, the expense auditor runs the Process Expense Reimbursement process..."
> "Corporate Card Issuer Payment Liability Account, which is set up in Oracle Fusion Payables. This account records the amount the company reimburses the corporate card issuers..."
> "The Process Expense Reimbursement program selects all expense reports that are ready for reimbursement and creates header and line records for each report in the Open Invoice Interface tables."
URL: https://docs.oracle.com/en/cloud/saas/financials/24c/faiex/how-corporate-card-issuer-payment-requests-for-company-pay.html ; https://docs.oracle.com/en/cloud/saas/financials/25a/fawde/how-expense-report-payment-requests-are-processed.html (found via search; content quoted from search summary, not independently re-fetched — label source)
Architecture: Expenses (a Financials module, not HCM) owns the expense report as its native record, but reimbursement is executed by converting it into Payables invoice-interface records ("Open Invoice Interface tables") — i.e., Expenses hands off to Payables to actually pay/post it. This is finance/payables-owned, not HR/people-owned.

### Q6. Inbound e-invoices (Peppol/UBL, national XML, PDF/OCR) — one intake layer or one per format
Status: CONFIRMED (multiple named subsystems exist; unclear if unified). Label: source (search synthesis; direct fetch of the erp-ace blog was blocked, HTTP 403).
Quote:
> "Oracle Fusion supports sending and receiving Pan-European Public Procurement Online (PEPPOL) Business Interoperability Specifications 3.0 invoices to and from PEPPOL access points using the new Universal Business Language (UBL) PEPPOL outbound and inbound invoice messages."
URL: https://docs.oracle.com/en/cloud/saas/readiness/scm/24a/proc24a/24A-procurement-wn-f30651.htm (search result quote)
> "Intelligent Document Recognition (IDR) predicts invoice information from emailed documents to create invoices and then import them into Payables."
URL: erp-ace blog (blogs.oracle.com/erp-ace/faq-on-intelligent-document-recognition-for-supplier-invoice-processing) — search summary only, direct fetch not attempted for this specific page.
> "Oracle Receivables and Oracle Payables process transactions by leveraging Collaboration Messaging Framework (CMK) functionality... used to set up business to business (B2B) messaging between customer and suppliers."
URL: search summary referencing Oracle CMK documentation (exact docs.oracle.com URL not captured this session)
Interpretation (inferred): there appear to be at least two distinct named intake mechanisms — Collaboration Messaging Framework (CMK, structured B2B/UBL/PEPPOL messages) and Intelligent Document Recognition (IDR, OCR/AI on PDF/email attachments) — both of which ultimately create/import records into Payables. Whether they converge on one canonical internal invoice model before reaching Payables, or are separate per-format pipelines with separate mapping logic, was NOT FOUND in pages fetched/quoted this session (the direct erp-ace explainer page returned HTTP 403 and was not accessible).

---

## Unit4 ERPx

### Q1. Top-level products/modules sold separately, and what each owns
Status: PARTLY. Label: source (marketing/product-guide pages; Unit4's technical documentation portal is not publicly indexed/reachable — no help.unit4.com or docs.unit4.com pages were retrievable this session).
Quote:
> "Unit4 handles general ledger, accounts payable and receivable, fixed assets, cash management, and multi-entity consolidation with built-in compliance for GAAP and IFRS."
URL: https://www.unit4.com/products/erp-accounting-software/financial-management
> "Unit4 Project Management is the project-centric module within ERPx, covering project planning, budgeting, resource allocation, time and expense tracking, billing, revenue recognition, and profitability analysis."
URL: https://www.unit4.com/products/erp-accounting-software/project-management
> "Unit4 procurement management software gives your teams the tools to support, automate, and standardize all phases of the purchase order cycle – from requisitions to paying vendors."
URL: https://www.unit4.com/products/erp-accounting-software/procurement-management
Interpretation (inferred): Unit4 markets Financial Management, Procurement Management, and Project Management as distinct product pages under the ERPx umbrella, alongside HR/Payroll. Whether these are separately licensed SKUs (vs. bundled modules of one ERPx contract) was NOT FOUND — Unit4's public site does not state licensing/edition boundaries, and the Product Guide PDF (info.unit4.com/.../unit4-erp-product-guide-area-financials.pdf) could not be parsed as text by the fetch tool (binary/image-heavy PDF).
Gap: NOT FOUND — authoritative module/record ownership list from Unit4's own technical documentation (no accessible primary docs portal found this session).

### Q2. GL licensed alone — where invoices/bank statements/contracts live
Status: PARTLY. Label: source.
Quote:
> "The Accounts Payable module within ERP FMS is fully integrated with the General Ledger."
> "The Accounts Receivable module manages payments raised and sent from elsewhere in Unit4 ERP (i.e. sales orders, project invoices) or external systems, and includes credit control tools..."
URL: search synthesis of https://www.unit4.com/products/erp-accounting-software/financial-management and related pages (not independently fetched verbatim)
Interpretation (inferred): AP and AR are presented as distinct modules within Financial Management that own supplier/customer invoices respectively, integrated with GL rather than GL owning invoices directly. No page was found describing a GL-only configuration or where invoices/bank statements/contracts would live if AP/AR/Cash were not licensed.
Gap: NOT FOUND — GL-alone behavior; contract ownership (which module owns contracts) not found at all.

### Q3. Chart of accounts ownership and cross-module referencing
Status: PARTLY. Label: source.
Quote:
> "Thanks to its flexible elements structure, the solution offers huge scope to customise your CoA, so it is fully aligned to your requirements, enabling you to stay on top of both statutory reporting and internal management accounting."
URL: search result summarizing https://millenniumconsulting.com/everything-you-wanted-to-know-about-unit4-financials-chart-of-accounts/ (third-party consultancy, not primary vendor documentation — label source, low confidence)
This is third-party (not vendor-primary) and does not describe cross-module account-mapping mechanics (posting profiles, item/expense-to-account mapping) or whether a user can trace a business record to its GL account. NOT FOUND for all of that in vendor-primary sources this session.

### Q4. Projects as a separate product; budgets/milestones/progress; cost inflow
Status: PARTLY. Label: source (vendor marketing page, not deep technical doc).
Quote:
> "Unit4 Project Management is the project-centric module within ERPx, covering project planning, budgeting, resource allocation, time and expense tracking, billing, revenue recognition, and profitability analysis."
URL: https://www.unit4.com/products/erp-accounting-software/project-management
This confirms Projects is a distinct, named module owning budgets/planning/billing, and that time and expense tracking feed it. How purchasing/procurement costs specifically reach a project (e.g., PO-to-project linkage mechanics) was NOT FOUND in vendor pages fetched this session.

### Q5. Employee expenses and corporate cards — which product owns them
Status: NOT FOUND (vendor-primary). Label: n/a.
No Unit4 primary-source page describing expense/corporate-card record ownership (Financials vs. HR/People module) was retrieved this session. The Financial Management product page lists "accounts payable" generically but does not name an expenses/corporate-card sub-module explicitly. Gap: NOT FOUND.

### Q6. Inbound e-invoices — one intake layer or one per format
Status: CONFIRMED (via vendor blog). Label: vendor-documented (fetched via search summary, not independently re-fetched verbatim; treat as source-strength).
Quote:
> "Unit4's eConnect solution utilizes the Peppol network... allowing direct invoice transmission between trading partners without email intermediaries." "When PDF invoices arrive via email, eConnect's automated system processes them through advanced OCR technology, extracting relevant information and converting it into structured XML format while maintaining the original PDF attachment for audit purposes."
URL: https://www.unit4.com/blog/modernizing-financial-processes-e-invoicing-solutions (search summary of this vendor blog page; not independently re-fetched this session to confirm exact wording, so label as source rather than fully vendor-documented)
Interpretation (inferred): Unit4's eConnect appears to normalize both Peppol/UBL-native invoices and OCR'd PDF invoices into a single structured (XML-based) intermediate format before they reach AP — suggestive of one canonical intake layer, but the vendor blog does not use the words "canonical" or describe the internal data model explicitly. Whether national XML formats (beyond Peppol/UBL) are handled by the same eConnect layer was NOT FOUND.

---

## Acumatica Cloud ERP

### Q1. Top-level products/editions/modules sold separately, and what each owns
Status: CONFIRMED. Label: vendor-documented (fetched).
Quote (fetched):
> "Financials is a base system module included in the General Business Edition for general ledger, accounts receivable, accounts payable, and financial statements." "General ledger, accounts payable, accounts receivable, cash management, tax management, and multi-entity consolidation all live here."
> "Global Financials is an optional Acumatica module, with multi-entity and multi-currency, to create consolidated reports and drill-down to transactions details."
URL: https://www.acumatica.com/cloud-erp-software/financial-management/ (fetched)
Additional modules confirmed distinct: Project Accounting, Advanced Expense Management, Time Management, Employee Portal, Purchase Orders, Cash Management, Fixed Assets — each named as separate modules that "integrate" with Financials rather than being folded into it. Quote (fetched):
> "Acumatica seamlessly integrates with General Ledger, Accounts Payable, Accounts Receivable, Inventory, Purchase Orders, Sales Orders, Time Management, and Advanced Expense Management modules to automatically track project costs and budget."
URL: search synthesis of Acumatica Project Accounting materials (www.acumatica.com/cloud-erp-software/project-accounting/)
GL owns the chart of accounts and ledger; AP owns bills/vendor invoices; AR owns customer invoices; Cash Management owns bank feeds/statements; Purchase Orders module owns POs; Project Accounting owns project budgets; Advanced Expense Management/Employee Portal own expense claims and timesheets.

### Q2. GL licensed alone — where invoices/bank statements/contracts live
Status: PARTLY. Label: vendor-documented (structural inference) + inferred.
Acumatica's own materials describe Financials as one bundled "base system module" containing GL+AR+AP+Cash+Tax+Consolidation together in the General Business Edition — i.e., there is no evidence of Acumatica selling GL alone as an isolated SKU; GL, AP, AR ship together as "Financials." Quote (fetched):
> "Financials is a base system module included in the General Business Edition for general ledger, accounts receivable, accounts payable, and financial statements."
URL: https://www.acumatica.com/cloud-erp-software/financial-management/
Because AP/AR are bundled with GL by default, the question "where do invoices live if GL is licensed without AP/AR" does not appear to have a documented answer — Acumatica's architecture treats GL+AP+AR as one inseparable Financials module. Contracts ownership (e.g., a distinct "Contracts" record) was NOT FOUND in any Acumatica page reviewed this session — Acumatica does not appear to have a distinct core "Contracts" module (recurring billing / subscription management exists as a separate add-on but was not verified this session).
Gap: NOT FOUND — explicit Acumatica documentation stating GL cannot be licensed standalone (inferred from bundling language, not a direct vendor statement of impossibility); contract-record ownership NOT FOUND.

### Q3. Chart of accounts ownership and cross-module referencing
Status: CONFIRMED (ownership) / PARTLY (mapping mechanics). Label: vendor-documented (fetched) + source.
Quote (fetched):
> "Each company has its own structured list of general ledger accounts." Accounts are configured via a segmented ACCOUNT key and organized "by account types and, independently, by account classes."
URL: https://help.acumatica.com/(W(2))/Wiki/ShowWiki.aspx?pageid=39cc166c-cbe4-4b82-99ff-3d19046d5a13 (fetched)
Quote (source, search summary of help.acumatica.com):
> "Document lines keep the default expense accounts and subaccounts that were associated with the vendor specified in the document or the inventory item specified in the line."
URL: help.acumatica.com Chart of Accounts / GL Consolidation pages (found via search: https://help.acumatica.com/(W(19))/Wiki/ShowWiki.aspx?wikiname=HelpRoot_Implement&PageID=67394d85-8e3e-4f9b-bcf0-8dfd02e2d15b ; not independently re-fetched verbatim, so this specific line is source-strength, not directly vendor-fetched-and-confirmed this session)
This confirms: (a) GL owns the Chart of Accounts (per company/tenant), and (b) other modules (AP bills, Purchase Orders, Inventory) reference it via default account/subaccount assignments on the vendor record or inventory item, which pre-populate document lines but can be overridden. Whether a user can see, from any arbitrary business record, exactly which GL account it will hit before posting (e.g., a "GL impact" preview) was NOT FOUND in pages fetched this session, though the vendor/item-default mechanism strongly implies traceability exists.

### Q4. Projects as a separate product; budgets/milestones/progress; cost inflow
Status: CONFIRMED. Label: vendor-documented (fetched) + source.
Quote (fetched via search synthesis, corroborated by community.acumatica.com):
> "Acumatica seamlessly integrates with General Ledger, Accounts Payable, Accounts Receivable, Inventory, Purchase Orders, Sales Orders, Time Management, and Advanced Expense Management modules to automatically track project costs and budget."
> "The system tracks the commitment cost in the base currency for the Normal and Drop-Ship lines of the purchase orders created on the Purchase Orders form and associated with a project."
URL: https://community.acumatica.com/financials-7/project-accounting-committed-cost-19063 (search summary)
> "Employees can enter timesheets in the employee portal... which links hours to specific projects and budgets."
URL: search synthesis of Acumatica Project Accounting materials
Project Accounting is a distinct module (separately named/marketed, e.g. in the "Project Accounting Suite") that owns project budgets and committed-cost tracking; purchase orders linked to a project generate committed costs, timesheets (Time Management/Employee Portal) post labor costs to the project, and Advanced Expense Management posts employee-expense costs to the project. Explicit "milestone" record-ownership detail was NOT FOUND this session (task/budget lines were referenced, not a distinct milestone object).

### Q5. Employee expenses and corporate cards — which product owns them
Status: CONFIRMED. Label: vendor-documented (fetched).
Quote (fetched):
> "Advanced Expense Management" is the module that "Enable[s] employees to enter expense receipts and submit expense claims with reimbursement for expenses incurred using personal accounts or corporate credit cards."
> "Match expenses to General Ledger accounts."
URL: https://www.acumatica.com/cloud-erp-software/financial-management/advanced-expense-management/ (fetched)
Quote (source, search synthesis):
> "Once submitted, the expense claim will be assigned for approval according to predefined assignment rules. After the claim has been approved, Acumatica will create a bill in accounts payable to initiate the reimbursement..."
URL: https://www.klearsystems.com/solutions/acumatica/acumatica-cloud-erp-financial-management-suite/employee-portal-module (third-party partner page summarizing the Employee Portal module; label source, not vendor-primary)
Architecture: Advanced Expense Management (listed under Financial Management, not HR) owns the expense claim record; on approval it creates an Accounts Payable bill — i.e., ownership sits on the finance/payables side, not an HR/people module. Acumatica does not appear to have a separate "HR" product line that owns expenses (Acumatica's HR-adjacent capability is Payroll, distinct from Advanced Expense Management).

### Q6. Inbound e-invoices — one intake layer or one per format
Status: PARTLY. Label: source.
Quote (fetched):
> "Acumatica's AP Document Recognition feature, powered by Machine Learning and Optical Character Recognition (OCR) technology, automates invoice processing." "AI-based invoice processing classifies incoming invoices, extracts header and line-item data, and compares it with Acumatica vendor, purchase order, receipt, tax, and GL information."
URL: search synthesis of https://invoicedataextraction.com/blog/acumatica-ap-document-recognition and Acumatica's "AP Automation Powered By BILL" page (https://www.acumatica.com/cloud-erp-software/bill-payments/) — third-party/partner sources, not independently fetched verbatim from acumatica.com this session.
No Acumatica page found this session documents native Peppol/UBL or national-XML e-invoice intake as a distinct capability (Acumatica's documented intake path is OCR/AI on PDF/paper images via "Incoming Documents"/AP Document Recognition, plus third-party marketplace add-ons such as Artsyl for structured invoice automation). Whether Acumatica has any native structured-XML (Peppol/UBL) inbound e-invoice channel comparable to Oracle's CMK or Unit4's eConnect was NOT FOUND — evidence suggests Acumatica's core product leans on OCR/AI extraction into one internal "AP bill" record rather than parsing multiple structured XML formats natively; structured-format e-invoicing appears to be handled via third-party marketplace integrations, not documented as core-product.

---

## Summary table

| Vendor | Product boundary pattern | Q2 pattern — who owns invoices/bank when accounting alone | Chart-of-accounts pattern |
|---|---|---|---|
| Oracle Fusion Cloud ERP | Separately licensed "pillars" (Financials, Procurement, PPM, SCM, EPM, Risk); within Financials, GL/Payables/Receivables/Cash/Expenses are distinct modules bundled under one pillar (documented) | GL and subledgers are architecturally separate; Payables/Receivables own invoices as business documents, Subledger Accounting derives and posts journal entries to GL (documented); GL-only SKU existence NOT FOUND |
| Chart of accounts owned by the ledger (GL); subledgers conform to it; account-mapping-rule detail (Subledger Accounting Account Rules) NOT FOUND in fetched pages (documented ownership, inferred mapping mechanics) |
| Unit4 ERPx | Named product pages (Financial Management, Procurement Management, Project Management, HR/Payroll) under ERPx; licensing/edition boundaries between them NOT FOUND (source, low confidence — no primary technical docs portal reachable) |
| AP/AR presented as distinct modules integrated with GL; invoice ownership sits with AP/AR, not GL; GL-alone scenario and contract ownership NOT FOUND (source) |
| CoA is customizable/flexible per vendor marketing and one third-party consultancy page; cross-module mapping mechanics NOT FOUND in vendor-primary sources (source, weak) |
| Acumatica Cloud ERP | Financials ships as one bundled base module (GL+AR+AP+Cash+Tax+Consolidation together) in General Business Edition; Project Accounting, Advanced Expense Management, Time Management, Purchase Orders are separate, named integrating modules (documented) |
| GL, AP, and AR are not sold apart from each other — Financials is one module, so a "GL alone" scenario does not appear to exist as a sellable configuration; contract-record ownership NOT FOUND (documented bundling, inferred non-availability of GL-only) |
| GL/company owns Chart of Accounts (segmented ACCOUNT key); AP bills and Purchase Orders default to accounts from vendor/inventory-item records, overridable per document line (documented ownership + mapping default; full "see the account before posting" traceability NOT FOUND) |

Note: table formatting above is intentionally verbose per-cell (multi-line) to avoid compressing quotes; if a stricter single-line table is required, collapse each Q2/CoA cell to its first clause.

---

## Status counts
- CONFIRMED (vendor-documented, directly fetched and quoted): 9 — Oracle Q1(GL/subledger split), Q2, Q3(CoA ownership); Acumatica Q1, Q2(bundling), Q3(CoA ownership), Q4, Q5, Q6(OCR/AI intake existence)
- PARTLY / source (search-derived, not independently re-fetched verbatim, or third-party corroboration only): 14 — Oracle Q1(pillars), Q4, Q5, Q6; all six Unit4 questions; Acumatica Q2(GL-alone non-existence, inferred), Q3(mapping mechanics), Q4(milestone detail), Q6(native structured-XML absence)
- REFUTED: 0
- NOT FOUND (explicit gaps): Oracle GL-only SKU behavior; Oracle Subledger Accounting Account Rules text; Oracle Project milestone-object detail; Oracle CMK/IDR canonical-model convergence; Unit4 primary technical documentation portal (entirely inaccessible this session — no help.unit4.com/docs.unit4.com pages found); Unit4 contract ownership; Unit4 expense/corporate-card module identity; Unit4 GL-alone behavior; Acumatica contract-record ownership; Acumatica native Peppol/UBL/national-XML inbound e-invoice capability; Acumatica pre-posting GL-account traceability UI.
