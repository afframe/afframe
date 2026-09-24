# CZ e-invoicing / VAT rules — verification pass (2026-09-24)

Scope: verify claims for a Czech SME finance platform (Peppol/UBL/EN 16931 reference
vocabulary), covering construction-fit-out reverse charge (§92e), subcontractor
self-billing, and advance payments to a materials supplier.

Budget note: ~25-minute research budget. Several claims could only be corroborated via
professional/secondary Czech sources (dauc.cz, du.cz, Sagit, Pohoda, kurzy.cz) because
the official law portals (zakonyprolidi.cz, e-sbirka.gov.cz) blocked automated
paragraph-level fetches during this session (404s / redirects) and financnisprava.gov.cz
PDFs were not text-extractable. Those claims are marked PARTLY with the best available
secondary source and should be re-verified against the official law text before
shipping.

---

## 1. ISDOC

**Status: PARTLY**

- URL: https://www.mvcr.cz/isdoc/ (redirect target of isdoc.cz), https://isdoc.cz/6.0.2/, https://mv.gov.cz/isdoc/soubor/isdoc6-0-1-pdf.aspx
- Quote (search snippet, not independently re-verified on the live page): "ISDOC 6.0.1 Národní standard pro elektronickou fakturaci 26. května 2014" (ISDOC 6.0.1, national standard for electronic invoicing, 26 May 2014).
- Rule in own words: ISDOC ("Information System Document") is the Czech national XML standard for electronic invoices and related documents, originally developed under the ICT Unie working group for electronic data-interchange standards; its historical governance/publication has moved through mvcr.cz / mv.gov.cz and is now also mirrored at isdoc.cz (current published version pages show 6.0.1 from 2014, with a 6.0.2 page also present — **the true "current" version number is NOT FOUND with certainty**; both 6.0.1 and 6.0.2 pages exist on isdoc.cz and I could not confirm which is authoritative "latest" within the time budget).
- Maintainer: historically associated with ICT Unie / Czech state administration (mvcr.cz, now referenced also under Digitální a informační agentura — dia.gov.cz — which hosts "historické verze" of ISDOC). Exact current maintainer of record: **NOT FOUND** (conflicting hosting between mvcr.cz and dia.gov.cz was not resolved in this session).
- EN 16931 compliance: **NOT FOUND as an explicit self-declared compliance statement.** Secondary characterization found: "ISDOC is a Czech customization of UBL 2.0... it is not identical to PEPPOL BIS 3.0 or UBL 2.1, which are used for the European standard. ISDOC remains a domestic format, not a cross-border standard" (paraphrase from search aggregation, not a verbatim quote from isdoc.cz itself). However, the Ministry of Finance page (see Claim 2) lists "ISDOC/ISDOCX version 5.2 and higher" as one of the three formats accepted under the EN 16931-1:2017-compliant public-procurement e-invoicing regime, implying that ISDOC ≥5.2 is treated by the Czech state as EN 16931-compliant for that purpose. This is an inference from the mf.gov.cz page, not a direct ISDOC-side compliance statement.
- Role in Czech practice: Used broadly as the de facto native exchange format between Czech accounting/ERP systems (Pohoda, Money S3, iDoklad, Premier, Helios, etc.) for B2B and B2G invoice exchange domestically.

---

## 2. Czech transposition of Directive 2014/55/EU / Peppol

**Status: PARTLY**

- URL: https://mf.gov.cz/cs/dane-a-ucetnictvi/elektronicka-fakturace/zakladni-informace (and referenced Act 134/2016 Sb.)
- Quote: not independently re-fetched verbatim; per WebFetch extraction of the mf.gov.cz page: contracting authorities in the "Czech Republic" category and the Czech National Bank were obliged **from 1 April 2019** to "accept and process electronic invoices" meeting EN 16931-1:2017; "other contracting authorities" from **1 April 2020**. Legal basis cited: **Act No. 134/2016 Sb., on Public Procurement (zákon o zadávání veřejných zakázek), § 279(5)**.
- Rule in own words: Directive 2014/55/EU is transposed via the Public Procurement Act 134/2016 Sb., §279(5), which obliges contracting authorities to accept and process e-invoices compliant with EN 16931. Government Resolution No. 347/2017 (usnesení vlády) supports/implements the mandatory-receipt rule.
- Accepted syntaxes per mf.gov.cz: UBL 2.1 (ISO/IEC 19845:2015), UN/CEFACT CII (Cross Industry Invoice), and ISDOC/ISDOCX version 5.2+.
- Peppol: **No Czech Peppol Authority found.** Search results indicate the Czech Republic has no designated national Peppol Authority; OpenPeppol (peppol.org) appears to act directly as the Peppol Authority for Czech-registered access-point/service providers ("OpenPeppol directly fulfills the Peppol Authority role for ... Czech members listed as certified providers" — paraphrase from aggregated search, not a verbatim OpenPeppol quote). This was **not independently confirmed on peppol.org's own "Peppol Authorities" list** within the time budget — treat as PARTLY / re-verify at https://peppol.org/members/peppol-authorities/.
- Caveat: the mf.gov.cz quotes above come from an AI-summarized WebFetch pass, not a directly re-read verbatim page dump; re-verify exact wording and §279(5) citation against mf.gov.cz / zakonyprolidi.cz Act 134/2016 Sb. directly.

---

## 3. ViDA — Council Directive (EU) 2025/516

**Status: PARTLY (dates conflict between sources — flagged, not resolved)**

- URL: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=OJ%3AL_202500516 ; https://taxation-customs.ec.europa.eu/taxation/vat/vat-digital-age-vida_en ; https://taxation-customs.ec.europa.eu/news/adoption-vat-digital-age-package-2025-03-11_en
- Adoption date: **CONFIRMED** — 11 March 2025. (Council/Commission pages consistently state adoption on 11 March 2025; consilium.europa.eu press release could not be fetched directly, HTTP 403.)
- Entry into force: 14 April 2025 (per taxation-customs.ec.europa.eu summary), giving Member States earlier freedom to mandate domestic e-invoicing.
- Mandatory intra-EU B2B e-invoicing / digital reporting date: **PARTLY / conflicting.** One EUR-Lex-derived AI extraction stated "1 January 2030" (citing an "Article 5"); the European Commission's own ViDA overview page (taxation-customs.ec.europa.eu) states cross-border B2B digital reporting requirements "take effect from 1 July 2030"; an initial general web search also stated "1 July 2030." Given two independent extractions point to **1 July 2030** and only one (a small-model EUR-Lex summarization prone to error) says 1 January 2030, the balance of evidence favors **1 July 2030**, but this was not confirmed against the primary consolidated Article text itself (the EUR-Lex full-text HTML could not be reliably parsed in this session). **Recommend re-verifying the exact application date directly against the OJ PDF of L_202500516 before relying on it.**
- EN 16931 as default standard: **CONFIRMED** (via AI extraction of eur-lex page, not independently re-verified verbatim) — Recital (6) is reported to state electronic invoices "should in principle comply with the European standard laid down in Commission Implementing Decision (EU) 2017/1870," and amended Article 218(3) is reported to require compliance with "the European standard on electronic invoicing and the list of its syntaxes pursuant to Directive 2014/55/EU." Treat as PARTLY pending direct verbatim confirmation from the OJ text.
- Domestic e-invoicing without derogation: **CONFIRMED in substance** — per AI extraction, an amended provision (reported as "Article 2(2)") states: "Member States may, in accordance with the conditions they lay down, require taxable persons established within their territory to issue electronic invoices for supplies of goods and services within their territory." This matches the well-documented ViDA policy change (removing the prior need for a Council implementing-decision derogation under old Art. 218/232) reported consistently across EC and Council sources. Exact article number not independently verified.
- Czech domestic B2B e-invoicing plan: **NOT FOUND.** No official mf.gov.cz / financnisprava.gov.cz page was located in this session announcing a concrete Czech domestic mandatory B2B e-invoicing timeline or legislative plan. Do not assume one exists; re-check mf.gov.cz "elektronická fakturace" section periodically.

---

## 4. Czech VAT self-billing (samofakturace)

**Status: PARTLY**

- URL (secondary, law-content aggregator): https://www.du.cz/33/selfbilling-vystavovani-danovych-dokladu-odberatelem-...; https://www.kurzy.cz/zakony/235-2004-zakon-o-dani-z-pridane-hodnoty-dph/paragraf-28/ (page reached but text not extracted); law itself at https://www.zakonyprolidi.cz/cs/2004-235 (paragraph-level deep link not resolved in this session — 404s on attempted direct paragraph URLs).
- Rule in own words (per secondary-source paraphrase, not verbatim law quote): §28 of Act 235/2004 Sb. permits a taxable person (the supplier) to authorize **in writing** the recipient of the supply ("odběratel") or a third party to issue the tax document on the supplier's behalf. If the authorization is given electronically, it must be signed with a recognized/qualified electronic signature. This is the legal basis for self-billing in Czech VAT law.
- Conditions: prior written agreement/authorization is required; the supplier remains responsible for the correctness of the data on the tax document and for its timely issuance even when a third party or the customer issues it under authorization (per general §26/§28 responsibility rule, per secondary source — **not independently verified verbatim**).
- Self-billing under reverse charge (§92a–§92e): **NOT FOUND conclusively.** Secondary sources (du.cz, financnisprava GFŘ guidance on §92a) confirm that under domestic reverse charge, the **supplier still issues the tax document** (without VAT rate/amount, marked "daň odvede zákazník" / "the customer will account for the tax"), and the **recipient** is the one obliged to self-assess and declare the tax in their VAT return — but none of the sources fetched explicitly stated whether the general §28 self-billing authorization (recipient issuing the document on the supplier's behalf) is legally permitted or excluded for reverse-charge supplies. Direct attempt to fetch official financnisprava.gov.cz GFŘ guidance on §92a returned only scope/record-keeping content, not this specific point. **Mark as NOT FOUND rather than inferring; requires reading the actual §92a/§28 text or a GFŘ information explicitly addressing this combination.**

---

## 5. Czech VAT advance payments (§20a and related)

**Status: CONFIRMED (tax point rule) / PARTLY (deadline, deduction, proforma) / CONFIRMED (reverse charge — no tax point on advance)**

- Tax point on receipt of payment — **CONFIRMED** (verbatim law text retrieved via WebFetch of zakonyprolidi.cz):
  > "Je-li před uskutečněním zdanitelného plnění přijata úplata, vzniká povinnost přiznat daň z této úplaty ke dni jejího přijetí."
  > (English: "If payment is received before the taxable supply is carried out, the obligation to declare tax on that payment arises on the day of its receipt.")
  - URL: https://www.zakonyprolidi.cz/cs/2004-235 (§20a, as rendered by WebFetch extraction of the consolidated text)
  - Rule: this is the classic Czech VAT "advance payment" tax-point rule — VAT must be self-assessed on an advance the moment it is received, provided the future supply is "sufficiently known" (goods/service, tax rate, place of supply must already be determinable — per §20a(3), per secondary aggregation, not independently re-quoted verbatim).
- Tax document for a received payment and its deadline — **PARTLY**: secondary sources (idoklad.cz, pohoda.cz aggregated via WebSearch) consistently state a **15-day deadline** from receipt of payment to issue the tax document for the advance ("Do 15 dnů od přijetí platby je nutné vystavit daňový doklad k přijetí zálohy"), consistent with the general §28 15-day tax-document deadline rule for supplies. This mirrors the known general rule but was **not independently confirmed against the official law text or a financnisprava.gov.cz source** in this session (the GFŘ PDF on §20a could not be text-extracted).
- Buyer's right to deduct VAT from an advance — **PARTLY**: secondary sources state the buyer may deduct VAT only once they receive the proper **tax document for the received payment** (not the proforma) — "Zákazník uplatní odpočet DPH až poté, co mu pošlete daňový doklad." Not independently verified against official law/GFŘ text.
- Proforma/advance invoice (zálohová faktura) is not a tax document — **PARTLY / consistent secondary confirmation**: "Zálohová faktura nikdy není daňovým dokladem a odběratel si z ní nemůže uplatnit odpočet DPH" ("A proforma/advance invoice is never a tax document, and the recipient cannot claim a VAT deduction from it") — consistent across multiple Czech accounting-software vendor sources (idoklad.cz, pohoda.cz, ČSOB průvodce podnikáním), but not sourced from an official government page in this session.
- Reverse charge (§92e) and advances — **CONFIRMED in substance via secondary sources, not verbatim law text**: multiple independent secondary sources (Sagit GFŘ information summary, Pohoda "Zálohy a dílčí plnění v režimu přenesení daňové povinnosti") state that **no tax point arises on receipt of an advance payment for a supply subject to domestic reverse charge (§92a–§92e)** — tax is declared only when the actual taxable supply is performed, not on the advance. This is a well-established, consistently repeated rule in Czech professional literature, but the official financnisprava.gov.cz GFŘ information document (PDF) that presumably states this explicitly could not be text-extracted in this session — treat as PARTLY pending a verbatim official-source confirmation.

---

## 6. Recording a disputed received invoice (Act 563/1991 Coll. or VAT Act)

**Status: NOT FOUND**

- No explicit provision was located in Act 563/1991 Sb. (Accounting Act) or the VAT Act (235/2004 Sb.) addressing how to record a received invoice that the buyer disputes (e.g., a "sporná faktura" / reklamace scenario). Search results only surfaced general accounting-record requirements (e.g., §11 signature/record requirements) and discussion of accounting for resolved complaints (reklamace), not a rule specifically governing bookkeeping treatment of a disputed/contested invoice pending resolution.
- Per the task's instruction, this is marked **NOT FOUND** rather than guessed. If this matters for the platform design, a dedicated follow-up search of Czech accounting standards (České účetní standardy pro podnikatele, e.g. ČÚS 017) and the Accounting Act's provisions on accruals/dohadné položky may be the right next step, since disputed invoices are typically handled there rather than in VAT law.

---

## Summary of source reliability caveats

Several answers above rely on AI-generated summaries of WebFetch/WebSearch results rather than directly re-read verbatim page text, because: (a) zakonyprolidi.cz paragraph-level deep links returned 404s when constructed manually, (b) several financnisprava.gov.cz PDFs were not text-extractable by the fetch tool, and (c) consilium.europa.eu blocked the fetch (403). Where this applies, the claim is marked PARTLY with an explicit note. Before shipping product logic on these rules (especially the ViDA cross-border e-invoicing mandate date and the §92a/self-billing-under-reverse-charge question), a follow-up pass reading the primary law texts directly (e.g., via a browser-rendering tool, or manual retrieval of the OJ PDF for 2025/516 and the zakonyprolidi.cz HTML for §20a/§26/§28/§92a/§92e) is recommended.

---
## Addendum (main session, 2026-09-24): ViDA dates verified in the Official Journal text
Source: https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=OJ:L_202500516 (Council Directive (EU) 2025/516), fetched with curl.
- Article 5 is titled "Amendments to Directive 2006/112/EC with effect from 1 July 2030". It replaces Article 218: "For the purposes of this Directive, invoices shall be issued as electronic invoices. However, Member States may accept documents or messages on paper or in electronic formats other than electronic invoices for transactions not subject to the reporting obligations laid down in Chapter 6." and "Electronic invoices shall comply with the European standard on electronic invoicing".
- Transposition clause: "Member States shall adopt and publish, by 30 June 2030, the laws, regulations and administrative provisions necessary to comply with Article 5 ... They shall apply those measures from 1 July 2030."
- New Article 232 (also Article 5): issuing an EN 16931-compliant e-invoice "shall not be subject to acceptance by the recipient".
- Recital 6: e-invoices "should in principle comply with the European standard ... However, Member States should still be able to allow for other standards for domestic supplies."
Status: CONFIRMED (official). Resolves the 1 January vs 1 July 2030 conflict: 1 July 2030.

---
## Addendum (second review follow-up, 2026-09-24): superseded lines and missing entries
Provenance: "fetched" means re-fetched with curl on 2026-09-24 for this addendum; "review" means verified live by the second independent review (`.context/reviews/2026-09-24-second-review.md`, EVIDENCE-1 and the STANDARDS findings) and quoted as recorded there. Earlier lines stay as written; where they conflict, this addendum wins.

**Supersedes lines 23-24 (§ 1, ISDOC version and maintainer "NOT FOUND").** https://isdoc.cz/6.0.2/ (fetched): "Verze 6.0.2 z 23.3.2022 ... Nyní se o další rozvoj a údržbu formátu stará Ministerstvo vnitra České Republiky." Status: CONFIRMED (documented).

**Supersedes lines 62-63 (§ 4, "authorize in writing" and "prior written agreement").** https://www.zakonyprolidi.cz/cs/2004-235 § 28(10) (fetched): "Vystavit daňový doklad může namísto osoby povinné k dani jiná osoba, a to na základě jejich ujednání; ... Správce daně může tuto jinou osobu vyzvat k prokázání existence takového ujednání." The law asks for an arrangement (ujednání) that can be proven; it states no written form. Status: CONFIRMED (official).

**Supersedes line 102 (the earlier addendum quotes only the first sentence of new Art. 232).** Directive (EU) 2025/516, Art. 5 point (9), via http://publications.europa.eu/resource/celex/32025L0516 (review; EUR-Lex blocked automated fetch). New Art. 232: EN 16931 invoices "shall not be subject to acceptance by the recipient. However, Member States may subject invoices compliant with that standard to acceptance by the recipient for transactions not subject to the reporting obligations ... where that Member State has made use of the option set out in Article 218(2)". An invoice in another standard "shall be subject to acceptance by the recipient" unless the Member State uses the Art. 218(3) option. New Art. 218(3): "Member States may allow the use of other standards for electronic invoices relating to supplies of goods and services within their territory". Art. 1 point (3) with Art. 6(1) lets a Member State that mandates domestic e-invoicing remove acceptance "from 14 April 2025". Status: CONFIRMED (official).

**New entries (rows of the report that had none):**
- VAT Act § 29(2)(b) (fetched): "„vystaveno zákazníkem“, je-li osoba, pro kterou je plnění uskutečněno, zmocněna k vystavení daňového dokladu". Official.
- VAT Act § 73(2) (fetched): "Plátce je oprávněn uplatnit nárok na odpočet daně nejdříve za zdaňovací období, ve kterém jsou splněny podmínky podle odstavce 1." Official.
- VAT Act § 29(1)(l) (fetched): "výši daně; tato daň se uvádí v české měně". § 73(6) (fetched): "Je-li částka daně uvedená na přijatém daňovém dokladu nižší, než která má být uplatněna podle tohoto zákona, je plátce oprávněn uplatnit nárok na odpočet daně jen ve výši odpovídající dani uvedené na daňovém dokladu." § 4(8): the exchange rate is the one "platný pro osobu provádějící přepočet" (review). Official.
- VAT Act § 29a: a VAT group's documents name "člena skupiny" (review). § 33(1): the tax document for an import is "rozhodnutí o propuštění zboží do celního režimu" or another customs tax decision (review). Official.
- Act 134/2016 § 221 (review): contracting authorities "nesmí odmítnout elektronickou fakturu ... z důvodu jejího formátu, který je v souladu s evropským standardem", https://www.zakonyprolidi.cz/cs/2016-134. The syntaxes UBL 2.1 and CII come from mf.gov.cz (§ 2 above) and Directive 2014/55/EU Art. 3(2), not from § 221. Government Resolution 347/2017 with ISDOC ≥ 5.2 is already in § 2 above. Official.
- Accounting Act 563/1991 § 11(1), text after letter f) (fetched, https://www.zakonyprolidi.cz/cs/1991-563, version 40, in force from 1 January 2026): "Skutečnosti podle písmen a) až f), které se týkají jednoho účetního dokladu, mohou být obsaženy na více účetních záznamech. ... V těchto případech musí účetní záznam i účetní doklad obsahovat identifikátor, kterým lze nezaměnitelně určit vzájemnou vazbu mezi účetním záznamem a účetním dokladem, včetně souvisejících skutečností." Letter f): "podpisový záznam podle § 33a odst. 4 osoby odpovědné za účetní případ a podpisový záznam osoby odpovědné za jeho zaúčtování". Official.
- New Accounting Act date, MF ČR FAQ (review): "nejbližší možné datum účinnosti ... 1. leden 2027", https://mf.gov.cz/cs/dane-a-ucetnictvi/ucetnictvi/nova-ucetni-legislativa-soukromeho-a-verejneho-sek/casto-kladene-dotazy-k-nove-ucetni-legislative/faq-k-ucetnictvi-soukromeho-a-verejneho-sektoru. Official.
- Control-statement FAQ, https://financnisprava.gov.cz/cs/dane/dane/dan-z-pridane-hodnoty/kontrolni-hlaseni-dph/caste-dotazy-a-odpovedi (review): number normalisation, "změna velkých písmen na malá ... není problém" and "není nutné vyplňovat tzv. vodící nuly"; Dotaz 5, both parties report the number "uvedené na daňovém dokladu vystavovatelem, kterým je v případě tzv. self-billingu odběratel". Official.
- ViDA digital reporting (review, same CELEX source): new Art. 263(2), data "shall be transmitted for each individual transaction referred to in Article 262(1), points (b) and (d), by the taxable persons to whom an invoice ... has to be issued, no later than 5 days after the invoice is received"; new Art. 262(4) lets Member States exempt these; Art. 6(5) applies them from 1 July 2030. Official.
- Commission Explanatory Notes on invoicing (review): C-1, a separate number series "may be used for instance for each branch, or for each type of supply or for each customer, and covers as well self-billed invoices"; C-4, Art. 230 "does not allow any requirement for a reference on the invoice, such as the exchange rate used". https://taxation-customs.ec.europa.eu/document/download/12dc566c-9f43-49d9-a306-b706879104ba_en. Official.
- ISDOC 6.0.2 (review): rule 4.1.2, a foreign-currency document "musí obsahovat v cizí měně i všechny finanční elementy"; section 2.1 lists "zálohovou fakturu (nedaňový zálohový list), daňový doklad při přijetí platby (daňový zálohový list)" as separate kinds. https://isdoc.cz/6.0.2/doc/isdoc.html. Documented.
