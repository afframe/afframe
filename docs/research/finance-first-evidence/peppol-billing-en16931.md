# Peppol BIS Billing 3.0, Self-Billing, Invoice Response, EN 16931 — Verified Claims

Purpose: verify (from primary sources) how Peppol/UBL/EN 16931 define invoices, references,
responses, prepayments and amount rules, to use as a REFERENCE vocabulary for a Czech SME
finance platform (not as our internal schema).

Sources restricted to: docs.peppol.eu, peppol.org, ec.europa.eu, docs.oasis-open.org. No
Russian-language or .ru sources were used (none were encountered).

---

## Claim 1 — Peppol BIS Billing 3.0 invoice/credit note type codes

**Status: CONFIRMED**

**URL:** https://docs.peppol.eu/poacc/billing/3.0/bis/
**URL:** https://docs.peppol.eu/poacc/billing/3.0/codelist/UNCL1001-inv/

**Quote (invoice type code list, BT-3):**
> "380" (Commercial invoice) as primary code, with allowed synonymous alternative codes
> "71, 80, 82, 84, 102, 218, 219, 326, 331, 382, 383, 384, 386, 388, 389, 393, 395, 553, 575,
> 623, 780, 817, 870, 875, 876, 877."

**Quote (credit note type code list, BT-3 for CreditNote document):**
> "381" (Credit note) as primary code, with allowed alternatives "81, 83, 396, 532."

**Rule in our own words:** Peppol BIS Billing 3.0 does not restrict `InvoiceTypeCode` to a
single value. It allows a whitelist of UN/CEFACT UNCL1001 subset codes on the `Invoice`
document (headed by 380 commercial invoice, but also including 383 debit note, 384 corrected
invoice, 386 prepayment invoice, 389 self-billed invoice, and others such as 751), and a
separate whitelist on the `CreditNote` document (headed by 381 credit note, plus 81, 83, 396,
532). All specific codes the earlier paper cited (380, 381, 383, 384, 386, 389) are confirmed
members of the respective lists; 751 was not explicitly re-confirmed in the fetched excerpt but
appears in the full UNCL1001-inv subset referenced by the same page (NOT independently
re-verified — see note below).

**Note:** the fetched summaries did not give the verbatim single-line text listing "751"; the
codelist page confirms a 27-code list for invoices ending in "...875, 876, 877" — code 751 was
not seen in the returned excerpt, so its presence is **PARTLY CONFIRMED** (list mechanism and
most codes confirmed; 751 specifically not directly quoted).

---

## Claim 2 — References an invoice can carry (EN 16931 BT IDs)

**Status: CONFIRMED** (all 8 references located with BT IDs), except invoiced object where two
IDs coexist (BT-18 header-level invoiced object identifier vs BT-122 generic supporting
document identifier using the same UBL element).

| Reference | BT ID | UBL element | Source URL |
|---|---|---|---|
| Contract reference | **BT-12** | `cac:ContractDocumentReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-ContractDocumentReference/cbc-ID/ |
| Purchase order reference | **BT-13** | `cac:OrderReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/bis/ |
| Receiving advice reference | **BT-15** | `cac:ReceiptDocumentReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-ReceiptDocumentReference/cbc-ID/ |
| Despatch advice reference | **BT-16** | `cac:DespatchDocumentReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-DespatchDocumentReference/cbc-ID/ |
| Invoiced object identifier | **BT-18** (mapped together with generic BT-122 onto the same UBL element, disambiguated by `DocumentTypeCode="130"`) | `cac:AdditionalDocumentReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-AdditionalDocumentReference/cbc-ID/ |
| Buyer accounting reference | **BT-19** | `cbc:AccountingCost` | https://docs.peppol.eu/poacc/billing/3.0/bis/ |
| Project reference | **BT-11** | `cac:ProjectReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-ProjectReference/cbc-ID/ |
| Preceding invoice reference | **BT-25** | `cac:BillingReference/cac:InvoiceDocumentReference/cbc:ID` | https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cac-BillingReference/cac-InvoiceDocumentReference/cbc-ID/ |

**Quote (BT-25):**
> "The identification of an Invoice that was previously sent by the Seller."

**Quote (BT-18, from cross-check via GitHub issue tracker of the official EN 16931 semantic
model repository, ConnectingEurope/eInvoicing-EN16931 — cited only to corroborate the BT-18
definition, not as a primary Peppol source):**
> "BT-18 Invoiced object identifier is used to refer to invoiced objects ... EN 16931 mentions
> subscriptions, meter readings (e.g. for energy or telephony), vehicle lease, and such like, as
> candidates for invoiced objects ... mapped in UBL to AdditionalDocumentReference/ID with
> DocumentTypeCode="130"."

**Rule in our own words:** every reference the earlier paper listed exists as a distinct EN
16931 business term with a confirmed BT number, and each maps to a specific Peppol BIS UBL
element. BT-18 and BT-122 share the same UBL container (`AdditionalDocumentReference`) but are
distinguished by the `DocumentTypeCode` value (130 = invoiced object).

---

## Claim 3 — Peppol Self-Billing specification

**Status: CONFIRMED**

**URL:** https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/

**Quote (purpose):**
> "describe the use of the self-billed invoice and self-billed credit note messages in Peppol"

**Quote (issuer, roles reversed):**
> "A customer issues and sends an invoice in its suppliers name and sends it to the supplier."
> The customer then "processes it as a purchase invoice, as having been received from the
> supplier."

**Quote (type codes):**
> Invoice type code 389 = "Self-billed invoice"; code 527 = "Self billed debit note"; credit
> note type code 261 = "Self-billed Credit note."

**Rule in our own words:** Peppol Self-Billing 3.0 is a separate CIUS of EN 16931 (distinct
specification tree from ordinary Billing 3.0), in which the **buyer**, not the seller, creates
and transmits the invoice document on the seller's behalf, using dedicated type codes (389
self-billed invoice, 527 self-billed debit note, 261 self-billed credit note) so downstream
systems can distinguish self-billed documents from ordinary ones.

**Required agreement:** **PARTLY CONFIRMED**. The fetched specification text does not state an
explicit mandatory prior written self-billing agreement as a machine-checked rule; it only
implies an operational/legal understanding between the parties ("the self-billed invoice refers
to the suppliers goods or services which have been consumed by the customer based on his own
records"). A formal "self-billing agreement is required" statement was **NOT FOUND** in the
fetched excerpt — this needs a follow-up fetch of the full introduction/scope section of
https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/ if a definitive statement is needed.

---

## Claim 4 — Peppol Invoice Response status codes

**Status: CONFIRMED**

**URL:** https://docs.peppol.eu/poacc/upgrade-3/codelist/UNCL4343-T111/
**URL:** https://docs.peppol.eu/poacc/upgrade-3/profiles/63-invoiceresponse/

**Quote (status codes, UNCL4343 subset T111):**
> AB — "Message acknowledgement" — "Indicates that an acknowledgement relating to receipt of
> message or transaction is required."
> AP — "Accepted" — "Indication that the referenced offer or transaction ... has been accepted."
> RE — "Rejected" — "Indication that the referenced offer or transaction ... is not accepted."
> IP — "In process" — "Indicates that the referenced message or transaction is being processed."
> UQ — "Under query" — "Indicates that the processing of the referenced message has been halted
> pending response to a query."
> CA — "Conditionally accepted" — "Indication that the referenced offer or transaction ... has
> been accepted under conditions."
> PD — "Paid" — "Indicates that the referenced document or transaction has been paid."

Note: AB in the official UNCL4343-T111 subset is defined as "Message acknowledgement," not
"Agreed to Bill" as loosely assumed in some secondary blog sources — this is a correction versus
informal/secondary descriptions.

**Quote (multiple responses allowed, rule OP-BR111-R003):**
> "Several Invoice Response's can be sent for one invoice."

**Quote (finality):**
> "If an invoice has been given the status Rejected or Paid, then no further Invoice Response
> may be sent regarding that invoice."
> "If an invoice has been given status Approved, then that may only be followed with an Invoice
> Response giving status Paid."

**Quote (status reason / clarification codes):**
> "The status code can be supplemented with a clarification or an action code or textual note
> that explains the status and assists the Seller in deciding on correct reaction."

**Rule in our own words:** Peppol Invoice Response supports a small business-status vocabulary
(AB acknowledgement, IP in process, UQ under query, CA conditionally accepted, RE rejected, AP
accepted, PD paid). Multiple Invoice Responses may be sent over the lifecycle of one invoice
(e.g., IP then UQ then AP then PD), but RE and PD are terminal (no further response allowed
after Rejected or Paid), and AP can only be followed by PD. Each status can carry a reason or
requested-action clarification code plus free text, which is the closest Peppol concept to an
"invoice dispute reason."

---

## Claim 5 — Message Level Response (MLR) vs Invoice Response (business)

**Status: PARTLY CONFIRMED** (primary-source Peppol pages for MLR/AS4 message-level response
were not directly fetched in this session — found via search summary rather than verbatim
primary quote; Invoice Response side is confirmed above from primary source).

**URL (Invoice Response, primary, confirmed above):** https://docs.peppol.eu/poacc/upgrade-3/profiles/63-invoiceresponse/
**URL (MLR, NOT independently fetched from a docs.peppol.eu/peppol.org primary page in this session):** general Peppol AS4/MLR mechanism described at https://peppol.helger.com/public/locale-en_US/menuitem-docs-peppol-mlr (third-party, not within allowed primary-source list — flagged as NOT FOUND for a compliant primary citation).

**Rule in our own words (based on confirmed Invoice Response primary source plus general Peppol
architecture knowledge that needs a follow-up primary citation for MLR specifically):** the
Message Level Response is a transport/technical-layer AS4 receipt confirming a document was
syntactically/technically received and validated by the access point / receiving system — it
says nothing about business acceptance. The Invoice Response (this document) is a
business-layer message sent by the buyer's application expressing whether the invoice itself is
accepted, rejected, queried, or paid. **Action needed:** a primary docs.peppol.eu or peppol.org
page specifically defining "Message Level Response" was not fetched in this session — mark this
half of Claim 5 as **NOT FOUND** against the primary-source constraint and revisit with a
targeted fetch of docs.peppol.eu's AS4 / MLR profile page before relying on it.

---

## Claim 6 — EN 16931 amount rules in Peppol Billing

**Status: CONFIRMED** (all four rules retrieved verbatim from docs.peppol.eu rule pages)

**BR-CO-10** — https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-10/
> "Sum of Invoice line net amount (BT-106) = Σ Invoice line net amount (BT-131)."

Rule in own words: the document-level sum of line net amounts (BT-106) must equal the arithmetic
sum of every individual invoice/credit note line's net amount (BT-131).

**BR-CO-13** — https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-13/
> "Invoice total amount without VAT (BT-109) = Σ Invoice line net amount (BT-131) - Sum of
> allowances on document level (BT-107) + Sum of charges on document level (BT-108)."

Rule in own words: the tax-exclusive invoice total (BT-109) equals the sum of line net amounts
minus document-level allowances plus document-level charges.

**BR-CO-15** — https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-15/
> "Invoice total amount with VAT (BT-112) = Invoice total amount without VAT (BT-109) + Invoice
> total VAT amount (BT-110)."

Rule in own words: the tax-inclusive total (BT-112) equals the tax-exclusive total (BT-109) plus
the total VAT amount (BT-110).

**BR-CO-16** — https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-16/
> "Amount due for payment (BT-115) = Invoice total amount with VAT (BT-112) - Paid amount
> (BT-113) + Rounding amount (BT-114)."

Rule in own words: what the buyer still owes (BT-115) is the tax-inclusive total minus any
amount already paid/prepaid (BT-113) plus a rounding correction (BT-114).

**Correction vs the claim as phrased:** the task described BR-CO-16 as "amount due = total with
VAT - paid amount + rounding" — this matches exactly. Note the earlier paper's claim numbering
of BT-113 (paid amount) and BT-114 (rounding amount) is confirmed correct by this same rule
text.

---

## Claim 7 — Prepayments/advances in an invoice

**Status: CONFIRMED**

**URL:** https://docs.peppol.eu/poacc/billing/3.0/rules/ubl-tc434/BR-CO-16/ (BT-113 usage,
confirmed above)
**URL:** https://docs.peppol.eu/poacc/billing/3.0/codelist/UNCL1001-inv/ (code 386, confirmed
above under Claim 1)

**Quote (BT-113 role, from BR-CO-16, already quoted in Claim 6):**
> "Amount due for payment (BT-115) = Invoice total amount with VAT (BT-112) - Paid amount
> (BT-113) + Rounding amount (BT-114)."

**Quote (invoice type 386):**
> "386" is listed among the allowed Peppol BIS Billing 3.0 invoice type codes (synonymous with
> 380), corresponding to UNCL1001's "Prepayment invoice."

**Rule in our own words:** EN 16931 / Peppol has two independent mechanisms for advances: (1) a
document-type mechanism — an invoice issued specifically to request or confirm a prepayment can
use type code 386 (prepayment invoice); and (2) an amount-field mechanism — any invoice
(including the final invoice settling the prepaid amount) can carry BT-113 "Paid amount," which
BR-CO-16 subtracts from the tax-inclusive total to compute what remains due. Peppol does not
appear to require both together; BT-113 can be used on a normal (380) final invoice to net off
a previously received prepayment.

---

## Claim 8 — Remittance advice / payment status document in Peppol

**Status: NOT FOUND** (no Peppol BIS profile for Remittance Advice located)

**URL checked:** search across docs.peppol.eu profile listing (https://docs.peppol.eu/poacc/upgrade-3/), covering Ordering, Order Only, Catalogue (with/without response), Despatch Advice, Billing, Invoice Response — **no RemittanceAdvice profile appears in this list.**

**Rule in our own words:** UBL 2.1/2.4 (OASIS) does define a `RemittanceAdvice` document type in
the base UBL library, but no fetched or searched docs.peppol.eu page shows OpenPeppol having
published a BIS profile that profiles/constrains `RemittanceAdvice` for the Peppol network. This
should be treated as an internal-platform gap (payment status / remittance communication) that
Peppol does not currently standardize — worth flagging as a genuine "missing concept" for the
Czech SME platform design, per the task's stated purpose. **Caveat:** this is an absence-of-
evidence finding from the sources reachable in this session (WebFetch/WebSearch against
docs.peppol.eu), not an exhaustive audit of every peppol.org/docs.oasis-open.org page; a
dedicated search of docs.oasis-open.org's UBL 2.4 RemittanceAdvice schema page was not performed
due to time budget.

---

## Claim 9 — EN 16931-1 current status/version

**Status: CONFIRMED**

**URL:** https://ec.europa.eu/digital-building-blocks/sites/spaces/DIGITAL/pages/467108971/Obtaining+a+copy+of+the+European+standard+on+eInvoicing

**Quote:**
> "A new version of the EN 16931-1, a version 2026, was published in May 2026 and consequently
> the 2017 version of the EN 16931-1 has been formally withdrawn."
> "the 2017 version will, however, remain compliant during the migration period."

**Rule in our own words:** EN 16931-1 was originally published in 2017 (the version underlying
current Peppol BIS Billing 3.0 / CIUS documents). As of this research (September 2026), the EU's
official eInvoicing page states a revised EN 16931-1 (dated 2026, following CEN/TC 434 approval
in late 2025 and a formal vote in February 2026) was published in May 2026, formally
superseding/withdrawing the 2017 edition, with a migration period during which the 2017 version
remains usable. Peppol BIS Billing 3.0 itself, as fetched, is still built on the 2017-era EN
16931 semantic model as of the "November 2025 Release" / "May 2026 Release" documentation pages
seen during this research; whether/when Peppol updates its CIUS to the new EN 16931-1 version was
**NOT FOUND** in the pages fetched this session and would need a dedicated check of
docs.peppol.eu's release notes/changelog.

---

## Summary of gaps needing follow-up (time-boxed at ~25 minutes, budget reached)

- Claim 1: code 751 not independently verified in exact list text (mechanism confirmed).
- Claim 3: no explicit "self-billing agreement required" statement found; needs deeper fetch of the self-billing BIS scope/introduction section.
- Claim 5: MLR primary-source page (docs.peppol.eu) not fetched directly — only secondary corroboration; needs a targeted follow-up.
- Claim 8: RemittanceAdvice — absence confirmed only against the Peppol BIS profile list found via search; UBL 2.4 OASIS schema page for RemittanceAdvice not checked.
- Claim 9: whether Peppol has adopted/timelined migration to EN 16931-1:2026 in its own CIUS was not found.

---
## Addendum (second review follow-up, 2026-09-24): superseded lines and missing entries
Provenance: "fetched" means re-fetched with curl on 2026-09-24 for this addendum; "review" means verified live by the second independent review (`.context/reviews/2026-09-24-second-review.md`) and quoted as recorded there. Earlier lines stay as written; where they conflict, this addendum wins.

**Supersedes lines 103-107 and the matching gap in the summary (self-billing agreement "NOT FOUND").** https://docs.peppol.eu/poacc/self-billing/3.0/bis-sb/ (fetched), business process P12: "Directive 2006/112/EC (Article 224) requires a specific process to be observed, involving prior agreement and a procedure where the supplier is to accept each invoice." Status: CONFIRMED (documented).

**New entries:**
- "Germany only" (fetched): the marking is in the Billing 3.0 specification, https://docs.peppol.eu/poacc/billing/3.0/bis/, not on the UNCL1001-inv code list page. 384 "Corrected invoice" and 389 "Self-billed invoice" are both marked "(Germany only)". Rule PEPPOL-EN16931-P0112 (fatal): "Invoice type code 326 or 384 are only allowed when both buyer and seller are German organizations". Documented.
- OP-BR111-R012 (review), https://docs.peppol.eu/poacc/upgrade-3/profiles/63-invoiceresponse/: "The status of invoices shall advance in the following order. AB IP UQ CA RE AP PD". Documented.
- Code 386 (review), https://docs.peppol.eu/poacc/billing/3.0/codelist/UNCL1001-inv/: "Prepayment invoice: An invoice to pay amounts for goods and services in advance; these amounts will be subtracted from the final invoice". Billing 3.0, https://docs.peppol.eu/poacc/billing/3.0/bis/ (fetched), section 5.6 on negative invoices: "Pre-payment (with or without VAT) is settled through a final invoice". Documented.
- National-currency VAT (review), Billing 3.0: "the amount of VAT payable in national currency is stated in the element Invoice total VAT amount in accounting currency (BT-111) ... The exchange rate is not specified in the invoice instance, and hence this calculation is not validated." Documented.
- Invoice number scope (review): BT-1 identifies the invoice "within the business context, time-frame, operating systems and records of the Seller" (https://docs.peppol.eu/poacc/billing/3.0/syntax/ubl-invoice/cbc-ID/); BT-26 "Shall be provided in case the Preceding Invoice identifier is not unique". BR-CO-26 requires only one of the Seller identifier (BT-29), the Seller legal registration identifier (BT-30) or the Seller VAT identifier (BT-31). Documented.
