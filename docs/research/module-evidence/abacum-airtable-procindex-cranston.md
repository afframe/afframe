# Module boundaries and record ownership: Abacum, Airtable, ProcIndex, Cranston

Scope note up front: of the four apps, only Airtable is a general business-app platform with CRM/Sales/Projects-shaped building blocks available to build with. Abacum, ProcIndex and Cranston are all narrow, single-domain products (FP&A; AP/AR/close automation; tax/bookkeeping automation) that explicitly do **not** contain CRM, Sales, or Projects modules and do **not** claim to be systems of record — they sit on top of an ERP/CRM/tax system and read or write into it. That absence is itself evidence for the owner's question: real narrow-domain vendors deliberately avoid owning sales or contact data and instead integrate with the systems that do.

## Identification of unclear names

- **ProcIndex** — identified with confidence. Vendor site `procindex.com`, tagline "AI Accounting Agents for Construction & Manufacturing." Label: source.
- **Cranston** — identified with confidence. Vendor site `cranston.ai`, "AI Tax and Accounting Software for CPA Firms." Label: source.

---

## Abacum (FP&A)

### Q1. Top-level modules / what's sold separately
- Label: source. URL: https://www.abacum.ai/product/reporting and https://www.abacum.ai/product/data (site navigation exposes separate product pages: Planning, Reporting, Intelligence, Data, Integrations, Excel connector).
- Label: inferred (from WebFetch summarization of abacum.ai homepage, not a direct quote — could not retrieve a verbatim block; original `/product` URL returned HTTP 404). Abacum markets itself as one platform ("end-to-end business planning platform") rather than separately priced modules; no evidence found of per-module pricing/editions. NOT FOUND: a public pricing page breaking out modules as add-ons.

### Q2. Records each module owns
- Label: inferred. Planning module: plans, budgets, forecasts, driver-based models, scenarios, versions/assumptions. Reporting module: dashboards, report templates, variance analysis. NOT FOUND: an Abacum API/object reference enumerating exact record types (no public API docs located in this pass).

### Q3. Sales
- NOT FOUND. Abacum has no quote/order/invoice objects; it is not a sales system. It reads revenue/billing actuals from source systems (see Q on actuals below) but does not originate sales documents.

### Q4. CRM
- NOT FOUND. Abacum has no CRM module. It lists Salesforce and HubSpot as source-system integrations for actuals (pipeline/bookings data), not as something it replaces or owns.

### Q5. Projects
- NOT FOUND for a dedicated Projects module. Abacum's "headcount planning" and "revenue planning" are planning dimensions, not project-execution records (no tasks/milestones/timesheets found).

### Q6. Finance/Accounting
- NOT FOUND (Abacum is not the ledger). It explicitly separates itself from the ERP: actuals (the ledger truth) live in the ERP; Abacum only plans against them.
  - Label: source. URL: https://www.abacum.ai/product/data. Quote (per WebFetch extraction, not independently re-verified verbatim): "700+ native integrations connect ERP, HRIS, CRM, billing, and data-lake systems directly, including Salesforce, NetSuite, Sage Intacct, Snowflake, BigQuery, Stripe, and Gusto." and "Actuals update, models and reports refresh instantly - no manual copy paste."

### Q7. Documents
- NOT FOUND.

### Q8. Contacts
- NOT FOUND. No contact/company master mentioned.

### Abacum-specific: source systems for actuals, and what it owns itself
- Label: source. URL: https://www.abacum.ai/product/data. Source systems named: ERP, HRIS, CRM, billing, data-lake systems — specifically Salesforce, NetSuite, Sage Intacct, Snowflake, BigQuery, Stripe, Gusto.
- Label: marketing/source (WebFetch-summarized, quote fidelity approximate — flagging rather than presenting as a verbatim quote): "Bring actuals, assumptions, and plans together," addressing the stated problem that "Actuals, assumptions, and plans live in different places."
- What Abacum owns itself: plans, assumptions, driver-based models, scenarios/versions, forecasts, workflow/approval state for those plans. It does not own actuals — actuals are read (one-way, per available evidence) from the connected systems of record.
- Additional integration evidence: Label: third-party/marketing. URL: https://www.maxio.com/integrations/abacum — "connects billing actuals and financial planning to create a direct pipeline between billing actuals and financial planning." URL: https://www.rillet.com/blog/rillet-and-abacum-partnership — describes syncing Rillet's "real-time financial actuals" into Abacum "without manual effort," reinforcing that the ledger/actuals system of record is external (Rillet, an accounting system) and Abacum is consumer, not owner, of those actuals.

---

## Airtable (base/table/interface platform)

### Q1. Top-level modules / what's sold separately
- Label: source. URL: https://airtable.com/pricing. Plans found: Free, Team ($20/user/month annual), Business ($45/user/month annual), Enterprise Scale (custom). Quote: "Airtable plans are charged per seat."
- Label: inferred. Feature set (bases, tables, Interfaces, automations, sync) is bundled per seat/plan rather than sold as separately priced modules — no evidence of an "Interfaces" or "Sync" add-on SKU found. NOT FOUND: a detailed feature-by-plan matrix (the pricing page's comparison table content wasn't retrievable via fetch).

### Q2. Records each "module" owns
- Label: documented. URL: https://support.airtable.com/docs/linking-records-in-airtable. A **base** is the container; **tables** hold **records**; **fields** define record shape. Airtable's own architecture description (via WebSearch synthesis of support docs): "The platform is structured on five core building blocks: bases, tables, fields, records, and views." Each table owns its own records (e.g., a "Projects" table owns project records, an "Action Items" table owns task records) — ownership is per-table, not per-app.
- **Interfaces**: Label: source (page URL returned 404 on direct fetch during this pass, so treating this as inferred from Airtable's own product description surfaced via search) — an Interface is a layer built on top of base data (dashboards, forms, record views); it does not appear to create its own independent record store separate from the underlying tables. NOT FOUND: a direct quote confirming Interfaces cannot own novel records not backed by a table.

### Q3–Q5. Sales / CRM / Projects
- NOT FOUND as fixed modules — Airtable is domain-agnostic. Users build a "Sales CRM base," "Projects base," etc. themselves; Airtable ships template bases (e.g., a Sales CRM template) but these are configurations of the same table/record/link primitives, not separately owned system modules. This is the key architectural fact for the owner's question: Airtable proves you *can* build Sales, CRM and Projects as separate bases/tables that share the same underlying record-linking mechanism, but the platform itself does not draw a boundary — the app builder does.

### Q6. Finance/Accounting
- NOT FOUND (no native accounting ledger; third-party template bases exist but are not part of the core platform's owned record types).

### Q7. Documents
- Label: inferred. Airtable fields support "attachments" as a field type (per WebSearch synthesis of support docs on table structure), so files attach to records within a table rather than living in a separate, independent documents module. NOT FOUND: a dedicated "Documents module" distinct from attachment fields.

### Q8. Contacts
- NOT FOUND as a single mandated contacts master. Any table can serve as a shared contacts table and be linked from multiple other tables (deals, invoices, tasks) via linked-record fields — Airtable's mechanism is generic enough to support one shared contacts table across all "apps" built in a base, but this is a modeling choice, not an enforced platform rule.

### Airtable-specific: how one platform lets apps share/link records without copying
- Label: documented. URL: https://support.airtable.com/docs/linking-records-in-airtable. Quote (per WebFetch extraction): "The association is automatically mirrored in the other table." — linking a record in Table A to Table B creates a bidirectional reference; "Linked records function as references between tables—they don't copy data, they reference it." Lookup fields "dynamically display values stored in linked records," and "Any updates to the original field will automatically persist in the lookup" — i.e., a single source-of-truth record is referenced (not duplicated) across every table/app that links to it.
- Cross-base limitation (important boundary): Label: third-party (community/blog sources, not Airtable's own docs, since official docs on this specific limitation weren't directly fetched — treat as third-party pending verification). URL: https://blog.coupler.io/how-to-link-bases-in-airtable/ and https://community.airtable.com discussions. Finding: "There is currently no way to link individual records to each other across bases" directly — true record-linking (mirrored, live references) only works **within a single base**; connecting data **across bases** requires "sync" (which copies/mirrors views and records into a destination base, including — as of an August 2024 rollout — preserving linked-record relationships in synced tables). This is a materially important nuance: Airtable's "no-copy, shared-record" model is scoped to one base; cross-base sharing falls back to a sync/copy mechanism, not a live shared record.

---

## ProcIndex (identified: AI accounting agents for construction & manufacturing)

### Q1. Top-level modules / what's sold separately
- Label: source. URL: https://procindex.com/. Products are sold as separate agents: AP Agent, AR Agent, Vendor Agent, Recon Agent (per site navigation/product pages, e.g. https://procindex.com/product/autonomous-ap, https://procindex.com/product/autonomous-ar). No CRM, Sales, Projects, or FP&A modules exist in the core product (an "FP&A Agent" listing appears on the third-party review aggregator SOTA2 — label: third-party, URL: https://www.sota2.com/products/procindex-procindex-fp-a-agent — not independently confirmed on procindex.com in this pass).

### Q2. Records each module owns
- Label: source (via WebFetch of https://procindex.com/). ProcIndex does not own records; it is described as connecting "to your ERP as the system of record." It reads/writes "vendors, purchase orders, projects, dimensions, and transaction data" that live in the ERP.
- AP Agent (Label: source, URL: https://procindex.com/product/autonomous-ap): "Reads incoming invoices, matches them to ERP purchase orders, applies coding, routes approvals, and posts approved transactions" — processes invoices and POs but posts the resulting transaction back into the ERP rather than retaining it as ProcIndex's own ledger record.
- AR Agent: "Follows up on overdue ERP receivables, tracks promises to pay, and keeps disputes ... visible" — works against ERP-resident receivables, not a ProcIndex-owned AR ledger.

### Q3. Sales
- NOT FOUND. No quote/order module. ProcIndex is downstream of sales (it processes AR/invoices that originate in the ERP), not a sales origination system.

### Q4. CRM
- NOT FOUND. No CRM functionality.

### Q5. Projects
- Label: inferred/source. "Projects" appears only as an ERP dimension that ProcIndex reads for coding purposes ("vendors, purchase orders, projects, dimensions, and transaction data"), not as a module ProcIndex owns.

### Q6. Finance/Accounting
- Label: source. ProcIndex explicitly disclaims ownership of the ledger: it "connects to your ERP as the system of record" and integrates with SAP S/4HANA, Oracle ERP, NetSuite, Dynamics 365, Sage Intacct, QuickBooks, Acumatica, Epicor (per site content). It automates AP/AR/reconciliation/close workflows but the invoice, bill, and journal-entry records of authority remain in the connected ERP.

### Q7. Documents
- Label: inferred. AP Agent "captures invoices from email and portals" — it ingests documents as an input channel but does not present itself as a general-purpose document/file vault; documents feed the AP workflow and the resulting transaction is posted to the ERP.

### Q8. Contacts
- NOT FOUND for a person/contact master; "vendors" (per ERP) are the closest analog, and ProcIndex reads/matches against ERP vendor master data rather than owning its own.

---

## Cranston (identified: AI tax and accounting software for CPA firms, cranston.ai)

### Q1. Top-level modules / what's sold separately
- Label: source. URL: https://cranston.ai/. Modules (per site content): Tax Prep, Document Check, Bookkeeping, Practice Management. No evidence found of these being sold as separately priced editions/add-ons (appears to be one product). NOT FOUND: a public pricing/tiers page.

### Q2. Records each module owns
- Tax Prep: reads client documents, enters data into external tax software (Drake, Lacerte, CCH Axcess, UltraTax) — does not own the tax return record; the tax-prep application does.
- Bookkeeping: "classifies transactions, reconciles accounts, and drafts journal entries in QuickBooks" — journal entries are drafted *in QuickBooks*, i.e., QuickBooks (not Cranston) is the ledger system of record.
- Practice Management: tracks "client status across returns" (workflow/status state), not itself a book of record for financial documents.

### Q3–Q6. Sales / CRM / Projects / Finance
- NOT FOUND for Sales, CRM, or Projects — Cranston has none of these; it is a vertical automation layer for a CPA firm's tax/bookkeeping practice, not a general business suite.
- Finance/Accounting: Cranston does not own the ledger. Label: source. Quote: "Cranston connects to QuickBooks, Drake, TaxDome, and Gmail. You keep your current software and data." The general ledger of record is QuickBooks; Cranston only drafts entries into it.

### Q7. Documents
- Label: source/inferred. Cranston coordinates "source docs, books, returns, and threads together" in a client workspace, but this reads as a coordination/aggregation layer over documents that live in connected systems (Gmail, TaxDome, tax software) rather than an independent document-of-record vault. NOT FOUND: an explicit statement that Cranston is the system of record for uploaded files (evidence suggests TaxDome plays that role for client documents, with Cranston reading/writing against it).

### Q8. Contacts
- Label: inferred. Client identity/contact data appears sourced from TaxDome (the practice's client-management system) rather than owned independently by Cranston. NOT FOUND: explicit confirmation.

---

## Summary table

| App | Top-level modules | Sales: owner & channels | CRM role | Projects role | Documents module | Shared contacts |
|---|---|---|---|---|---|---|
| Abacum | Planning, Reporting, Intelligence, Data/Integrations (one platform; no evidence of per-module editions) | NOT FOUND — no sales module; reads CRM/billing actuals (Salesforce, HubSpot, Stripe) as input, originates nothing | Not owned; CRM (Salesforce/HubSpot) is only a read-only actuals source | NOT FOUND as a module; headcount/revenue planning are planning dimensions, not project-execution records | NOT FOUND | NOT FOUND |
| Airtable | None fixed — platform primitives (base, table, field, record, view, Interface) that users configure into apps like "Sales CRM," "Projects," etc.; one per-seat pricing plan, not per-module | Not predetermined — whichever table the builder designates; Airtable enforces no boundary | Same — CRM is a base/table configuration, not a distinct owned module | Same — Projects is a base/table configuration; linked records make it a view/dimension over shared data if modeled that way | Attachment fields on records, not a separate module | Achievable via one shared contacts table linked from other tables (within a base); cross-base sharing needs sync (copy), not live linking |
| ProcIndex | AP Agent, AR Agent, Vendor Agent, Recon Agent — sold as separate agents; ERP is system of record | Not owned by ProcIndex; it processes AR/AP transactions that originate in the connected ERP | NOT FOUND — no CRM | Projects only as an ERP coding dimension it reads, not owned | Ingests invoices/documents as workflow input; not a document-of-record vault | No contact master; matches against ERP vendor master data |
| Cranston | Tax Prep, Document Check, Bookkeeping, Practice Management — appears as one bundled product | Not applicable/NOT FOUND — vertical tax/bookkeeping tool, no sales module; ledger of record is QuickBooks | NOT FOUND — no CRM; likely relies on TaxDome for client data | NOT FOUND — Practice Management tracks workflow status, not project execution records | Coordinates documents across Gmail/TaxDome/tax software; not clearly the system of record for files | Likely sourced from TaxDome; NOT FOUND confirmed independently |

### Relevance to the owner's question
None of the four vendors researched are general business suites that natively resolve "does Sales sit in CRM, Projects, or Finance." The clearest architectural signal is negative-space evidence: three of the four products (Abacum, ProcIndex, Cranston) are narrow, single-domain tools that explicitly refuse to own another domain's records and instead integrate with the external system that owns them (Abacum reads CRM/billing actuals but doesn't touch sales documents; ProcIndex/Cranston treat the ERP/ledger as the sole system of record and never assert ownership of sales or CRM data). Airtable is the one platform that shows the alternative model at the mechanism level: a single shared, live-linked record can be referenced by multiple purpose-built apps (a "Sales" table, a "Projects" table, a "Contacts" table) without duplication — but only within one base; the moment you cross a base boundary, Airtable's own limitation is that live linking stops working and you fall back to a sync (copy), which is exactly the failure mode Afframe should design against if Sales, CRM, Projects and Finance are meant to reference the same customer/sale record live rather than via copies.
