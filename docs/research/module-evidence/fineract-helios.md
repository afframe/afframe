# Module boundaries and record ownership: Apache Fineract and HELIOS (Asseco Solutions)

Budget: ~20 min. Fetched live 2026-09-24 via GitHub API/raw source (apache/fineract, `develop` branch) and public.helios.eu / helios.eu / third-party Helios-partner pages. No Russian sources used. Scope is architecture only (modules, boundaries, record ownership) — workflow/UI is out of scope. Labels: **documented** (primary vendor/project doc or source code), **source** (source code itself, strongest evidence), **marketing** (vendor brochure/blog, still primary but promotional), **third-party** (partner/reseller content, not the vendor), **inferred** (my reading of evidence, not a direct quote), **NOT FOUND** (gap).

Owner's driving question: should Sales sit in CRM, Projects, or Finance, given sales can originate from CRM, a store, a one-off outside any contact, or an asset disposal — and if Finance owns sales, what is CRM for, and is Projects just a dashboard?

---

## Apache Fineract

### Q1 — Top-level modules, separate deployment
Label: source. URL: https://github.com/apache/fineract (root directory listing, `develop` branch, fetched via GitHub Contents API 2026-09-24)

Fineract's Gradle build is split into independently buildable modules at the repo root, including (from the live directory listing): `fineract-core`, `fineract-loan`, `fineract-savings`, `fineract-accounting`, `fineract-charge`, `fineract-document`, `fineract-branch`, `fineract-investor`, `fineract-loan-origination`, `fineract-progressive-loan`, `fineract-working-capital-loan`, `fineract-rates`, `fineract-tax`, `fineract-cob`, `fineract-report`, `fineract-security`, `fineract-provider` (the Spring Boot server that wires everything together), plus `fineract-client`/`fineract-client-feign` (generated API client) and `fineract-war`.

Quote (module names copied verbatim from the API response): `"fineract-accounting"`, `"fineract-loan"`, `"fineract-savings"`, `"fineract-document"`, `"fineract-charge"`, `"fineract-investor"`, `"fineract-loan-origination"`.

These are Gradle modules of one monolithic deployable (`fineract-provider`/`fineract-war`), not separately sold products — Fineract itself is a single open-source core-banking platform, not a suite of separately licensed apps. Whether any of these modules can be deployed as independent services was **NOT FOUND** in this session (the older `fineract-cn-*` microservices line, e.g. `fineract-cn-accounting`, is a separate historical/deprecated project, not the current `apache/fineract` mainline — label: inferred from search results, not verified against that repo directly).

Inside `fineract-provider`'s main package, feature areas are further separated into `portfolio` (business/product features: `client`, `group`, `loanaccount`/`loanproduct`, `savings`, `charge`, `fund`, `collateral`, `note`, `shareaccounts`, `tax`, `transfer`, etc.), `accounting`, `organisation`, `useradministration`, `interoperation`, `notification`, `cob` (close-of-business batch), `batch`, `adhocquery`, `spm`. (Source: GitHub Contents API listing of `fineract-provider/src/main/java/org/apache/fineract/` and `.../portfolio/`.)

### Q2 — Records each module owns
Label: source.

- **`fineract-core` → `portfolio/client/domain`**: `Client` is the shared party record — fields observed directly in `Client.java` (https://raw.githubusercontent.com/apache/fineract/develop/fineract-core/src/main/java/org/apache/fineract/portfolio/client/domain/Client.java): `accountNumber`, `office` (branch), `status`, `firstname`/`lastname`/`fullname`/`displayName`, `mobileNo`, `emailAddress`, `isStaff`, `externalId`, `dateOfBirth`, `gender`, `staff` (loan officer link). There is also `Group` (a set of clients) alongside it in `portfolio`.
- **`fineract-loan` → `portfolio/loanaccount/domain`**: owns `Loan` (the loan account) and `LoanTransaction` (disbursement, repayment, waiver, charge-off, etc.). URL: https://github.com/apache/fineract/blob/develop/fineract-loan/src/main/java/org/apache/fineract/portfolio/loanaccount/domain/Loan.java (path confirmed via repo git-tree listing).
- **`fineract-savings`**: owns savings accounts and savings transactions (deposit, withdrawal, interest posting) — same pattern as loans (module directory confirmed; deep field read not performed this session, label: inferred from directory structure + accounting-processor code below, which explicitly references `AccountingProcessorForSavings`).
- **`fineract-accounting`**: owns `GLAccount` (chart of accounts), `GLClosure` (accounting period closures), `JournalEntry`, and `ProductToGLAccountMapping` (`producttoaccountmapping` sub-package). Confirmed via directory listing (`accounting/{accrual, common, jobs, journalentry, productaccountmapping, provisioning}`) and by reading `ProductToGLAccountMapping.java` (below).
- **`fineract-document`**: owns `Document` and `Image` (generic, polymorphic attachment records) — see Q7.
- Other modules (`fineract-charge`, `fineract-rates`, `fineract-tax`, `fineract-branch`, `fineract-investor`) own charges, interest/fee rates, tax components, branch/office hierarchy, and loan-investor participation records respectively (directory names only, not deep-read this session — label: inferred).

Fineract has **no sales, quote, order, or customer-invoice records anywhere in the module list** — its domain vocabulary is entirely client/loan/savings/share/GL, i.e. it is a core-banking ledger platform, not a CRM/ERP with a commercial sales pipeline. This absence itself is evidence: label inferred (absence-of-evidence from a full top-level and portfolio-level directory listing, not a targeted denial by Fineract docs).

### Q3 — How products/accounts relate to clients, and how accounting derives GL entries
Label: source (strongest evidence in this file).

A **loan product** (`LoanProduct`) is a template; opening a loan account for a `Client` (or `Group`) instantiates a `Loan` from that product. The `Loan`/`LoanTransaction` records reference the client and the loan product, but never touch GL accounts directly — GL derivation is a separate, downstream step performed by the `accounting` module reading a **product-to-GL-account mapping**.

Quote — `ProductToGLAccountMapping.java` (https://raw.githubusercontent.com/apache/fineract/develop/fineract-accounting/src/main/java/org/apache/fineract/accounting/producttoaccountmapping/domain/ProductToGLAccountMapping.java):
```java
@Table(name = "acc_product_mapping", uniqueConstraints = { @UniqueConstraint(columnNames = { "product_id", "product_type",
        "financial_account_type", "payment_type" }, name = "financial_action") })
public class ProductToGLAccountMapping extends AbstractPersistableCustom<Long> {
    @ManyToOne(optional = true)
    @JoinColumn(name = "gl_account_id")
    private GLAccount glAccount;
    @Column(name = "product_id", nullable = true)
    private Long productId;
    ...
    @Column(name = "product_type", nullable = true)
    private int productType;
    @Column(name = "financial_account_type", nullable = true)
    private int financialAccountType;
```
This confirms: GL accounts are mapped per `(product_id, product_type, financial_account_type, payment_type)`, not per transaction and not per client — the ledger destination is a property of the *product configuration*, looked up at posting time.

The actual posting logic lives in `CashBasedAccountingProcessorForLoan` (https://raw.githubusercontent.com/apache/fineract/develop/fineract-provider/src/main/java/org/apache/fineract/accounting/journalentry/service/CashBasedAccountingProcessorForLoan.java), which iterates each new `LoanTransactionDTO` on a loan and dispatches by transaction type:
```java
public void createJournalEntriesForLoan(final LoanDTO loanDTO) {
    ...
    for (final LoanTransactionDTO loanTransactionDTO : loanDTO.getNewLoanTransactions()) {
        ...
        if (loanTransactionDTO.isReversed()) {
            journalEntryWritePlatformService.createJournalEntryForReversedLoanTransaction(...);
            continue;
        }
        /** Handle Disbursements **/
        if (transactionType.isDisbursement()) {
            createJournalEntriesForDisbursements(loanDTO, loanTransactionDTO, office);
        }
```
This is the mechanism the owner is asking about by analogy: **the primary business transaction (loan disbursement, repayment, savings deposit) is a first-class record owned by the portfolio module (loan/savings); the accounting module never creates that record — it only reads the product's GL mapping and writes a derived `JournalEntry`.** There is a family of processor classes per portfolio area (`AccountingProcessorForLoan`, `AccountingProcessorForSavings`, `AccountingProcessorForShares`, `AccountingProcessorForClientTransactions`), each with Cash-based and Accrual-based variants (confirmed via directory listing of `accounting/journalentry/service`), i.e. the derivation strategy (cash vs. accrual) is also product/account-level configuration, not hardcoded per module.

Fineract has no "sales channel" concept (CRM/store/e-commerce/one-off/asset-sale) — the only "sale" analog is loan disbursement/savings deposit against an already-onboarded `Client`, always mediated by a `Product` + client account. **NOT FOUND**: any notion of a transaction against a party that is not a registered `Client`/`Group` (i.e., no anonymous/one-off counterpart concept) — Fineract's whole transaction model requires an account, and accounts require a client.

### Q4 — CRM
**NOT FOUND.** Fineract has no CRM module, no `contact`/`lead`/`opportunity`/`deal` package anywhere in the directory tree fetched. The closest concept is the `Client`/`Group` party record itself (Q2), which is operational (loan/savings eligibility, KYC fields) rather than relationship/pipeline-tracking. This is a genuine architectural absence, not a naming difference (inferred from full top-level and portfolio-level directory listings).

### Q5 — Projects/orders (zakázky) equivalent
**NOT FOUND** as a distinct module. Fineract has no "project" or "job costing" dimension; the nearest structural analog is the `Office`/branch hierarchy (used for reporting/GL segmentation) and `Fund` (funding-source tagging on loans), which behave like dimensions attached to transactions rather than a first-class record with its own lifecycle (inferred from directory names `organisation`, `fund` and the fact `Loan`/`LoanTransaction` reference `officeId` per transaction, seen in `CashBasedAccountingProcessorForLoan.java` above).

### Q6 — Finance/Accounting
Label: source. The `accounting` module owns `GLAccount` (chart of accounts), `GLClosure` (period closes), `JournalEntry`, and `ProductToGLAccountMapping`. It does **not** own any primary transaction record — loans, savings transactions, and share transactions are all owned by their respective portfolio modules and merely *feed* the accounting module through the processor classes in Q3. This is the cleanest evidence in this file for "Finance owns the ledger, not the business transaction that causes it."

### Q7 — Documents/DMS
Label: source. `fineract-document` is a standalone module owning a generic, polymorphic attachment record. Quote — `Document.java` (https://raw.githubusercontent.com/apache/fineract/develop/fineract-document/src/main/java/org/apache/fineract/infrastructure/documentmanagement/domain/Document.java):
```java
@Table("m_document")
public final class Document implements Serializable {
    @Column("id") private Long id;
    @Column("parent_entity_type") private String parentEntityType;
    @Column("parent_entity_id") private Long parentEntityId;
    @Column("name") private String name;
    @Column("file_name") private String fileName;
```
`parentEntityType` + `parentEntityId` is a polymorphic link: any record in the system (client, loan, savings account, group, staff, etc.) can have `Document`/`Image` rows attached by tagging the owning entity's type and id, without the `Document` module needing to know about every domain model. Content storage itself is pluggable (`ContentStoreService` with `FileContentStoreService` and `S3ContentStoreService` implementations, confirmed via directory listing).

### Q8 — Contacts / shared party master
Label: source. `Client` (and `Group`, a set of clients) in `fineract-core` is the single shared party master used by every portfolio module — loans, savings, shares, and client-level transactions (`ClientTransaction`) all key off the same `Client` id (confirmed by `portfolio/client/domain` containing `ClientCharge`, `ClientTransaction`, `ClientAddress`, `ClientFamilyMembers`, `ClientNonPerson` — i.e., one client record with satellite tables, all in the `client` package, referenced by `loanaccount` and `savings`). There is no separate "personal contacts"/private-CRM register — Fineract has exactly one party model (Client/Group), consistent with its single-purpose core-banking scope.

---

## HELIOS iNuvio / Orange / Green (Asseco Solutions)

### Q1 — Top-level modules/products, what's sold separately
Label: marketing + third-party (corroborating). URL: https://www.helios.eu/files/obchod-v-inuviu.pdf (Asseco vendor PDF brochure "OBCHOD — HELIOS iNuvio", fetched and text-extracted 2026-09-24)

The vendor's own "Obchod" (Commerce) product brochure lists its own internal sub-areas as a table of contents:
Quote (extracted verbatim from the PDF): `"Podpora obchodního procesu / Pokladní prodej / CRM / Skladové hospodářství a obchod / Rozšiřující funkcionality / Fakturace a pošta"` (Sales-process support / Till/POS sales / CRM / Warehouse management and sales / Extension functionalities / Invoicing and mail).

This shows Asseco packages **CRM as a sub-area of the "Obchod" (Commerce) product line**, not as an independent product — but per the earlier evidence file (`docs/research/finance-first-evidence/cz-erp-tools.md`, Q1, module price list for the related Helios Red product), functional areas across the Helios family are still separately priced/licensed modules (e.g. "Zakázky (Orders) – 6,300 CZK, Majetek (Assets) – 5,300 CZK, ... Maloobchodní pokladna (Retail cash register) – 7,300 CZK"). Helios also exists as distinct **product lines by customer segment** — iNuvio (SME, successor to Orange since 15 Sept 2021) vs. Green (larger/other org types) — confirmed in that same earlier evidence file (label there: vendor-documented).

### Q2 — Records per module (from the brochure's own bullet lists)
Label: marketing. Same PDF, quoted verbatim per section:

- **Podpora obchodního procesu** (sales-process support): `"efektivní pořizování obchodních dokladů... práce s výrobními čísly / šaržemi... automatické generování dodavatelských objednávek... evidence obalů"` — i.e. owns commercial documents broadly (purchase/sales orders, packaging records), tightly coupled to the warehouse ("Modul... je úzce spojen s modulem Sklad").
- **Pokladní prodej** (till/POS sales): `"realizace prodeje... vazba na skladovou evidenci... automatické účtování tržeb"` (sale execution, linked to stock records, automatic posting of takings) — a distinct POS/cash-sale record type, separate from invoicing.
- **CRM**: `"evidence pošty a datové schránky, firemní aktivity, kontaktní centrum, kalendáře, řízení projektů, servis, zakázky"` (mail/data-box records, company activities, contact centre, calendars, project management, service, **zakázky/orders**). Note "zakázky" (jobs/projects) is bundled inside the CRM feature list in this brochure.
- **Skladové hospodářství a obchod** (warehouse mgmt. and sales): `"saldo nad prvotními doklady, zádržné, skonta, pokladní prodej, věrnostní program, ... kontrakty, nabídky, objednávky a rezervace"` — **quotes ("nabídky"), orders ("objednávky") and reservations are explicitly owned here**, not in CRM.
- **Fakturace a pošta** (invoicing and mail): `"faktury přijaté... skonta k vydaným nebo přijatým fakturám, faktury vydané, zádržné, vzájemné zápočty z obchodních vztahů"` — **received and issued invoices** are their own bullet list, separate again from both CRM and from quotes/orders.

### Q3 — Sales: who owns quotes/orders/invoices, and channels
Label: marketing (brochure) + third-party (partner blog, corroborating).

Per the brochure structure above, **quotes and orders live in "Skladové hospodářství a obchod," invoices live in "Fakturace a pošta,"** and POS/till sales are a third, separate record type in "Pokladní prodej" — three different places for three different sales-originating flows within the same "Obchod" product line, all distinct from CRM.

A Helios-partner integrator's blog makes the CRM/ERP boundary explicit for the presales-vs-commercial-document split:
Quote (Czech, machine-translated), URL https://www.datamix.eu/blog/crm-helios-inuvio-360-pohled-na-zakaznika/: `"CRM eviduje komunikaci, obchodní případy, schůzky a další práci se zákazníkem"` (CRM records communication, business cases/deals, meetings and other customer-facing work) vs. `"ERP systém Helios Inuvio... obsahuje objednávky, dodací listy, faktury a další ekonomické doklady"` (the Helios Inuvio ERP system contains orders, delivery notes, invoices and other economic documents), and: `"Pro skutečný 360° pohled na zákazníka je potřeba obě části propojit"` (for a true 360° customer view, both parts need to be linked) — stated precisely because they are *not* the same data by default; the vendor's own CRM add-on and third-party bridges (ADAPTY) exist to surface ERP order/invoice data inside the CRM UI, not to move ownership of those records into CRM.

A second search-result summary (label: third-party, unverified against a live fetch this session) describes the CRM agenda's own scope directly:
`"CRM umožňuje kompletní a komplexní řízení obchodních případů v celé presales fázi, včetně řízení aktivit a veškerých vztahů souvisejících se zakázkou... přípravy cenových a dalších nabídek"` (CRM allows complete management of business cases through the entire presales phase, including managing activities and all relationships related to the deal, and preparing price quotes and other offers) — i.e. CRM can *draft* an offer as part of a presales case, but the brochure (Q2) places the authoritative "nabídky" (quotes) record inside the Skladové hospodářství/Obchod area, implying CRM's offer-drafting is either a front-end to that same record or a separate presales artifact that gets converted — this distinction was **NOT FOUND** at source-code/data-model precision in the pages fetched this session (gap).

**Channels**: the brochure evidences at least three separate landing points for a "sale": (a) a CRM-tracked "obchodní případ" flowing into a quote/order in Obchod; (b) POS/"Pokladní prodej" till sales, structurally distinct, feeding "automatické účtování tržeb" (automatic posting of takings) directly; (c) issued invoices in "Fakturace a pošta," which per the brochure's own text can also arise independent of a prior CRM case (e.g. "vzájemné zápočty," direct invoicing). **NOT FOUND** in this session: an explicit statement on how a one-off sale to a counterpart that has no existing Organizace record is handled, or how the sale of a company asset (as opposed to inventory/goods) is recorded — likely the separate "Majetek" (Assets) module referenced in the module price list (earlier evidence file), but no direct evidence of an asset-disposal-to-invoice flow was fetched this session (gap).

### Q4 — CRM: what it owns, does it create sales/finance documents itself
Label: third-party (partner content), corroborated by brochure structure (Q2/Q3).

CRM owns: organizational contacts/contact persons (shared with the rest of the system, see Q8), activities ("firemní aktivity"), calendars, contact-centre records, "obchodní případy" (business cases/deals), and, per the brochure, "zakázky" and "řízení projektů" are listed as CRM-area bullets too — suggesting in this product line CRM is the home of the deal/relationship *and* a place where job/project tracking is surfaced, while the actual commercial documents (nabídky/objednávky/faktury) are owned by the neighbouring Obchod/Fakturace areas per Q2's explicit bullet placement. Per the DATAMIX quote in Q3, CRM does not natively contain orders/delivery notes/invoices — those live in the ERP (economic) side, and third-party tools exist specifically to bridge the two, which is itself evidence CRM does **not** natively own or write those documents; it hands off/surfaces them, per: `"CRM eviduje komunikaci, obchodní případy... ERP... obsahuje objednávky, dodací listy, faktury..."`.

### Q5 — Projects/zakázky: own records or a dimension?
Label: documented (public.helios.eu search-result excerpts, direct fetch of the target page returned 404 this session) + inferred, consistent with the earlier evidence file's PARTLY finding.

Search-indexed public.helios.eu content shows "zakázky" (job/order number) used as a **reference field on other modules' documents** rather than as a document type with its own primary transactions: e.g. wage/cost postings reference a job by number (`"pole, které slouží jako odkaz na zakázky... kde lze zadat číslo zakázky přímo nebo použít přidružený seznam Zakázky"`, from the earlier evidence file's fetch of the Cestovní náhrady page), and issued complaints/travel/bank-connection screens all carry a "Číslo zakázky" field. Combined with the brochure listing "zakázky" under the CRM feature bullets (Q2) rather than under Fakturace, the evidence across both sessions points to **zakázky functioning primarily as a cost/reporting dimension attached to documents owned by other modules** (accounting, travel expenses, wages), while also being a licensed module in its own right per the Helios Red price list. Whether it owns first-class records such as a project budget, milestones, or its own P&L rollup as opposed to just being a tag was **NOT FOUND** in either session — this is the direct evidence-based answer to "is Projects just a dashboard": on the evidence gathered, it behaves like a **dimension/tag over other modules' documents for cost attribution and reporting**, not a module that itself originates sales, invoices, or ledger entries.

### Q6 — Finance/Accounting: what it owns
Label: documented (from the earlier evidence file, cz-erp-tools.md, re-used as background, not re-fetched this session — flagged as carried-over evidence).

Per that earlier fetch of public.helios.eu's Účetní deník (accounting journal) page: `"Účetní deník slouží zejména k pořizování účetních dokladů... V účetním deníku jsou zobrazeny i doklady, které jsou pořízeny automatickým účtováním prvotních dokladů z jiných agend"` (the accounting journal is used primarily to record accounting documents; it also shows documents produced by automatic posting of primary documents from other agendas) and on posting rules: `"Účetní kódy (kontace) slouží v různých modulech ekonomického systému HELIOS iNuvio k označení jednotlivých prvotních dokladů účetním pravidlem, které je následně použito pro zaúčtování prvotního dokladu do účetního deníku v modulu Účetnictví"` (accounting codes/kontace are used across various modules to tag primary documents with a posting rule, subsequently used to post into the accounting-module journal). This is the same shape as Fineract's product→GL mapping (Q3 above): **invoices/orders/POS receipts are "primary documents" (prvotní doklady) owned by their originating module; the Accounting module owns only the chart of accounts and the journal, and derives entries from those primary documents via a shared kontace/posting-rule registry** — Accounting does not itself own invoices or bills as its native record type.

### Q7 — Documents/DMS
**NOT FOUND** as a dedicated module page in pages fetched this session (neither this session nor the earlier evidence file located a standalone Helios DMS/document-management module page). The brochure mentions "evidence pošty a datové schránky" (mail and data-box record-keeping) under CRM, which handles inbound/outbound correspondence and data-box messages, but this is not the same as a generic file-attachment/DMS layer. Gap — flagged as NOT FOUND rather than a confirmed absence, since Helios/Asseco is known in the market to integrate with DMS products (unverified this session).

### Q8 — Contacts: shared master?
Label: documented (public.helios.eu search-result excerpts) + inferred.

Public.helios.eu search-indexed content confirms a single shared **Organizace** register: `"Organizace - Pás karet - Obchodní partneři a CRM"` and `"Organizace - Editor - Obchodní partneři a CRM"` place the register under a combined "Business partners and CRM" area, and search summaries of that content state: "the organization registry ... is used by most modules of the Helios Inuvio system" and "the list is shared for both customers and suppliers, so if your business partner is simultaneously your supplier and customer, they can be managed under a single card" (label: documented via WebFetch summary of the live page, not a direct verbatim quote captured — the tool returned a paraphrase rather than exact source text on the pass fetched this session; treat the quoted English sentences as a close paraphrase, not a verbatim quote, and this is flagged accordingly). The same source area also lists separate **Kontakty** (contacts/communication log entries) and **Kontaktní osoby** (contact persons linked to an organization) as related but distinct registers: attempted verbatim quote from the page, `"Do přehledu zadáváte pouze ty kontaktní osoby, které mají nějaký vztah k organizaci"` (the overview only contains those contact persons who have some relationship to the organization) — this one is a direct extracted quote. **NOT FOUND**: any separate "personal/private" relationship-management register distinct from the shared Organizace/CRM contact model — no evidence of a personal-CRM concept was found in either session.

---

## Summary table

| App | Top-level modules | Sales owner and channels | CRM role | Projects role | Documents module | Shared contacts |
|---|---|---|---|---|---|---|
| Apache Fineract | One deployable platform (`fineract-provider`), built from Gradle modules: `fineract-core`, `-loan`, `-savings`, `-accounting`, `-charge`, `-document`, `-branch`, `-investor`, etc. Not separately sold products. | No sales/quote/order/customer-invoice concept at all. "Sale" analog = loan disbursement / savings deposit on a `Client` account, instantiated from a `Product`; GL entries derived by the `accounting` module from a per-product-and-transaction-type GL mapping (`ProductToGLAccountMapping`), never written by the portfolio module itself. | Not present (NOT FOUND) — no CRM/lead/opportunity model anywhere in the source tree. | Not present (NOT FOUND) — no project/job-costing module; nearest analogs are `Office`(branch) and `Fund`, used as reporting dimensions on transactions. | `fineract-document`: generic `Document`/`Image` records with polymorphic `parentEntityType`/`parentEntityId` link to any other record. | Single shared party master: `Client` (+ `Group`), owned by `fineract-core`, referenced by every portfolio module (loan, savings, shares, client transactions). No personal/private contact concept. |
| HELIOS iNuvio / Orange / Green (Asseco) | Distinct product lines by segment (iNuvio for SME since 2021, succeeding Orange; Green for larger/other orgs); within a line, "Obchod" (Commerce) bundles Sales-process support / POS / CRM / Warehouse+Sales / Extensions / Invoicing as sub-areas, but functional areas (Zakázky, Majetek, POS, etc.) are still separately priced/licensed modules per the vendor price list. | Quotes and orders ("nabídky", "objednávky") owned by "Skladové hospodářství a obchod"; issued/received invoices owned by "Fakturace a pošta"; POS/till sales owned by "Pokladní prodej" with its own automatic posting to takings — three distinct record homes, all separate from CRM. Asset disposals and non-CRM one-off invoicing to unregistered counterparts: NOT FOUND at source-data-model precision this session. | Owns communication log, activities, calendars, contact centre, and "obchodní případy" (deals/business cases) through the presales phase; can prepare price offers as part of a case, but per partner documentation does not natively contain orders/delivery notes/invoices — those live in the ERP/Obchod side; third-party bridges (ADAPTY) exist specifically to surface ERP sales data inside CRM, evidencing separate ownership. | Zakázky ("orders"/jobs) appears mainly as a reference/tag field on other modules' documents (travel, wages, bank, complaints) for cost attribution/reporting, while also being separately licensed; no evidence found of zakázky owning first-class budget/milestone/P&L records of its own — closer to a cost dimension than an independent transactional module. | Not identified as a distinct module in either research session (NOT FOUND); CRM area includes mail/data-box record-keeping, not a generic file-attachment/DMS layer. | Shared **Organizace** register under "Obchodní partneři a CRM," used by most modules, common list for both customers and suppliers (a partner can hold one card as both); separate but linked **Kontakty** (communication log) and **Kontaktní osoby** (contact persons per organization) registers. No personal/private CRM register found. |

