# 07. Worked example

**Covers:** one fit-out project (P1) and a second project (P2) run through the reference model: every stored record, the plan, the chart of accounts, every result table from a real run, the backward trace, and one koruna of cost walked from request to bank.
**Read it when:** you want to see the rules produce numbers, check an implementation against known results, or explain the design to someone new.
Back to the overview: [README.md](README.md).

All amounts are CZK. The result tables in section 4 are copied from a run of the reference model ([05](05-data-model.md)) on PostgreSQL 18.6, as printed. The run ends with `ALL ASSERTIONS PASSED` (250 assertions, including scenario probes run in rolled-back transactions). Figures quoted as "asserted" are values the run checks and confirms.

---

## 1. Setting

- **P1** "Office fit-out for Client X": a fixed-price contract in three milestones. **P2** "Other project" only receives labour.
- Czech VAT: materials at 21 %. Fit-out works (CZ-CPA 41 to 43) between VAT payers fall under reverse charge (VAT Act § 92e), so customer invoices carry no VAT and the subcontractor bills without VAT.
- Reporting dates: 31 March 2026 and 31 May 2026.

---

## 2. Stored records

### 2.1 Shared lists and agreements

| Kind | Records |
| --- | --- |
| Projects | P1 Office fit-out for Client X; P2 Other project |
| Cost center | ADMIN Administration (not used by the main run) |
| Categories | `revenue` (revenue, Contract revenue); `materials`, `subcontracting`, `labour`, `bank_fees` (cost); `taxes` (cash, Tax payments) |
| Counterparties | CLIENT_X Client X s.r.o.; SUPPLIER_A Supplier A s.r.o.; SUPPLIER_B Supplier B s.r.o.; SUPPLIER_C Subcontractor C s.r.o. |
| Agreement | AG-B: self-billing with Supplier B, valid from 2026-05-01, open-ended |
| Employee | E1 Site technician; standard cost rate 500/h from 2026-01-01 |

### 2.2 CRM and Sales

| Record | Content | Dates |
| --- | --- | --- |
| OPP1 | Client X, P1, 1,000,000 at probability 0.60 | opened 02-02; **won** 03-05 |
| OPP2 | Client X, P1, 150,000 at probability 0.50 | opened 04-10; still open |
| SO1 | Client X, P1, from OPP1, payment terms 14 days | 03-05 |
| SO1-M1 / M2 / M3 | 1 × 400,000 / 1 × 300,000 / 1 × 300,000, VAT 0 (reverse charge) | expected 03-31 / 04-30 / 05-31 |
| CI1 (FV-2026-0001) | SO1-M1, 400,000, VAT 0 | issued 03-31, due 04-14 |
| CI2 (FV-2026-0002) | SO1-M2, 300,000, VAT 0 | issued 04-30, due 05-14 |
| CI3 (FV-2026-0003) | extra works agreed on site, **no order line**, 50,000, VAT 0 | issued 05-25, due 06-08 |

### 2.3 Spend and Inventory

| Record | Content | Dates |
| --- | --- | --- |
| MR1 / MR1-1 | P1: 10 steel frames at an estimated 30,000 | 03-10 |
| PO1 / PO1-1 | Supplier A, P1: 6 frames at 32,000, VAT 21 %, terms 30 days | ordered 03-12; delivery 03-25 |
| PO2 / PO2-1 | Supplier B, P1: 2 frames at 29,000, VAT 21 %, terms 30 days | ordered 03-20; delivery 04-02 |
| PO3 / PO3-1 | Subcontractor C, P1: partition walls, 100 % of works at 1,500 per %, VAT 0, terms 30 days | ordered 03-25; expected 04-30 |
| PO4 / PO4-1 | Supplier B, **for stock**, no project: 2 frames at 28,000, VAT 21 %, terms 30 days | ordered 05-18; delivery 05-20 |
| PO5 / PO5-1 | Supplier A, P1: 50 m² insulation panels at 1,000, VAT 21 %, terms 14 days | ordered 04-20; delivery 05-10 |
| OR5 | response **CA** on PO5: PO5-1 accepted as **40 m² at 1,050** | 04-21 |
| ISS1 / ISS1-1 | 1 frame from stock to P1 at average cost 27,500 (stock bought last year, 4 frames) | 04-20 |
| RF1 / RF2 / RF3 | MR1-1 fulfilled by PO1-1 (6), PO2-1 (2), ISS1-1 (1); 1 frame stays open | 03-12 / 03-20 / 04-20 |
| GR1 | PO1-1, 4 frames | 03-25 |
| GR3 | PO2-1, 2 frames | 04-02 |
| GR2 | PO1-1, 2 frames | 04-08 |
| GR5 | PO5-1, 40 m² | 05-10 |
| GR4 | PO4-1, 2 frames into stock | 05-20 |

**Supplier invoices** (all for P1 unless stated)

| Invoice | Number | Line links to | Qty | Net | VAT | Issued / due / recorded | Notes |
| --- | --- | --- | --: | --: | --: | --- | --- |
| VB1 | A-26-0331 | GR1-1 | 4 | 128,000 | 26,880 | 03-31 / 04-30 / **04-03** | reaches the system late |
| VB3 | B-2026-044 | GR3-1 | 2 | 59,000 | 12,390 | 04-05 / 05-05 / 04-05 | 29,500 per frame against an order at 29,000; **needs approval: UQ 04-06, AP 04-12** |
| VB2 | A-26-0415 | GR2-1 | 2 | 64,000 | 13,440 | 04-15 / 05-15 / 04-15 | |
| VB2C | A-26-0428-D | corrects VB2-1 | 0 | 2,000 | 420 | 04-28 / 05-15 / 04-28 | corrective tax document: price +1,000 per frame |
| VB4 | C-2026-12 | PO3-1 (no receipt) | 60 | 90,000 | 0 | 04-30 / 05-30 / 05-04 | 60 % of the subcontract; self-assessed VAT 18,900 |
| VB7 | A-26-0512 | GR5-1 | 40 | 42,000 | 8,820 | 05-12 / 05-26 / 05-12 | PO5 at accepted terms, 40 × 1,050 |
| VB5 | SB-2026-001 | GR4-1 | 2 | 56,000 | 11,760 | 05-22 / 06-21 / 05-22 | stock purchase, no project, **self-billed by us** under AG-B |
| VB6 | A-26-0525 | GR2-1 | 2 | 64,000 | 13,440 | 05-25 / 06-24 / 05-26 | duplicate of VB2 under a new number; needs approval; **rejected RE 05-27** |

### 2.4 People

| Record | Content | Dates (worked / recorded) |
| --- | --- | --- |
| TS1 | E1, P1, 40 h | 03-20 / 03-20 |
| TS2 | E1, P2, 120 h | 03-20 / 03-20 |
| TS3 | E1, P1, 80 h | 04-15 / 04-15 |
| TS4 | E1, internal (no project), 80 h | 04-15 / 04-15 |
| TS5 | E1, P1, 6 h | 05-26 / 05-26 |
| TS6 | E1, P1, 8 h (wrong project) | 05-27 / 05-27 |
| TS6R | E1, P1, −8 h, reverses TS6 | 05-27 / 05-28 |
| TS7 | E1, P2, 8 h (the correct booking) | 05-27 / 05-28 |

| Payroll | Content | Posted / paid |
| --- | --- | --- |
| PR-2026-03 | E1 employer cost 88,000; one company-level labour cost line of 88,000 | 04-10 / 04-12 |
| PR-2026-04 | E1 employer cost 84,800; one company-level labour cost line of 84,800 | 05-10 / 05-12 |
| PA-03-1 / PA-03-2 | March cost line re-attributed: TS1 40 h 22,000; TS2 120 h 66,000 (actual rate 88,000 / 160 h = 550) | recorded 04-10 |
| PA-04-1 / PA-04-2 | April cost line re-attributed: TS3 80 h 42,400; TS4 80 h 42,400 (84,800 / 160 h = 530) | recorded 05-10 |

### 2.5 Treasury

Bank account BA1 "Main current account".

| Bank line | Booked | Amount | Matched to |
| --- | --- | --: | --- |
| BT-PAY-03A | 04-12 | −60,000 | PR-2026-03, 60,000 (net wages) |
| BT-PAY-03B | 04-20 | −28,000 | PR-2026-03, 28,000 (insurance and tax) |
| BT5 | 04-25 | −25,410 | advance on PO5, 25,410 (50 % of accepted gross 50,820) |
| BT3 | 05-05 | −40,000 | VB3, 40,000 (partial) |
| BT-PAY-04 | 05-12 | −84,800 | PR-2026-04, 84,800 |
| BT2 | 05-15 | −234,740 | VB1 154,880; VB2 77,440; VB2C 2,420 |
| BT1 | 05-20 | +550,000 | CI1 400,000; CI2 150,000 (partial) |
| BT6 | 05-26 | −25,410 | VB7, 25,410 (balance) |

AA1: the PO5 advance (25,410) is applied to VB7 on 05-12. Every match is recorded on its bank line's date.

---

## 3. Plan and chart of accounts

**Plan lines** (P1, P&L family, by month)

| Category | Mar | Apr | May | B1 total | S1 total |
| --- | --: | --: | --: | --: | --: |
| revenue | 400,000 | 300,000 | 300,000 | 1,000,000 | 1,000,000 |
| materials | 200,000 | 150,000 | | 350,000 | 350,000 |
| subcontracting | | 100,000 | 50,000 | 150,000 | 150,000 |
| labour | 40,000 | 40,000 | 40,000 | 120,000 | 150,000 |

- **B1** "Budget 2026" (budget).
- **S1** "Budget 2026, labour +25 %" (scenario, based on B1): a copy of B1 with labour × 1.25 (50,000 per month).

**Chart of accounts** (Czech chart groups; codes are illustrative only)

| Code | Name | Mapped category | Used in the main run |
| --- | --- | --- | --- |
| 112 | Material in stock | none | yes |
| 221 | Bank accounts (ledger account of BA1) | none | yes |
| 261 | Cash in transit | none | probes only |
| 311 | Trade receivables | none | yes |
| 314 | Advances paid | none | yes |
| 321 | Trade payables | none | yes |
| 331 | Payroll liabilities (simplified) | none | yes |
| 342 | Other direct taxes | taxes | probes only |
| 343 | VAT | none | yes |
| 383 | Accrued expenses | none | probes only |
| 501 | Material consumed | materials | yes |
| 518 | Services: subcontracted works | subcontracting | yes |
| 521 | Personnel costs (simplified) | labour | yes |
| 568 | Other financial costs | bank_fees | probes only |
| 602 | Revenue from services | revenue | yes |
| 701 | Opening balance account | none | yes |

Opening balance OB-2026 (internal document, 01-01): Dr 112 110,000; Dr 221 500,000; Cr 701 610,000.

---

## 4. Results

### 4.1 Positions for P1 on 31 May 2026 (one query, every stage)

| family | category_id | expected | expected_weighted | committed | incurred | actual | forecast | open | settled |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cash | labour |  |  |  |  |  | -3000.00 | 0.00 | -64400.00 |
| cash | materials |  |  |  |  |  | 0.00 | -31390.00 | -325560.00 |
| cash | revenue |  |  |  |  |  | 300000.00 | 200000.00 | 550000.00 |
| cash | subcontracting |  |  |  |  |  | -60000.00 | -90000.00 |  |
| cost | labour |  |  |  | 3000.00 | 64400.00 |  |  |  |
| cost | materials | 30000.00 | 30000.0000 | 0.00 | 0.00 | 322500.00 |  |  |  |
| cost | subcontracting |  |  | 60000.00 |  | 90000.00 |  |  |  |
| revenue | revenue | 150000.00 | 75000.0000 | 300000.00 |  | 750000.00 |  |  |  |

- Cash totals for P1 (asserted): settled 160,040, open 78,610, forecast 237,000.
- Materials across all stages come to 352,500, with no unit counted twice:

| Item | Amount |
| --- | --: |
| 6 frames × 32,000 | 192,000 |
| corrective invoice VB2C | 2,000 |
| 2 frames × 29,500 | 59,000 |
| 1 frame from stock | 27,500 |
| 40 m² insulation × 1,050 | 42,000 |
| 1 frame still open at the 30,000 estimate | 30,000 |
| **Total** | **352,500** |

### 4.2 Budget control and estimate at completion, P1, budget B1

| category_id | plan | expected | committed | incurred | actual | consumed | available | remaining_plan | estimate_at_completion |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| revenue | 1000000.00 | 150000.00 | 300000.00 | 0 | 750000.00 | 1050000.00 | -50000.00 | 0 | 1050000.00 |
| labour | 120000.00 | 0 | 0 | 3000.00 | 64400.00 | 67400.00 | 52600.00 | 52600.00 | 120000.00 |
| materials | 350000.00 | 30000.00 | 0.00 | 0.00 | 322500.00 | 352500.00 | -2500.00 | 0 | 352500.00 |
| subcontracting | 150000.00 | 0 | 60000.00 | 0 | 90000.00 | 150000.00 | 0.00 | 0.00 | 150000.00 |

The supplier's price change on PO5 shows up as a materials overrun of 2,500 before any invoice arrives.

### 4.3 Same, scenario S1 (labour +25 %): only the uncommitted remainder changes

| category_id | plan | consumed | remaining_plan | estimate_at_completion |
| --- | --- | --- | --- | --- |
| revenue | 1000000.00 | 1050000.00 | 0 | 1050000.00 |
| labour | 150000.00 | 67400.00 | 82600.00 | 150000.00 |
| materials | 350000.00 | 352500.00 | 0 | 352500.00 |
| subcontracting | 150000.00 | 150000.00 | 0.00 | 150000.00 |

### 4.4 Project P&L for P1 on 31 May 2026

| revenue_actual | cost_actual | cost_incurred_not_booked | margin_to_date | margin_at_completion |
| --- | --- | --- | --- | --- |
| 750000.00 | 476900.00 | 3000.00 | 270100.00 | 427500.00 |

`margin_at_completion` uses the B1 estimate at completion.

### 4.5 Budget vs actual by month, P1

| category_id | period_month | budget | actual | incurred |
| --- | --- | --- | --- | --- |
| labour | 2026-03-01 | 40000.00 | 22000.00 | 0.00 |
| labour | 2026-04-01 | 40000.00 | 42400.00 | 0.00 |
| labour | 2026-05-01 | 40000.00 | 0 | 3000.00 |
| materials | 2026-03-01 | 200000.00 | 128000.00 | 0.00 |
| materials | 2026-04-01 | 150000.00 | 152500.00 | 0.00 |
| materials | 2026-05-01 | 0 | 42000.00 | 0.00 |
| revenue | 2026-03-01 | 400000.00 | 400000.00 | 0 |
| revenue | 2026-04-01 | 300000.00 | 300000.00 | 0 |
| revenue | 2026-05-01 | 300000.00 | 50000.00 | 0 |
| subcontracting | 2026-04-01 | 100000.00 | 90000.00 | 0 |
| subcontracting | 2026-05-01 | 50000.00 | 0 | 0 |

### 4.6 "What was committed on 31 March?": as reported then vs as known on 31 May, P1 cost

| view | category_id | expected | committed | incurred | actual |
| --- | --- | --- | --- | --- | --- |
| as reported 2026-03-31 | labour |  |  | 20000.00 |  |
| as reported 2026-03-31 | materials | 60000.00 | 122000.00 | 128000.00 |  |
| as reported 2026-03-31 | subcontracting |  | 150000.00 |  |  |
| as known 2026-05-31 | labour |  |  | 0.00 | 22000.00 |
| as known 2026-05-31 | materials | 60000.00 | 122000.00 | 0.00 | 128000.00 |
| as known 2026-05-31 | subcontracting |  | 150000.00 |  |  |

On 31 March the late invoice VB1 (recorded 3 April) and March payroll (posted 10 April) were not yet known. As known on 31 May, the same valid date shows them as actual.

### 4.7 Cash by cash-date month, P1 and company

Settled = bank, open = invoices and payroll, forecast = orders and hours.

| cash_month | stage | p1 | company |
| --- | --- | --- | --- |
| 2026-04-01 | settled | -47410.00 | -113410.00 |
| 2026-05-01 | forecast | -60000.00 | -60000.00 |
| 2026-05-01 | open | 28610.00 | 28610.00 |
| 2026-05-01 | settled | 207450.00 | 165050.00 |
| 2026-06-01 | forecast | 297000.00 | 293000.00 |
| 2026-06-01 | open | 50000.00 | -17760.00 |

- April settled includes the PO5 advance (−25,410).
- May open: CI2 150,000 unpaid; VB3 −31,390 and VB4 −90,000, both overdue.
- May forecast: the subcontract remainder (40 % of PO3).
- June open: CI3 50,000; VB5 −67,760 (company only).
- June forecast: milestone M3 300,000; May hours not yet in payroll, −3,000 (P1) and −4,000 (P2).
- Company settled over all months = 51,640, which equals the bank movements. Ledger bank = 551,640 (opening 500,000 + 51,640).
- PO5's total cash exposure is −50,820 on 30 April (advance paid, rest forecast) and on 31 May (all settled): asserted. The advance never double-counts.

### 4.8 Statutory trial balance

| account_code | name | balance |
| --- | --- | --- |
| 112 | Material in stock | 138500.00 |
| 221 | Bank accounts | 551640.00 |
| 311 | Trade receivables | 200000.00 |
| 314 | Advances paid | 0.00 |
| 321 | Trade payables | -189150.00 |
| 331 | Payroll liabilities (simplified) | 0.00 |
| 343 | VAT | 73710.00 |
| 501 | Material consumed | 322500.00 |
| 518 | Services: subcontracted works | 90000.00 |
| 521 | Personnel costs (simplified) | 172800.00 |
| 602 | Revenue from services | -750000.00 |
| 701 | Opening balance account | -610000.00 |

The reverse-charge VAT on VB4 (18,900) is declared and deducted in the same entry, so it nets to zero in 343.

### 4.9 Reconciliation: management actuals vs ledger by project, category, month

| project_id | category_id | period_month | management | ledger | difference | adjustment | reasons |
| --- | --- | --- | --- | --- | --- | --- | --- |
| - | labour | 2026-03-01 | 0.00 | 0.00 | 0.00 |  |  |
| - | labour | 2026-04-01 | 42400.00 | 42400.00 | 0.00 |  |  |
| P1 | labour | 2026-03-01 | 22000.00 | 22000.00 | 0.00 |  |  |
| P1 | labour | 2026-04-01 | 42400.00 | 42400.00 | 0.00 |  |  |
| P1 | materials | 2026-03-01 | 128000.00 | 128000.00 | 0.00 |  |  |
| P1 | materials | 2026-04-01 | 152500.00 | 152500.00 | 0.00 |  |  |
| P1 | materials | 2026-05-01 | 42000.00 | 42000.00 | 0.00 |  |  |
| P1 | revenue | 2026-03-01 | 400000.00 | 400000.00 | 0.00 |  |  |
| P1 | revenue | 2026-04-01 | 300000.00 | 300000.00 | 0.00 |  |  |
| P1 | revenue | 2026-05-01 | 50000.00 | 50000.00 | 0.00 |  |  |
| P1 | subcontracting | 2026-04-01 | 90000.00 | 90000.00 | 0.00 |  |  |
| P2 | labour | 2026-03-01 | 66000.00 | 66000.00 | 0.00 |  |  |

- Every row has zero difference.
- `adjustment` shows management-only adjustments (FP&A records that never post) and `reasons` their reason codes. The example has none. A rolled-back probe adds an imputed cost on P1 labour with reason `imputed_cost`; the reconciliation shows it as the adjustment, and the difference stays zero (asserted).
- The zero row for company labour in March comes from how payroll posts. The payroll run posts its cost lines in full at company level. Each payroll allocation then posts its own reclass entry, which moves its part to the project of the hours. All of March payroll (88,000) is allocated to P1 and P2, so company labour in March is 0 in both books.

### 4.10 Timesheet correction: TS6 on the wrong project, reversed on 28 May

| known_on | p1_labour_incurred_may |
| --- | --- |
| 2026-05-27 | 7000.00 |
| 2026-05-31 | 3000.00 |

### 4.11 Responses in time

| document | id | response_code | responded_on | accepted_quantity | accepted_price |
| --- | --- | --- | --- | --- | --- |
| order | PO5 | CA | 2026-04-21 | 40.0000 | 1050.00 |
| supplier invoice | VB3 | UQ | 2026-04-06 |  |  |
| supplier invoice | VB3 | AP | 2026-04-12 |  |  |
| supplier invoice | VB6 | RE | 2026-05-27 |  |  |

- **PO5 committed** (asserted): 50,000 as known on 20 April (as ordered); 42,000 from 21 April (as accepted).
- **P1 materials incurred on 10 April** (asserted): 122,000 as known on 10 April (GR2 and GR3, because VB3 was under query); 64,000 as known on 12 April, after VB3 was accepted.
- **VB6 (rejected):** zero positions and zero ledger entries (asserted).

### 4.12 Backward trace: journal line → source record → order → CRM opportunity

| journal_entry_id | account_code | project_id | source_type | source_id | order_type | order_id | opportunity_id |
| --- | --- | --- | --- | --- | --- | --- | --- |
| customer_invoice:CI1 | 602 | P1 | customer_invoice | CI1 | sales_order | SO1 | OPP1 |
| customer_invoice:CI2 | 602 | P1 | customer_invoice | CI2 | sales_order | SO1 | OPP1 |
| customer_invoice:CI3 | 602 | P1 | customer_invoice | CI3 |  |  |  |

CI3 has no order line (extra works), so its trace ends at the invoice. This is also exactly what an invoice registered by Accounting sold alone looks like: it counts once, posts and reconciles.

---

## 5. One koruna of cost, from request to bank

Follow the first frame delivered on P1.

1. **Request, 10 March.** MR1 asks for 10 frames at an estimated 30,000. Spend's rule writes `cost / expected` +300,000.
2. **Order, 12 March.** PO1 orders 6 frames at 32,000, and the link RF1 says 6 of the request are fulfilled. The request is relieved at **its own** estimate: `expected` −180,000. The order books its own price: `committed` +192,000, and `cash / forecast` −232,320 (gross) dated 24 April (delivery 25 March + 30 days).
3. **Receipt, 25 March.** GR1 receives 4 frames. At the accepted order price: `committed` −128,000, `incurred` +128,000. On 31 March, as reported then, this is the 128,000 of materials incurred in table 4.6.
4. **Invoice, dated 31 March, recorded 3 April.** VB1 bills the 4 frames (128,000 + 26,880 VAT) against GR1. It needs no approval, so it counts from registration on 3 April. `incurred` −128,000 at the order price; `actual` +128,000 at the invoice price (no variance here). Cash: the order forecast is relieved +154,880 at the order's cash date, and a payable opens: `open` −154,880 due 30 April. The ledger posts Dr 501 128,000, Dr 343 26,880, Cr 321 154,880, with the entry pointing to VB1. The VAT can be deducted in the April return at the earliest.
5. **Payment, 15 May.** BT2 pays 234,740; the match PAY-VB1 takes 154,880 of it. `open` +154,880 at the due date, `settled` −154,880 at 15 May. The ledger posts Dr 321 / Cr 221 154,880.

At every moment the koruna sits in exactly one cost stage, and as known on 31 May it is actual on 31 March (table 4.6). Backwards, the journal entry for VB1 points to VB1, whose line points to GR1, then to PO1-1, then through RF1 to MR1.

---

## 6. The checks catch broken rules

The checks were validated by deliberately breaking each rule of the model, one mutation at a time, covering relief valuation, the approval gate, advances, registration uniqueness, payroll, bank lines, cash dates, dimensions of reliefs, supplier responses, accruals, proformas and the recorded time of late links. Every broken rule was caught by at least one assertion, and the unmodified model passes all 250.
