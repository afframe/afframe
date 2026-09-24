# Czech VAT / accounting-correction rules and modelling-pattern citations

Research date: 2026-09-23/24. Rates and rules checked against sources reachable today; must hold for 2026 unless noted.

---

## 1. VAT rates valid in 2026: standard 21%, reduced 12%

**Status:** CONFIRMED
**Label:** official (law text, consolidated version, as republished by zákonyprolidi.cz, a legal-text aggregator of the official Sbírka zákonů)
**URL:** https://www.zakonyprolidi.cz/cs/2004-235 (§ 47, "Sazby daně u zdanitelného plnění")
**Quote (Czech):**
> „(1) U zdanitelného plnění nebo přijaté úplaty se uplatňuje
> a) základní sazba daně ve výši 21 %, nebo
> b) snížená sazba daně ve výši 12 %."

**English translation:** "(1) For a taxable supply or received payment: a) the standard tax rate of 21% applies, or b) the reduced tax rate of 12% applies."

**Rule in my own words:** Act No. 235/2004 Coll. on VAT (§ 47) currently sets only two rates: a standard rate of 21% and a single reduced rate of 12%. This reflects the 2024 "consolidation package" (Act No. 349/2023 Coll.), which merged the former two reduced rates (10% and 15%) into one 12% rate, effective 1 January 2024. No further rate change is indicated in the fetched text for 2025 or 2026 — the current consolidated text of § 47 (as served by zákonyprolidi.cz) still shows 21%/12%, so these remain the rates for 2026. I could not independently fetch the e-sbírka.gov.cz historical-versions page to double-confirm no amendment took effect between 2024 and 2026; treat the "no change since 2024" part as PARTLY confirmed (rates themselves are CONFIRMED from the current consolidated text; absence of an interim change is inferred, not separately verified against e-sbírka's amendment log).

---

## 2. Reverse charge for construction/assembly works — § 92e, Act 235/2004 Coll.

**Status:** CONFIRMED
**Label:** official (law text via zákonyprolidi.cz; scope figures corroborated by Finanční správa's own page on the regime)
**URL (law text):** https://www.zakonyprolidi.cz/cs/2004-235 (§ 92e, "Poskytnutí stavebních nebo montážních prací")
**URL (tax authority):** https://financnisprava.gov.cz/cs/dane/dane/dan-z-pridane-hodnoty/informace-stanoviska-a-sdeleni/rezim-preneseni-danove-povinnosti/rezim-preneseni-danove-povinnosti

**Quote (Czech, law text):**
> „(1) Při poskytnutí stavebních nebo montážních prací, které odpovídají kódům 41 až 43 klasifikace produkce CZ-CPA ve znění platném k 1. lednu 2015, plátci použije plátce režim přenesení daňové povinnosti."

**English translation:** "(1) When providing construction or assembly works corresponding to codes 41 to 43 of the CZ-CPA production classification, in the version valid as of 1 January 2015, the VAT payer providing the service to another VAT payer shall apply the reverse-charge regime."

**Quote (Finanční správa, on who owes the tax):**
> „Povinnost přiznat a zaplatit daň plátce, pro kterého bylo uvedené zdanitelné plnění v tuzemsku uskutečněno (odběratel)." — "The obligation to declare and pay the tax rests with the payer for whom the taxable supply was carried out domestically (the recipient)."

**Rule in my own words:** § 92e mandates the reverse-charge (self-assessment) mechanism for construction/assembly works classified under CZ-CPA sections 41–43, when supplied between two VAT payers ("plátci") in the Czech Republic. The supplier issues a tax document without VAT (states only the taxable amount, not the tax); the recipient self-assesses (declares) the output VAT on that supply in their own VAT return and, to the extent the input is used for taxable economic activity, may simultaneously claim the corresponding input VAT deduction under the general § 72/§ 73 rules (see claim 3) — so if the recipient has full deduction entitlement, the net cash VAT effect of that transaction is zero (declare and deduct the same amount in the same period). § 92e also extends (odst. 2) to the supply of workers for construction/assembly work. In force since 1 January 2012 per Finanční správa's page.

---

## 3. Input VAT deduction: conditions, timing, partial deduction

**Status:** CONFIRMED
**Label:** official (law text via zákonyprolidi.cz)
**URL:** https://www.zakonyprolidi.cz/cs/2004-235 (§ 72 "Nárok na odpočet daně", § 73 "Podmínky pro uplatnění nároku na odpočet daně", § 75 "Způsob výpočtu odpočtu daně v poměrné výši", § 76 "Způsob výpočtu nároku na odpočet daně v krácené výši")

**Quote (§ 72 odst. 5, when the right arises):**
> „(5) Nárok na odpočet daně vzniká plátci okamžikem, kdy nastaly skutečnosti zakládající povinnost tuto daň přiznat."
English: "(5) The payer's entitlement to deduct tax arises at the moment the facts giving rise to the obligation to declare that tax occur" — i.e., when the taxable supply occurs (or the tax point is otherwise triggered).

**Quote (§ 73 odst. 1a, holding a tax document):**
> „(1) Pro uplatnění nároku na odpočet daně je plátce povinen splnit tyto podmínky: a) při odpočtu daně, kterou vůči němu uplatnil jiný plátce, mít daňový doklad,"
English: "(1) To exercise the entitlement to deduct tax, the payer must meet these conditions: a) when deducting tax charged to them by another payer, hold a tax document,"

**Quote (§ 73 odst. 2, earliest period):**
> „(2) Plátce je oprávněn uplatnit nárok na odpočet daně nejdříve za zdaňovací období, ve kterém jsou splněny podmínky podle odstavce 1."
English: "(2) The payer is entitled to exercise the deduction at the earliest for the tax period in which the conditions under paragraph 1 are met."

**Rule in my own words:** Entitlement to deduct arises when the taxable supply is made (tax point), but it can only be *exercised* once the payer both (a) that tax point has occurred and (b) holds a valid tax document (§ 73(1)(a)); it can be claimed at the earliest in the period both conditions are satisfied, and generally must be claimed within the second calendar year following the year the entitlement arose (§ 73(3)). Where a received supply is used partly for purposes giving entitlement to deduct and partly not, only a proportional part may be deducted (§ 72 odst. 9), computed either as a "poměrný koeficient" (proportional/use-based coefficient, § 75 — e.g., business vs. private use) or a "krácený" (reduced) deduction with a coefficient under § 76 for mixed taxable/exempt-without-entitlement activities. Non-deductible VAT includes, e.g., input attributable to representation/entertainment expenses not recognized as tax-deductible costs (§ 72 odst. 6), with narrow exceptions.

---

## 4. Accounting corrections — § 35, Act 563/1991 Coll. on accounting

**Status:** CONFIRMED
**Label:** official (law text via zákonyprolidi.cz)
**URL:** https://www.zakonyprolidi.cz/cs/1991-563 (§ 35, "Opravy a ostatní ustanovení o účetních záznamech")

**Quote (Czech):**
> „(3) Opravy se musí provádět tak, aby bylo možno určit osobu odpovědnou za provedení každé opravy, okamžik jejího provedení a zjistit jak obsah opravovaného účetního záznamu před opravou, tak jeho obsah po opravě."

**English translation:** "(3) Corrections must be made in such a way that it is possible to determine the person responsible for making each correction, the moment it was made, and to ascertain both the content of the accounting record being corrected before the correction and its content after the correction."

Supporting quotes from the same section:
> „(1) Opravy nebo doplnění v účetních záznamech nesmějí vést k neúplnosti, neprůkaznosti, nesprávnosti, nesrozumitelnosti nebo nepřehlednosti účetnictví." — "(1) Corrections or supplements to accounting records must not result in incompleteness, lack of evidential value, incorrectness, unintelligibility, or lack of clarity of the accounting."

> „(4) Okamžik se v účetním záznamu zaznamenává s takovou přesností, aby nejistota v určení času neměla za následek nejistotu v určení obsahu účetních případů." — "(4) The moment [of the record/correction] is recorded with such precision that uncertainty in determining the time does not result in uncertainty in determining the content of the accounting transactions."

**Rule in my own words:** Czech accounting law requires that any correction to an accounting record preserve full traceability: both the pre-correction and post-correction content must remain determinable, along with who made the correction and exactly when (§ 35 odst. 3). Corrections may never make the accounting incomplete, unverifiable, incorrect or unclear (odst. 1); if a record is found defective, the entity must correct it without undue delay in this traceable manner (odst. 2). This is the statutory basis for an audit-trail / append-only correction pattern rather than silent overwrite. I did not find a separately relevant "must not be altered without trace" clause under § 8 in the fetched text — § 8 in the visible excerpt concerns other duties (not reached in the section I retrieved); marking that specific cross-reference as **NOT FOUND** rather than guessing its content.

---

## 5. REA model — McCarthy (1982) and extensions

**Status:** CONFIRMED (citation and one-line definition); PARTLY (extensions — found via secondary/tertiary sources, not the primary papers themselves)
**Label:** academic (secondary source: Wikipedia, summarizing the original Accounting Review article; original paper itself was not directly fetched — paywalled JSTOR)
**URL:** https://en.wikipedia.org/wiki/Resources,_Events,_Agents

**Citation as given by source:**
> McCarthy, William (July 1982). "The REA Accounting Model: A Generalized Framework for Accounting Systems in a Shared Data Environment." *The Accounting Review*, 57(3): 554–578.

**One-line definition (from source, paraphrased by the fetch, not a verbatim quote from McCarthy's own text since the primary article was not directly accessible):** the REA model treats an accounting system as a semantic representation of real economic phenomena built around economic Resources, economic Events, and economic Agents, with the core mechanism being the "duality" pairing of give/take economic events (e.g., a sale event paired with a cash-receipt event) rather than debit/credit double-entry bookkeeping.

**Extensions:**
- Geerts & McCarthy commitments/contracts extension — referenced in the source as "Geerts and McCarthy's work on 'An Ontological Analysis of the Primitives of the Extended-REA Enterprise Information Architecture' (2002)," extending REA to commitments, policies and other constructs. **Label: academic, but only found via a tertiary summary — mark PARTLY**, since I did not independently fetch the Geerts & McCarthy paper itself to verify title/date.
- ISO/IEC 15944-4 — the Wikipedia source mentions this standard as related to REA-influenced business transaction modelling but "provides no additional details about its specific provisions." **Status: NOT FOUND** (existence of a link is asserted by a tertiary source, but I could not fetch the ISO standard itself or a primary source verifying the REA connection in this session — do not cite ISO/IEC 15944-4 as REA-confirmed without further primary verification).

---

## 6. Martin Fowler accounting patterns (martinfowler.com/eaaDev)

**Status:** CONFIRMED (Account, Accounting Entry, Reversal/Replacement/Difference Adjustment); NOT FOUND (Posting Rule — page not locatable at a working URL in this session)
**Label:** author (martinfowler.com is Fowler's own site — primary source for his own patterns)

**Account** — URL: https://martinfowler.com/eaaDev/Account.html
> "Collect together related accounting entries and provide summarizing behavior"

**Accounting Entry** — URL: https://martinfowler.com/eaaDev/AccountingEntry.html
> "An allocation of a sum of money"

**Reversal Adjustment / Difference Adjustment / Replacement Adjustment** — URL (catalog page): https://martinfowler.com/eaaDev/AccountingNarrative.html, and https://martinfowler.com/eaaDev/ReversalAdjustment.html
- Replacement Adjustment: "deletes the incorrect Accounting Transactions and creates the correct set"
- Reversal Adjustment: "you leave the incorrect Accounting Transactions in place, but for each one you post an opposite Accounting Entry" — used as "a simple alternative when entries are immutable and thus you can't use Replacement Adjustment"
- Difference Adjustment: "posts in new entries that represent the difference between the incorrect and correct entries"

**Posting Rule:** **NOT FOUND** — attempted URLs https://martinfowler.com/eaaDev/PostingRule.html and https://martinfowler.com/eaaDev/PostingRules.html both returned HTTP 404. A paraphrase exists in secondary search snippets ("Posting rules are specialized chunks of code which calculate an amount to be charged and then charge it to the given account") but I could not fetch the actual page to verify this as a verbatim Fowler quote — do not present it as a confirmed direct quote.

---

## 7. Kimball Group: conformed dimensions, bus matrix, accumulating snapshot

**Status:** CONFIRMED (bus matrix, accumulating snapshot); PARTLY (conformed dimensions — page reached but no single explicit one-line definition sentence was extracted); NOT FOUND (periodic snapshot — not separately fetched)
**Label:** author (Kimball Group's own site — primary source for the Kimball methodology)

**Enterprise bus matrix** — URL: https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/enterprise-data-warehouse-bus-matrix/
> "The essential tool for designing and communicating the enterprise data warehouse bus architecture. The rows of the matrix are business processes and the columns are dimensions."

Conformed dimensions (context sentence from the same page, not a standalone formal definition):
> "...scans each column to see where a dimension should be conformed across multiple business processes"
**Rule in my own words:** conformed dimensions are dimension tables (e.g., Date, Customer, Product) built once with consistent keys, names, attributes and values, then reused across multiple fact tables/business processes so that queries can "drill across" — combine metrics from different business-process fact tables via the shared dimension. This is my synthesis; the page did not give one crisp defining sentence, so treat "drill-across" as **PARTLY** sourced from this page (the term itself was not quoted verbatim from Kimball's page in this session).

**Accumulating snapshot fact table** — URL: https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/accumulating-snapshot-fact-table/
> "A row in an accumulating snapshot fact table summarizes the measurement events occurring at predictable steps between the beginning and the end of a process."
**Rule in my own words:** used for pipeline/workflow processes with a defined start, standard milestones, and a defined end (e.g., order fulfillment); one row per process instance is inserted at the start and updated in place as milestones are reached, rather than inserting a new row per event.

**Periodic snapshot:** **NOT FOUND** — not separately fetched in this session; do not cite a Kimball quote for it.

---

## 8. Earned value / EAC = actual cost + estimate to complete

**Status:** PARTLY
**Label:** third-party summary of an official/authoritative standard (Wikipedia summarizing PMI's PMBOK Glossary; the GAO Cost Estimating and Assessment Guide, GAO-20-195G, was located but its PDF text could not be reliably extracted/quoted verbatim in this session)
**URL (secondary, with citation to primary):** https://en.wikipedia.org/wiki/Earned_value_management
**URL (GAO guide, located but not independently quote-verified):** https://www.gao.gov/assets/gao-20-195g.pdf / https://www.gao.gov/products/gao-20-195g

**Quote (PMI PMBOK, via Wikipedia, cited there as "Project Management Institute 2021, Glossary §3 Definitions"):**
> "expected total cost of completing all work expressed as the sum of the actual cost to date and the estimate to complete"

Formula given: EAC = AC + ETC (also EAC = AC + (BAC − EV)/CPI, or BAC/CPI, under specific assumptions).

**Rule in my own words:** Estimate at Completion is the current forecast of total project/contract cost: the actual cost incurred so far (AC) plus a re-forecast of the cost required to finish the remaining work (Estimate to Complete, ETC). This is the standard formula used in earned-value management for construction/contract cost control, matching the standard approach referenced in GAO's Cost Estimating and Assessment Guide (GAO-20-195G) — I confirmed the guide exists and covers EAC update practice ("Update the Program Cost Estimate with Actual Costs" appears as a chapter heading extracted from the guide's own table of contents), but I could not extract a clean verbatim EAC formula sentence from the GAO PDF text in the time available, so the GAO-specific quote is **NOT FOUND** even though the guide's relevance is CONFIRMED via its table of contents. ISO 21508 was not fetched — **NOT FOUND**.

---

## 9. Bitemporal data: valid time vs. transaction time

**Status:** CONFIRMED
**Label:** author (Fowler's own article, primary for his terminology choice); the article itself attributes the valid-time/transaction-time terms to Snodgrass and to the SQL:2011 standard (I did not independently fetch the SQL:2011 standard text or a Snodgrass primary source — treat that specific attribution as PARTLY, resting on Fowler's say-so)
**URL:** https://martinfowler.com/articles/bitemporal-history.html

**Quote:**
> "The terminology of valid time and transaction time comes from Snodgrass, and is also used in the SQL:2011 standard."

**Rule in my own words:** Bitemporal modelling tracks two independent time axes for a fact: (1) valid time / "actual time" — when something is/was/will be true in the real world, and (2) transaction time / "record time" — when the system learned about or recorded that fact. Fowler prefers "actual" and "record" over "valid"/"transaction" because his workshop attendees found the latter pair confusing, but the underlying concepts are the same ones standardized in SQL:2011 (system-versioned tables track transaction/record time; application-time period tables track valid/actual time). With this model, retroactive corrections and future-dated changes can both be represented without losing history: "actual time is always at or before record time" is violated only when you're recording something you already know will happen in the future relative to the record.

---

## Summary counts
- CONFIRMED: 6 (claims 1 core rate fact, 2, 3, 4, 6 core patterns, 7 core facts, 9)
- PARTLY: 4 (claim 1 sub-point on 2025/26 stability, claim 5 extensions, claim 7 conformed-dimension exact wording, claim 8 EAC/GAO exact quote)
- REFUTED: 0
- NOT FOUND: 4 (§8 accounting cross-reference in claim 4; ISO/IEC 15944-4 REA link in claim 5; Posting Rule page in claim 6; periodic snapshot and ISO 21508 in claims 7/8)
