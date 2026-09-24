-- Worked example: project P1 "Office fit-out for Client X", amounts in CZK.
-- Czech VAT: materials at 21 %; fit-out works (CZ-CPA 41-43) between VAT payers
-- fall under reverse charge (section 92e of Act 235/2004 Coll.), so customer invoices carry no VAT.
set search_path = finance_model;

insert into project values
    ('P1', 'Office fit-out for Client X'),
    ('P2', 'Other project');

insert into cost_center values ('ADMIN', 'Administration');

insert into category values
    ('revenue', 'revenue', 'Contract revenue'),
    ('materials', 'cost', 'Materials'),
    ('subcontracting', 'cost', 'Subcontracted works'),
    ('labour', 'cost', 'Labour'),
    ('bank_fees', 'cost', 'Bank fees'),
    ('taxes', 'cash', 'Tax payments');

insert into counterparty values
    ('CLIENT_X', 'Client X s.r.o.'),
    ('SUPPLIER_A', 'Supplier A s.r.o.'),
    ('SUPPLIER_B', 'Supplier B s.r.o.'),
    ('SUPPLIER_C', 'Subcontractor C s.r.o.');

-- Self-billing arrangement: we issue Supplier B's invoices for stock deliveries we receive.
insert into agreement values ('AG-B', 'SUPPLIER_B', 'self_billing', '2026-05-01', null);

insert into employee values ('E1', 'Site technician');
insert into employee_cost_rate values ('E1', '2026-01-01', 500);

-- CRM: one won inquiry, one open inquiry that must never count as earned revenue.
insert into opportunity values
    ('OPP1', 'CLIENT_X', 'P1', 'revenue', 1000000, 0.60, '2026-02-02', '2026-02-02'),
    ('OPP2', 'CLIENT_X', 'P1', 'revenue', 150000, 0.50, '2026-04-10', '2026-04-10');
insert into opportunity_outcome values ('OPP1', 'won', '2026-03-05', '2026-03-05');

-- Sales: fixed-price contract in three milestones.
insert into sales_order values ('SO1', 'CLIENT_X', 'P1', 'OPP1', '2026-03-05', '2026-03-05', 14);
insert into sales_order_line values
    ('SO1-M1', 'SO1', 'revenue', 'Milestone 1', 1, 400000, 0, '2026-03-31'),
    ('SO1-M2', 'SO1', 'revenue', 'Milestone 2', 1, 300000, 0, '2026-04-30'),
    ('SO1-M3', 'SO1', 'revenue', 'Milestone 3', 1, 300000, 0, '2026-05-31');
-- CI3 bills extra works agreed on site without an order line.
insert into customer_invoice values
    ('CI1', 'CLIENT_X', '2026-03-31', '2026-04-14', '2026-03-31', 'FV-2026-0001'),
    ('CI2', 'CLIENT_X', '2026-04-30', '2026-05-14', '2026-04-30', 'FV-2026-0002'),
    ('CI3', 'CLIENT_X', '2026-05-25', '2026-06-08', '2026-05-25', 'FV-2026-0003');
insert into customer_invoice_line values
    ('CI1-1', 'CI1', 'SO1-M1', 'P1', 'revenue', 1, 400000, 0),
    ('CI2-1', 'CI2', 'SO1-M2', 'P1', 'revenue', 1, 300000, 0),
    ('CI3-1', 'CI3', null, 'P1', 'revenue', 1, 50000, 0);

-- Procurement: one site request (10 frames, estimated 30 000 each) becomes
-- two orders at different prices, one stock issue, and one frame still open.
insert into material_request values ('MR1', 'P1', '2026-03-10', '2026-03-10');
insert into material_request_line values ('MR1-1', 'MR1', 'steel frame', 'materials', 10, 30000);

-- PO3 is a subcontract for fit-out works (reverse charge on our input side), billed
-- by progress without goods receipts. PO4 replenishes stock: an asset, not project cost.
insert into purchase_order values
    ('PO1', 'SUPPLIER_A', '2026-03-12', '2026-03-12', 30),
    ('PO2', 'SUPPLIER_B', '2026-03-20', '2026-03-20', 30),
    ('PO3', 'SUPPLIER_C', '2026-03-25', '2026-03-25', 30),
    ('PO4', 'SUPPLIER_B', '2026-05-18', '2026-05-18', 30),
    ('PO5', 'SUPPLIER_A', '2026-04-20', '2026-04-20', 14);
insert into purchase_order_line values
    ('PO1-1', 'PO1', 'steel frame', 'P1', false, 'materials', 6, 32000, 0.21, '2026-03-25'),
    ('PO2-1', 'PO2', 'steel frame', 'P1', false, 'materials', 2, 29000, 0.21, '2026-04-02'),
    ('PO3-1', 'PO3', 'partition walls, % of works', 'P1', false, 'subcontracting', 100, 1500, 0, '2026-04-30'),
    ('PO4-1', 'PO4', 'steel frame', null, true, 'materials', 2, 28000, 0.21, '2026-05-20'),
    ('PO5-1', 'PO5', 'insulation panels, m2', 'P1', false, 'materials', 50, 1000, 0.21, '2026-05-10');

-- Supplier A accepts PO5 with changes: 40 m2 instead of 50, at 1 050 instead of 1 000.
insert into order_response values ('OR5', 'PO5', 'CA', '2026-04-21', '2026-04-21');
insert into order_response_line values ('OR5', 'PO5-1', 40, 1050);

-- Stock bought last year (4 frames at average cost 27 500) is an asset until issued.
insert into stock_issue values ('ISS1', 'P1', '2026-04-20', '2026-04-20');
insert into stock_issue_line values ('ISS1-1', 'ISS1', 'steel frame', 'materials', 1, 27500);

insert into request_fulfilment values
    ('RF1', 'MR1-1', 'PO1-1', null, 6),
    ('RF2', 'MR1-1', 'PO2-1', null, 2),
    ('RF3', 'MR1-1', null, 'ISS1-1', 1);

-- Partial deliveries straight to site.
insert into goods_receipt values
    ('GR1', '2026-03-25', '2026-03-25'),
    ('GR3', '2026-04-02', '2026-04-02'),
    ('GR2', '2026-04-08', '2026-04-08'),
    ('GR4', '2026-05-20', '2026-05-20'),
    ('GR5', '2026-05-10', '2026-05-10');
insert into goods_receipt_line values
    ('GR1-1', 'GR1', 'PO1-1', 4),
    ('GR3-1', 'GR3', 'PO2-1', 2),
    ('GR2-1', 'GR2', 'PO1-1', 2),
    ('GR4-1', 'GR4', 'PO4-1', 2),
    ('GR5-1', 'GR5', 'PO5-1', 40);

-- Supplier invoices. VB1 is dated 31 March but reaches the system on 3 April.
-- VB3 is invoiced at 29 500 per frame against an order at 29 000.
-- VB2C is a corrective tax document: the supplier raised the price by 1 000 per frame.
-- VB4 bills 60 % of the subcontract without VAT (section 92e); we self-assess 21 %.
-- VB3 needs approval: queried on 6 April (price above order), accepted on 12 April.
-- VB6 bills VB2's delivery again under a new number and is rejected: it never counts.
-- VB5 is self-billed by us.
insert into supplier_invoice values
    ('VB1', 'SUPPLIER_A', '2026-03-31', '2026-04-30', '2026-04-03', false, null, 'A-26-0331'),
    ('VB3', 'SUPPLIER_B', '2026-04-05', '2026-05-05', '2026-04-05', true, null, 'B-2026-044'),
    ('VB2', 'SUPPLIER_A', '2026-04-15', '2026-05-15', '2026-04-15', false, null, 'A-26-0415'),
    ('VB2C', 'SUPPLIER_A', '2026-04-28', '2026-05-15', '2026-04-28', false, null, 'A-26-0428-D'),
    ('VB4', 'SUPPLIER_C', '2026-04-30', '2026-05-30', '2026-05-04', false, null, 'C-2026-12'),
    ('VB5', 'SUPPLIER_B', '2026-05-22', '2026-06-21', '2026-05-22', false, 'AG-B', 'SB-2026-001'),
    ('VB6', 'SUPPLIER_A', '2026-05-25', '2026-06-24', '2026-05-26', true, null, 'A-26-0525'),
    ('VB7', 'SUPPLIER_A', '2026-05-12', '2026-05-26', '2026-05-12', false, null, 'A-26-0512');
insert into supplier_invoice_line values
    ('VB1-1', 'VB1', 'GR1-1', null, null, 'P1', 'materials', 4, 128000, 26880, 0),
    ('VB3-1', 'VB3', 'GR3-1', null, null, 'P1', 'materials', 2, 59000, 12390, 0),
    ('VB2-1', 'VB2', 'GR2-1', null, null, 'P1', 'materials', 2, 64000, 13440, 0),
    ('VB2C-1', 'VB2C', null, null, 'VB2-1', 'P1', 'materials', 0, 2000, 420, 0),
    ('VB4-1', 'VB4', null, 'PO3-1', null, 'P1', 'subcontracting', 60, 90000, 0, 18900),
    ('VB5-1', 'VB5', 'GR4-1', null, null, null, 'materials', 2, 56000, 11760, 0),
    ('VB6-1', 'VB6', 'GR2-1', null, null, 'P1', 'materials', 2, 64000, 13440, 0),
    ('VB7-1', 'VB7', 'GR5-1', null, null, 'P1', 'materials', 40, 42000, 8820, 0);
insert into invoice_response values
    ('IR-VB3-1', 'VB3', 'UQ', '2026-04-06', '2026-04-06'),
    ('IR-VB3-2', 'VB3', 'AP', '2026-04-12', '2026-04-12'),
    ('IR-VB6-1', 'VB6', 'RE', '2026-05-27', '2026-05-27');

-- People: hours at the standard rate of 500 per hour, then payroll actuals.
-- TS6 was booked to the wrong project and corrected by a reversal plus a new entry.
insert into timesheet_entry values
    ('TS1', 'E1', 'P1', '2026-03-20', 40, null, '2026-03-20'),
    ('TS2', 'E1', 'P2', '2026-03-20', 120, null, '2026-03-20'),
    ('TS3', 'E1', 'P1', '2026-04-15', 80, null, '2026-04-15'),
    ('TS4', 'E1', null, '2026-04-15', 80, null, '2026-04-15'),
    ('TS5', 'E1', 'P1', '2026-05-26', 6, null, '2026-05-26'),
    ('TS6', 'E1', 'P1', '2026-05-27', 8, null, '2026-05-27'),
    ('TS6R', 'E1', 'P1', '2026-05-27', -8, 'TS6', '2026-05-28'),
    ('TS7', 'E1', 'P2', '2026-05-27', 8, null, '2026-05-28');

insert into payroll_run values
    ('PR-2026-03', '2026-03-01', '2026-04-10', '2026-04-12'),
    ('PR-2026-04', '2026-04-01', '2026-05-10', '2026-05-12');
insert into payroll_line values
    ('PL-03-E1', 'PR-2026-03', 'E1', 88000),
    ('PL-04-E1', 'PR-2026-04', 'E1', 84800);
-- Payroll's own cost lines (company level), then re-attributed by the hours worked.
insert into payroll_cost_line values
    ('PC-03-E1', 'PL-03-E1', 'labour', null, null, 88000),
    ('PC-04-E1', 'PL-04-E1', 'labour', null, null, 84800);
-- Actual rate: March 88 000 / 160 h = 550; April 84 800 / 160 h = 530.
insert into payroll_allocation values
    ('PA-03-1', 'PC-03-E1', 'TS1', 40, 22000),
    ('PA-03-2', 'PC-03-E1', 'TS2', 120, 66000),
    ('PA-04-1', 'PC-04-E1', 'TS3', 80, 42400),
    ('PA-04-2', 'PC-04-E1', 'TS4', 80, 42400);

-- Treasury: one supplier payment settles three documents, one invoice is paid in part,
-- one customer payment settles one invoice in full and another in part,
-- March payroll is paid in two transfers (net wages, then insurance and tax).
insert into bank_account values ('BA1', 'Main current account');
insert into bank_transaction values
    ('BT-PAY-03A', 'BA1', '2026-04-12', -60000, 'Payroll March, net wages', '2026-04-12'),
    ('BT-PAY-03B', 'BA1', '2026-04-20', -28000, 'Payroll March, insurance and tax', '2026-04-20'),
    ('BT3', 'BA1', '2026-05-05', -40000, 'Supplier B, partial', '2026-05-05'),
    ('BT-PAY-04', 'BA1', '2026-05-12', -84800, 'Payroll April', '2026-05-12'),
    ('BT2', 'BA1', '2026-05-15', -234740, 'Supplier A', '2026-05-15'),
    ('BT1', 'BA1', '2026-05-20', 550000, 'Client X', '2026-05-20'),
    ('BT5', 'BA1', '2026-04-25', -25410, 'Supplier A, 50 % advance on PO5', '2026-04-25'),
    ('BT6', 'BA1', '2026-05-26', -25410, 'Supplier A, VB7 balance', '2026-05-26');
insert into payment_allocation (id, bank_transaction_id, customer_invoice_id, supplier_invoice_id, payroll_run_id, amount) values
    ('PAY-03A', 'BT-PAY-03A', null, null, 'PR-2026-03', 60000),
    ('PAY-03B', 'BT-PAY-03B', null, null, 'PR-2026-03', 28000),
    ('PAY-VB3', 'BT3', null, 'VB3', null, 40000),
    ('PAY-04', 'BT-PAY-04', null, null, 'PR-2026-04', 84800),
    ('PAY-VB1', 'BT2', null, 'VB1', null, 154880),
    ('PAY-VB2', 'BT2', null, 'VB2', null, 77440),
    ('PAY-VB2C', 'BT2', null, 'VB2C', null, 2420),
    ('PAY-CI1', 'BT1', 'CI1', null, null, 400000),
    ('PAY-CI2', 'BT1', 'CI2', null, null, 150000),
    ('PAY-VB7', 'BT6', null, 'VB7', null, 25410);
insert into payment_allocation (id, bank_transaction_id, purchase_order_id, amount) values
    ('PAY-ADV5', 'BT5', 'PO5', 25410);
-- The advance is offset against the final invoice VB7 (50 820 gross).
insert into advance_application values ('AA1', 'PAY-ADV5', 'VB7', 25410, '2026-05-12', '2026-05-12');

-- FP&A: budget and a pessimistic scenario (labour +25 %).
insert into plan_version values
    ('B1', 'Budget 2026', 'budget', null),
    ('S1', 'Budget 2026, labour +25 %', 'scenario', 'B1');
insert into plan_line (plan_version_id, project_id, category_id, period_month, amount_net) values
    ('B1', 'P1', 'revenue', '2026-03-01', 400000),
    ('B1', 'P1', 'revenue', '2026-04-01', 300000),
    ('B1', 'P1', 'revenue', '2026-05-01', 300000),
    ('B1', 'P1', 'materials', '2026-03-01', 200000),
    ('B1', 'P1', 'materials', '2026-04-01', 150000),
    ('B1', 'P1', 'subcontracting', '2026-04-01', 100000),
    ('B1', 'P1', 'subcontracting', '2026-05-01', 50000),
    ('B1', 'P1', 'labour', '2026-03-01', 40000),
    ('B1', 'P1', 'labour', '2026-04-01', 40000),
    ('B1', 'P1', 'labour', '2026-05-01', 40000);
insert into plan_line (plan_version_id, family, project_id, cost_center_id, category_id, period_month, amount_net)
select 'S1', family, project_id, cost_center_id, category_id, period_month,
       case category_id when 'labour' then amount_net * 1.25 else amount_net end
from plan_line where plan_version_id = 'B1';

-- Accounting: chart, the opening balance as an internal document, then the posting run.
insert into account values
    ('112', 'Material in stock', null, null),
    ('221', 'Bank accounts', null, 'BA1'),
    ('261', 'Cash in transit', null, null),
    ('311', 'Trade receivables', null, null),
    ('321', 'Trade payables', null, null),
    ('331', 'Payroll liabilities (simplified)', null, null),
    ('314', 'Advances paid', null, null),
    ('342', 'Other direct taxes', 'taxes', null),
    ('343', 'VAT', null, null),
    ('383', 'Accrued expenses', null, null),
    ('501', 'Material consumed', 'materials', null),
    ('518', 'Services: subcontracted works', 'subcontracting', null),
    ('521', 'Personnel costs (simplified)', 'labour', null),
    ('568', 'Other financial costs', 'bank_fees', null),
    ('602', 'Revenue from services', 'revenue', null),
    ('701', 'Opening balance account', null, null);

insert into internal_document values ('OB-2026', '2026-01-01', '2026-01-01', 'Opening balance 2026');
insert into internal_document_line (id, internal_document_id, account_code, debit, credit) values
    ('OB-2026-1', 'OB-2026', '112', 110000, 0),
    ('OB-2026-2', 'OB-2026', '221', 500000, 0),
    ('OB-2026-3', 'OB-2026', '701', 0, 610000);

call post_to_ledger();
