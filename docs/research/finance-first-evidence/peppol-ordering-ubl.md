# Peppol BIS Post-Award / Ordering-Fulfilment Profiles and UBL 2.4 — Verified Facts

Method note: Fetched primary sources at docs.peppol.eu, peppol.org, docs.oasis-open.org via automated
fetch+summarize tool. Quotes below are as extracted by that tool from the fetched pages; where a quote
could not be independently re-verified character-for-character, this is flagged. No Russian-language or
.ru sources used. Research window ~25 minutes; some sub-points are marked NOT FOUND / PARTLY where the
fetch tool could not surface the exact text within budget.

---

## Claim 1 — Current list of Peppol BIS post-award specifications

**Status: CONFIRMED (list), PARTLY (all version numbers independently spot-checked)**

**URL:** https://docs.peppol.eu/poacc/upgrade-3/ (index page, "DEV 2026-Q2 Release")

List returned from the index page (profile names as titled on the page, with relative links resolved
against the base URL):

| Profile | Version | URL |
|---|---|---|
| Peppol BIS Order only | 3.3 | https://docs.peppol.eu/poacc/upgrade-3/profiles/3-order-only/ |
| Peppol BIS Ordering | 3.3 | https://docs.peppol.eu/poacc/upgrade-3/profiles/28-ordering/ |
| Peppol BIS Catalogue with response | 3.1 | https://docs.peppol.eu/poacc/upgrade-3/profiles/1-catalogueonly/ |
| Peppol BIS Catalogue without response | 3.1 | https://docs.peppol.eu/poacc/upgrade-3/profiles/64-catalogue-wo-response/ |
| Peppol BIS Despatch Advice | 3.1 | https://docs.peppol.eu/poacc/upgrade-3/profiles/30-despatchadvice/ |
| Peppol BIS Punch Out | 3.1 | https://docs.peppol.eu/poacc/upgrade-3/profiles/18-punchout/ |
| Peppol BIS Order Agreement | 3.0 | https://docs.peppol.eu/poacc/upgrade-3/profiles/42-orderagreement/ |
| Peppol BIS Message Level Response | 3.0 | https://docs.peppol.eu/poacc/upgrade-3/profiles/36-mlr/ |
| Peppol BIS Invoice Response | 3.2 | https://docs.peppol.eu/poacc/upgrade-3/profiles/63-invoiceresponse/ |
| Peppol BIS Billing with response | 3.0 | https://docs.peppol.eu/poacc/upgrade-3/profiles/66-billing-with-response/ |
| Peppol BIS Advanced Ordering | 3.0 | https://docs.peppol.eu/poacc/upgrade-3/profiles/65-advanced-ordering/ |
| Peppol BIS Ordering (transaction detail: Ordering 3.3) | 3.3 | https://docs.peppol.eu/poacc/upgrade-3/profiles/28-ordering/ |
| Peppol BIS Billing 3.0 (invoicing) | 3.0 (implementation build 3.0.21 seen) | https://docs.peppol.eu/poacc/billing/3.0/bis/ |

Separately, "Self-Billing" and full "Logistics profiles" (Advanced Despatch Advice, Advanced Despatch
Advice with Receipt Advice) live under a **different** documentation tree, `docs.peppol.eu/logistics/...`,
not under `poacc/upgrade-3`:
- Peppol Advanced Despatch Advice Only — https://docs.peppol.eu/logistics/2024-Q1/profiles/66-advanceddespatchadvice/
- Peppol Advanced Despatch Advice with Receipt Advice — https://docs.peppol.eu/logistics/2024-Q1/profiles/67-advanceddespatchadvice_w_receiptadvice/

**Rule (own words):** The expected list is essentially confirmed, with two corrections to the framing in
the claim: (a) "Self-Billing" as a named profile was **NOT FOUND** in the `poacc/upgrade-3` index within
budget — it may exist under a different community/tree and needs a follow-up fetch; (b) the "Logistics
profiles" (Receipt Advice included) are a **separate Peppol domain** ("logistics"), not part of the
`poacc` (Post-Award) tree, i.e. Receipt Advice is not part of core POACC Ordering/Despatch Advice but of
the Logistics BIS family.

---

## Claim 2 — Order Response codes (Peppol Ordering, non-advanced)

**Status: PARTLY CONFIRMED**

**URL:** https://docs.peppol.eu/poacc/upgrade-3/syntax/OrderResponse/cbc-OrderResponseCode/

Quote (as extracted): "An order response with code AB (Acknowledged) must NOT provide order lines" /
"An order response with code AP (Accepted) must NOT provide order lines" / "An order response with code
RE (Rejected) must NOT provide order lines" / "An order response with code CA (Conditionally accepted)
must provide order lines."

General description quote: "the referenced order has been received and not yet processed, or is Accepted
or Rejected as whole, alternatively, Accepted with change or already delivered."

**Rule (own words):** In basic Peppol Ordering, OrderResponseCode has (at least) four values: **AB**
(acknowledged, header-only, no lines), **AP** (accepted in full, header-only, no lines), **RE** (rejected
in full, header-only, no lines), **CA** (conditionally/partially accepted — this is the ONLY code that
carries order-response lines, i.e. line-level status). This means **line-level status and partial
acceptance are allowed only under CA**; changed quantity/price/delivery-date per line is carried at the
order-line level when CA is used (line-level detail confirmed to exist structurally, but the exact set of
line-level changeable fields such as price/date was not independently re-verified against the schema on
this pass — mark that part **NOT FOUND / needs follow-up** against the actual OrderResponse line syntax
page). The full authoritative UNCL4343-subset code list (which may include more codes) was **NOT FOUND**
verbatim; only these four were surfaced.

---

## Claim 3 — Advanced Ordering: Order Change and Order Cancellation

**Status: CONFIRMED (roles/flow), PARTLY (verbatim precision)**

**URL:** https://docs.peppol.eu/poacc/upgrade-3/profiles/65-advanced-ordering/

Quotes (as extracted):
- "The buyer creates an Order Change with changes to one or more order lines."
- "The buyer may cancel the order" and "The seller may cancel the order because of lack of delivery
  capacity or other reasons."
- Scenario 3 (change of order from seller): "The seller creates an Order Response Advanced with changes
  to one or more order lines."

**Rule (own words):**
- **Order Change**: sent only by the **buyer**, to modify one or more lines of a previously sent order.
- **Order Cancellation**: can be sent by **either party** — buyer-initiated cancellation, or
  seller-initiated cancellation (e.g., insufficient delivery capacity).
- **Seller-proposed changes**: yes — the seller does not send a separate "Order Change" but instead
  responds to the (Advanced) order with an **Order Response Advanced** carrying line-level changes
  (quantity, delivery period, replacement item, price per the fetch); the buyer then either accepts or
  rejects (via Order Cancellation).
- Header-level response codes reported for Advanced Ordering: AB (received, not processed), RE (rejected
  in full), AP (accepted, no changes), CA (accepted with line-level amendments) — consistent with Claim 2.

---

## Claim 4 — Order Agreement purpose, issuer, business scenario

**Status: PARTLY CONFIRMED (purpose and scenario), CONTRADICTION FLAGGED (issuer)**

**URL:** https://docs.peppol.eu/poacc/upgrade-3/profiles/42-orderagreement/

Quote (purpose): "The purpose of this document is to describe a common format for the order agreement in
the European market, and to facilitate an efficient implementation and increased use of electronic
collaboration regarding the ordering process based on this format."

Quote (issuer/flow): "The seller creates an order in his ordering system based on requirements from the
buyer and, after agreeing/committing to it, sends a copy of the order as an Order agreement to the buyer."

Quote (fraud-control note): "it is very important that the buyer's system can verify that the seller is
allowed to send an order agreement and that the process is described in the contract between seller and
buyer to prevent fraud and to secure good quality in the transaction."

**Rule (own words):** The **seller** issues the Order Agreement, sending it to the buyer as a
retrospective record of an order that was placed outside the buyer's formal ordering/procurement system
(e.g. web shop, phone order, email, in-store/warehouse purchase, framework-agreement call-off). This lets
the buyer's system ingest the order into its procurement/matching flow (order-to-invoice matching,
spend visibility) even though the order itself never originated from the buyer's system. Note: this
directly matches the claim's expected scenario ("purchase made outside the buyer's ordering system"),
confirming that framing, and clarifies the direction is seller→buyer (not the other way round).

---

## Claim 5 — Despatch Advice: purpose, quantities, references; Receipt Advice

**Status: PARTLY CONFIRMED**

**URL (Despatch Advice):** https://docs.peppol.eu/poacc/upgrade-3/profiles/30-despatchadvice/
**URL (Outstanding Quantity element):** https://docs.peppol.eu/poacc/upgrade-3/syntax/DespatchAdvice/cac-DespatchLine/cbc-OutstandingQuantity/

Quotes (as extracted): "The Despatch Advice message is used in the fulfillment process by the supplier to
notify the receiver about the despatch and delivery period for the goods being sent, as well as details
about the goods for cross checking with the order." / "The Despatch Advice states what is shipped; the
quantity of goods shipped and what is outstanding." / OutstandingQuantity is "equivalent to the amount
that will be delivered in a later Despatch," with "Backorder" usable as an OutstandingReason.

**Rule (own words):** Peppol BIS Despatch Advice (currently v3.1, transaction T16 v3.4) is the
seller-to-buyer fulfilment message confirming what was actually shipped, carrying at minimum a despatched
quantity per line plus an optional outstanding-quantity per line (with a reason, e.g. "Backorder") for
goods not yet shipped but still expected in a future despatch; items neither shipped nor declared as
outstanding are implicitly not going to be delivered. It references order lines for cross-checking against
the original order (link back to Order confirmed by page purpose statement; the exact UBL element used for
the order-line back-reference was **NOT FOUND** verbatim in this pass).

**Receipt Advice in Peppol:** **CONFIRMED as existing, but NOT part of the core POACC (Post-Award) profile
family** — it appears under the separate **Logistics** domain: "Peppol Advanced Despatch Advice with
Receipt Advice" at https://docs.peppol.eu/logistics/2024-Q1/profiles/67-advanceddespatchadvice_w_receiptadvice/.
This means: standard Peppol BIS Despatch Advice (POACC, v3.1) does **not** include a matching Receipt
Advice response — Receipt Advice (with rejected-quantity capability, as in UBL) is only profiled in the
separate Logistics "Advanced Despatch Advice with Receipt Advice" specification. Rejected-quantity detail
within that Logistics Receipt Advice was **NOT FOUND** within budget (would need a direct fetch of the
2024-Q1 Logistics profile 67 page).

---

## Claim 6 — Catalogue and Catalogue Response

**Status: PARTLY CONFIRMED**

**URL:** https://docs.peppol.eu/poacc/upgrade-3/profiles/1-catalogueonly/ (Catalogue With Response, v3.1)
also https://docs.peppol.eu/poacc/upgrade-3/profiles/64-catalogue-wo-response/ (Catalogue without
response, v3.1); Catalogue Response transaction identified as **T58** (v3.0) at
https://docs.peppol.eu/poacc/upgrade-3/syntax/CatalogueResponse/tree/

Quote (extracted, paraphrase-adjacent — flagged as not independently re-verified verbatim): "Buyers can
accept or reject the catalogue using a catalogue response." Base doc note: "This Peppol BIS is based on
the CEN WS/BII2 'Profile BII01 Catalogue Only'."

**Rule (own words):** Peppol offers two Catalogue profiles: **Catalogue with response** (v3.1) where the
buyer sends back a Catalogue Response (T58, v3.0) that can accept or reject the submitted catalogue
(structurally, at whole-catalogue and/or line level per CatalogueResponse schema — line-level detail not
independently verified this pass), and **Catalogue without response** (v3.1) where no response document
is expected. Exact accept/reject code list for Catalogue Response was **NOT FOUND** verbatim in this pass.

---

## Claim 7 — Party roles across Ordering, Despatch and Billing

**Status: PARTLY CONFIRMED**

**URLs:** https://docs.peppol.eu/poacc/upgrade-3/profiles/28-ordering/ ; https://docs.peppol.eu/poacc/billing/3.0/bis/

From **Ordering** (quotes as extracted):
- Buyer — `cac:BuyerCustomerParty` — "The buyer is the legal person or organization acting on behalf of
  the customer and who buys or purchases goods or services."
- Seller — `cac:SellerSupplierParty`.
- Originator — `cac:OriginatorCustomerParty` — "A person or unit that initiates an order."
- Invoicee — `cac:AccountingCustomerParty` (receives invoices on behalf of the buyer, per fetch summary —
  **flag**: in UBL/Peppol Billing, AccountingCustomerParty is normally the *buyer/customer* role for
  invoicing purposes, not a separate "invoicee" role; this needs a direct re-check against the Ordering
  page's actual party-role table before relying on it — treat as **PARTLY CONFIRMED / needs verification**).
- Consignee/Delivery Party — described as "final recipients of delivered goods" (role name not confirmed
  verbatim as "Consignee" vs "DeliveryCustomerParty").

From **Billing 3.0** (quotes as extracted):
- Accounting Supplier Party (Seller) — "The supplier is the legal person or organisation who provides a
  product or service."
- Accounting Customer Party (Buyer) — "The customer is the legal person or organisation who is in demand
  of a product or service."
- Payee Party — described as an optional role used in factoring, i.e. payment receiver differs from
  seller.
- Tax Representative Party — "for sellers delivering goods and services in a country without having a
  permanent establishment in that country."
- Delivery Party — receiver of goods/services if different from the buyer.

**Rule (own words):** Across POACC profiles, roles are named consistently with UBL's ABIE names:
`BuyerCustomerParty` / `SellerSupplierParty` in Ordering; `AccountingCustomerParty` /
`AccountingSupplierParty` in Billing (these map to buyer/customer and seller/supplier respectively across
the whole POACC family — Billing's "Accounting Customer/Supplier Party" is the same concept as Ordering's
"Buyer/Seller", just using the UBL element names that Billing profiles by convention). Additional
optional roles appear across profiles: **Originator** (who initiates an order, distinct from the buyer
who is financially responsible), **Payee** (who receives payment, for factoring/assignment cases),
**Tax Representative** (fiscal representative in another jurisdiction), and **Delivery
Party/Consignee** (physical recipient of goods, distinct from the buyer). **Not independently confirmed**
this pass: whether "Invoicee" is a distinct named Peppol role or a mislabel of AccountingCustomerParty —
flagged for follow-up.

---

## Claim 8 — UBL 2.4 release status/date and money-flow document types

**Status: CONFIRMED (release date/status), PARTLY CONFIRMED (document list — see caveat)**

**URLs:**
- https://www.oasis-open.org/2023/10/27/universal-business-language-v2-4-from-the-ubl-tc-approved-as-a-committee-specification/ (Committee Specification approval, 27 Oct 2023 announcement)
- https://docs.oasis-open.org/ubl/os-UBL-2.4/UBL-2.4.html (OASIS Standard)
- https://docs.oasis-open.org/ubl/UBL-2.4.html (index)

**Release status/date:** UBL 2.4 was approved by the UBL Technical Committee as a **Committee
Specification** (per the 27 Oct 2023 OASIS announcement), and subsequently approved/published as an
**OASIS Standard**, with the fetch-derived date of **20 June 2024** for the OASIS Standard milestone. The
exact OASIS Standard approval date **should be re-confirmed directly against the OASIS Standard
cover page** (`os-UBL-2.4`) TC-approval boilerplate — this pass relied on a search-engine-summarized date
rather than a verbatim quote from the cover page itself, so treat the specific "20 June 2024" date as
**PARTLY CONFIRMED**, not fully verbatim-verified.

**Document types (money-flow relevant), as returned by the fetch tool with one-line purposes** — these are
the tool's paraphrases of document intent, **not verbatim spec quotes** (the actual UBL 2.4 spec index
page was not quote-extracted line by line within budget), so mark the whole table **PARTLY CONFIRMED**:

| Document | Exists in UBL 2.4? | One-line purpose (paraphrase, not verbatim) |
|---|---|---|
| Order | Yes | Buyer-to-seller purchase request |
| OrderResponse | Yes | Detailed response/acknowledgement to an Order |
| OrderResponseSimple | Yes | Simplified accept/reject acknowledgement of an Order |
| OrderChange | Yes | Modification of a previously submitted Order |
| OrderCancellation | Yes | Cancellation of an existing Order |
| DespatchAdvice | Yes | Notification of goods shipped |
| ReceiptAdvice | Yes | Confirmation of goods received (incl. rejected quantities per UBL model) |
| Invoice | Yes | Request for payment for goods/services delivered |
| CreditNote | Yes | Reduction of amount owed (returns/adjustments) |
| DebitNote | Yes | Increase of amount owed (additional charges) |
| SelfBilledInvoice | Yes | Invoice issued by the buyer instead of the seller |
| SelfBilledCreditNote | Yes | Credit note issued by the buyer instead of the seller |
| Reminder | Yes | Request for payment of overdue invoice(s) |
| Statement | Yes | Report of account balance/transaction history |
| RemittanceAdvice | Yes | Notification of a payment made, for reconciliation |
| ApplicationResponse | Yes | Generic acknowledgement/status response to a submitted document |

**Rule (own words):** All 16 document types named in the claim exist as UBL document types (this document
list is stable across UBL 2.1/2.3/2.4 — none of these are new-to-2.4), but this pass did not verbatim-quote
each document's one-line purpose directly from the OASIS spec text (docs.oasis-open.org/ubl/os-UBL-2.4/) —
that would need one fetch per document type (or one fetch of the full document-and-transaction list page)
to move from PARTLY CONFIRMED to CONFIRMED with verbatim quotes.

---

## Summary of Verification Status

- CONFIRMED: 2 (Claim 1 list existence/URLs at top level; Claim 4 seller-issues / outside-system scenario)
- PARTLY CONFIRMED: 6 (Claims 2, 3, 5, 6, 7, 8 — core facts right, but some sub-details or exact verbatim
  quotes not independently re-verified against the raw HTML/spec text within the time budget)
- REFUTED: 0
- NOT FOUND: several sub-points flagged inline (full UNCL4343 code list for OrderResponseCode; exact
  order-line back-reference element in Despatch Advice; Catalogue Response accept/reject code list;
  "Self-Billing" as a named POACC profile; verbatim OASIS Standard approval-date boilerplate for UBL 2.4;
  per-document verbatim one-line purposes from the UBL 2.4 spec text itself)

**Caveat on method:** Most facts here were obtained via an automated fetch-and-summarize tool rather than
raw HTML inspection, so quotes marked "as extracted" should be treated as high-confidence paraphrase
close to verbatim, not guaranteed byte-for-byte matches to the source. Where this matters for downstream
design decisions (e.g., exact OrderResponseCode list, exact UBL 2.4 document purpose wording), a follow-up
direct-fetch pass is recommended before citing these as authoritative quotes.
