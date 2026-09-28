# 03. Domains and products

**Covers:** the shared lists, the domain map (records owned, links, money contributed, what each needs to sell alone), products as feature bundles over domains, sellability rules, the design decisions, and the open proposals.
**Read it when:** you must decide who owns a record, what a product ships, or whether a feature may create a new record type.
Back to the overview: [README.md](README.md).

---

## 1. Principle: domains own records, products add features

- Owners are business domains, not products.
- A product is a sellable set of features over domain records. Records never move between products.
- Installing a product never takes a record over. It adds features, and new record types that link to the existing records.
- Each domain contributes the stage rules for its own records only, always active ([04](04-money-model.md)). Selling another product adds features and records, never rules.
- Each link record belongs to the successor's domain: the domain that performs a fulfilment writes the link.
- A successor's rule reads its predecessor's price. That coupling only produces rows when both records exist.

---

## 2. Shared lists

Owned by the platform, not sold. Every domain tags its records with them, and none of them belongs to one product.

- parties (companies and people) and their roles; parties carry their IČO and DIČ
- projects (zakázky) and their milestones (open proposal 3)
- cost centers (střediska)
- activities (činnosti)
- categories, items, periods, currencies
- the chart of accounts and the tax codes (rate, regime, VAT return and control-statement mapping), which Accounting owns and ships read-only to every product

A milestone is a level under a project. Sales, spend and plan lines may tag one, so a milestone's sales and expenses are one `GROUP BY`, and FP&A's progress estimates may name one.

---

## 3. The domain map

The last column says what a product built on the domain needs from other domains in order to sell alone.

| Domain | Records it owns | Links to other domains | Money it contributes | To sell alone it also needs |
| --- | --- | --- | --- | --- |
| **CRM** | leads, deals, interactions, communication log, relationship status | party; a won deal hands off to a Sales quote or order (Sales writes the link) | expected revenue (deal × probability) | nothing beyond the shared lists |
| **Private relationships** (open proposal 2) | private contacts, notes and reminders owned by one user and invisible to the company | optional link from a private contact to a shared party | none | nothing |
| **Sales** | quotes, sales orders (a billing line may tag a project milestone), customer contracts, customer invoices and credit notes, till (POS) receipts, invoices for sold assets | deal (CRM), project, asset (Accounting), settlement (Treasury) | committed revenue, actual revenue, open cash | bank lines to mark invoices paid (Treasury records, basic import feature) |
| **Spend** | requests, purchase orders, supplier responses, goods receipts against an order, supplier invoices and approval, supplier advance requests (proformas), expense claims, card transactions, supplier contracts | request → order → receipt → invoice; project, cost center; settlement (Treasury) | expected, committed, incurred and actual cost; forecast and open cash | bank lines to mark invoices paid |
| **Inventory** | stock receipts without an order (open proposal 4), issues, transfers, valuation | stock in from Spend receipts for stock orders; issue → project or cost center | stock is an asset until issued; an issue is actual cost | nothing |
| **People** | employment data of employees (the person is a shared party, open proposal 5), employment contracts, cost rates, timesheets, payroll runs with their own cost lines, time-based re-attribution of payroll cost | timesheet → project, cost center, activity; payroll → bank (Treasury) | incurred labour (hours × rate), actual labour (payroll cost lines), open payroll liabilities | bank lines for payroll payments (Treasury records, basic import feature) |
| **Treasury** | bank accounts, statement lines, payment matches to any open item, classification of lines with no document (fees, interest, taxes, insurance, loans, own transfers), payment orders, advances, expected-cash items, loans, write-offs (open proposal 7) | any open item in Sales, Spend, People or Accounting | settled cash, own forecast items | registering open receivables and payables on the Sales and Spend records, and card transactions on the Spend record (the Accounting-alone pattern in section 5) |
| **Accounting** | account determination, journal entries, internal documents (opening balance, depreciation, accruals, FX, WIP, VAT settlement; a WIP document may reference FP&A's progress estimate), imported external ledger lines (not in the reference model), fixed asset register, VAT return and control statement, period close | every journal entry points to its source record | the statutory ledger; internal documents with a management category also count as actual | registering invoices and importing bank statements on the Sales, Spend and Treasury records; registering payroll recaps on People's payroll records; stock purchases carry the "for stock" fact on the invoice line (section 5) |
| **FP&A** | plan versions (budget, forecast, scenario) on any shared list, including milestones; cash plans; progress estimates (percent complete or estimate to complete, per project or milestone); management-only adjustments (never posted, with a reason code); period review | reads the projection; writes no statutory actuals. Its WIP figure is a view of Accounting's WIP internal document, not a second owner. | the plan side of every comparison; management-only actuals | nothing for plans. To compare plans with actuals without other products, it needs actuals imported as Accounting's external-ledger record ([04](04-money-model.md)); not in the reference model |
| **Documents** | files and their versions, links from any record to its files, the archive of e-invoice originals and scans used by intake | any record in any domain | none; it is the evidence behind every money record | nothing |

**Ownership details that the map implies**

| Part | Owner |
| --- | --- |
| Agreements (contracts, framework, self-billing) | Sales (customer side), Spend (supplier side, including self-billing) |
| Goods receipt against an order | Spend |
| Goods receipt without an order, stock issue | Inventory |
| Expense claims and card transactions | Spend. Treasury settles them (repays the employee or clears the card statement). The Treasury line only settles; it never carries the cost a second time. |
| Stage rules | each domain, for its own records |
| Helper rules (accepted order terms, invoice counting, settlement spreading) | Spend and Treasury |
| Position projection (union of the domain rules) | Platform |
| Plans, progress estimates, management-only adjustments | FP&A |
| Ledger, chart, tax (VAT return, control statement) | Accounting |

Table-level ownership in the reference model is in [05](05-data-model.md).

---

## 4. Products

**Products** are sellable feature bundles over the domains. Adding one never moves a record.

CRM, Private relationships, Sales, Procurement, Inventory, Payroll and timesheets (People), Treasury, Accounting, Budgeting (FP&A), Projects, Documents.

- **Projects** is a product built on FP&A's project financial control, the shared project and milestone lists and the records every domain tags with a project. It owns no records of its own.
  - It ships project and milestone budgets and forecasts, progress estimates, management-only adjustments, and the project views: P&L, cash flow, forecast at completion, WIP (read from Accounting), extra costs and variance.
  - Sold alone, it needs nothing beyond the shared lists, but it shows plans only. Actual cost, revenue and cash appear when Sales, Procurement, Payroll, Treasury or Accounting records exist, or once the external-ledger import exists (see the open question in section 8).
- **Cost centers and activities** are shared lists planned in FP&A. They are not projects.
- **Cash is company-wide**, and project is a filter.
- **Tax** (VAT returns, control statement) is part of Accounting.

**Derived, owned by no product:** the position projection (all money figures), FP&A's project financial control views (budget against actual, P&L, cash flow, forecast at completion, WIP, extra costs, variance), period-close snapshots, the reconciliation to the ledger, and the backward trace from any journal line to its source record, order, quote and CRM deal.

---

## 5. Sellability

- **Accounting sold alone** ships the minimum it needs from other domains:
  - registering received and issued invoices, importing bank statements, and matching payments
  - on the same supplier invoice, customer invoice and bank records the other products use
  - registering payroll recaps on People's payroll run and payroll cost lines, the records the Payroll product uses, not as internal documents
  - a stock purchase carries its "for stock" fact on the invoice line itself, so it posts to stock without an order or a receipt
  - its journal entries point to those records (`source_type`, `source_id`)
  - without Procurement there is no approval feature, so an invoice counts from registration
- **Adding Procurement** adds requests, orders, supplier responses, receipts and invoice approval.
  - New invoices link to orders and receipts.
  - Invoices registered earlier stay exactly as they are, with their payments and journal entries.
  - Adding Sales or Treasury works the same way: sales orders; payment orders, advances and the cash forecast.
- **One source per amount.** Each document kind has one record type, so an invoice exists once whichever products are sold. The reference model refuses the same supplier document number from the same supplier twice, and our own invoice numbers are unique ([05](05-data-model.md)).
- **Contracts** stay in the Sales and Spend domains. Accounting does not need them to post.
- **Evidence** ([01](01-constraints-and-evidence.md)):
  - Xero works this way: its Projects and Expenses add-ons link to or create the same core invoice and bank records.
  - The Czech tools keep invoice and bank agendas in one product and feed the journal from them. ABRA Flexi calls the journal "a view over the line items of all accounting documents".
  - Oracle and SAP Business One separate business documents from the journal. No journal-only edition was found for either (Oracle: NOT FOUND; SAP Business One: third-party).
- **Czech law.** The invoice stays the business record, and the journal entry links to it.
  - Act 563/1991 § 11(1) lets the facts of one accounting document sit in several accounting records, and "in these cases the accounting record and the accounting document must contain an identifier by which their link can be unambiguously determined" ([zakonyprolidi.cz](https://www.zakonyprolidi.cz/cs/1991-563), official, version in force in 2026).
  - A new Accounting Act is planned ([04](04-money-model.md), corrections), so the citation must be rechecked against it.
- **Exercised in the reference model and worked example** ([05](05-data-model.md), [07](07-worked-example.md)):
  - An invoice with no order or receipt is exactly what Accounting sold alone produces. CI3 in the worked example is one: it counts once, posts and reconciles to the ledger.
  - A supplier invoice without an order can still take an advance.
  - A stock purchase registered without an order posts to stock.
  - A payroll recap entered as an internal document next to a payroll run is caught.
  - Registering a supplier's document number a second time is refused by a constraint.

---

## 6. Design decisions

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | Projects is a sellable product. Afframe watches projects in money terms: cash flow, P&L, milestones with their sales and expenses, WIP, extra costs. It owns no records; it is a product over FP&A's project financial control and the shared project and milestone lists. | Vendors sell projects separately, and Xero Projects owns no ledger records ([01](01-constraints-and-evidence.md)); keeping records in their domains means a project budget and every project cost exist once. |
| 2 | Cost centers (střediska) and activities (činnosti) are not projects. They are shared lists, planned in FP&A. | They tag company-level and opex records; project control and cost-center control stay separate `GROUP BY`s, so one plan version never counts a cost twice. |
| 3 | Spend is part of Procurement and Treasury. There is no Spend product. | Procurement sells the buying features and Treasury settles; the spend domain's records need no third product. |
| 4 | One chart of accounts, connected to everything, owned by Accounting. | Every vendor where it was found has one chart owned by the ledger, mapped to other records by rules ([01](01-constraints-and-evidence.md)). |
| 5 | Expenses are not People. Tax is Accounting. | An expense claim or card transaction is a spend cost record that Treasury settles; VAT returns derive from posted records. |
| 6 | Accounting owns accounting, the spend side owns spend documents, Sales owns sales documents. Products add features; they never take records over. | An invoice then exists once whichever products are sold, and Czech law requires an unambiguous link between the accounting record and the document (section 5). |
| 7 | Input is mixed (Peppol, ISDOC, PDF, scans); the design is strong on Peppol. | ViDA makes EN 16931 e-invoices the default from 1 July 2030, and Czech contracting authorities must already accept them ([06](06-peppol-reference-layer.md)). |

---

## 7. Open proposals

Plain statements awaiting confirmation.

1. **Documents is a generic file record linked to any record.** This is the pattern in Xero Files, Midday Vault, NetSuite File Cabinet and Fineract ([01](01-constraints-and-evidence.md)).
2. **Private relationships** are user-owned private contacts, notes and reminders with an optional link to a shared party. The pattern was not found in any of the products examined.
3. **Project milestones are a shared list under projects.** Sales, spend and plan lines may tag one, and FP&A's progress estimates may name one. This answers "milestones with their sales and expenses" in decision 1. The reference model carries it (`project_milestone`).
4. **Goods-receipt ownership follows order presence.** A receipt against an order belongs to Spend, one without an order to Inventory. The stock flag is an attribute, not an owner.
5. **An employee is a shared party.** People owns the employment data, not the person.
6. **CRM's own records are "interactions"**, so they do not clash with the activities (činnosti) list.
7. **Write-offs belong to Treasury.**
8. **Sales documents belong to one Sales domain for every channel, not to CRM.** CRM owns relationships and pipeline and hands a won deal to Sales. Every suite examined except Dynamics 365 separates them, and Dynamics needs an ownership field to reconcile its two chains ([01](01-constraints-and-evidence.md)).

---

## 8. Open question

- **Projects sold alone:** does it include registering actuals (invoices, bank lines, payroll recaps) on the shared domain records, the way Accounting sold alone does, or only plans? Today the design ships plans only, and actuals appear when another product's records exist or an external-ledger import exists.

---

## 9. Out of scope as architecture

These are workflow rules, not architecture. The architecture only has to express each one as a domain's stage or posting rule, without changing the stage contract. Where the reference model needs a rule, it uses a sample policy and names it where it appears.

- remaining plan
- revenue timing
- labour date
- conditionally accepted and disputed invoices
- stale commitments
- VAT in cash
- order amendments
- books kept externally
- projection and scenario storage
