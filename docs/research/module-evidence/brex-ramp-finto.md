# Module boundaries in Brex, Ramp and "Finto" — evidence for Sales/CRM/Projects/Finance ownership

Scope: Brex and Ramp are both corporate-card / spend-management platforms (buy-side).
Neither sells a CRM, Sales, or Projects module, so their API surfaces are strong
negative evidence about where sales documents do **not** live. "Finto" is ambiguous
(see below) and none of the candidates found is a Brex/Ramp-class spend platform, so
Finto's evidence for the owner's question is thin and flagged as such.

Research budget: ~20 minutes, primary sources only (vendor API docs). Time did not
allow crawling every help-centre page; gaps are marked NOT FOUND rather than guessed.

---

## Finto — name ambiguity (documented)

WebSearch turned up at least three unrelated products/sites using the name "Finto",
none clearly matching "the finance or spend product by that name" as a Brex/Ramp peer:

1. **finto.io** — Banking-as-a-Service / card-issuing infrastructure for other
   companies to embed, not a spend-management app itself.
   - Label: source. URL: https://finto.io/
   - Quote: "Deploy innovative digital banking products or embed financial services
     into your customer experience at extraordinary speed." (self-description,
     "Comprehensive digital banking infrastructure")
2. **gofinto.com** — AI invoice-to-accounting automation for enterprises (AP
   capture → coding → ERP posting). This is the closest of the three to a
   finance-department product, but it is narrower than Brex/Ramp: no CRM, no
   sales side, no expense/travel/procurement.
   - Label: source. URL: https://www.gofinto.com/
   - Quote: "an AI finance platform - built for enterprises" that ships "verified
     journal entries — no clicking required," with modules described as Inbox
     (capture), Validation, Account Coding, and Analytics; integrates to SAP,
     Microsoft Dynamics, DATEV.
3. **finto0.webflow.io** — a Webflow-hosted marketing page for an "all-in-one
   finance app" (payments, business accounts, invoicing, BaaS) whose copy
   (round adoption stats, generic feature list, `.webflow.io` demo subdomain,
   near-identical sibling site "Finto | Financial Framer Template") looks like
   a website template/mockup rather than a shipping product.
   - Label: inferred (not verified as a real, distinct product).
   - Quote: "Keep your business account and all your finance needs safely
     organized under one roof."

**Because the name is ambiguous and none of the three is a confirmed Brex/Ramp-class
spend platform, this report does not force answers to Q1–Q8 for Finto.** Where
gofinto.com's own material speaks to a question, it is cited below as the best
available candidate; everything else is NOT FOUND for Finto.

- Finto (gofinto.com) Q1: Single product, not sold as separate modules as far as the
  marketing site discloses. Label: marketing. NOT FOUND: pricing/edition page.
- Finto (gofinto.com) Q2: Owns incoming AP documents and the journal entries derived
  from them ("verified journal entries"). Label: marketing.
- Finto (gofinto.com) Q3–Q8 (Sales/CRM/Projects/Contacts/Documents): NOT FOUND —
  the public site describes only inbound invoice capture and GL coding; no sales,
  CRM, project, or contact-master functionality is disclosed.

---

## Brex

### Q1. Top-level modules / what's sold separately
Label: source (developer.brex.com, brex.com).
URL: https://developer.brex.com/
Quote (API catalogue, i.e. the shipped product surface): "Accounting API",
"Budgets API", "Expenses API", "Fields API", "Onboarding API", "Payments API",
"Team API", "Transactions API", "Travel API", "Webhooks API" — each with a
one-line purpose, e.g. Payments API: "Manage vendors and send ACH, domestic
wires, and checks"; Accounting API: "View and manage accounting data";
Expenses API: "View and manage card expenses data, receipt match and receipt
uploads".

Label: marketing. URL: https://www.brex.com/pricing (via search summary).
Pricing tiers are Essentials (free), Premium (~$12/user/mo, adds live budgets,
custom expense policies, anomaly alerts, HRIS/SSO), and Enterprise (local card
issuance, unlimited entities). Modules gated by tier are expense management,
bill pay, travel, reimbursements — all buy-side. **No CRM, Sales, or Projects
product exists in Brex's lineup.**

### Q2. Records owned per module
Label: documented (Brex OpenAPI markdown, fetched directly).
- **Payments API → Vendors**: URL https://developer.brex.com/openapi/payments_api.md
  Quote: "## Vendors — Endpoints to manage vendors" with `GET/POST/PUT/DELETE
  /v1/vendors` ("This endpoint lists all existing vendors for an account.");
  also owns **Transfers** ("Create incoming transfer", "Create transfer") and
  **Linked Accounts**.
- **Accounting API → Accounting Records**: URL
  https://developer.brex.com/openapi/accounting_api.md
  Quote: headers are "Accounting Integrations" (Create/Disconnect/Reactivate an
  integration) and "Accounting Records" (Get by ID, Query, Report export
  results). Brex's own catalogue text: "View and manage accounting data."
  Accounting records are typed by *source* (card expense, reimbursement, or
  bill), not by a Brex-owned ledger — Brex pushes them into a connected
  external ERP/accounting system rather than owning a general ledger itself.
- **Expenses API**: owns card expense records and receipts (documented,
  https://developer.brex.com/).
- **Travel API**: owns trip records ("View trips made in Brex Travel").
- **Team API**: owns users, locations, departments, cards.
- **Fields API**: owns custom fields and field values used to tag spend
  (dimension/tag records, not transactional documents).

No object named "bill" for AP was found broken out in Brex's public catalogue
summary the way Ramp exposes it explicitly — Brex's bill-pay is described in
marketing copy ("Bill pay software automates invoice capture, line
itemization, bill drafting, PO matching, multi-level approvals" —
https://www.brex.com/product/bill-pay, label: marketing) but the underlying API
object was NOT FOUND at the payments/accounting-API level within the time
budget; it may be folded into "Accounting Records" with `source: BILL`.

### Q3. Sales: quotes, orders, customer invoices
NOT FOUND. Brex's API surface (Accounting, Budgets, Expenses, Fields,
Onboarding, Payments, Team, Transactions, Travel, Webhooks) contains no
quote, sales-order, or customer-invoice object. Brex is exclusively a
buy-side/spend platform: it pays vendors, it does not bill customers. Label:
documented (absence confirmed against the full API list above).

### Q4. CRM
NOT FOUND. Brex has no CRM module, no contact/company/deal/lead objects
beyond internal "Team" (employee users) and payment "Vendors". The
"Onboarding API" description — "Refer your customers and personal contacts to
Brex and prefill signup information" (label: documented,
https://developer.brex.com/) — is about referring prospects *to Brex itself*
as a bank customer, not a CRM for Brex's own customers to manage their sales
pipeline.

### Q5. Projects
No standalone Projects module. "PROJECT" appears only as one of many
accounting-field *categories* used to tag spend (seen indirectly via Ramp's
identical dimension model, see below; Brex's own Fields API — "View and
manage fields and their options" — serves the equivalent purpose but the
category enum was NOT FOUND in the time budget for Brex specifically). Label:
inferred for Brex by analogy to Ramp's documented enum; treat as unverified
for Brex until Brex's Fields API enum is pulled directly.

### Q6. Finance/Accounting
Brex's "Accounting API" does not host a general ledger of record; it
synchronizes accounting records (card/reimbursement/bill sourced) to and from
a connected external accounting system. Label: documented. Quote: "Create a
new accounting integration. The behavior depends on the existing active
integration" and "Retrieve a single accounting record by its unique
identifier" (https://developer.brex.com/openapi/accounting_api.md /
.../accounting_api). Brex owns the spend-side documents (card expenses,
reimbursements, vendor bills) and pushes them to the customer's real ledger
(QuickBooks/Xero/NetSuite etc.) rather than owning journal entries itself.

### Q7. Documents
Bill pay marketing copy mentions invoice capture and PO matching
(https://www.brex.com/product/bill-pay, label: marketing) implying file
attachments live on bill/expense records, but no separate documents/vault API
object was found. NOT FOUND at API level within budget.

### Q8. Contacts
No single shared contact master was found. Brex has: Team API "users" (Brex's
own customer's employees), Payments API "Vendors" (payees), and
Onboarding-API "personal contacts" (prospects referred to Brex). These are
three separate, purpose-specific lists, not one shared contact/company
object. Label: documented (inferred from the three distinct API resources
listed above). No personal/private relationship-management feature was
found (Brex is not a CRM).

---

## Ramp

### Q1. Top-level modules / what's sold separately
Label: marketing (ramp.com/pricing, ramp.com/products, via search summary).
Ramp is "an all-in-one spend management platform that combines corporate
cards, expense management, accounts payable, travel, procurement, and
accounting automation into a single system." Pricing: base plan free
(cards, expense policy enforcement, invoice extraction); "Ramp Plus"
$15/user/month; "Ramp Enterprise" quote-based; **Procurement is an explicit
paid add-on** ("Procurement: Available as an add-on to Plus or Enterprise
plans with ... automated PO creation and tracking, and three-way match with
Ramp purchase orders."). Again, everything sold is buy-side; no CRM/Sales/
Projects product line exists.

### Q2. Records owned per module — confirmed directly from Ramp's API reference
Label: documented. Source: `https://docs.ramp.com/llms-api.txt` (Ramp's own
machine-readable API reference), fetched and grepped directly.

Endpoint titles found (selected, verbatim from the doc):
- "List general ledger accounts" / "Upload general ledger accounts" /
  "Fetch a general ledger account" — path `/developer/v1/accounting/accounts`
  — Ramp owns a **GL account list** (a mirror/tag list for coding, classified
  ASSET/LIABILITY/EQUITY/REVENUE/EXPENSE/etc.), not a journal-entry ledger.
- "List vendors" / "Upload vendors" / "Delete a vendor" / "Fetch a vendor" /
  "Update a vendor" (`/developer/v1/vendors` and a richer
  `/developer/v1/accounting/vendors` set) — Ramp owns **Vendor** records,
  including "List vendor contacts for vendor" / "Create a vendor contact" /
  "Fetch a vendor contact", **vendor bank accounts**, **vendor agreements**
  (with linked purchase orders/documents/spend requests), and **vendor
  credits**.
- "List bills" / "Create a bill" / "List draft bills" / "Create a draft bill"
  / "Submit a draft bill" / "Archive a bill" / "Fetch a bill" / "Update a
  bill" / "Hold Bill" / "Release Bill Hold" / "Fetch a bill remittance
  receipt" (`/developer/v1/bills`) — Ramp owns **Bill** (AP invoice) records
  in full, including line items, payment method/status, and a
  `purchase_order_id` link.
- Bill schema fields (quoted directly from the API reference, `List bills`):
  `accounting_date`, `amount`, `applied_vendor_credits`, `approval_status`,
  `bill_owner`, `due_at`, `entity_id`, `inventory_line_items`,
  `invoice_number`, `invoice_urls`, `issued_at`, `line_items`, `payment`
  (with `payment_method` enum incl. `ACH`, `CHECK`, `DOMESTIC_WIRE`, `SWIFT`,
  `VENDOR_CREDIT`…), `purchase_order_id`, `status: 'OPEN' | 'PAID'`, `vendor`,
  `vendor_contact_id`.
- Accounting field/dimension enum attached to every bill/GL-account line
  item, quoted verbatim: `type: 'AMORTIZATION_TEMPLATE' | 'BILLABLE' |
  'COST_CENTER' | 'CUSTOMERS_JOBS' | 'DEFERRAL_CODE' | 'EXPENSE_ENTITY' |
  'GL_ACCOUNT' | 'INVENTORY_ITEM' | 'JOURNAL' | 'MERCHANT' | 'NON_ERP' |
  'OTHER' | 'PROJECT' | 'REPORTING_TAG' | 'SUBSIDIARY' | 'TAX_CODE' |
  'UNIT_OF_MEASURE'`. **This is the most directly relevant evidence for the
  owner's question: in Ramp, "Project" and "Customers/Jobs" are not owned
  records — they are tag/dimension values borrowed from the customer's real
  ERP (via the accounting integration) so that AP spend can be coded against
  them. Ramp does not create or own project or customer records itself.**
- No "customer", "invoice" (to a customer), "quote", "sales order", "deal",
  or "lead" object appears anywhere in the endpoint-title grep of the full
  21,391-line API reference. Confirms Ramp is exclusively buy-side (AP/spend),
  never sell-side.

### Q3. Sales: quotes, orders, customer invoices
NOT FOUND / confirmed absent. Ramp's API has no quote, sales-order, or
customer-invoice object (see Q2 grep). Ramp is a spend/AP tool; it never
issues invoices to customers. Label: documented (absence confirmed by full
endpoint-title search of Ramp's own API reference).

### Q4. CRM
NOT FOUND. No contact/company/lead/deal objects beyond **vendor contacts**
(contacts belonging to a vendor/payee, for AP purposes only — "List vendor
contacts for vendor", "Create a vendor contact"). Ramp has no CRM.

### Q5. Projects
Not an owned record. "PROJECT" and "CUSTOMERS_JOBS" are entries in the
accounting **field/category enum** used to tag GL lines (see Q2 quote) —
i.e., Ramp treats "project" the same way it treats "cost center" or
"subsidiary": as a dimension pulled from the connected ERP, purely for
coding spend, not a project record with tasks/timesheets/budgets that Ramp
itself owns. Label: documented.

### Q6. Finance/Accounting
Ramp owns **GL accounts** (a synced list, for coding, not a full chart-of-
accounts source of truth) and **Bills** (AP invoices, fully owned including
line items and payment status) but not journal entries or a general ledger
of record — those live in the connected accounting system via the
"accounting integration" / "accounting_connection_id" field present on every
GL-account and bill record. Label: documented (inferred from the
`accounting_connection_id` field appearing on every account/bill object,
plus the GL-account endpoints being framed as upload/sync rather than
ledger-of-record CRUD).

### Q7. Documents
Ramp explicitly links documents to vendor agreements and bills:
"Upload documents for a vendor agreement", "Link purchase orders or documents
to a vendor agreement", "Unlink purchase orders or documents from a vendor
agreement", "Upload a file attachment to an existing draft bill", "Upload a
file attachment to an existing bill", "Fetch a bill remittance receipt"
(quoted endpoint titles, `docs.ramp.com/llms-api.txt`). There is no
standalone documents/vault module; files are attachments hung off Bill and
Vendor Agreement records. Label: documented.

### Q8. Contacts
No single shared contact master. Ramp has **Users** (internal org members)
and **Vendor Contacts** (contacts scoped to a specific vendor, for AP/
remittance purposes) as two separate resources; no evidence of a
cross-module contact/company entity, and no CRM or personal-relationship
feature. Label: documented (inferred from the distinct `/vendors/.../
contacts` vs. user endpoints).

---

## Summary table

| App | Top-level modules (sold) | Sales owner & channels | CRM role | Projects role | Documents module | Shared contacts |
|---|---|---|---|---|---|---|
| **Brex** | Corporate cards, Expenses, Bill Pay, Travel, Budgets, Accounting-sync, Team — tiered Essentials/Premium/Enterprise | None — no quote/order/customer-invoice object exists; Brex only pays vendors (Payments API → Vendors, Transfers) | None — no CRM; "Onboarding API" only refers prospects to Brex itself | None — no owned Projects module found (Fields API tags likely include a project-like dimension, unverified) | Not a standalone module; attachments implied on bill/expense records (NOT FOUND as API object) | No single master — separate Team "users", Payments "vendors", Onboarding "contacts" |
| **Ramp** | Corporate cards, Expense Mgmt, Accounts Payable, Travel, Procurement (add-on), Accounting-sync — free/Plus $15/user/Enterprise | None — confirmed no quote/order/customer-invoice object; only Bills (AP, to vendors) exist | None — only "vendor contacts" scoped to AP, no lead/deal/company CRM object | Not owned — "PROJECT" is one value in the accounting-field/dimension enum used to tag spend, sourced from the connected ERP | Not standalone — files attach to Bills and Vendor Agreements (documented endpoints) | No single master — separate Users vs. Vendor Contacts; no cross-module contact object |
| **"Finto"** | Ambiguous — 3 unrelated products found (finto.io BaaS infra; gofinto.com AI invoice-to-GL automation; finto0.webflow.io possible template/mockup) — none confirmed as a Brex/Ramp-class spend platform | NOT FOUND for all 3 candidates | NOT FOUND | NOT FOUND | NOT FOUND | NOT FOUND |

---

## Relevance to the owner's question

The strongest, most directly on-point evidence is Ramp's own accounting-field
enum (`'CUSTOMERS_JOBS' | ... | 'PROJECT' | ...`, documented,
`docs.ramp.com/llms-api.txt`): in a real, shipped finance product, "Customer"
and "Project" are not separate owned modules with their own record types —
they are **dimension/tag values on the transactional record** (the Bill),
sourced from whatever system (ERP/CRM/PM tool) actually owns that master
data. Neither Brex nor Ramp needed to build a CRM or a Projects module to
handle spend; they instead expose a generic tagging mechanism and rely on the
customer's accounting integration to supply the real customer/project list.
This supports treating Projects as a dimension/view over Finance's spend and
revenue records rather than as its own record-owning module, and suggests
Sales documents (quotes, orders, customer invoices) belong wherever the
*transaction* is created (CRM deal, store/POS, e-commerce, or a bare
Finance-issued invoice) with CRM/Projects contributing tags/context rather
than owning the sales document itself — but note this inference is drawn from
two buy-side-only products; neither Brex nor Ramp actually issues customer
invoices, so this file contains no direct evidence about how a real product
splits Sales/CRM ownership on the *sell* side. That question needs a
sell-side product (e.g., an ERP/CRM suite) as a follow-up.
