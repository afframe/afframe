# Module boundaries and record ownership: Xero, Intuit (QuickBooks Online + add-ons), Midday

Owner's question this feeds: should Sales sit in CRM, Projects or Finance; what does CRM
own if Finance owns sales; is Projects just a dashboard. This file reports what three real
products actually do, with primary sources quoted where fetchable.

Method note: `developer.xero.com` and `developer.intuit.com` are client-side single-page
apps — `curl`/WebFetch only return an empty JS shell (`This app works with JavaScript
enabled.`), no server-rendered doc text. Where the live doc page could not be fetched
verbatim, this file uses each vendor's **public OpenAPI/data-model source** instead (Xero
publishes its API spec on GitHub; this is a primary, authoritative source, just not the
HTML doc page) and labels third-party summaries accordingly. Midday is open source, so its
Postgres schema (`packages/db/src/schema.ts`) is used directly — the strongest possible
evidence of what each module owns.

---

## Xero

### Q1. Top-level modules / what's sold separately
- Label: marketing. URL: https://www.xero.com/us/pricing/ (fetched 2026-09-24). Three
  core editions — **Early**, **Growing**, **Established** — differ by invoice/bill volume,
  bank reconciliation automation, multi-currency, and: "All Growing features, plus: ...
  Track time and costs for projects" (Established only).
- Label: marketing (same page). Separate priced add-ons outside the core editions:
  "Xero Payroll, powered by Gusto" ($36/mo + per-employee), "Inventory Plus," and
  "Xero Projects, Xero Expenses" billed usage-based. So Projects is commercially an
  add-on module, not bundled into the base ledger product, even though its data (per Q5)
  is thin.
- Label: source. Xero also ships wholly separate API products with their own OpenAPI
  specs on GitHub (github.com/XeroAPI/Xero-OpenAPI): `xero_accounting.yaml` (core ledger:
  invoices, bills, contacts, bank transactions...), `xero-projects.yaml` (Projects),
  `xero_files.yaml` (Files/documents), `xero_assets.yaml` (Fixed Assets), plus separate
  Payroll specs per country (`xero-payroll-au.yaml`, `-nz`, `-uk`). Each is a distinct
  product surface with its own base URL, confirming Accounting, Projects, Files, Fixed
  Assets and Payroll are architecturally separate modules, not one monolith.

### Q2. Records each module owns
- Label: source. URL: https://raw.githubusercontent.com/XeroAPI/Xero-OpenAPI/master/xero_accounting.yaml
  (fetched 2026-09-24). The **Accounting API** (one module) exposes these top-level paths:
  `/Accounts /BankTransactions /BankTransfers /BatchPayments /BrandingThemes /Budgets
  /ContactGroups /Contacts /CreditNotes /Currencies /ExpenseClaims /InvoiceReminders
  /Invoices /Items /Journals /LinkedTransactions /ManualJournals /Organisation
  /Overpayments /PaymentServices /Payments /Prepayments /PurchaseOrders /Quotes /Receipts
  /RepeatingInvoices /Reports /Setup /TaxRates /TrackingCategories /Users`. One module
  owns quotes, purchase orders, sales and purchase invoices, credit notes, bank
  transactions, manual journal entries and contacts — Xero does not split "sales ledger"
  from "purchase ledger" from "general ledger" into separate modules; the `Type` field
  (`ACCREC` = sales invoice, `ACCPAY` = purchase bill) distinguishes direction on the same
  `Invoice` object, per the spec's inline examples (`Type: ACCREC`, `Type: ACCPAY`).
- Label: source. URL: .../xero-projects.yaml. **Projects API** paths: `/Projects
  /Projects/{id} /ProjectsUsers /Projects/{id}/Tasks /Projects/{id}/Tasks/{id}
  /Projects/{id}/Time /Projects/{id}/Time/{id}`. Projects owns Project, Task and Time
  entries. It does **not** expose an Invoice-creation path — its schema instead carries
  read-only rollup fields (`minutesToBeInvoiced`, `taskAmountToBeInvoiced`,
  `taskAmountInvoiced`, `expenseAmountToBeInvoiced`, `projectAmountInvoiced`,
  `totalInvoiced`, `totalToBeInvoiced`) that track billing status of work already
  invoiced elsewhere. Label: inferred — this means Projects tracks money-to-be-billed as
  a derived state, but the actual Invoice record is created and owned by the Accounting
  API (Xero's UI "create invoice from project" flow posts to `/Invoices`, not to a
  Projects endpoint) — NOT FOUND: an explicit statement of this handoff in the spec
  itself, this is inferred from the absence of any invoice-write endpoint in
  `xero-projects.yaml` plus presence of only aggregate "to be invoiced" counters.
- Label: source. URL: .../xero_files.yaml. **Files API** paths: `/Files /Files/{id}
  /Files/{id}/Content /Files/{id}/Associations /Files/{id}/Associations/{ObjectId}
  /Associations/{ObjectId} /Associations/Count /Folders /Folders/{id} /Inbox`. Files owns
  file blobs and folders, plus an `Associations` sub-resource that links a file to
  another Xero object by `ObjectId` (e.g., an Invoice or Contact) — files are not stored
  inside the Invoice/Contact record itself, they're a separate module joined by ID.
- Label: source. URL: .../xero_assets.yaml — description: "The Assets API exposes fixed
  asset related functions of the Xero Accounting application and can be used for a
  variety of purposes such as creating assets, retrieving asset valuations etc." Assets
  own `AssetType`, `PurchaseDate`, `PurchasePrice`, and disposal state: "Requests can be
  ordered by AssetType, AssetName, AssetNumber, PurchaseDate and PurchasePrice. If the
  asset status is DISPOSED it also allows DisposalDate and DisposalPrice," with an asset
  status enum including `Disposed`.

### Q3. Sales: who owns quotes/orders/invoices, and channel landing
- Label: source (per Q2 path list). **Quotes, PurchaseOrders and Invoices are all owned
  by the single Accounting API** — there is no separate "Sales module" or "Order module"
  in Xero; quote-to-invoice conversion and PO-to-bill matching happen inside one API/data
  model. URL: xero_accounting.yaml, `operationId: getQuotes`, `summary: Retrieves sales
  quotes`.
- Label: inferred. Xero has no native CRM, no native e-commerce/POS, and no native
  subscription-billing engine (these are third-party add-ons via the Xero App Store —
  NOT FOUND: primary confirmation fetched in this pass, inferred from the absence of any
  CRM/deals/POS/subscription path in the Accounting, Projects, Files or Assets specs).
  Consequently every sales channel — a deal a sales team tracked in an external CRM, an
  e-commerce/POS sale synced in via an app-store connector, a one-off invoice to someone
  never entered as a CRM contact, or billing that starts from a Project — all converge on
  the **same** `Invoice` object (`Type: ACCREC`) against the **same** `Contacts` table.
  Xero's own object model treats "where the sale came from" as outside its concern: it
  only cares that an Invoice references a Contact once it lands.
- Label: source. **Sale of a company asset** is explicitly a different object family: the
  Assets API's `DisposalPrice`/`DisposalDate` fields (Q2) record proceeds from disposing
  a fixed asset — this is not a customer Invoice at all, it's asset-register state,
  though disposal typically also touches the ledger via a manual journal (NOT FOUND: a
  spec-level statement of the asset-disposal-to-journal-entry link).

### Q4. CRM: what it owns
- Label: inferred / NOT FOUND. Xero ships no CRM module or CRM API in its own product
  line (no `/Leads`, `/Deals`, `/Opportunities`, `/Activities` path exists in any of the
  fetched specs). Xero's own "CRM" story is entirely third-party, via App Store
  integrations (e.g. HubSpot, Pipedrive, Method) that write Contacts/Invoices/Quotes back
  into the Accounting API rather than Xero owning CRM data itself. NOT FOUND: a primary
  Xero page enumerating official CRM-category app-store partners (not fetched this pass).

### Q5. Projects: records or dashboard?
- Label: source (Q2). Projects **does** own real records — Project, Task and Time-entry
  rows exist as first-class API resources with their own IDs and CRUD endpoints (not just
  a filter/tag on Accounting records). But it does not own invoices, budgets-as-ledger,
  or contracts; its "amountToBeInvoiced" fields are a computed view over accounting data
  it doesn't control. So Xero Projects is a genuine sub-module for time/task capture, that
  hands off billing to the Accounting module — a middle case, not "just a dashboard" but
  also not the sales-document owner.

### Q6. Finance/Accounting: what it owns
- Label: source (Q2). The Accounting module owns the full commercial and ledger surface
  in one API: Invoices (both directions), Quotes, PurchaseOrders, CreditNotes,
  BankTransactions, ManualJournals, Journals (system-generated), Payments, Contacts,
  Budgets, Items, TrackingCategories. Xero draws its module line around "the ledger and
  everything that posts to it," not around "sales vs. purchasing vs. GL."

### Q7. Documents
- Label: source (Q2, Files API). Yes — a dedicated Files module owning file bytes and
  folders, joined to any other Xero object (invoice, contact, etc.) via an `Associations`
  resource keyed on `ObjectId`. Documents are not embedded fields on Invoice/Contact;
  they're an independently owned, cross-linkable resource.

### Q8. Contacts
- Label: source. `Contacts` lives inside the Accounting API and is referenced by ID from
  Projects (`xero-projects.yaml` uses `contactId` as the project's customer link, e.g.
  `"contactId": "00000000-0000-0000-0000-000000000000", "name": "New Kitchen"`) and from
  Assets/Files via associations. This is one shared contact master reused across modules,
  not a per-module contact table. NOT FOUND: any "private/personal relationship" concept
  distinct from the shared business Contact.

---

## Intuit — QuickBooks Online and its add-ons

Scope note: "Intuit" itself is not a single product; the relevant products are QuickBooks
Online (QBO, core accounting), QuickBooks Payroll / Workforce, QuickBooks Time (formerly
TSheets), and the newly-launched QuickBooks Customer Hub (CRM-shaped feature). All
identified with confidence via Intuit's own marketing/help-centre domains.

### Q1. Top-level modules / what's sold separately
- Label: marketing. URL: https://quickbooks.intuit.com/pricing/ (fetched 2026-09-24).
  Five QBO tiers: Free, Simple Start, Essentials, Plus, Advanced — differentiated mainly
  by user count and feature gating, e.g. "Projects functionality appears only in higher
  tiers... Advanced plan mentions 'advanced project financials'... Plus enables users to
  'track project profitability.'" Confirmed separately by official help centre: Label:
  documented. URL: https://quickbooks.intuit.com/learn-support/en-us/reports-and-accounting/projects-profitability-reporting
  family and https://quickbooks.intuit.com/accounting/job-costing/ — "QuickBooks Online
  Plus and QuickBooks Online Advanced include job costing."
- Label: marketing. **QuickBooks Payroll** is sold as an add-on at QBO checkout ("Optional
  add-on during checkout") and is now branded/bundled as "QuickBooks Workforce," combining
  "payroll, HR, team management and benefits administration—all in one place" — a
  separately licensed product line, not part of base QBO. URL:
  https://quickbooks.intuit.com/payroll/.
- Label: marketing. **QuickBooks Time** (ex-TSheets) is "a separate login portal" /
  standalone time-tracking product, included free only with "QuickBooks Online Payroll
  Premium and Elite subscription services," otherwise sold on its own. URL:
  https://quickbooks.intuit.com/time-tracking/.
- Label: marketing. **Customer Hub** — Intuit's new CRM feature — is described as
  "built-in" rather than a separate SKU: "QuickBooks now includes built-in CRM
  capabilities through Customer Hub," "part of QuickBooks." URL:
  https://quickbooks.intuit.com/ca/resources/crm/does-quickbooks-have-crm/.

### Q2. Records each module owns
- Label: third-party (data-model aggregator, not Intuit's own doc page, since
  developer.intuit.com is a JS SPA that could not be fetched verbatim in this pass). URL:
  https://www.synchub.io/connectors/quickbooks/datamodel. QBO core entities: Account,
  Bill, BillPayment, Class, Customer, CreditMemo, Department, Deposit, Employee,
  Estimate, Expense, Invoice, Item, JournalEntry, Payment, PurchaseOrder, SalesReceipt,
  TaxAgency, TaxCode, TaxRate, Term, TimeActivity, Vendor, VendorCredit — plus per-entity
  line-item and report sub-objects. Cross-checked by a second third-party summary (Label:
  third-party, zuplo.com/learning-center/quickbooks-api and getknit.dev), which agrees on
  Invoice/Estimate/SalesReceipt/Bill/JournalEntry/Customer/Vendor as core. This is a
  single QBO "Accounting" module owning both sales-side (Invoice, Estimate, SalesReceipt,
  CreditMemo) and purchase-side (Bill, PurchaseOrder, VendorCredit) documents plus the
  ledger (JournalEntry, Account) — same non-split pattern as Xero.
- Label: documented. QuickBooks Time owns: "Timesheets... Schedules/Shifts... Projects...
  Jobs" per https://quickbooks.intuit.com/time-tracking/ ("Manage multiple timesheets and
  approve time when you're ready"; "Create schedules by jobs or shifts"). It is a
  separate data silo from QBO's own `Project` grouping (see Q5) unless integrated.
- Label: documented. QuickBooks Payroll/Workforce owns Employee records, pay runs/payroll
  schedules, HR workflow records, and tax forms: "Create and e-file 1099-MISC and
  1099-NEC forms" — https://quickbooks.intuit.com/payroll/.

### Q3. Sales: who owns quotes/orders/invoices, and channel landing
- Label: third-party (see Q2 sourcing caveat). QBO's own Accounting module owns Estimate
  (quote), Invoice, SalesReceipt (point-of-sale-style immediate sale with payment) and
  CreditMemo — again one module, not a separate "Sales" product.
- Label: source. QuickBooks Online Projects is **not a record owner of sales documents**;
  it is a grouping tag applied to existing transactions. URL:
  https://quickbooks.intuit.com/learn-support/en-us/help-article/manage-projects/set-create-projects-quickbooks-online/L9GAdLMyT_US_en_US
  (fetched 2026-09-24). Quote (per fetch): a project "will remain empty until you add or
  create transactions to assign it," and when recording an invoice or expense you "select
  the Project from the Customer field" — i.e., Project is a value on the Customer field of
  an Invoice/Expense/Bill, not a container that creates its own billing record. This is
  the clearest documented evidence in this file that a "Projects" surface can be **purely
  a dimension/view**, contrasting with Xero Projects which does own real Task/Time rows.
- Label: marketing/documented. **Customer Hub (CRM-shaped feature)** does originate
  leads/pipeline activity but explicitly hands off to QBO's transactional objects rather
  than owning its own quote/invoice type: "Everything flows directly into your
  financials, estimates, invoices, and job history, so your CRM and accounting workflows
  finally live in the same place," and describes a "Unified customer record (financial +
  CRM Data)" spanning "Transactions, Payments, Invoices... Lead and pipeline activity,
  Estimates and job info." URL:
  https://quickbooks.intuit.com/ca/resources/crm/does-quickbooks-have-crm/ (fetched
  2026-09-24). This directly answers the owner's "what's left for CRM if Finance owns
  sales documents" question for Intuit's own design: CRM owns leads/pipeline/relationship
  activity as its own record type, but delegates the actual Estimate/Invoice creation to
  the shared accounting objects — CRM and Finance share the customer record, not the
  transaction record.
- Label: NOT FOUND. No evidence located in this pass of a distinct e-commerce/subscription
  sales-channel object inside core QBO (Intuit's subscription/e-commerce story runs through
  third-party integrations, e.g. Shopify-to-QBO connectors, which is out of scope for
  primary QBO ownership).
- Label: NOT FOUND. No evidence located of a "sale of company asset" object distinct from
  a normal Invoice/SalesReceipt in QBO (unlike Xero's dedicated Assets API with
  DisposalPrice/DisposalDate) — QBO fixed-asset tracking exists but disposal-specific API
  objects were not found in this pass.

### Q4. CRM: what it owns
- Label: marketing/documented (Q3 quotes). Customer Hub owns: "Capturing leads,
  Following up with prospects, Managing customer information... Tracking work requests,
  Scheduling appointments," and "Feedback, Referrals, Testimonials" per
  https://quickbooks.intuit.com/ca/resources/crm/does-quickbooks-have-crm/. It does not
  independently generate formal accounting documents; those documents (Estimate,
  Invoice, job history) are the shared QBO objects. Third-party commentary (Label:
  third-party, multiple CRM-integration vendor blogs found via search, e.g. Nutshell,
  Teamgate, Insightly) is consistent: "QuickBooks... does not fully manage sales
  pipelines, lead tracking... like a dedicated CRM," which is why a large market of
  third-party CRM-to-QuickBooks integrations exists — corroborating that even with
  Customer Hub, most real QBO customers still run a separate CRM system of record for
  deal/pipeline management.

### Q5. Projects: records or dashboard?
- Label: documented (Q3). For core QuickBooks Online, Projects is **a dashboard/dimension
  over other modules' records** — it groups existing Invoice/Expense/Bill/Time-Activity
  rows via the Customer/Project field rather than owning its own Task/Milestone/Budget
  entities. This is the strongest "Projects = pure view" evidence found across all three
  apps and directly informs the owner's question. Separately, **QuickBooks Time** (the
  add-on) does own its own Project/Job/Schedule/Timesheet records (Q2), so "Projects" only
  becomes record-owning once you buy the separate Time product — reinforcing that the
  boundary is commercial/product, not conceptual.

### Q6. Finance/Accounting: what it owns
- Label: third-party (Q2 sourcing caveat). QBO's core module owns the full commercial
  document set (Estimate, Invoice, SalesReceipt, Bill, PurchaseOrder, CreditMemo,
  VendorCredit) plus the ledger (JournalEntry, Account, chart of accounts). Same pattern
  as Xero: Finance owns both sales and purchase documents and the GL, not just journal
  entries.

### Q7. Documents
- Label: NOT FOUND. No dedicated "Files/Vault API" module for QBO core was located in
  this pass (QBO supports attachments on transactions via the Attachable entity per
  third-party summaries, but no primary doc page was fetched to confirm scope/behaviour
  in this pass — flagged as a gap rather than guessed).

### Q8. Contacts
- Label: third-party (Q2). QBO splits **Customer** and **Vendor** into two separate
  entities (not one universal "Contact" like Xero) — i.e., the same real-world party
  acting as both a customer and a supplier would need two records in QBO's own data
  model. Customer Hub layers CRM data (leads, pipeline) onto the existing Customer
  entity rather than introducing a third contact table: "Unified customer record
  (financial + CRM Data)." NOT FOUND: confirmation of any personal/private relationship
  management concept.

---

## Midday (midday.ai, open source: github.com/midday-ai/midday)

Note on current status: Label: source. URL: https://midday.ai/pricing (fetched
2026-09-24) — the page currently states Midday is being acquired by Ramp and winding down
over three months, not a normal pricing page. Product/architecture evidence below is
still valid as a record of how the (still-public) source code models the business.

### Q1. Top-level modules / what's sold separately
- Label: source. URL: https://github.com/midday-ai/midday (repo `packages/` listing,
  fetched via GitHub API 2026-09-24): `accounting, app-store, banking, bot, cache,
  categories, cli, connectors, customers, db, desktop-client, documents, email,
  encryption, events, health, import, inbox, insights, invoice, job-client, jobs,
  location, logger, mcp-apps, notifications, plans, supabase, trpc, ...`. Midday is one
  product (one pricing plan historically, no per-module SKUs found), but its **codebase**
  is already decomposed into modules matching real business-app boundaries: `customers`,
  `invoice`, `banking`, `documents`, `inbox` (received-document matching), `accounting`
  (sync to external ledgers), `insights`.
- Label: source. README (github.com/midday-ai/midday/blob/main/README.md, fetched
  2026-09-24): "Midday is an all-in-one tool designed to help freelancers, contractors,
  consultants, and solo entrepreneurs manage their business operations... Features: Time
  Tracking... Invoicing... Magic Inbox... Vault... Seamless Export... Assistant."

### Q2. Records each module owns
- Label: source. URL: https://raw.githubusercontent.com/midday-ai/midday/main/packages/db/src/schema.ts
  (fetched 2026-09-24, Drizzle ORM Postgres schema — ground truth for what Midday
  persists). Key tables: `customers`, `invoices`, `invoiceRecurring`, `invoiceTemplates`,
  `invoiceProducts`, `trackerProjects`, `trackerEntries`, `trackerReports`,
  `trackerProjectTags`, `transactions`, `transactionCategories`, `transactionTags`,
  `transactionAttachments`, `documents`, `documentTags`, `documentTagAssignments`,
  `bankAccounts`, `bankConnections`, `accountingSyncRecords`, `reports`, `insights`,
  `inbox`. There is **no** `quotes`, `salesOrders`, `bills`, or `journalEntries` table —
  Midday does not model a general ledger or a quote-to-order-to-invoice pipeline at all.

### Q3. Sales: who owns quotes/orders/invoices, and channel landing
- Label: source (schema.ts, `invoices` table). Midday owns exactly one sales-document
  type, `invoices`, with columns `customerId` (FK to `customers`), `lineItems` (jsonb),
  `amount`, `status` (`draft`/etc via `invoiceStatusEnum`), `invoiceRecurringId` (for
  subscriptions), `templateId`. There is no Estimate/Quote object — an invoice is created
  directly. Recurring/subscription billing is modeled as a self-referencing
  `invoiceRecurring` link on the same `invoices` table, not a separate subscription
  product.
- Label: source. Midday has **no CRM deal/pipeline table and no e-commerce/POS
  integration table** in the schema — all invoices reference the same `customers` row
  regardless of channel. A one-off invoice "to someone not in the CRM" is handled by the
  same object: `customerId` is nullable (FK uses `.onDelete("set null")`), and there are
  also freeform `customerName`/`customerDetails` (jsonb) columns on `invoices` for cases
  with no linked customer row at all.
- Label: source. **Sale of a company asset**: NOT FOUND — no asset-register or
  fixed-asset table exists in the schema; Midday has no concept of this at all (it is not
  a general ledger).
- Label: source. `trackerProjects` carries an optional `customerId` FK and `billable`
  boolean, and `invoices` are not directly foreign-keyed to `trackerProjects` in the
  visible schema — Label: inferred, meaning project time/billable status likely feeds
  invoice line items at the application layer (not enforced by a DB relation), NOT FOUND:
  explicit tracker→invoice foreign key or join table confirming automatic conversion.

### Q4. CRM: what it owns
- Label: source (schema.ts, `customers` table). Midday's `customers` table has been
  extended well beyond a plain contact record: `status` ("active, inactive, prospect,
  churned" per inline code comment), `source` ("manual, import, quickbooks, xero, etc."),
  plus a large block of AI-enrichment fields (`industry`, `companyType`, `employeeCount`,
  `foundedYear`, `estimatedRevenue`, `fundingStage`, `linkedinUrl`, etc.) and portal fields
  (`portalEnabled`, `portalId`). This is CRM-shaped enrichment bolted onto the one shared
  Customer record rather than a separate Lead/Deal/Company object set — Midday does not
  create separate sales/finance documents from a CRM layer; there is no CRM layer, only a
  richer Customer table that Invoicing and Tracker both reference.
- Label: NOT FOUND. No `deals`, `leads`, `opportunities`, or `activities` (CRM-activity)
  tables in the schema — confirming Midday genuinely has no CRM/pipeline module, only an
  enriched contact master.

### Q5. Projects: records or dashboard?
- Label: source (schema.ts, `trackerProjects`/`trackerEntries`/`trackerReports` tables).
  Midday's "Tracker" (its Projects/time-tracking feature) **does own real records**: a
  project row (`trackerProjects`: name, rate, currency, status, `billable`, `estimate`,
  `customerId`), time entries (`trackerEntries`), and generated reports
  (`trackerReports`), plus tag join tables (`trackerProjectTags`). It is not merely a
  filter over Invoices/Transactions — it's an independently-owned record set that
  optionally links to a Customer, similar in shape to Xero Projects (Q5 above), not to
  QBO's dashboard-only Projects (Q5 above).

### Q6. Finance/Accounting: what it owns
- Label: source (schema.ts, `accountingSyncRecords` table + `accountingProviderEnum`).
  Midday does **not** own a general ledger or journal entries at all. Its own
  `accounting_provider` enum lists external systems only: `"xero", "quickbooks",
  "fortnox"`, and `accountingSyncRecords` tracks one-way (or bidirectional per-record)
  sync state per bank `transaction` to an external accounting system, including
  provider-specific entity types in a free-text column: comment in code: "Provider-specific
  entity type (e.g., 'Purchase', 'SalesReceipt', 'Voucher', 'BankTransaction')". This is
  direct, primary evidence that Midday's own "Finance" boundary is: own bank
  transactions/categorisation/invoicing, but delegate the actual ledger (journal entries,
  chart of accounts) to an external Xero/QuickBooks/Fortnox instance via sync.

### Q7. Documents
- Label: source (schema.ts, `documents`/`documentTags`/`documentTagAssignments`
  tables). Yes — a dedicated Documents/"Vault" module: `documents` table has `teamId`,
  `objectId` (a generic link column), `tag`, full-text-search columns, AI-generated
  `summary`/`content`. Separately, `transactionAttachments` and `invoices.filePath`
  (a text array) show that some records embed direct file-path references while the
  `documents` table also exists as an independently searchable/taggable store — i.e.
  Midday has both inline file references *and* a first-class Documents module, not one
  clean either/or split. README: "**Vault**: Secure storage for important files like
  contracts and agreements, keeping everything in one place for easy access."

### Q8. Contacts
- Label: source (schema.ts). One shared `customers` table, referenced by `invoices`
  (`customerId`) and `trackerProjects` (`customerId`) — a single contact/company master
  reused across the Invoicing and Tracker modules, matching the Xero pattern (Q8 above)
  rather than the QBO Customer/Vendor split (Q8 above). NOT FOUND: any personal/private
  relationship-management concept (no separate "contact interactions" or personal-CRM
  table found in the schema).

---

## Summary table

| App | Top-level modules (commercial split) | Sales document owner & channels | CRM role | Projects role | Documents module | Shared contacts |
|---|---|---|---|---|---|---|
| **Xero** | One Accounting API (ledger + sales + purchasing + contacts) is the base product; Projects, Payroll, Files, Fixed Assets are separate priced add-ons/APIs | Accounting API owns Quotes/PurchaseOrders/Invoices (`ACCREC`/`ACCPAY` on one Invoice type) for every channel; no native CRM/e-comm/POS/subscription engine, so channel is out-of-scope for Xero itself; company-asset sales go through a separate Fixed Assets `DisposalPrice`/`DisposalDate`, not an Invoice | No native CRM; third-party apps write Contacts/Invoices back into Accounting API | Owns real Project/Task/Time records but not invoices; tracks "amount to be invoiced" as a rollup, hands billing to Accounting API | Yes — dedicated Files API, linked to any object via `Associations` on `ObjectId` | One shared `Contacts` table in Accounting API, referenced by ID from Projects/Files/Assets |
| **Intuit QBO family** | QBO core (one Accounting entity set) is base; Payroll/Workforce and QuickBooks Time are separately sold add-ons; Customer Hub (CRM) is bundled into QBO itself | QBO core owns Estimate/Invoice/SalesReceipt/CreditMemo/Bill/PurchaseOrder in one entity set; core QBO Projects is a tag on the Customer field of existing transactions, not a document owner; Customer Hub originates leads/pipeline but hands off to the same Estimate/Invoice objects; no evidence found of a distinct company-asset-sale object | Customer Hub owns leads, pipeline, appointments, referrals as its own state, layered on the shared Customer record; does not mint its own invoice/estimate type; many customers still run a third-party CRM per third-party sources | Core QBO Projects = pure dashboard/dimension over Invoice/Expense/Bill/TimeActivity (no owned Task/Milestone/Budget entities); the separate QuickBooks Time add-on does own Project/Job/Schedule/Timesheet records | NOT FOUND (no primary doc fetched confirming a Files/Vault API scope) | Split: separate Customer and Vendor entities (not one universal contact); Customer Hub adds CRM fields onto Customer, not a third table |
| **Midday** | One product (no per-module pricing found; currently winding down per its own pricing page); codebase is modularized (`invoice`, `banking`, `customers`, `documents`, `accounting`-sync, `inbox`) | `invoices` table (with nullable `customerId`, freeform `customerName`/`customerDetails` for non-CRM parties, self-linked `invoiceRecurring` for subscriptions) is the only sales-document type; no Quote/Order object; no company-asset-sale concept exists at all | No CRM tables (no leads/deals/activities); CRM-shaped fields (status, source, enrichment data) are bolted onto the shared `customers` row itself | `trackerProjects`/`trackerEntries`/`trackerReports` are real owned records, optionally linked to a Customer; not directly FK'd to Invoices (link is inferred at app layer) | Yes — dedicated `documents`/`documentTags` tables ("Vault"), plus some records also carry direct file-path/attachment references | One shared `customers` table referenced by both `invoices` and `trackerProjects` |
