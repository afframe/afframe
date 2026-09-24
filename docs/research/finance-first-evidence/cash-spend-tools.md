# Cash / Spend Tools: Forecasts, Commitments, Actuals — Domain Model Research

Research question: smallest coherent domain model making plans, commitments, incurred costs,
accounting actuals and cash comparable/traceable without double counting.

Method note: closed-source SaaS vendors — only public docs/help centers/engineering blogs count
as evidence. WebFetch/WebSearch results below are summarized by an intermediate model from live
page fetches; where a verbatim quote could be extracted it is marked as such, otherwise the
paraphrase is labelled and the claim is downgraded to PARTLY/NOT FOUND rather than asserted as
CONFIRMED. No claim below is filled from memory.

---

## 0. Brief URLs — what they actually say

### https://event.agicap.com/webinar/improve-liquidity-with-AI/
Status: **CONFIRMED** (page fetched) — Label: vendor-documented (webinar landing page)
Content (paraphrase, no long verbatim available from fetch): Agicap describes a three-part
data model — forecast, actuals (bank statements, "source of truth"), and "expected
transactions" (customer invoices, POs, payroll fed from ERP). AI features advertised:
transaction-categorization rule suggestions, recurring-transaction detection, ML-based
cash-flow prediction with confidence intervals, and an upcoming MCP connector for external AI
tools. **This is a marketing/webinar page, not product documentation** — treat mechanism
claims here as directional only, not authoritative.

### https://engineering.ramp.com/workflows
Status: **PARTLY** — the correct working URL is `https://engineering.ramp.com/post/workflows`
("Abstraction Engineering — Ramp Builders Blog"). The bare `/workflows` path returned only a
page header with no body content when fetched directly.
Label: vendor-documented (engineering blog) once the correct URL is used. See Claim 4.

### https://www.brex.com/product/spend-management
Status: **CONFIRMED** (page fetched) — Label: vendor-documented (marketing product page, not
help-center docs — flagged explicitly).
Verbatim: "Set top-level budgets across departments and assign them to department heads."
Also (verbatim, from fetch): "real-time budget tracking with automated alerts when spending
approaches thresholds" and "Brex AI will even flag anomalous activity to help you keep
everyone on budget globally." This page is **marketing**; it does not define the mechanism by
which a budget's "available" amount is reduced (see Claim 7 — NOT FOUND in help docs).

### https://www.rillet.com/
Status: **CONFIRMED** (page fetched) — Label: vendor-documented (marketing homepage).
Verbatim: "Zero-day close starts here." Also verbatim: "Not a chatbot. Specialized agents
embedded in your workflows, trained on accounting, connected to your GL" and "Run a continuous
close with every entry traceable to the source." Positions itself as "AI-native ERP" with a
"perpetual general ledger." Core modules mentioned: GL, revenue recognition (ASC 606), AR/AP
subledgers, bank reconciliation, contract/billing integration (Maxio, Stripe). No schema
detail on this homepage — marketing only, see Claim 8 for docs-level detail.

---

## Agicap

### 1. Forecast consumption by actuals — exact term and rule
Status: **NOT FOUND** (precise mechanism/term) — Label: vendor-documented pages found describe
adjacent behavior, but no help-center page was retrieved that states the exact rule/term for
how a forecast line for a past/current period is reduced/replaced as actual bank transactions
land.
What was found: Agicap's own marketing/help pages (agicap.com and help.agicap.com, via search
snippets) describe: "Agicap can pull in expected transactions, and users can set forecasted
budgets for each category of receipts and disbursements and check the actual/budget variance
at any time," and short-term forecasting (3–15 days) is described as using "a direct,
transaction-level method based on real-time bank activity and scheduled payments," while
medium-term forecasting (4–13 weeks) "integrates expected flows from ERP, invoices, purchase
orders, actual DSO per client, and debt deadlines." URL: agicap.com marketing pages (via
search); help.agicap.com article "What is the 'Uncategorized' Category" (help.agicap.com/en/articles/10038431)
confirms bank transactions are categorized into Inflows/Outflows for forecast accuracy, but
does not state a consumption rule.
Mechanism (best available, labelled **inferred** from marketing language, not confirmed by a
docs page): forecast and actual/expected transactions appear to be compared/netted per category
per period ("actual/budget variance") rather than a documented "auto-replace" rule being
directly quoted. **This claim should be re-verified against help.agicap.com directly in a
follow-up pass; current evidence is PARTLY at best.**

### 2. Expected transactions / invoices vs forecast; reconciliation with bank transactions
Status: **PARTLY** — Label: vendor-documented (agicap.com articles, via search snippets; not
directly fetched from help.agicap.com)
Quote (as returned by search, attributed to Agicap's own pages, not independently re-fetched
verbatim): "Agicap uses matching algorithms capable of handling complex reconciliations (one
transaction against multiple invoices, or the reverse)." Also: "Agicap synchronizes financial
data with your ERP via API, SFTP, and OpenAPI... automatic transfer of bank transactions,
invoices, and cash flow forecasts."
Mechanism (as described, not independently confirmed verbatim): expected transactions (invoices,
POs, payroll) are imported from ERP as forward-looking cash items; when a bank transaction
appears, it is matched ("reconciled") against one or more expected transactions/invoices,
supporting one-to-many and many-to-one matching. Whether the expected transaction is marked
"paid" and removed from the forward forecast, or partially reduced for partial payments, is
**NOT FOUND** in a directly-fetched primary source — only inferred from generic "automated bank
reconciliation" marketing copy (agicap.com/en/article/automated-bank-reconciliation/).

### 3. Scenarios — construction method
Status: **PARTLY** — Label: marketing (agicap.com article pages, via search, not help-center)
Paraphrase (search snippet, attributed to Agicap marketing copy): "Agicap allows you to
duplicate your cash flow plan to create several potential scenarios: pessimistic, realistic,
optimistic... compare your various forecasts with each other." This indicates scenarios are
**full duplicates ("copy") of a base plan**, not a delta/patch layered on top — but this is
marketing phrasing ("duplicate"), not a docs page describing the underlying data model, so it
is labelled **inferred** rather than confirmed product behavior. No help.agicap.com page was
retrieved describing scenario storage as diffs vs. full copies.

---

## Ramp

### 4. Engineering "workflows" article — building blocks; workflow engine not financial model
Status: **CONFIRMED** — Label: vendor-documented (engineering blog)
URL: https://engineering.ramp.com/post/workflows ("Abstraction Engineering — Ramp Builders Blog")
Verbatim: "The building blocks then became vertices and edges, a vertex being either an action
or a condition." Also verbatim (earlier in the piece): "snippets of code (what we later termed
'actions') were dependent on boolean expressions ('conditions')."
Mechanism: Ramp's workflows are modeled as a graph (vertices = actions or conditions, edges =
transitions); "executing the workflow became traversing the graph, performing (or enqueuing)
any action found, and waiting [for] conditions to be true" (paraphrase of fetched summary).
This is confirmed to be about the **generic workflow execution engine** (approvals, receipt
requirements, field visibility, persisted in Postgres) — **not** a description of Ramp's
financial/accounting data model. Confirms the brief's expectation exactly.

### 5. Semantic layer / data model; own ledger vs. sync to ERP
Status: **PARTLY** — Label: vendor-documented (support.ramp.com)
No Ramp public page uses the term "semantic layer." On ledger-vs-sync: URL
https://support.ramp.com/overview-of-ramp-accounting — verbatim: "With a click, sync or export
transactions like credit card charges and reimbursements for your accounting system," and "Ramp
sends coded details, including the memo. For direct integrations, receipt files are included
when the connected provider supports them."
Mechanism: Ramp codes each transaction/bill with GL account, department, class, location, and
custom fields (per Ramp's Accounting Agent description, support.ramp.com search snippet: "auto-
codes every transaction and bill across every field, including general ledger, department,
class, location, and even custom fields") and **syncs/exports these coded transactions to the
connected ERP (NetSuite, QuickBooks, Sage Intacct, Xero, Business Central, etc.), which remains
the system of record** — Ramp does not present itself as maintaining its own GL of record.
"Semantic layer" terminology itself: **NOT FOUND** on Ramp's public sites.

### 6. Procurement (PR -> PO -> bill, matching) and budget consumption by commitments
Status: **PARTLY** — Label: vendor-documented (support.ramp.com) for matching; mixed marketing/docs for budget consumption
3-way match, URL https://support.ramp.com/3-way-match-with-ramp-procurement — paraphrase (search
snippet, from Ramp help center): "3-way match allows you to match bills in Ramp Bill Pay with
purchase orders and item receipts... With 3-way match enabled, once you match a bill to an
imported PO from NetSuite, Ramp will automatically fetch related item receipts... and will show
an alert if the billed units haven't been received." Supported for POs from NetSuite, Sage
Intacct, QuickBooks Online (native Ramp POs) and Business Central (item receipts).
Budget consumption by commitments: Ramp's own **marketing** page (https://ramp.com/budgets)
states verbatim: "You always know what's spent, what's committed, and what's left — right
now," and "See budget impact from every dollar—T&E, AP, procurement, and POs—live, in one
platform." This confirms Ramp Budgets tracks a distinct "committed" bucket alongside "spent"
and "available," consistent with commitments (approved-but-unspent requests/POs) reducing
available budget separately from actual spend. **However**, the Ramp **help-center** article
fetched (support.ramp.com/hc/en-us/articles/45484584119571-Budgets-overview-and-setup) did not
contain an explicit definition of "committed" vs "spent" vs "available" — so the precise
consumption rule (e.g., does an approved-but-unpaid PR reduce "available" the moment it's
approved, or only at PO/bill creation?) is **NOT FOUND** in vendor docs, only asserted in
marketing copy. Status downgraded to PARTLY accordingly.

---

## Brex

### 7. Budgets/spend limits: consumed by approved-but-unspent requests? Accounting sync
Status: **PARTLY** (marketing confirms concept; help-center mechanism NOT FOUND) — Label: mixed
Marketing (brex.com/product/spend-management, vendor-documented but marketing): verbatim
"real-time visibility into spending against allocated amounts," "sends alerts when teams
approach limits," budgets "automatically restrict spending once budgets are exhausted."
Help-center fetch (https://www.brex.com/support/manage-budgets-and-spend-limits): the page
explains how to request/approve spend-limit increases but — per direct fetch — **does not
specify whether an approved request reduces available budget as a commitment before money is
spent, or only reduces it at actual settlement**. This is explicitly **NOT FOUND** rather than
guessed.
Accounting sync (confirmed, vendor-documented): Brex supports ERP sync to NetSuite, QuickBooks
Online, Sage Intacct, Xero, and Dynamics 365 Business Central (support.brex.com/help center
pages, via search: "Brex syncs various fields depending on the ERP, either once the bill is
approved in Brex or at bill creation" and "default configuration for card expenses and
reimbursements is to export as journal entries"). This confirms **Brex is not the general
ledger** — it exports coded transactions (as journal entries or vendor bills) to the connected
ERP, which is the system of record. Consistent with Ramp's pattern (Claim 5).

---

## Rillet

### 8. What Rillet is; documented core objects; unified data model claim
Status: **PARTLY** — Label: mostly marketing (rillet.com product pages), one item third-party
Rillet self-describes (rillet.com, vendor marketing) as an "AI-native ERP" with a "perpetual
general ledger" / "intelligent system of record." Verbatim: "Apply ASC 606 automatically,
directly from your contracts" (revenue recognition product page) and "Run a continuous close
with every entry traceable to the source."
Core objects claimed on product pages (rillet.com/product/*, marketing, not schema docs):
General Ledger, Advanced Revenue Recognition (ASC 606/IFRS 15 schedules), Accounts Receivable /
Accounts Payable subledgers, bank reconciliation, contract/billing sync (Stripe, Maxio, CRM).
Search-snippet paraphrase of a Rillet product page: "Rillet's revenue recognition module is
designed to transform contract terms and operational activity (invoices, usage) into ASC
606–aligned revenue schedules and the corresponding journal entries... maintains a revenue
subledger covering deferred vs recognized balances, waterfall schedules, and contract
liabilities." This is **vendor-documented but still product-marketing copy**, not an engineering
schema doc — no Rillet page describing internal table/schema structure was found.
API-level evidence (Label: vendor-documented, developer docs — docs.api.rillet.com, found via
apitracker.io third-party listing but the changelog URL itself, docs.api.rillet.com/changelog, is
Rillet's own docs domain): confirms existence of a `GET /reports/journal-entries` endpoint and a
"Filter Journal Entries by GL Account" changelog entry, i.e., journal entries are a first-class,
queryable API object — this is the strongest **CONFIRMED** data-point for Claim 8 (journal
entries as a documented object with a GL-account-filterable API), though it was reached via a
third-party summary (apitracker.io) rather than direct fetch of docs.api.rillet.com and should
be re-verified by fetching docs.api.rillet.com directly in a follow-up pass.
No Rillet page uses the phrase "unified data model" verbatim in what was retrieved — treat any
such phrase as **NOT FOUND** unless re-confirmed.

---

## Procore (reference)

### 9. Budget view columns — exact definitions/formulas
Status: **CONFIRMED** — Label: vendor-documented (support.procore.com, "Read a Budget")
URL: https://support.procore.com/products/online/user-guide/project-level/budget/tutorials/read-a-budget
Verbatim/near-verbatim definitions as fetched from the page:
- Original Budget Amount: "Shows the original budget amount for the budget line item."
- Approved COs: "Shows the commitment change orders in the Approved status by default."
- Revised Budget: "Shows the total amount of any Budget Modifications + Approved COs."
- Pending Budget Changes: "Shows the amounts from pending prime contract change orders in the
  Pending - statuses."
- Projected Budget: "Calculates the value of the Revised Budget + Pending Budget Changes
  values."
- Committed Costs: shows commitment costs for subcontracts in Approved and Complete statuses,
  purchase orders in Approved status, and change orders in Approved status.
- Direct Costs: "Shows direct costs in the Pending, Revise and Resubmit, and Approved status."
- Job to Date Costs: "Shows Direct Costs + Subcontractor Invoices."
- Pending Cost Changes: shows subcontracts in Out for Signature status, purchase orders in
  various statuses, and change orders in Pending - statuses.
- Projected Costs: "Shows Committed Costs + Direct Costs + Pending Cost Changes."
- Forecast to Complete: "An automatic calculation of the Projected Budget - Project[ed] Costs."
- Estimated Cost at Completion: "Calculates the Projected Costs + Forecast to Complete."
- Projected Over/Under: "Calculates the Projected Budget - Estimated Cost at Completion."
- Budget Modifications: not on this specific page, but confirmed via
  support.procore.com/.../tutorials/create-a-budget-modification (search snippet):
  "Budget tool modifications transfer amounts from one budget line to another, which results in
  a 'net-zero' transaction and updates the Original Budget and Budget Modification amounts."

Mechanism: this gives an explicit, fully-defined waterfall — Original -> (+Modifications,
+Approved COs) -> Revised -> (+Pending Budget Changes) -> Projected Budget; and on the cost
side, Committed -> (+Direct, +Pending Cost Changes) -> Projected Costs -> (+Forecast to
Complete) -> Estimated Cost at Completion; with Projected Over/Under = Projected Budget minus
Estimated Cost at Completion. This is the clearest, most fully-specified commitment/actuals/
forecast waterfall found across all five vendors in this research pass.

### 10. Commitments (subcontracts, POs), commitment change orders, subcontractor invoices feeding budget
Status: **PARTLY** — Label: vendor-documented (support.procore.com, marketing overlap)
Direct fetch of https://support.procore.com/products/online/user-guide/project-level/commitments
did **not** contain an explicit sentence stating the budget is calculated from commitments
rather than typed in — that specific linkage sentence was **NOT FOUND** in the fetched page.
However, corroborating evidence from search snippets of Procore's own pages: "In Procore,
purchase orders and subcontracts are used exclusively to bill for pre-determined costs recorded
in your project's budget," and "Your budget and budget reports are automatically updated to
reflect your entries," and "See real-time change impacts that committed, uncommitted, pending,
and projected costs have in the Procore Budgets tool." Combined with the Claim 9 finding that
"Committed Costs" is explicitly defined as showing costs from subcontracts/POs/change orders in
specific statuses (Approved, Complete), this strongly supports that the **Committed Costs
column is computed live from the Commitments tool's records by status, not manually typed** —
but the single connecting sentence stating this outright was not captured verbatim, hence
PARTLY rather than CONFIRMED.

---

## Extra findings (up to 5)

1. **Ramp Budgets unifies multiple spend types into one number.** Marketing page ramp.com/budgets,
   verbatim: "Unify spend data with one source of truth across cards, reimbursements, Bill Pay,
   and POs" (search-snippet quote of Ramp's own help/marketing copy) — relevant to avoiding
   double counting across payment rails. Label: marketing.
2. **Ramp's Accounting Agent auto-codes every transaction/bill across GL account, department,
   class, location and custom fields** (support.ramp.com, via search snippet) — relevant
   evidence that Ramp's coding dimensions map directly onto standard ERP GL dimensions rather
   than a Ramp-specific taxonomy. Label: vendor-documented (help center, snippet).
3. **Procore's "Budget Modifications" are explicitly net-zero transfers between budget lines**,
   not top-line increases — support.procore.com/.../create-a-budget-modification. Label:
   vendor-documented.
4. **Brex supports ERP journal-entry export as the default for card expenses/reimbursements**,
   confirming Brex is a coding/capture layer, not itself the GL. Label: vendor-documented
   (help.brex.com, via search snippet).
5. **Rillet ships an MCP server and OpenAPI-based REST API** (docs.api.rillet.com/changelog),
   suggesting a documented, structured API surface (journal entries filterable by GL account)
   that could be a source of truth for integration design. Label: vendor-documented (developer
   docs domain), reached via third-party (apitracker.io) summary — recommend direct re-fetch.

---

## Gaps flagged for follow-up (do not treat as resolved)
- Agicap: no help.agicap.com page was directly fetched and quoted verbatim for the exact
  "forecast consumption" term/rule (Claim 1) or the scenario-construction mechanism (Claim 3).
- Ramp: exact rule for when "committed" reduces "available" budget (approval time vs. PO/bill
  time) not found in help-center text as fetched.
- Brex: budget-consumption-by-commitment mechanism not found in help-center text as fetched.
- Rillet: no engineering blog or schema-level doc (only product marketing pages + API changelog)
  was found describing an explicit "unified data model."
- Procore: the single sentence explicitly stating "budget is calculated from Commitments, not
  typed in" was not captured verbatim from the Commitments tool page itself.
