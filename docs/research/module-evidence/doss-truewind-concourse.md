# Module evidence: Doss, Truewind, Concourse

Research question (owner): should Sales sit in CRM, Projects, or Finance, given sales can
come from CRM, a store, an outside party, or an asset disposal; if Sales lives in Finance
what is CRM for, and is Projects just a dashboard? Architecture only — modules, boundaries,
record ownership.

Method: live fetches of vendor marketing/help pages (no public API reference or source code
was found for any of the three — all are relatively young, private-pricing SaaS products, not
open-source). Budget ~20 minutes; evidence is therefore marketing/support-page depth, not API
docs. Every claim below is labelled. Time-boxed — treat gaps as NOT FOUND, not as absence.

Product identification: all three names are unambiguous matches for the apps named in the
brief once fetched — Doss = doss.com (AI-native composable ERP/"Adaptive Resource Platform"),
Truewind = truewind.ai (AI bookkeeping / "digital accountant"), Concourse = concourse.ai
(AI finance agents; concourse.co 308-redirects to concourse.ai, confirming it is the same
product, not a different company).

---

## Doss (doss.com)

### Q1. Top-level modules / what's sold separately
- Label: documented. Source: https://www.doss.com/solutions — Quote: module list on the
  page: "Demand Planning", "Finance & Accounting", "Freight & Fulfillment", "Inventory
  Management", "Order Management", "Procurement", "Production Planning", "Project
  Management", "Relationship Management", "Warehouse Management". Four platform-level
  products are also named: "ARP" ("Unify and automate your system of record"), "IDP"
  ("Transform, connect, and govern your data"), "DataStudio" ("Get real-time intelligence,
  directly in DOSS"), "Dossbot" ("Query, analyze and automate via chat").
- Label: documented. Source: https://www.doss.com/pricing — Quote: "We charge a single
  recurring fee for access to the platform, applications, and ongoing support. We don't
  charge a separate implementation fee, and you don't pay until you go live." No distinct
  editions or per-module pricing tiers are published; usage-based, single-subscription
  model. NOT FOUND: any module sold as a stand-alone SKU/edition — Doss appears to be sold
  as one composable platform rather than separately licensed products.

### Q2. Records per module
- Label: documented/inferred (page text, module attribution inferred from context).
  - Relationship Management: leads, deals, accounts, customer communications/timeline.
    Source: https://www.doss.com/solutions/relationship-management — Quote: "all customer
    interactions, project updates, and account history alongside orders, production status,
    and financial data" are centralized on the account; "On stage changes, workflows can
    create quotes, kick off production or onboarding tasks, and sync data to downstream
    systems."
  - Order Management: sales orders, order confirmations, CPQ quotes. Source:
    https://www.doss.com/blog/what-is-order-management — Quote: describes a sales order as
    "an internal document that a seller creates to confirm the details of a customer's
    purchase and authorize its fulfillment"; the module "captures, tracks, and fulfills
    customer orders" and aggregates "orders from Shopify, Amazon, email, EDI, and more";
    produces "Auto-generated PDFs and Confirmations."
  - Finance & Accounting: invoices, GL entries. Source: https://www.doss.com/erp — Quote:
    module labelled "FinAcc Bridge" in the page; mentions "GL integration — Run operations
    on DOSS" and "Contribution Margin — Accurate COGS & landed cost"; a customer quote notes
    invoicing time dropped from "a week" to "a couple of hours."
  - Project Management: budgets, tasks/deliverables, resource allocation, job costing.
    Source: https://www.doss.com/solutions/project-management (via search extract) — Quote:
    "track labor, materials, overhead, and vendor costs against project budgets in real
    time"; "supporting unlimited projects and deliverables, tightly integrated with
    budgeting, HR, and operations." Label: documented (page content retrieved via search
    snippet, not full WebFetch — treat as slightly weaker documented evidence).
  - Procurement: purchase orders, vendor management (label: marketing, from earlier module
    description; not independently re-verified this session).
  - Inventory/Warehouse/Freight & Fulfillment/Demand Planning: inventory records, shipments,
    forecasts (label: marketing, from https://www.doss.com/solutions module names; detail
    not independently quoted this session).
- NOT FOUND: an explicit "customer invoice" object definition, a "contract" object, or a
  documents/files object on any Doss page fetched this session.

### Q3. Sales ownership and channels
- Label: documented. Source: https://www.doss.com/blog/what-is-order-management — Order
  Management is the module that owns the sales order: "The sales order is the operational
  trigger that moves a transaction from a committed sale into the warehouse, production, and
  logistics systems that execute delivery." It ingests orders from multiple channels:
  Quote: "orders from Shopify, Amazon, email, EDI, and more" — i.e., e-commerce (Shopify,
  Amazon), manual/email one-offs, and EDI all land in the same Order Management object.
- Label: documented. Source: https://www.doss.com/solutions/relationship-management — CRM
  deals become quotes via workflow, not via CRM itself: "On stage changes, workflows can
  create quotes, kick off production or onboarding tasks, and sync data to downstream
  systems." So a CRM-originated sale still produces its quote/order artifact in the
  Order Management (CPQ) module, triggered by a CRM workflow event, not stored as a CRM
  record.
- Label: inferred. Finance & Accounting is downstream of Order Management for invoicing —
  the order-management page states the OMS gives "finance the ability to invoice cleanly"
  (https://www.doss.com/blog/what-is-order-management), implying Finance issues the
  customer invoice off the sales order, but this is not an explicit "Finance owns invoice
  object" statement — labelled inferred, not documented.
- NOT FOUND: explicit treatment of POS/retail-store sales, subscription billing, or sale of
  a company (fixed) asset as a distinct channel/object on any Doss page fetched.

### Q4. CRM (Relationship Management)
- Label: documented. Source: https://www.doss.com/solutions/relationship-management —
  Owns: leads, deals (with "configurable workflows with custom stages"), accounts, customer
  communications/timeline. Quote: "connects leads, deals, and sales orders directly to
  production, inventory, and fulfillment." It does **not** create sales orders or invoices
  directly — Quote: "On stage changes, workflows can create quotes... and sync data to
  downstream systems" — i.e., CRM emits an event; another module (Order Management)
  materializes the quote/order record. This is the clearest evidence for the owner's
  question: Doss keeps CRM as the relationship/pipeline layer and hands off the actual
  commercial document to Order Management.

### Q5. Projects
- Label: documented (search-snippet-sourced, not full-page WebFetch this session). Source:
  https://www.doss.com/solutions/project-management — Project Management owns real records,
  not just a view: budgets, job-costing lines (labor/materials/overhead/vendor cost vs.
  budget), deliverables/milestones, resource allocation. Quote: "track labor, materials,
  overhead, and vendor costs against project budgets in real time, allowing you to know
  exactly where your margins are." This directly answers part of the owner's question:
  in Doss, Projects is a first-class module with owned budget/cost records, not merely a
  dashboard/dimension over Finance — though it is "tightly integrated with budgeting, HR,
  and operations," implying it consumes cost data sourced elsewhere (inferred).

### Q6. Finance & Accounting
- Label: documented. Source: https://www.doss.com/erp — Quote: "GL integration — Run
  operations on DOSS," "Contribution Margin — Accurate COGS & landed cost." Finance module
  is presented as GL/margin-analysis plus invoicing enablement, downstream of Order
  Management for the commercial documents (see Q3). NOT FOUND: an explicit statement that
  Finance is the system of record for the invoice object itself (as opposed to Order
  Management) — the two pages fetched are consistent with either "Finance owns invoices"
  or "Order Management drafts, Finance posts/reconciles"; this session's evidence does not
  disambiguate cleanly. Flag as an open question rather than resolved.

### Q7. Documents
- NOT FOUND. No documents/file/vault module was named on https://www.doss.com/solutions or
  any other Doss page fetched this session. A prior search for "doss.com documents module
  file vault attachments" returned no Doss-specific results at all (only unrelated
  third-party document-vault products). Gap, not a negative confirmation.

### Q8. Contacts
- Label: inferred. The CRM ("Relationship Management") page's language — "all customer
  interactions... alongside orders, production status, and financial data" tied to "the
  account" — implies one shared account/contact record referenced by CRM, Order
  Management, and Finance, consistent with Doss's stated composable-tables architecture
  (single underlying data model, not siloed per-module contacts). This is inferred from
  architecture description, not an explicit "single contact object" statement. NOT FOUND:
  any mention of personal/private relationship management (e.g., personal CRM for internal
  account owners) — no evidence found either way.

---

## Truewind (truewind.ai)

### Q1. Top-level modules / sold separately
- Label: documented. Source: https://www.truewind.ai/product/ai-bookkeeping and
  https://www.truewind.ai/solutions/cas-firms — Truewind is marketed as a single product
  ("AI Bookkeeping" / "digital accountant") with solution pages segmented by customer type
  (SMB, CAS firms, startups) rather than by functional module. Quote: "automates repetitive
  bookkeeping work across ingestion, categorization, reconciliation, and review prep."
  NOT FOUND: any evidence of separate modules (e.g., separate CRM, Sales, or Projects
  products) or of tiered editions/add-ons with distinct pricing — no pricing page was
  reachable/found in this session.

### Q2–Q8. Records, sales, CRM, projects, finance, documents, contacts
- Label: documented (scope only, not itemized). Source:
  https://www.truewind.ai/solutions/cas-firms — Quote: "Transaction coding and
  reconciliation automation," "Evidence-linked outputs for audit readiness," and mentions
  of "Sage Intacct Integration." Truewind operates as an automation layer on top of
  existing accounting systems of record (QuickBooks Online, NetSuite, Sage Intacct, Xero
  per https://www.truewind.ai/product/ai-bookkeeping) rather than owning its own
  chart-of-accounts/GL/invoice objects. It ingests source documents — Quote: "bank
  statements, credit card activity, payout reports, PDFs, and spreadsheets" — for
  categorization and reconciliation, i.e., it is closer to a bookkeeping/close-automation
  layer than a system of record.
- Label: NOT FOUND (with a caveat). No Truewind marketing/help page fetched this session
  states that Truewind owns customer invoices, bills, journal entries, contacts/CRM, or
  projects as first-class objects. One search result (a third-party software-directory
  aggregator, techjockey/GetApp-style listing) suggested Truewind "has CRM capabilities" —
  labelled **third-party** and unreliable (category auto-tagging on a comparison site, not
  a vendor statement); it contradicts the vendor pages' framing and should not be trusted.
  No evidence for Sales, Projects, or Documents modules was found for Truewind at all —
  its scope, per every primary source fetched, is bookkeeping/reconciliation/close, full
  stop.
- NOT FOUND: any Sales, CRM, Projects, or Documents module. NOT FOUND: whether Truewind
  writes invoices/bills back into the connected ERP or only proposes categorizations for
  human/accountant approval — pages describe "review-ready" outputs and "keeping
  accountants in control," consistent with a review/approval workflow, but no page
  explicitly confirms write-back scope.

---

## Concourse (concourse.ai; concourse.co redirects here — same product)

### Q1. Top-level modules / sold separately
- Label: documented. Source: https://www.concourse.ai/overview and
  https://www.concourse.ai/insights/ai-agents-finance-automation-workflows — Concourse is
  organized as a set of AI agents rather than modules: "Forecasting Agent," "Contract
  Renewals Agent," "Close Agent," "Bond Rotation Agent," "T&E Audit Agent." NOT FOUND:
  published pricing tiers or evidence that individual agents are sold as separate SKUs
  (no pricing page was fetched this session — inferred from a $12M Series A general
  availability announcement that the product ships as one agent platform, per
  https://www.prnewswire.com/news-releases/concourse-raises-12m-series-a-and-expands-access-to-its-enterprise-grade-ai-agents-for-finance-302670827.html,
  which is a press-release/marketing source, not vendor pricing docs).

### Q2. Records per module
- Label: documented. Concourse explicitly does not claim to own records. Source:
  https://www.concourse.ai/overview — Quote (paraphrase avoided; exact except where
  fetched summary used quotes): "connects natively to the core systems finance runs on,"
  "no migration, no manual exports, no changes to your stack." It reads from and writes
  outputs to external systems, sitting "across every system at once." NOT FOUND: any
  Concourse-owned object (invoice, journal entry, deal) — architecture is read/analyze
  and push-to-destination (Slack, Teams, Excel, Email), not own-and-store.

### Q3. Sales ownership and channels
- NOT FOUND directly on Concourse's own pages fetched this session (overview and the
  finance-automation-workflows insight page make no mention of quotes, sales orders, or
  customer invoices as objects Concourse touches). However:
- Label: documented. Source: search result summarizing
  https://www.concourse.co/integrations/salesforce (redirects to concourse.ai) — Quote (as
  extracted): "Concourse works directly with your CRM to surface deal movement, customer
  changes, and risk, so teams act faster and close more revenue." This confirms Concourse
  reads CRM deal data for analysis but gives no evidence it creates or owns sales/quote/
  invoice records — consistent with its stated read-only, cross-system analysis role.

### Q4. CRM
- Label: documented. Concourse integrates with CRM (Salesforce, per
  https://www.concourse.co/integrations/salesforce) as a data source for "deal movement,
  customer changes, and risk" but does not itself function as a CRM — it has no
  contacts/leads/deals objects of its own; it is an analysis/agent layer over the
  customer's existing CRM, ERP, and data-warehouse stack.

### Q5. Projects
- NOT FOUND. No project, task, timesheet, or milestone object or module was mentioned on
  any Concourse page fetched this session. Concourse's domain is finance workflows
  (forecasting, close, contract renewals, treasury, T&E audit), not project management.

### Q6. Finance/Accounting
- Label: documented. Source: https://www.concourse.ai/insights/ai-agents-finance-automation-workflows
  — Concourse "automate[s] core finance workflows by connecting to your ERP" (NetSuite,
  QuickBooks, SAP named) and its Close Agent "orchestrates month-end reconciliations and
  surfaces exceptions" (https://www.concourse.ai/overview). It does not own the ledger or
  invoices/bills — those remain in the connected ERP; Concourse reads, analyzes, and
  pushes outputs (reports, forecasts, exception flags) to destinations like Slack/Teams/
  Excel/Email, per the overview page.

### Q7. Documents
- NOT FOUND. No documents/file/vault module or object was mentioned in any Concourse
  source fetched this session. Its "Transparency panel" surfaces "each agent's reasoning,
  including the underlying SQL and Python used to generate outputs" (per
  https://www.concourse.ai/overview) — an audit/explainability feature, not a document
  store.

### Q8. Contacts
- NOT FOUND. Concourse has no CRM/contact object of its own; it reads contact/deal data
  from whichever CRM the customer already runs (e.g., Salesforce). No evidence of a
  personal/private relationship-management feature.

---

## Summary table

| App | Top-level modules | Sales owner and channels | CRM role | Projects role | Documents module | Shared contacts |
|---|---|---|---|---|---|---|
| Doss | Order Mgmt, Procurement, Inventory, Finance & Accounting, Freight & Fulfillment, Warehouse Mgmt, Demand/Production Planning, Project Management, Relationship Management (CRM); platform layers ARP/IDP/DataStudio/Dossbot; sold as one composable platform, usage-based, no separate editions found | Order Management owns the sales order/quote (CPQ); ingests e-commerce (Shopify, Amazon), email, EDI; CRM deals trigger quote creation via workflow rather than CRM owning the quote; Finance invoices off the order (inferred) | Owns leads, deals, accounts, communications timeline; explicitly hands off to Order Management for quotes/orders — does not itself hold sales/finance documents | First-class module with owned budget, job-costing, milestone/resource records — not merely a dashboard, though integrated with Finance/HR data | NOT FOUND — no documents/vault module found | Inferred single account/contact record referenced across CRM, orders, finance (composable-tables architecture); no evidence found of personal/private CRM |
| Truewind | Single bookkeeping/close-automation product; no distinct modules or editions found | Not applicable — Truewind does not own sales documents; it is a categorization/reconciliation layer on top of the customer's existing accounting system (QuickBooks, NetSuite, Sage Intacct, Xero) | No CRM module documented (a third-party directory's "CRM capabilities" tag is unreliable and contradicted by vendor pages) | NOT FOUND — no projects module | NOT FOUND | NOT FOUND — no contact object described; operates on the connected accounting system's data |
| Concourse | Agent platform (Forecasting, Contract Renewals, Close, Bond Rotation, T&E Audit agents) over existing ERP/CRM/data-warehouse stack; no separate editions/pricing found | Not applicable — Concourse owns no sales/quote/invoice records; reads CRM deal data (e.g., via Salesforce integration) for analysis only, pushes insights to Slack/Teams/Excel/Email | Reads customer's existing CRM (e.g., Salesforce) for deal/customer signals; has no CRM objects of its own | NOT FOUND — no projects module | NOT FOUND — only an agent "transparency panel" showing reasoning/SQL/Python, not a document store | NOT FOUND — no contact object of its own; consumes whatever CRM the customer runs |

## Relevance to the owner's question

The single most load-bearing finding is Doss's Relationship Management page
(https://www.doss.com/solutions/relationship-management): CRM owns the pipeline (leads,
deals, accounts) but explicitly does **not** create the quote or sales order — "On stage
changes, workflows can create quotes... and sync data to downstream systems" — while
Order Management is the module that materializes and owns the sales order/quote object
regardless of which channel it came from (CRM-originated, e-commerce, email/EDI one-off).
This is a real-product precedent for a Sales/Order layer that is separate from both CRM and
Finance: CRM stays the relationship/pipeline system, Finance stays the ledger/invoice
system, and a distinct Sales/Order-Management layer is the single place where quotes and
orders land no matter which channel originated the deal — directly answering "if Sales
lives in Finance, what is CRM for" (CRM is pipeline/relationship, not the transaction
system) and suggesting Projects (per Doss) can be a genuine owner of budget/cost records
rather than "just a dashboard," while still consuming Finance data for margin reporting.
