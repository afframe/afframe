# 06. Peppol / UBL / EN 16931 as the reference domain layer

**Covers:** how Peppol, UBL and EN 16931 are reused (as record types, vocabularies, validation and an external boundary), the domain groups, party roles, link types, the money effect of each response and document kind, the intake boundary for ISDOC, Peppol and ViDA, and the standard's invariants against this model.
**Read it when:** you build intake or outbound e-invoicing, add a response or document type, or need to know what a Peppol code does to money.
Back to the overview: [README.md](README.md). Evidence for every Peppol and legal claim is in [01](01-constraints-and-evidence.md).

---

## 1. How it is reused

Peppol is used to find **which business facts, roles, outcomes and dependencies must exist**, not to shape tables or limit the platform to what fits in a message. Each concept is used in one of four ways:

- **Adopted as a record type**: order response, invoice response, self-billing, advance.
- **Adopted as a controlled vocabulary**: response codes, invoice type codes, party roles, reference kinds.
- **Adopted as validation**: the EN 16931 amount rules.
- **Recorded as an external boundary**: ISDOC and Peppol documents map to and from typed records. A document being valid externally never means it is approved internally.

---

## 2. Domain groups

A domain analysis of Peppol, UBL and EN 16931 yields the groups below. The owners are this paper's design ([03](03-domains-and-products.md)).

| Domain group | Owner | In the reference model (05) | Peppol / UBL reference |
| --- | --- | --- | --- |
| Identity and governance: parties, roles, periods, currencies, audit, validation profiles | Platform | parties, agreement kinds | party roles, EN 16931 rules |
| Market and sourcing: opportunities, RFQ, quotations | CRM (opportunities), Sales (quotations), Spend (RFQ and supplier quotations) | opportunities | UBL RFQ/Quotation; pre-award is outside Peppol post-award |
| Catalogue and offering | Platform reference data | item text only | Catalogue 3.1 with response |
| Agreement: contracts, framework, call-offs, self-billing | Sales (customer side), Spend (supplier side) | self-billing agreement | Order Agreement 3.0, Self-billing 3.0 |
| Ordering: orders, responses, changes, cancellations | Sales, Spend | order + CA response | Ordering 3.3, Advanced Ordering 3.0 |
| Operations: projects, work, milestones, acceptance | Platform (project and milestone lists), Sales (billing lines per milestone), People (time), FP&A (project financial control, progress estimates); delivery management is out of scope | milestones, timesheets, progress estimates | weak in Peppol |
| Fulfilment: despatch, receipt, rejects, returns | Spend (receipts against an order), Inventory (receipts without an order, issues) | receipts | Despatch Advice 3.1; Receipt Advice in Logistics |
| Logistics | out of scope for now | none | Logistics profiles |
| Billing: invoices, credit and debit notes, self-billing, disputes | Sales (issued), Spend (received); Accounting sold alone registers them in the same records | invoices, corrective document, invoice responses | Billing 3.0, Self-billing 3.0, Invoice Response 3.2 |
| Financial control: budgets, reservations, commitments | FP&A (budgets) + projection (commitments) | plan store, stages | not in Peppol |
| Accounting | Accounting | ledger | not in Peppol |
| Receivables and payables | Sales (customer invoices), Spend (supplier invoices), Treasury (payment matches) + projection (`open`) | open stage | invoice due data, BT-113 |
| Settlement: payments, advances, offsets, write-offs | Treasury (write-offs: open proposal) | allocations, advance application | UBL RemittanceAdvice (no Peppol profile) |
| Treasury: expected cash, payment orders, bank, reconciliation | Treasury | forecast and settled stages | not in Peppol |
| Planning | FP&A | plans, scenarios | not in Peppol |
| Attribution and analytics | Platform projection + FP&A | projection, reports | BT-19 buyer accounting reference, BT-11 project |

---

## 3. Party roles

UBL / Peppol names the roles:

- Ordering: Buyer (`BuyerCustomerParty`), Seller (`SellerSupplierParty`), Originator, Delivery party / consignee.
- Billing: Accounting customer / supplier, Payee (e.g. factoring), Tax representative.

**Rule:** a party's identity is platform data; its role is per document.

- **In the reference model:** the self-billing issuer. VB5 is issued by us under agreement AG-B, and a check requires a valid agreement (the Czech § 28 requirement).
- **Described, not modelled:**
  - a payee different from the seller (factoring)
  - a payer different from the customer (a parent company pays)
  - an originator different from the buyer
  - a delivery party different from the buyer

---

## 4. Link types

The domain analysis names 13 dependency types. They map to implementation as follows.

| Dependency | Implementation |
| --- | --- |
| Predecessor | foreign key on the successor line: receipt → order line; invoice → receipt or order line; invoice → sales order line |
| Fulfilment | `request_fulfilment`, receipt quantity |
| Claim | invoice lines |
| Match | **implicit**: the invoice line's foreign key to receipt or order, plus the invoice response. There is no separate match record. |
| Allocation | `payroll_allocation`, `settlement_line` (largest remainder) |
| Derivation | stage rules (projection), posting rules (ledger) |
| Correction | `reverses_id`, `corrects_line_id`, order response |
| Settlement | `payment_allocation`, `advance_application` |
| Reconciliation | **implicit**: bank ↔ allocation via `payment_allocation`; projection ↔ ledger as a check, not a record |
| Agreement | `agreement` (self-billing modelled; contract and framework described) |
| Role | per-document role columns (issuer modelled; others described) |
| Attribution | project and category on lines (direct), payroll allocation (allocated) |
| Inference | **not stored as fact**. Suggested matches must stay separate until confirmed. |

Transitive ancestry (e.g. invoice → contract through the order) is derived, never stored. That follows from the rule against a universal relationship graph ([01](01-constraints-and-evidence.md)).

---

## 5. Responses and business outcomes → money effects

| Peppol concept | Money effect | Reference model (05) / example (07) |
| --- | --- | --- |
| Order response AB | none | allowed code |
| Order response AP | none; the order stands as sent | default when there is no response |
| Order response CA (lines changed) | committed and cash forecast re-valued to the accepted quantity and price; later receipts and invoices relieve at accepted terms. [Peppol Ordering 3.3](https://docs.peppol.eu/poacc/upgrade-3/profiles/28-ordering/) (documented): on a CA "All lines must be sent"; quantity, delivery period, replacement item and price "can be changed"; and "It is possible to send more than one Order Response line per Order line". `order_response_line` stores only changed lines (an unlisted line is accepted as ordered), one per order line, with quantity and price only, so it cannot yet hold a split delivery, a moved delivery period or a replacement item. | PO5: 50,000 → 42,000 |
| Order response RE | committed and forecast relieved in full | allowed code |
| Order change / cancellation (Advanced Ordering) | same as a response / closure | described |
| Order agreement (seller records an order made outside our process) | creates the order and commitment at the agreed terms | described |
| Despatch advice (outstanding quantity) | no money stage; could move forecast dates | described |
| Receipt with rejected quantity | only the accepted quantity counts; the rest stays committed | described |
| Invoice response UQ / IP / AB | the invoice does not count yet (when approval is required) | VB3 queried on 6 April |
| Invoice response AP / CA | the invoice counts from this moment: relief, actual, open, ledger | VB3 counts from 12 April |
| Invoice response RE (terminal) | never counts; the supplier must issue a credit note if anything was posted | VB6 duplicate, no effect anywhere |
| Invoice response PD | information only; payment facts come from the bank | allowed code |
| Invoice response ordering (OP-BR111-R012, R004, R005) | none; an exchange rule for outbound responses, separate from the internal counting policy | not enforced |
| Prepayment invoice 386 / paid amount BT-113 | 386 is a prepayment invoice, and Peppol settles a pre-payment "with or without VAT" through a final invoice. So the code alone does not tell a Czech non-tax advance request (zálohová faktura) from a tax document for a received payment; intake decides the kind from content (VAT breakdown, tax point date BT-7, paid amount BT-113, ISDOC document type). An order advance paid → settled, and relieves the order forecast. A proforma that names its order relieves that forecast when it is registered. Both reliefs are handed back when the advance is applied, and the final invoice's open amount is reduced by the applied advance (BR-CO-16). | PO5: advance 25,410, VB7 50,820, balance 25,410; a proforma for an order is exercised as a probe (05) |
| Czech tax document for a received payment (daňový doklad při přijetí platby, ISDOC type 5) | no EN 16931 type code tells it apart from the non-tax advance request; needs a national extension. A typed record on the Sales side (advances received) and the Spend side (advances paid) that carries base and VAT per rate, feeds VAT but not cost or revenue `actual`, and is deducted per rate on the final invoice | described, not modelled |
| Self-billed invoice 389 / credit note 261 | stages unchanged; issuer role and agreement required | VB5 |
| Credit note 381, debit note 383, Czech corrective tax document (opravný daňový doklad, ISDOC types 2 and 3) | difference documents ([04](04-money-model.md)) | VB2C |
| Corrected invoice 384 (Germany only in Peppol) | a full replacement: reverse the original and register the replacement | described |
| Remittance advice (UBL only) | explains a payment's split, i.e. input for `payment_allocation` | described |

---

## 6. EN 16931 rules applied internally

Apply BR-CO-10, BR-CO-13, BR-CO-15 and BR-CO-16 to every invoice, whether exchanged or not:

- line sum
- total without VAT = lines − allowances + charges
- + VAT
- amount due = total with VAT − paid amount + rounding

The reference model has no document-level allowances, charges or rounding, so these are specified here but not exercised.

EN 16931-1 was revised in May 2026, and the 2017 version stays compliant during migration. Validation profiles should carry their version ("specification versions" under Identity and governance).

---

## 7. External boundary: ISDOC, Peppol, ViDA

**ISDOC and the public sector**

- ISDOC 6.0.2 is the Czech national format in daily use between accounting systems.
- Contracting authorities must accept EN 16931 e-invoices (Act 134/2016 § 221), in UBL 2.1 or CII (syntaxes per mf.gov.cz).
- Central state bodies also accept ISDOC ≥ 5.2 (Government Resolution 347/2017).

**ViDA** (Directive (EU) 2025/516, official)

- From 1 July 2030, new VAT Directive Art. 218 makes electronic invoices to the European standard the default for all invoices. Member States may still accept other formats for transactions outside the reporting obligations, and new Art. 218(3) lets them "allow the use of other standards for electronic invoices relating to supplies of goods and services within their territory".
- New Art. 232: EN 16931 invoices "shall not be subject to acceptance by the recipient. However, Member States may subject invoices compliant with that standard to acceptance by the recipient for transactions not subject to the reporting obligations ... where that Member State has made use of the option set out in Article 218(2)". An invoice in another standard, such as ISDOC, "shall be subject to acceptance by the recipient" unless the Member State uses the Art. 218(3) option.
- Separately, Art. 1(3) with Art. 6(1) lets a Member State that mandates domestic e-invoicing remove acceptance from 14 April 2025.
- No Czech domestic mandate was found.
- For the design: the intake layer must accept EN 16931 invoices technically. For Czech domestic B2B outside the reporting obligations, with no Czech mandate found, the right to refuse may remain.

**ViDA digital reporting**

- New Art. 263(2) makes the recipient report each intra-Community acquisition and each reverse-charge acquisition (Art. 262(1)(b) and (d)) "no later than 5 days after the invoice is received", from 1 July 2030.
- New Art. 262(4) lets a Member State exempt these, and no Czech choice was found.
- The architecture therefore captures the legally relevant receipt time (for example the transport receipt time) as a declared intake field, separate from registration, confirmation and `recorded_on`. An Accounting tax report would consume it (not in the reference model).

**Mixed input: one intake layer**

One intake layer handles every inbound source: Peppol (UBL, CII), ISDOC, other national XML, e-mailed PDF and scans.

- **Invoices, credit notes and debit notes** map to EN 16931 semantics (the BT business terms) **plus a declared Czech extension** at the boundary:
  - document kind (including ISDOC types 1 to 7)
  - taxed-advance deductions per rate with their reference
  - the reverse-charge commodity code
  - the source document's UUID, the channel and the receipt time
  - simplified documents may be incomplete, with the missing terms marked

  From there they map to the typed record of the owning domain, whichever products are sold.
- **Foreign currency.** The extension also carries the CZK taxable base and VAT per rate and the exchange rate with its date and source.
  - The VAT Act requires the VAT amount in Czech currency (§ 29(1)(l)) and caps the deduction at the VAT on the tax document (§ 73(6)).
  - ISDOC carries these figures in its local-currency subtotals (rules 4.1.2 to 4.1.4).
  - Peppol carries only the total VAT in accounting currency (BT-111) and no exchange rate, so for Peppol input they are computed at the rate the law sets (§ 4(8)) and marked inferred.
  - The supplier cannot be required to state a rate (Commission explanatory note C-4).
- **Tax documents that are not invoices** have no seller and buyer invoice semantics. The customs release decision that is the tax document for import VAT (VAT Act § 33) maps directly to its own typed record in the owning domain, with the original kept in Documents. Not in the reference model.
- EN 16931 is the boundary vocabulary, not the internal schema.
- The original file is kept as evidence in the Documents domain. Each document is registered once ([03](03-domains-and-products.md)).
- **Registration key.** One rule for every document, received or issued, and for the actual-source rule ([04](04-money-model.md)):
  - **Parties.** The seller party and the party that actually issued the document. Each is the internal party resolved from the seller identifier, legal registration identifier or VAT identifier (BT-29, BT-30, BT-31; BR-CO-26 requires only one of them), preferring the IČO or a foreign equivalent. A VAT group's shared DIČ is resolved to the member the document names (VAT Act § 29a).
  - **Number.** The document number normalised as the tax office does (case-folded, separators and leading zeros removed), with the original number stored verbatim for the control statement. Under self-billing that is the customer's number. Both points come from the [control-statement FAQ](https://financnisprava.gov.cz/cs/dane/dane/dan-z-pridane-hodnoty/kontrolni-hlaseni-dph/caste-dotazy-a-odpovedi) (official).
  - **Time.** Numbers are unique only within the seller's "business context, time-frame" (BT-1), and a separate series may be kept "for each customer, and covers as well self-billed invoices" (Commission explanatory note C-1). A same-key document with a different issue date or year therefore goes to review, not to a refusal.
  - A same-seller, same-amount, same-date document with a different number form is a suspected duplicate for review, not a conflict.
  - **Reference model.** Received documents are unique on counterparty plus raw number. Issued documents are unique on the raw number alone.
- Fields extracted from PDF or scans are inferred until a person or a rule confirms them. That needs a suggestion store (section 9).
- Outbound runs the other way: typed record → EN 16931 semantics → Peppol or ISDOC.

**Rule.** Inbound and outbound documents map to and from typed records at the boundary. An inbound invoice creates a supplier invoice that still needs our acceptance (external validity ≠ internal approval). A Message Level Response (technical receipt) is not an Invoice Response (business decision).

---

## 8. What Peppol does not cover

These come from the ERP patterns in [01](01-constraints-and-evidence.md) and from the reference model, not from Peppol: commitments and relief, budgets, payroll costing, ledger derivation, bank reconciliation, the cash forecast, planning, management allocation and project costing. Remittance has no Peppol profile.

---

## 9. The domain analysis's 12 invariants vs this model

| Invariant | Status here |
| --- | --- |
| Every business fact has one authoritative domain | designed ([03](03-domains-and-products.md)); in the reference model `agreement` has no side column |
| Accounting results are explainable through an approved source | modelled: journal `source_type`/`source_id`; invoices post when they count |
| Posted accounting is not silently mutated | designed; `post_to_ledger` inserts only; not enforced (no trigger or privilege) and not asserted |
| A correction identifies what it corrects | modelled (`reverses_id`, `corrects_line_id`, response → order) |
| Splits and merges conserve quantity and money, with explicit rounding | asserted (largest-remainder rounding) |
| Fulfilment cannot exceed the obligation without an accepted exception | asserted (requests, orders, receipts, request links ≤ accepted); **no exception record type**, so the check simply fails |
| Settlement cannot exceed the obligation without a recorded advance or unapplied amount | asserted (invoices, advances) |
| Analytical projections are not transactional authorities | modelled (view, no writers) |
| Inferred relationships are distinguishable | **not modelled**: no inferred links are stored; a suggestion store is needed if matching is automated |
| Every combined fact declares its stage and grain | modelled (`family`, `stage`, `source_type`) |
| Replaced or fulfilled stages are not counted as open | asserted (generic invariant) |
| External message validity ≠ internal approval | modelled (invoice approval gate, order commitment follows acceptance) |
