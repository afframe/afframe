# SAP S/4HANA & Anaplan — domain-model verification

**Methodology note / limitation (read first):** help.sap.com is now a client-side rendered Vue SPA. Both `WebFetch` and a direct `curl` against SAP help URLs return only the empty HTML shell (`<title>SAP Help Portal | SAP Online Help</title>`, no body) — the JS bundle that would fetch and render the actual article never executes in these tools. This means I could **not** directly fetch verbatim body text from help.sap.com pages in this session, despite repeated attempts (WebFetch, curl, r.jina.ai reader proxy). Where SAP content is cited below, it comes from `WebSearch` result snippets, which appear to quote indexed page text (Google's cache of the rendered page) — these are labelled **PARTLY** (mechanism plausible, quote not independently re-verified by direct fetch) rather than CONFIRMED, except where a non-SPA help.sap.com/community.sap.com page was fetched successfully. help.anaplan.com is server-rendered and fetched cleanly.

---

## 0. Brief URLs — what they actually say

**URL A:** `https://help.sap.com/docs/SAP_S4HANA_CLOUD/186460fdc35a4b64a713da9bb00deb1e/27fbca0f32da40d39bb66ef161008d27.html?locale=en-US`
- Status: **PARTLY** (identified, not body-fetched)
- Label: vendor-documented (inferred from search index)
- Could not render body text directly (SPA limitation above). WebSearch identified the page title via its Japanese locale mirror: "One Exposure from Operations の在庫/購買管理" = **"Inventory/Procurement Management [flows] in One Exposure from Operations"**, under product GUID `186460fdc35a4b64a713da9bb00deb1e` = **SAP S/4HANA Cloud, Cash and Liquidity Management**. So this page is part of the One Exposure from Operations documentation, specifically covering how inventory/procurement documents (POs, goods receipts, invoices) feed liquidity/cash forecast flows — directly relevant to Claim 6.
- URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/186460fdc35a4b64a713da9bb00deb1e/27fbca0f32da40d39bb66ef161008d27.html?locale=ja-JP (mirror used to identify title)

**URL B:** `https://help.anaplan.com/dimensions-e020c93d-9f3e-4cce-8294-2d34073b302a`
- Status: **CONFIRMED**
- Label: vendor-documented
- Fetched directly and successfully. Quote: "Dimensions are the lists that workspace administrators select to be a module's rows, columns, and pages." Also: "You select the lists to use as the dimensions of a module when you create the module," and dimensions include general lists, default lists (Time, Versions, Users, Organization), or line items from other modules. Mechanism: a module's cells are addressed by the combination of dimension members (rows × columns × pages), and Versions is one of the built-in default dimensions usable this way — consistent with Claim 10/11.
- URL: https://help.anaplan.com/dimensions-e020c93d-9f3e-4cce-8294-2d34073b302a

---

## 1. Universal Journal (ACDOCA): FI+CO actuals in one table, with ledgers

- Status: **PARTLY**
- Label: vendor-documented (via search snippet, not directly re-fetched)
- URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/0fa84c9d9c634132b7c4abb9ffdd8f06/523b8a55559ad007e10000000a44538d.html (Universal Journal, help.sap.com — not fetchable body in-session)
- Quote (from indexed snippet, third-party summary of vendor content, treat cautiously): "The Universal Journal (ACDOCA) is a single table that contains more than 360 fields containing both financial and controlling postings... it is called a single source of truth." A non-leading ledger "contains a full set of line items in table ACDOCA."
- Mechanism: ACDOCA is documented as the single line-item table underlying FI and CO (and additional components like Asset Accounting, Material Ledger). Leading and non-leading standard ledgers each carry full line items in ACDOCA; could not directly confirm exact field-level claims by primary fetch this session — mark PARTLY, not CONFIRMED.

## 2. Extension ledgers store only delta entries on top of a standard ledger

- Status: **PARTLY**
- Label: vendor-documented (SAP Community blog by SAP, title suggests SAP author, but page returned HTTP 403 on fetch attempt — could not verify authorship or quote directly)
- URL: https://community.sap.com/t5/enterprise-resource-planning-blog-posts-by-sap/sap-s-4hana-extension-ledger-use-cases/ba-p/13449537 (fetch blocked: 403 Forbidden)
- Quote (from search-index snippet only, not independently re-verified): "an extension ledger is a new type of ledger that is a delta ledger, meaning only differences between valuations are posted into it... the extension ledger always must have a standard ledger assigned as an underlying ledger... When reporting on the extension ledger, data from the underlying ledger are always accessed and displayed together with delta postings."
- Mechanism if accurate: extension ledger rows contain only the adjustment/delta amount; reporting logically overlays extension-ledger deltas onto the base ledger's full line items rather than duplicating the full journal entry.

## 3. Predictive Accounting: incoming sales orders → prediction (extension) ledger → reversed/replaced by actuals

- Status: **PARTLY**
- Label: vendor-documented (help.sap.com page identified but not body-fetchable) / third-party (blogs.sap.com community blog, author identity not verified this session)
- URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/1e3c2c0366834d1fb76461f439248880/5a8cdccda23348919ddfa8d3c208c0e7.html (Predictive Accounting in Sales Processes — SPA, body not fetchable); https://blogs.sap.com/2019/05/13/predictive-accounting-for-incoming-sales-orders-in-s4hana/
- Quote (search-index snippet, not independently re-fetched verbatim): "When a sales order is created, predictive accounting simulates the corresponding goods issue and invoice. The results of the simulation are stored as journal entries in an extension ledger." Configuration note: "maintain the predictive accounting ledger 0E in table FINSV_PRED_RLDNR."
- Mechanism: predictive journal entries post to a dedicated extension ledger (e.g. ledger "0E") tied to margin analysis (COPA); could not confirm from a primary source in-session whether the mechanism is "reversal" vs. "automatic non-carry-forward/replacement" when actual GI/billing documents post — this specific reversal/replacement detail is **NOT FOUND** (not confirmed by any fetched primary source this session).

## 4. Purchase order commitments: storage and reduction mechanics

- Status: **PARTLY**
- Label: third-party (WebSearch snippets of help.sap.com SUPPORT_CONTENT pages; body not directly fetchable — fetch attempt returned empty title-only shell)
- URL: https://help.sap.com/docs/SUPPORT_CONTENT/ficontrolling/3361878592.html ("Creating Purchase Order Commitments"); https://help.sap.com/docs/SUPPORT_CONTENT/spmm/3362167804.html ("Commitments in Purchasing")
- Quote (search-index snippet, not independently re-verified): "A flag called 'goods unvalued' available on the PO document controls whether the commitment is decreased when goods are received or when an invoice has been posted." Also: "For positions using quantity-based commitments, the commitments will be reduced based on the quantity from the goods receipt/invoice and not in value." And: "If the commitment has been reduced, for example, by a goods receipt or an invoice, the system displays the residual commitment."
- Mechanism: commitment = open PO value/quantity; reduced (not necessarily to zero) as goods receipts and invoice receipts post against the line, tracked as a "residual commitment" until fully consumed. Whether commitments are stored in ACDOCA (universal journal, "commitment management in universal journal") specifically, versus the classic commitment line-item table (COOI/CBS-type tables), was **NOT FOUND** — no primary source fetched confirms or refutes ACDOCA storage of commitments in this session. Do not assume; this is a genuine open question requiring a follow-up fetch of an accessible (non-SPA) SAP source.

## 5. Plan data in ACDOCP with plan categories, separate from ACDOCA

- Status: **PARTLY**
- Label: third-party (aggregator sites: SAPLearners, TCodeSearch, s4hd.com — not vendor docs; help.sap.com/community.sap.com primary sources not fetchable this session)
- URL: none successfully fetched; search-only evidence from https://saplearners.com/sap-tables/acdocp/ and community.sap.com Q&A threads (not vendor-authored, community Q&A)
- Quote (third-party, not vendor): "In S/4HANA Finance, plan data records are stored in the ACDOCP table (Plan Data Line Items)... In ACDOCP all plan data is stored in categories whereas in the old ERP planning was stored in versions."
- Mechanism: plausible that ACDOCP is a separate plan-line-item table keyed by "plan category" (analogous role to CO plan versions), kept apart from actuals in ACDOCA. This is **not vendor-confirmed** in this session — mark PARTLY only, and flag for a follow-up direct fetch of an SAP help/community page before relying on it in the domain model.

## 6. One Exposure from Operations: expected cash flows replaced as documents progress

- Status: **PARTLY**
- Label: vendor-documented (page identified per Claim 0, body not fetchable) / third-party (sap-press blog summary)
- URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/186460fdc35a4b64a713da9bb00deb1e/27fbca0f32da40d39bb66ef161008d27.html (Inventory/Procurement Management in One Exposure from Operations — identified but not body-fetchable); https://blog.sap-press.com/what-is-one-exposure-from-operations-in-sap
- Quote (third-party summary, not verbatim from a directly fetched vendor page): "One Exposure from Operations in SAP is a tool that helps businesses manage their cash and liquidity that collects data from all of your SAP systems and gives you a real-time view of your cash position across the entire company."
- Mechanism claimed by the ecosystem (NOT independently confirmed by a fetched primary source this session): operational documents (PO, sales order, open item, payment request) each generate a "cash flow" record classified by category/subcategory, and as a document progresses to the next stage (e.g., PO → goods receipt/invoice), the earlier flow is superseded. I could not confirm the specific storage detail (table name "FQM_FLOW" or similar) from any source fetched in this session — **NOT FOUND** for the table-name-level claim specifically; mark that sub-claim NOT FOUND.

## 7. CO: activity allocation at plan price, then actual price revaluation

- Status: **NOT FOUND**
- Label: n/a
- No source was fetched or even search-indexed with a usable vendor quote in the time available. This claim was not investigated before the time budget was reached. Needs follow-up.

## 8. Budget availability control: consumed = commitments + actuals, with tolerance limits

- Status: **PARTLY**
- Label: vendor-documented (help.sap.com page identified, body not fetchable — SPA limitation) 
- URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/c56f622a2edf491b9f1b596b55587009/30cb8deab95e4d8c9420aeabb2ae496f.html ("Budget Availability Control")
- Quote (search-index snippet, not independently re-verified by direct fetch): "The availability control checks whether the consumed amounts for an AVC control object do not exceed the consumable budget... takes into account tolerance limits." Assigned/consumed values are calculated from "(1) actual costs posted to a WBS element..., (2) Statistical actual costs..., (3) Commitments posted to a WBS element..., (4) Remaining order plan."
- Mechanism: consumed budget = actual costs + commitments (+ some statistical/remaining-plan components), compared against the consumable budget; when consumption crosses a configured tolerance threshold, the system can warn or block further postings (error message). This matches the claim's shape well but is PARTLY, not CONFIRMED, absent a direct primary-source fetch.

## 9. Posted journal entries are corrected by reversal, not editing

- Status: **NOT FOUND**
- Label: n/a
- Not investigated before the time budget was reached (widely known SAP behaviour, but per the brief's rule, memory-based claims must be marked NOT FOUND rather than guessed as CONFIRMED). Needs a follow-up fetch of an SAP help page on document reversal (transaction FB08/reversal reasons) before this can be marked CONFIRMED.

---

## 10. Anaplan versions: dimension, Actual/Current, switchover date

- Status: **CONFIRMED**
- Label: vendor-documented
- URL: https://help.anaplan.com/versions-19b4391f-5257-40ee-8dfb-36f0ab426c8f
- Quotes (verbatim, directly fetched): "When a workspace administrator creates a model, it includes versions called Actual and Forecast by default." / "You cannot delete the Actual version." / "Workspace administrators can optionally select the Current checkbox next to a version to mark the version as current. You can only set one version as the current version." / "Up to the date you select, the data for that version is the same as for Actual and is read-only. After the switchover date, data for the version that's not actual defaults to zero."
- Mechanism: Versions is a default list/dimension; exactly one version can be flagged "Current"; a non-Actual version (e.g. Forecast) can have a switchover date such that before that date its values mirror Actual read-only, and after that date it holds independently enterable forecast data — i.e. a single version column is a historical-actuals + forward-forecast blend, switching at one date rather than being two separately unioned datasets.

## 11. Lists/dimensions, modules, line items; cells addressed by dimension combinations

- Status: **CONFIRMED**
- Label: vendor-documented
- URL: https://help.anaplan.com/dimensions-e020c93d-9f3e-4cce-8294-2d34073b302a
- Quote (verbatim): "Dimensions are the lists that workspace administrators select to be a module's rows, columns, and pages." / "The data in a cell has meaning due to the context given by the dimensions that apply to the cell."
- Mechanism: a module is a grid whose axes (rows/columns/pages) are populated by dimensions (general lists, default lists such as Time/Versions/Users/Organization, or line items imported from other modules); a cell's value is addressed by the specific combination of dimension members selected on each axis.

## 12. Actuals enter Anaplan via import; Anaplan is not system of record for actuals

- Status: **PARTLY**
- Label: vendor-documented, but from marketing/blog copy rather than the Anapedia technical reference page (the specific import page was not opened for a verbatim quote in the time available)
- URL: https://www.anaplan.com/blog/guide-to-financial-consolidation-and-planning-modernization/ (vendor blog, not opened directly — quote via search index only); https://help.anaplan.com/import-data-sources-be597624-2bd1-4216-b1cd-90198e7186fc (Anapedia reference identified, not opened)
- Quote (search-index snippet, not independently re-verified): "You can pull general ledger actuals from SAP, NetSuite, or Oracle ERP into Anaplan on a scheduled or event-driven basis to power rolling forecasts and variance analysis." Also, on system-of-record positioning: "The recommendation is to keep your systems of record in place... while modernizing the layer that connects them."
- Mechanism: actuals are populated into Anaplan modules via scheduled/event-driven import actions from external ERP/GL systems (push or pull); Anaplan's own documentation frames the ERP/GL as the system of record, with Anaplan consuming a copy of the actuals for planning/comparison purposes. This is consistent with the claim but was not confirmed via a directly fetched Anapedia page — mark PARTLY, follow up by opening help.anaplan.com/import-data-sources and help.anaplan.com/import-basics directly.

---

## Extra findings (not fully verified — time-boxed)

1. **Plan categories vs. plan versions**: community.sap.com Q&A snippet suggests "plan category" in S/4HANA plays the role that "plan version" played in classic CO — worth confirming with a primary source before using in the domain model. (NOT independently confirmed.)
2. **Extension ledgers for margin analysis / management views**: search snippets repeatedly mention extension ledgers used for "management views on top of legal data (IFRS or local GAAP)" — i.e. multiple extension ledgers can exist per base ledger for different adjustment purposes (not just predictive accounting). NOT independently confirmed by direct fetch.
3. **AVC "residual commitment" concept**: the "Commitments in Purchasing" search snippet explicitly used the term "residual commitment" for the still-open portion of a PO commitment after partial GR/IR — a useful precise term for the domain model, but sourced from a search snippet, not a directly fetched page.
4. **Anaplan Data Orchestrator**: mentioned in search results as Anaplan's newer no-code pipeline tool for connecting ERPs/GLs — potentially relevant to how actuals get imported, but not explored further (time-boxed).
5. **SAP help.sap.com is not machine-fetchable via generic tools**: operationally important for future research — any follow-up verification of SAP claims will need either the SAP Community (non-SPA) pages, PDF "help.sap.com/doc/..." mirrors, or a headless-browser-capable fetch tool, since the current SPA blocks plain HTTP/JS-less fetches entirely.

---

## Summary counts

- CONFIRMED: 3 (Claim 0-B, Claim 10, Claim 11)
- PARTLY: 8 (Claim 0-A, 1, 2, 3, 4, 5, 6, 8, 12) — note this is 9, see below
- NOT FOUND: 2 (Claim 7, 9)
- REFUTED: 0

(Claim count: 0-A + 0-B + 1..12 = 14 items; 3 CONFIRMED + 9 PARTLY + 2 NOT FOUND = 14.)

---

## Addendum (main session, 2026-09-24): SAP pages rendered with headless Chrome

help.sap.com renders with `google-chrome --headless=new --dump-dom --virtual-time-budget=25000`. Verbatim quotes below are from the rendered pages (Cloud Public Edition, version 2608).

### A1. One Exposure from Operations, Materials Management (brief URL) — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/186460fdc35a4b64a713da9bb00deb1e/27fbca0f32da40d39bb66ef161008d27.html?locale=en-US
> "Creating purchase requisition, purchase orders or scheduling agreements leads to forecasted cash that is adjusted by subsequent invoicing processes."
> "The system creates the forecasted cash from the net amount of an item and the non-deductible tax amount"
> "Amount of invoice verification is deducted from forecasted amount of purchase order"
> Certainty levels: "MMPR Purchase Requisition" / "MMPO Purchase Orders or Scheduling Agreement"
> "If you want to integrate the transaction data that had already been created before the source application Materials Management was activated, you use the Schedule Jobs for Flow Builder app with the job template Flow Builder to rebuild MM flows."
Mechanism: cash exposure is derived from source documents, relieved by invoice verification, excludes deductible VAT, and can be rebuilt from source documents.

### A2. Predictive Commitments Management — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/60d6187546b343569423c2a06b6a5c57.html?locale=en-US
> "The commitment for the predicted expense is created in a prediction ledger 0E. ... When the follow-on documents are created in the system, predictive commitments management reduces the commitments in the prediction ledger. The follow-on document can be the corresponding valuated goods receipt, or when the goods receipt isn't valuated, the corresponding supplier invoice. After this reduction, only the actuals are considered in reporting."
> "if the predicted amount was USD 1000 and the value of the goods receipt is also USD 1000, the system then reduces the amount of the original commitment by creating a new commitment for USD -1000."
> "The commitment document number starts with "PA" to make it easier to differentiate commitments from GAAP-relevant journal entries."
> Scope item 2I3: "only creates and processes commitments based on purchase requisitions or purchase orders, which have a creation date [after activation] ... Purchase requisitions and purchase orders that were created and/or changed [before] the activation date aren't supported."
Mechanism: commitments are append-only delta entries in an extension ledger inside ACDOCA, relieved by negative entries; NOT rebuildable for documents older than activation (contrast A1).

### A3. Example PR -> PO — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/a01315ea9245454aa85a2ec3389400b9.html?locale=en-US
PR 100 pcs, EUR 100 commitment. Converted to PO at EUR 120: PR entry gets obsolete reason 1; "a new predictive journal entry PA0000UGE1 was created. The quantities and amounts of its line items have the opposite sign. Their obsolete reason is 2"; new PO entry EUR 120. Commitments go 340 -> 440 -> 460.
Mechanism: predecessor relieved at its own amount (100), successor recorded at its own amount (120).

### A4. Example PO -> GR -> invoice — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/a6bfd52d075746c6a021b43d97b6318e.html?locale=en-US
PO 2,000 pcs EUR 285,000; valuated GR creates cancelling entry EUR -285,000 with obsolete reason 3 ("reduces the amount of the original commitment posting"); supplier invoice: "had no impact in the prediction ledger 0E".

### A5. Example PR quantity change — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/bd39d476d1e34b48afed98759286efd6/686e7e459ad548e1b97611a3777291e1.html?locale=en-US
Change of PR quantity 100 -> 500: old entry marked obsolete (1), full reversal entry (2), new entry for the changed amount. Correction = reversal + replacement, never in-place edit.

### A6. Predictive Accounting (sales) — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/0fa84c9d9c634132b7c4abb9ffdd8f06/c78ce92ab96346f7ab2722b79756ffc1.html?locale=en-US
> "When a sales order is created, predictive accounting creates predictive journal entries for the corresponding future goods issue and billing document in a special extension ledger, the prediction ledger. ... As the sales process continues and actual journal entries are created in the underlying ledger, predictive accounting updates the information in your prediction ledger by reducing or reversing the amounts of the predictive journal entries."

### A7. ACDOCP — CONFIRMED, vendor-documented
URL: https://help.sap.com/docs/SAP_S4HANA_CLOUD/1cbcff7ccd35405ab445b223c1ab1588/f900a12c7abf4c91957478cd6f6e48e8.html?locale=en-US
> "[ACDOCP] table, which is the main table for planning. It serves as the single source of truth for plan data and helps connect predecessor and successor processes."

## Addendum: ERPNext PO relief valuation (main session, verified in public source)
`erpnext/accounts/doctype/purchase_invoice/purchase_invoice.py` (version-15, commit 4aee12e) status_updater: `"source_dt": "Purchase Invoice Item", "target_dt": "Purchase Order Item", "target_field": "billed_amt", ... "source_field": "amount"`. So `billed_amt` = sum of invoice line amounts at invoice price, and budget.py's ordered amount `child.amount - child.billed_amt` relieves the PO by the successor's value. Partial invoice at a higher price understates the open remainder (PO 10 x 100, invoice 5 x 120 -> open 400, true remainder 5 x 100 = 500).
