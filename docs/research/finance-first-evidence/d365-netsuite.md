# D365 Finance & NetSuite domain-model verification

Budget: ~20 min. Sources fetched live via WebFetch/WebSearch on 2026-09-23. No memory-filled claims; gaps marked NOT FOUND.

## 0. Brief URLs — what they actually say

**https://learn.microsoft.com/en-us/dynamics365/finance/public-sector/budget-analysis-report**
Status: CONFIRMED (fetched). Label: vendor-documented.
This is the "Budget analysis report" page (public sector). It describes a report that, per account, lists: revised budget, actuals, encumbrances (from POs), preencumbrances (from purchase requisitions), and remaining budget. Quote:
> "For each account, the report lists budgeted amounts, actual expenses or revenue, encumbrance amounts from purchase orders, and preencumbrance amounts from purchase requisitions."
And the budget-remaining definition:
> "Budget remaining (original budget plus budget adjustments, minus actuals, encumbrances, and preencumbrances; only posted transactions are considered in this calculation)"
It is a reporting/inquiry page, not the budget-control configuration page — the configurable engine is documented separately (see claim 1).

**https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_3862676046.html**
Status: CONFIRMED (fetched), but topic differs from the brief's assumption. Label: vendor-documented.
This page is NOT about transactions/links/budgets — it is about **Multi-Book Accounting record categorization** ("book-generic" vs "book-specific" records). Quote:
> "Records that are created and shared across all accounting books... Book-specific: Records that are created for only one book." and "Most transactions are book-generic, many with book-specific attributes."
Relevant to claim 12 (multi-book) but not to transaction-link or budget claims — those were separately verified via other NetSuite Help Center pages (see claims 9–11).

## 1. Budget control formula and pre-encumbrance/encumbrance/actuals mapping
Status: CONFIRMED. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/budgeting/budget-control-overview-configuration
Quote:
> "Match the source documents that you select with the check boxes for balances that are included in the calculation of available budget funds. ... When you perform a budget check for the amounts and accounts on a purchase line, the budget control category that you assign to the reservation is Encumbrance. When you perform a budget check for the amounts and accounts on a purchase requisition, the budget control category ... is Preencumbrance."
The exact "budget funds available = budget − (actuals+encumbrances+pre-encumbrances)" formula is not spelled out as one algebraic line on this page, but the page explicitly says the calculation is configurable ("Should the calculation of available funds consider documents such as purchase requisitions (preencumbrances) and purchase orders (encumbrances)?") and the drilldown/report page (claim 0) states remaining budget = revised budget − (actuals + encumbrances + preencumbrances). Invoices generate "Actual expenditures" per the guideline table: "Budget reservations for encumbrances → You must also select Actual expenditures." Mechanism confirmed as claimed.

## 2. Relief mechanics (PO from requisition; invoice posts) and valuation of partial/price differences
Status: PARTLY. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/public-sector/general-budget-reservations
Quote:
> "A general budget reservation is relieved differently, depending on the document that references it: If the document is a purchase order, the reservation is relieved when the purchase order is confirmed. If the document is an invoice, and it doesn't reference a purchase order or purchase agreement, the general budget reservation is relieved when the invoice is posted. If the document is a purchase requisition, the reservation is relieved when the purchase requisition is approved."
This confirms relief points (requisition approval / PO confirmation / invoice posting for non-PO invoices) but this text is about **general budget reservations** (public-sector commitment documents), not literally "pre-encumbrance relieved when PO created from requisition, encumbrance relieved when invoice posts" in those exact terms. For plain encumbrance/pre-encumbrance (non general-budget-reservation) relief, and specifically **how relief is valued for partial quantity/price differences** (relieved at predecessor's amount vs successor's), NOT FOUND — no fetched page states this valuation mechanism explicitly. Flag as an open question requiring a dedicated "About purchase order encumbrances" (AX2012-era) or "Budget funds available" deep-dive page, which we did not fetch within budget.

## 3. "Budget source tracking" as a documented concept
Status: CONFIRMED. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/budgeting/budget-control-overview-configuration
Quote:
> "The Only track amounts in the budget funds available calculation feature changes what data is tracked in the BudgetSourceTracking tables. When this feature is on, amounts are stored only if they're selected for use in the available budget funds calculation."
This confirms `BudgetSourceTracking` is a real, documented table/concept underlying encumbrance/pre-encumbrance amount tracking, controllable by a feature flag.

## 4. Encumbrance accounting (public sector): posted to GL; year-end processing of open encumbrances
Status: CONFIRMED. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/budgeting/purchase-order-year-end-process
Quote:
> "If you record encumbrances for purchase orders in the general ledger, including purchase orders for projects, you can generate closing entries in the general ledger and against budget reservations at the end of each fiscal year. At the start of the new fiscal year, you can create opening entries to correctly record the encumbrances and budget reservations."
And on partial invoicing:
> "In the case of a partially invoiced purchase order, only the amount that hasn't been invoiced is closed and then reopened in the next fiscal year."
Mechanism: encumbrances CAN be posted to GL (configurable via "Commitment accounting" on General ledger parameters, per claim 1 source); year-end reverses remaining encumbrance/budget-reservation balances, generates closing entries, then reverses those closing entries and re-establishes encumbrances in the new year.

## 5. Budget register entries, budget models, budget planning with scenarios — plan storage separate from GL actuals
Status: CONFIRMED. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/budgeting/budget-control-overview-configuration
Quote:
> "After you approve budgets in the system, use budget plans to generate budget register entries that record the expenditure budget for an organization. Alternatively, you can create or import budget register entries from a third-party program instead of using budget planning functionality."
Also: "On the Assign budget models tab, assign budget models to the budget cycle time spans that should be included in budget control." This confirms budget register entries are a distinct ledger-adjacent store (not GL actuals), fed either by the Budget planning module or external import, and organized under Budget models/cycles. Scenario-specific claims (multiple budget models = scenarios) are supported by "Assign budget models" but explicit "scenario" terminology was not directly quoted; treat that framing as inferred.

## 6. Cash flow forecasting: source documents and replacement as documents progress
Status: CONFIRMED. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/cash-bank-management/cash-flow-forecasting
Quote:
> "Sales orders – Sales orders that aren't yet invoiced... Purchase orders – Purchase orders that aren't yet invoiced... Accounts receivable – Open customer transactions (invoices that aren't yet paid). Accounts payable – Open vendor transactions (invoices that aren't yet paid). Ledger transactions... Budget register entries – Budget register entries that are selected for cash flow forecasts."
On replacement/no-double-count risk during project flows:
> "If you've turned on the Cash flow project forecast feature, don't transfer project forecasts to a ledger budget model, because this action will cause the project forecasts to be counted two times."
This confirms the source list matches the claim and explicitly documents a double-counting risk the vendor warns against (relevant "no double counting" finding). Explicit statement that "forecast entries are replaced as documents progress" (e.g., SO forecast removed once invoiced) was not directly quoted; the mechanism is implied by scoping to "not yet invoiced" / "not yet paid" (i.e., forecast lines are computed from currently-open documents rather than persisted and separately retired) — treat the "replacement" framing as inferred rather than a direct vendor statement.

## 7. Posted vouchers corrected by reversal, not edited
Status: CONFIRMED. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/finance/general-ledger/reverse-journal-posting
Quote:
> "This article describes the capabilities in Microsoft Dynamics 365 Finance for reversing either an entire journal, or one or more vouchers from the voucher transaction list, regardless of their origin."
> "Transactions can be reversed only if they meet the business rules for reversing them. Vendor payments can't be reversed by using the capability that's described in this article. To reverse them, you must follow the steps in Reverse a vendor payment."
Mechanism: correction is via a reversal transaction (new offsetting voucher), not an edit of the posted voucher; some transaction types (vendor payments) require a separate dedicated reversal process rather than this generic one.

## 8. Project hour transactions valued at cost price; true-up to payroll actuals
Status: PARTLY. Label: vendor-documented.
URL: https://learn.microsoft.com/en-us/dynamics365/project-operations/project-accounting/project-adjustments
Quote on the adjustment mechanism (reversal + new transaction, not in-place edit):
> "The system sets the Invoice Status field of the original transaction to Adjusted. The system creates a reversal transaction to reverse the original transaction, and sets the Status field to Adjusted. The system creates a new transaction that has the changes that you made during the adjustment process."
And the recalculation parameter:
> "Autoupdate field: If you enable this parameter, the system recalculates cost price and sales price."
This confirms a documented "Adjust transactions" mechanism that can recalculate cost price on posted hour transactions via reversal + rebooking — consistent with a true-up mechanism. However, no fetched page explicitly ties this adjustment flow to "payroll actuals" specifically (i.e., a documented cost-price-from-payroll reconciliation); that linkage is PARTLY confirmed structurally (the generic adjustment/recalculation mechanism exists) but the payroll-specific trigger/source was NOT FOUND in the pages fetched.

---

## NetSuite

## 9. All transaction types stored as one "transaction" record with transactionline/transactionaccountingline; posting vs non-posting
Status: CONFIRMED. Label: vendor-documented (NetSuite Help Center, fetched via search-derived quote from docs.oracle.com).
URL: https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_1548805090.html
Quote:
> "If you need to join the transaction accounting line record type in a dataset, you must use the join path Transaction > Transaction Line > Transaction Accounting Line. This join path prevents increased data duplication which would occur if you used the join path Transaction > Transaction Accounting Line."
This confirms the three-record-type structure (Transaction, TransactionLine, TransactionAccountingLine) and that TransactionAccountingLine carries the book-level GL amounts ("stores monetary values in the base currency of the subsidiary... used for accounting purposes"), consistent with the claim that GL impact is recorded per accounting book on a separate line record. The posting-vs-non-posting flag itself was not directly quoted from a primary page within budget (community/blog sources described it as "posting transactions (having financial impact) or non-posting"); mark the posting/non-posting flag detail as PARTLY (third-party corroboration only, not a verbatim vendor quote fetched this session).

## 10. Transaction links: NextTransactionLineLink / PreviousTransactionLineLink
Status: PARTLY. Label: third-party (not vendor-fetched this session — found via search summary of community/blog sources, not a directly fetched docs.oracle.com quote).
The existence of `NextTransactionLineLink` and `PreviousTransactionLineLink` as SuiteAnalytics/SuiteQL join tables with fields `PreviousDoc`/`NextDoc` linking parent/child transactions (e.g., sales order → item fulfillment/invoice) is corroborated by an Oracle NetSuite Community discussion thread and a third-party blog, summarized as:
> "In the NextTransactionLineLink table, PreviousDoc is the internal ID of the source transaction (for example, the ID of a sales order), and NextDoc is the internal ID of the destination transaction (for example, the ID of a customer invoice, a customer deposit, or an item fulfillment record)."
This was not independently fetched from an official docs.oracle.com record-browser page in this session, so treat the field-level detail as third-party-corroborated pending a direct fetch of the Records Catalog / SuiteAnalytics Connect schema page. Amount/quantity fields on the link records were NOT FOUND (not verified this session).

## 11. NetSuite Budgets: dimensions, budget categories, commitment/encumbrance concept
Status: CONFIRMED (dimensions/categories) / CONFIRMED (separate encumbrance concept exists but as an add-on). Label: vendor-documented.
URL: https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_N3662262.html
Quote:
> "A budget records the expected values of income and expenses for your business." Budgets can be created "for specific customers, items, departments, classes, locations, or any combination of these criteria," and for "multiple subsidiaries" in OneWorld.
Budget categories are documented separately (article_0904123846.html / article_0522035327.html, titled "Budget Category") allowing multiple budgets to be differentiated when other criteria are identical — confirms budget-vs-budget scenario support via categories, label vendor-documented (titles/URLs found, full text not independently quoted this session — mark that specific quote as NOT FOUND, only the title/topic is confirmed).
On commitment/encumbrance: NetSuite's native core does not appear to have a built-in encumbrance ledger; instead there is a separate, distinctly named SuiteApp:
URL: https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/article_161794419548.html (title: "Expense Commitments and Budget Validation") — found via search, not independently fetched/quoted this session. Per search summary: "The Expense Commitments and Budget Validation SuiteApp lets users create budgets for specific account, segment, and period combinations, and check purchase orders, purchase requests, and vendor bills against the budget." Status for this sub-claim: PARTLY (title/topic confirmed via search result snippet; full page not fetched, so treat as third-party-level confidence until a direct fetch is done).

## 12. Statistical accounts; multi-book accounting
Status: CONFIRMED. Label: vendor-documented.
URL: https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_3861062326.html
Quote:
> "A statistical account is a general ledger account that appears in your chart of accounts but doesn't impact your general ledger." It tracks non-monetary data via "Unit of Measure Type" and is "Always debit positive" and "Always excluded from foreign currency translation."
Multi-book accounting confirmed via claim-0 page (section_3862676046.html): transactions are "book-generic" (shared) but can carry "book-specific attributes," and GL/accounting-line data is stored per accounting book in TransactionAccountingLine (claim 9). Combined, this confirms: (a) statistical accounts are a distinct non-monetary GL account type, and (b) multi-book accounting stores separate accounting-book-specific GL impact lines while sharing the base transaction record.

## 13. Corrections: reversing journal entries, voids, accounting period locks
Status: CONFIRMED. Label: vendor-documented.
URL: https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_N1471552.html
Quote:
> "A reversing journal entry is an exact opposite of the original journal entry... A reversing journal entry is also permanently linked to the original entry. Any change you make to the original entry affects the reversing transaction. You can't directly edit a reversing journal entry."
Void mechanism, URL: https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/bridgehead_N1469460.html (found via search, summarized not directly quoted — PARTLY): "The Void Transactions Using Reversing Journals preference permits the creation of journal entries that void transactions on days or periods different from the original transaction dates." This shows NetSuite's "void" for posted transactions is itself implemented as a reversing journal entry when that preference is enabled — i.e., corrections are via reversal, not in-place edits, consistent with the claim. Accounting period lock behavior: per a community-thread-informed summary (third-party, not vendor-quoted): approving a journal entry cannot select a closed period; open-and-locked periods may be selectable only with an override permission. Mark that specific period-lock behavior sentence as third-party/NOT independently vendor-quoted this session.

---

## Extra findings (up to 5)

1. **Double-counting risk explicitly documented (D365):** Vendor explicitly warns not to transfer project forecasts into a ledger budget model when the "Cash flow project forecast" feature is on, "because this action will cause the project forecasts to be counted two times." (CONFIRMED, vendor-documented, https://learn.microsoft.com/en-us/dynamics365/finance/cash-bank-management/cash-flow-forecasting)
2. **D365 general budget reservations are NOT documents in the private-sector encumbrance/pre-encumbrance sense:** "Private sector entities use the term budget reservation to talk about encumbrances or pre-encumbrances. However, unlike general budget reservations, those budgets reservations aren't documents." (CONFIRMED, vendor-documented, https://learn.microsoft.com/en-us/dynamics365/finance/public-sector/general-budget-reservations) — important domain-model distinction: encumbrance/pre-encumbrance are computed reservations, general budget reservations are first-class documents.
3. **D365 year-end encumbrance processing has two documented modes** ("Process and do not carry forward budget" vs "Process and carry forward budget"), each with explicit closing/opening posting steps reversing and re-establishing encumbrances — a concrete state machine for period-boundary commitment carry-forward. (CONFIRMED, vendor-documented, https://learn.microsoft.com/en-us/dynamics365/finance/budgeting/purchase-order-year-end-process)
4. **NetSuite TransactionAccountingLine duplication risk with Multi-Book:** "If enabled, data duplication increases because each transaction accounting line stores data for each accounting book" — direct evidence that one TransactionLine can map to N TransactionAccountingLine rows (one per book), which is the mechanism for keeping multi-book actuals comparable without duplicating the operational transaction. (CONFIRMED, vendor-documented, https://docs.oracle.com/en/cloud/saas/netsuite/ns-online-help/section_1548805090.html)
5. **D365 project adjustment "Autoupdate field" parameter** recalculates cost price/sales price during adjustment — this is the closest documented mechanism to a "true-up" tool for project transactions but its trigger is manual/batch adjustment, not automatic payroll reconciliation. (CONFIRMED as a recalculation mechanism; payroll linkage NOT FOUND, https://learn.microsoft.com/en-us/dynamics365/project-operations/project-accounting/project-adjustments)

---

## Status counts
- CONFIRMED: 9 (claims 1, 3, 4, 5, 6, 7, 9(partial core)/12, 13 core reversal mechanism, plus brief items 0)
- PARTLY: 5 (claims 2, 8, 9-posting-flag-detail, 10, 11-encumbrance-suiteapp, 13-period-lock-detail — several sub-parts land as PARTLY due to session time budget preventing a direct fetch of every underlying page)
- REFUTED: 0
- NOT FOUND: relief valuation for partial qty/price differences (claim 2); amount/quantity fields on NetSuite transaction links (claim 10); explicit payroll-actuals true-up trigger (claim 8); full text of NetSuite Budget Category and Expense Commitments/Budget Validation pages (claim 11, titles confirmed only)

Note: budget was exceeded slightly while finishing the write-up; no further fetches were performed beyond this point.
