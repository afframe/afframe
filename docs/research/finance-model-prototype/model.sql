-- Finance-first platform: minimal model prototype (PostgreSQL 18).
-- Typed records are the only writable truth. `position_entry` is a derived view:
-- dropping it and re-creating it from the typed records gives identical results.
-- Run: cat model.sql accounting.sql example.sql checks.sql | psql -v ON_ERROR_STOP=1
-- Statutory accounting (journal_entry / journal_line) is a separate book, posted
-- from the same typed records, never from position_entry.

drop schema if exists finance_model cascade;
create schema finance_model;
set search_path = finance_model;

-- ---------------------------------------------------------------------------
-- Shared identities (platform). Every domain may reference them.
-- ---------------------------------------------------------------------------
create table project (
    id text primary key,
    name text not null
);

-- A level under a project (ARCH-1, REDTEAM-2): sales, spend and plan lines may tag it,
-- so milestone P&L and cash are one GROUP BY on the projection.
create table project_milestone (
    id text primary key,
    project_id text not null references project,
    name text not null,
    due_on date not null
);

create table cost_center (
    id text primary key,
    name text not null
);

-- 'cash' categories have no P&L meaning (taxes, loans, own transfers); they serve
-- cash plans and the classification of bank lines.
create table category (
    id text primary key,
    family text not null check (family in ('revenue', 'cost', 'cash')),
    name text not null
);

create table counterparty (
    id text primary key,
    name text not null
);

create table employee (
    id text primary key,
    name text not null
);

-- Date-effective standard cost rate (People). Used for estimates only.
create table employee_cost_rate (
    employee_id text not null references employee,
    valid_from date not null,
    hourly_rate numeric(14, 2) not null,
    primary key (employee_id, valid_from)
);

-- ---------------------------------------------------------------------------
-- Agreements: contracts, framework agreements, self-billing arrangements.
-- ---------------------------------------------------------------------------
create table agreement (
    id text primary key,
    counterparty_id text not null references counterparty,
    kind text not null check (kind in ('contract', 'framework', 'self_billing')),
    valid_from date not null,
    valid_to date
);

-- ---------------------------------------------------------------------------
-- CRM
-- ---------------------------------------------------------------------------
create table opportunity (
    id text primary key,
    counterparty_id text not null references counterparty,
    project_id text references project,
    category_id text not null references category,
    amount_net numeric(14, 2) not null,
    probability numeric(3, 2) not null check (probability between 0 and 1),
    opened_on date not null,
    recorded_on date not null
);

create table opportunity_outcome (
    opportunity_id text primary key references opportunity,
    outcome text not null check (outcome in ('won', 'lost')),
    decided_on date not null,
    recorded_on date not null
);

-- ---------------------------------------------------------------------------
-- Sales
-- ---------------------------------------------------------------------------
create table sales_order (
    id text primary key,
    counterparty_id text not null references counterparty,
    project_id text references project,
    opportunity_id text references opportunity,
    ordered_on date not null,
    recorded_on date not null,
    payment_terms_days integer not null
);

create table sales_order_line (
    id text primary key,
    sales_order_id text not null references sales_order,
    category_id text not null references category,
    description text not null,
    quantity numeric(14, 4) not null,
    unit_price numeric(14, 2) not null,
    vat_rate numeric(4, 2) not null,       -- 0.00 when reverse charge applies
    expected_on date not null,
    milestone_id text references project_milestone
);

create table customer_invoice (
    id text primary key,
    counterparty_id text not null references counterparty,
    issued_on date not null,                -- taxable supply date
    due_on date not null,
    recorded_on date not null,
    document_number text not null unique    -- our number (EN 16931 BT-1)
);

create table customer_invoice_line (
    id text primary key,
    customer_invoice_id text not null references customer_invoice,
    sales_order_line_id text references sales_order_line,
    project_id text references project,
    category_id text not null references category,
    quantity numeric(14, 4) not null,       -- quantity of the order line fulfilled
    amount_net numeric(14, 2) not null,
    vat_amount numeric(14, 2) not null,
    milestone_id text references project_milestone
);

-- ---------------------------------------------------------------------------
-- Procurement
-- ---------------------------------------------------------------------------
create table material_request (
    id text primary key,
    project_id text references project,
    requested_on date not null,             -- approval date
    recorded_on date not null
);

create table material_request_line (
    id text primary key,
    material_request_id text not null references material_request,
    item text not null,
    category_id text not null references category,
    quantity numeric(14, 4) not null,
    estimated_unit_price numeric(14, 2) not null
);

create table purchase_order (
    id text primary key,
    counterparty_id text not null references counterparty,
    ordered_on date not null,
    recorded_on date not null,
    payment_terms_days integer not null
);

create table purchase_order_line (
    id text primary key,
    purchase_order_id text not null references purchase_order,
    item text not null,
    project_id text references project,     -- null = company-level
    to_stock boolean not null default false, -- bought for stock: an asset, not a cost
    category_id text not null references category,
    quantity numeric(14, 4) not null,
    unit_price numeric(14, 2) not null,
    vat_rate numeric(4, 2) not null,        -- 0.00 when reverse charge applies
    expected_on date not null,
    milestone_id text references project_milestone
);

-- Supplier's answer to an order (Peppol Order Response). Without a response the
-- order counts as accepted as ordered. The latest response decides the terms:
-- AB acknowledged (no effect), AP accepted, CA accepted with changes, RE rejected.
create table order_response (
    id text primary key,
    purchase_order_id text not null references purchase_order,
    response_code text not null check (response_code in ('AB', 'AP', 'CA', 'RE')),
    responded_on date not null,
    recorded_on date not null
);

-- Changed lines of a CA response; lines not listed are accepted as ordered.
create table order_response_line (
    order_response_id text not null references order_response,
    purchase_order_line_id text not null references purchase_order_line,
    accepted_quantity numeric(14, 4) not null,
    accepted_unit_price numeric(14, 2) not null,
    primary key (order_response_id, purchase_order_line_id)
);

create table goods_receipt (
    id text primary key,
    received_on date not null,
    recorded_on date not null
);

-- A receipt without an order line is an Inventory receipt into stock.
create table goods_receipt_line (
    id text primary key,
    goods_receipt_id text not null references goods_receipt,
    purchase_order_line_id text references purchase_order_line,
    quantity numeric(14, 4) not null,
    item text,
    check (num_nonnulls(purchase_order_line_id, item) >= 1)
);

create table supplier_invoice (
    id text primary key,
    counterparty_id text not null references counterparty,
    issued_on date not null,                -- taxable supply date
    due_on date not null,
    recorded_on date not null,
    requires_approval boolean not null default false,
    self_billing_agreement_id text references agreement,  -- set when we issued it on the supplier's behalf
    document_number text not null,          -- the supplier's number (EN 16931 BT-1)
    unique (counterparty_id, document_number)  -- each received document is registered once
);

create table supplier_invoice_line (
    id text primary key,
    supplier_invoice_id text not null references supplier_invoice,
    goods_receipt_line_id text references goods_receipt_line,
    purchase_order_line_id text references purchase_order_line,  -- services: invoiced without a receipt
    corrects_line_id text references supplier_invoice_line,  -- corrective tax document; traceability only
    project_id text references project,
    category_id text not null references category,
    quantity numeric(14, 4) not null,       -- quantity invoiced against the receipt or order; 0 on a price correction
    amount_net numeric(14, 2) not null,
    vat_amount numeric(14, 2) not null,     -- VAT charged by the supplier
    self_assessed_vat numeric(14, 2) not null default 0,  -- reverse charge: declared and deducted by us
    to_stock boolean not null default false,  -- bought for stock, known from the invoice itself (ARCH-3)
    milestone_id text references project_milestone,
    check (num_nonnulls(goods_receipt_line_id, purchase_order_line_id) <= 1)
);

-- Goods invoiced before they arrive: the later receipt names the invoice line it
-- delivers (the successor writes the link), so it moves no cost stage.
alter table goods_receipt_line add column supplier_invoice_line_id text references supplier_invoice_line;

-- Our answer to a supplier invoice (Peppol Invoice Response): AB acknowledged,
-- IP in process, UQ under query, CA conditionally accepted, RE rejected,
-- AP accepted, PD paid.
create table invoice_response (
    id text primary key,
    supplier_invoice_id text not null references supplier_invoice,
    response_code text not null check (response_code in ('AB', 'IP', 'UQ', 'CA', 'RE', 'AP', 'PD')),
    responded_on date not null,
    recorded_on date not null
);

-- Supplier advance request (proforma): not a tax document and not a
-- cost; an open payable until paid, then applied to the final invoice. No order needed;
-- a proforma for an order names it and replaces that part of the order's cash forecast.
create table supplier_advance_request (
    id text primary key,
    counterparty_id text not null references counterparty,
    project_id text references project,
    category_id text not null references category,
    amount numeric(14, 2) not null,         -- gross amount requested
    issued_on date not null,
    due_on date not null,
    recorded_on date not null,
    document_number text not null,
    purchase_order_id text references purchase_order,
    unique (counterparty_id, document_number)
);

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------
create table stock_issue (
    id text primary key,
    project_id text references project,
    issued_on date not null,
    recorded_on date not null
);

create table stock_issue_line (
    id text primary key,
    stock_issue_id text not null references stock_issue,
    item text not null,
    category_id text not null references category,
    quantity numeric(14, 4) not null,
    unit_cost numeric(14, 2) not null       -- valuation from the inventory module (average cost)
);

-- Fulfilment of a request line by an order line or a stock issue line (many-to-many).
create table request_fulfilment (
    id text primary key,
    material_request_line_id text not null references material_request_line,
    purchase_order_line_id text references purchase_order_line,
    stock_issue_line_id text references stock_issue_line,
    quantity numeric(14, 4) not null,
    recorded_on date not null,              -- links carry their own time (REDTEAM-1)
    check (num_nonnulls(purchase_order_line_id, stock_issue_line_id) = 1)
);

-- ---------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------
create table timesheet_entry (
    id text primary key,
    employee_id text not null references employee,
    project_id text references project,     -- null = internal work
    worked_on date not null,
    hours numeric(8, 2) not null,           -- negative only on a reversal
    reverses_id text references timesheet_entry,
    recorded_on date not null
);

create table payroll_run (
    id text primary key,
    period_month date not null,             -- first day of the payroll month
    posted_on date not null,
    paid_on date not null
);

create table payroll_line (
    id text primary key,
    payroll_run_id text not null references payroll_run,
    employee_id text not null references employee,
    employer_cost numeric(14, 2) not null   -- gross wage plus employer contributions
);

-- Payroll's own cost lines: they sum to the employer cost and need no timesheets.
create table payroll_cost_line (
    id text primary key,
    payroll_line_id text not null references payroll_line,
    category_id text not null references category,
    project_id text references project,
    cost_center_id text references cost_center,
    amount numeric(14, 2) not null
);

-- Time-based re-attribution: part of a cost line moves to the project of the hours
-- worked, and relieves those hours' incurred estimate.
create table payroll_allocation (
    id text primary key,
    payroll_cost_line_id text not null references payroll_cost_line,
    timesheet_entry_id text not null references timesheet_entry,
    hours numeric(8, 2) not null,
    amount numeric(14, 2) not null,
    recorded_on date not null
);

-- ---------------------------------------------------------------------------
-- Treasury
-- ---------------------------------------------------------------------------
create table bank_account (
    id text primary key,
    name text not null
);

create table bank_transaction (
    id text primary key,
    bank_account_id text not null references bank_account,
    booked_on date not null,
    amount numeric(14, 2) not null,         -- signed: + inflow, - outflow
    description text not null,
    recorded_on date not null
);

create table payment_allocation (
    id text primary key,
    bank_transaction_id text not null references bank_transaction,
    customer_invoice_id text references customer_invoice,
    supplier_invoice_id text references supplier_invoice,
    payroll_run_id text references payroll_run,
    purchase_order_id text references purchase_order,  -- advance paid before any invoice
    supplier_advance_request_id text references supplier_advance_request,  -- advance on a proforma
    amount numeric(14, 2) not null,         -- positive, settled amount
    recorded_on date not null,              -- when the match was made
    check (num_nonnulls(customer_invoice_id, supplier_invoice_id, payroll_run_id, purchase_order_id,
                        supplier_advance_request_id) = 1)
);

-- Expected cash that no document announces yet (tax payment, loan instalment): a
-- Treasury forecast item, relieved by the classified bank lines that pay it.
create table expected_cash (
    id text primary key,
    counterparty_id text references counterparty,
    category_id text references category,
    project_id text references project,
    cost_center_id text references cost_center,
    amount numeric(14, 2) not null,         -- signed: + inflow, - outflow
    cash_on date not null,
    recorded_on date not null,
    description text not null
);

-- ARCH-2: a later document that announces an expected-cash item names it (the successor
-- writes the link), so adding Sales or Procurement relieves it without editing it.
alter table customer_invoice add column expected_cash_id text references expected_cash;
alter table supplier_invoice add column expected_cash_id text references expected_cash;

-- A bank line with no business document (fee, interest, tax or insurance payment,
-- loan, transfer between own accounts), classified by Treasury to a category (its
-- mapped account posts) or straight to an account. A P&L account needs its category too
-- (ARCH-11), so the line counts as management actual; account and category must agree.
create table bank_line_classification (
    id text primary key,
    bank_transaction_id text not null references bank_transaction,
    category_id text references category,
    account_code text,                      -- references account (defined below)
    project_id text references project,
    cost_center_id text references cost_center,
    expected_cash_id text references expected_cash,
    amount numeric(14, 2) not null,         -- signed like the bank line
    recorded_on date not null,
    check (num_nonnulls(category_id, account_code) >= 1)
);

-- An advance offset against the final invoice: a settlement without a bank movement.
create table advance_application (
    id text primary key,
    advance_allocation_id text not null references payment_allocation,
    supplier_invoice_id text not null references supplier_invoice,
    amount numeric(14, 2) not null,
    applied_on date not null,
    recorded_on date not null
);

-- ---------------------------------------------------------------------------
-- FP&A: plans, versions and scenarios (separate store, never mixed with actuals)
-- ---------------------------------------------------------------------------
create table plan_version (
    id text primary key,
    name text not null,
    kind text not null check (kind in ('budget', 'forecast', 'scenario')),
    based_on text references plan_version
);

-- Project and cost center are optional: a line without them is a company-level plan.
-- family 'cash' is a cash plan: signed gross amount, period_month is the cash month.
create table plan_line (
    plan_version_id text not null references plan_version,
    family text not null default 'pnl' check (family in ('pnl', 'cash')),
    project_id text references project,
    cost_center_id text references cost_center,
    category_id text not null references category,
    period_month date not null,
    amount_net numeric(14, 2) not null,
    milestone_id text references project_milestone,
    unique nulls not distinct (plan_version_id, family, project_id, milestone_id, cost_center_id, category_id, period_month)
);

-- FP&A's progress estimate for a project or one of its milestones (ARCH-1): percent
-- complete or estimate to complete, as known on recorded_on. WIP valuation may reference it.
create table project_progress (
    id text primary key,
    project_id text not null references project,
    milestone_id text references project_milestone,
    as_of date not null,
    percent_complete numeric(5, 2) check (percent_complete between 0 and 100),
    estimate_to_complete numeric(14, 2),
    recorded_on date not null,
    check (num_nonnulls(percent_complete, estimate_to_complete) >= 1)
);

-- FP&A's management-only adjustment (ARCH-4, REDTEAM-7), such as an imputed cost: it
-- counts as management actual, never posts to the ledger, and the reconciliation shows
-- it under its reason code.
create table management_adjustment (
    id text primary key,
    project_id text references project,
    milestone_id text references project_milestone,
    cost_center_id text references cost_center,
    category_id text not null references category,
    amount numeric(14, 2) not null,         -- positive = more cost or more revenue
    effective_on date not null,
    recorded_on date not null,
    reason_code text not null,
    description text not null
);

-- ---------------------------------------------------------------------------
-- Accounting (statutory book). Posted, immutable, corrected by new entries.
-- ---------------------------------------------------------------------------
create table account (
    code text primary key,
    name text not null,
    category_id text unique references category,  -- management mapping for reconciliation
    bank_account_id text unique references bank_account,  -- the ledger account of a bank account
    unique (code, category_id)
);

alter table bank_line_classification add foreign key (account_code) references account;
alter table bank_line_classification add foreign key (account_code, category_id) references account (code, category_id);

-- Internal document: the source of every ledger-only posting, such as
-- the opening balance, accruals, WIP or depreciation. A line with a cost or revenue
-- category also counts as management actual.
create table internal_document (
    id text primary key,
    issued_on date not null,
    recorded_on date not null,
    description text not null,
    project_progress_id text references project_progress  -- the estimate a WIP valuation used
);

-- An accrual or WIP line may name the order line, receipt line or sales order line it
-- accrues for (MONEY-10): it then relieves that record's committed or incurred amount
-- instead of adding to it.
create table internal_document_line (
    id text primary key,
    internal_document_id text not null references internal_document,
    account_code text not null references account,
    category_id text references category,
    project_id text references project,
    cost_center_id text references cost_center,
    debit numeric(14, 2) not null default 0,
    credit numeric(14, 2) not null default 0,
    purchase_order_line_id text references purchase_order_line,
    sales_order_line_id text references sales_order_line,
    goods_receipt_line_id text references goods_receipt_line,
    check (num_nonnulls(purchase_order_line_id, goods_receipt_line_id, sales_order_line_id) <= 1)
);

create table journal_entry (
    id text primary key,
    entry_date date not null,
    recorded_on date not null,
    source_type text not null,
    source_id text not null,
    unique (source_type, source_id)
);

create table journal_line (
    id bigint generated always as identity primary key,
    journal_entry_id text not null references journal_entry,
    account_code text not null references account,
    project_id text references project,
    debit numeric(14, 2) not null default 0,
    credit numeric(14, 2) not null default 0
);

-- ---------------------------------------------------------------------------
-- Management projection. Nobody writes to it: it is a pure function of typed
-- records and links. Each domain contributes one always-active view with the rules
-- for the record types and links it owns; the platform unions them.
-- family  cost | revenue : amounts are net, positive = cost or revenue
-- family  cash           : amounts are gross, signed (+ in, - out), dated by cash_on
-- stage   expected -> committed -> incurred -> actual   (cost, revenue)
--         forecast -> open -> settled                    (cash)
-- A successor relieves its predecessor at the predecessor's own valuation
-- (quantity x predecessor price), so an open remainder keeps its estimate.
-- A cash relief carries the cash date of what it relieves, so cash buckets net out.
-- Every relief row carries the project and category of the record it relieves.
-- Project, milestone and cost center are nullable dimensions: company-level items stay in the
-- projection. A row carries the cost center of its record where the record has one.
-- ---------------------------------------------------------------------------

-- Procurement helpers. Terms of each order line after every decisive supplier response,
-- with the terms that response replaced (the previous response's, or the order's).
create view order_response_terms as
select *,
       lag(quantity, 1, ordered_quantity) over w as previous_quantity,
       lag(unit_price, 1, ordered_unit_price) over w as previous_unit_price,
       row_number() over (partition by purchase_order_line_id order by recorded_on desc, order_response_id desc) as newest
from (
    select pol.id as purchase_order_line_id, pol.quantity as ordered_quantity, pol.unit_price as ordered_unit_price,
           r.id as order_response_id, r.responded_on, r.recorded_on,
           case when r.response_code = 'RE' then 0 else coalesce(rl.accepted_quantity, pol.quantity) end as quantity,
           coalesce(rl.accepted_unit_price, pol.unit_price) as unit_price
    from purchase_order_line pol
    join order_response r on r.purchase_order_id = pol.purchase_order_id and r.response_code <> 'AB'
    left join order_response_line rl on rl.order_response_id = r.id and rl.purchase_order_line_id = pol.id
) x
window w as (partition by purchase_order_line_id order by recorded_on, order_response_id);

-- Accepted terms of each order line after the supplier's latest decisive response,
-- and the moment each supplier invoice starts to count.
create view purchase_order_line_terms as
select pol.id as purchase_order_line_id,
       coalesce(t.quantity, pol.quantity) as quantity,
       coalesce(t.unit_price, pol.unit_price) as unit_price
from purchase_order_line pol
left join order_response_terms t on t.purchase_order_line_id = pol.id and t.newest = 1;

-- An invoice counts from registration, or from its first acceptance (AP, CA) when it
-- needs approval. Rejection (RE) is terminal and only possible before acceptance, so a
-- rejected invoice never counts. After acceptance, disagreement needs a credit note.
create view supplier_invoice_approval as
select si.id as supplier_invoice_id,
       case when not si.requires_approval then si.recorded_on
            else (select min(r.recorded_on) from invoice_response r
                  where r.supplier_invoice_id = si.id and r.response_code in ('AP', 'CA'))
       end as counts_from
from supplier_invoice si;

-- Procurement: requests, orders, order responses, receipts, supplier invoices, proformas.
create view position_procurement as
-- Request approved: expected cost.
select 'cost' as family, 'expected' as stage, mr.project_id, null::text as cost_center_id, mrl.category_id,
       mrl.quantity * mrl.estimated_unit_price as amount, 1.00 as probability,
       mr.requested_on as effective_on, mr.recorded_on, null::date as cash_on,
       'material_request_line' as source_type, mrl.id as source_id, null::text as milestone_id
from material_request_line mrl
join material_request mr on mr.id = mrl.material_request_id

union all
-- Request fulfilled by an order: relieve expected at the request's estimate.
select 'cost', 'expected', mr.project_id, null, mrl.category_id,
       -rf.quantity * mrl.estimated_unit_price, 1.00,
       po.ordered_on, greatest(rf.recorded_on, po.recorded_on), null,
       'request_fulfilment', rf.id, null
from request_fulfilment rf
join material_request_line mrl on mrl.id = rf.material_request_line_id
join material_request mr on mr.id = mrl.material_request_id
join purchase_order_line pol on pol.id = rf.purchase_order_line_id
join purchase_order po on po.id = pol.purchase_order_id

union all
-- Order placed: committed cost (not for stock: stock is an asset until issued; not for a
-- non-P&L category such as a capital purchase, MONEY-11), and a cash forecast for every
-- line, paid after terms. The later cost stages of an order line follow the same rule.
select v.family, v.stage, pol.project_id, null, pol.category_id,
       case v.family
           when 'cost' then pol.quantity * pol.unit_price
           else -round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
       end, 1.00,
       po.ordered_on, po.recorded_on,
       case v.family when 'cash' then pol.expected_on + po.payment_terms_days end,
       'purchase_order_line', pol.id, pol.milestone_id
from purchase_order_line pol
join purchase_order po on po.id = pol.purchase_order_id
join category pcat on pcat.id = pol.category_id
cross join lateral (values ('cost', 'committed'), ('cash', 'forecast')) v(family, stage)
where v.family = 'cash' or (pcat.family = 'cost' and not pol.to_stock)

union all
-- Each supplier response that changes or rejects a line: the terms it replaces are
-- relieved and its accepted terms committed instead, dated by that response, so a
-- later response never rewrites what an earlier one showed.
select v.family, v.stage, pol.project_id, null, pol.category_id,
       case v.family
           when 'cost' then t.quantity * t.unit_price - t.previous_quantity * t.previous_unit_price
           else round(t.previous_quantity * t.previous_unit_price * (1 + pol.vat_rate), 2)
                - round(t.quantity * t.unit_price * (1 + pol.vat_rate), 2)
       end, 1.00,
       t.responded_on, t.recorded_on,
       case v.family when 'cash' then pol.expected_on + po.payment_terms_days end,
       'order_response', t.order_response_id || ':' || pol.id, pol.milestone_id
from purchase_order_line pol
join purchase_order po on po.id = pol.purchase_order_id
join order_response_terms t on t.purchase_order_line_id = pol.id
join category pcat on pcat.id = pol.category_id
cross join lateral (values ('cost', 'committed'), ('cash', 'forecast')) v(family, stage)
where (t.quantity, t.unit_price) is distinct from (t.previous_quantity, t.previous_unit_price)
  and (v.family = 'cash' or (pcat.family = 'cost' and not pol.to_stock))

union all
-- Goods received: committed -> incurred at the accepted order price. A receipt of goods
-- already invoiced (matched to the invoice line) moves nothing: the invoice relieved
-- the commitment first.
select 'cost', v.stage, pol.project_id, null, pol.category_id,
       v.sign * grl.quantity * t.unit_price, 1.00,
       gr.received_on, gr.recorded_on, null,
       'goods_receipt_line', grl.id, pol.milestone_id
from goods_receipt_line grl
join goods_receipt gr on gr.id = grl.goods_receipt_id
join purchase_order_line pol on pol.id = grl.purchase_order_line_id
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
join category pcat on pcat.id = pol.category_id
cross join lateral (values ('committed', -1), ('incurred', 1)) v(stage, sign)
where pcat.family = 'cost' and not pol.to_stock and grl.supplier_invoice_line_id is null

union all
-- Supplier invoice, once it counts: relieve incurred (after a receipt) or committed
-- (services, or goods invoiced before receipt) at the accepted order price; record
-- actual at invoice price. An invoice dated before the receipt it names (MONEY-16)
-- relieves committed on its own date, and moves that relief to incurred on the
-- receipt's date, so no valid-time read shows negative incurred or a double count.
select 'cost', v.stage, pol.project_id, null, pol.category_id,
       v.sign * sinl.quantity * t.unit_price, 1.00,
       v.effective_on, greatest(a.counts_from, v.recorded_on), null,
       'supplier_invoice_line', sinl.id, pol.milestone_id
from supplier_invoice_line sinl
join supplier_invoice sinv on sinv.id = sinl.supplier_invoice_id
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
left join goods_receipt_line grl on grl.id = sinl.goods_receipt_line_id
left join goods_receipt gr on gr.id = grl.goods_receipt_id
join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, sinl.purchase_order_line_id)
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
join category pcat on pcat.id = pol.category_id
cross join lateral (select coalesce(gr.received_on > sinv.issued_on, false) as early) e
cross join lateral (values
    (case when grl.id is null or e.early then 'committed' else 'incurred' end, -1, sinv.issued_on, a.counts_from, true),
    ('committed', 1, gr.received_on, gr.recorded_on, e.early),
    ('incurred', -1, gr.received_on, gr.recorded_on, e.early)
) v(stage, sign, effective_on, recorded_on, applies)
where pcat.family = 'cost' and not pol.to_stock and v.applies

union all
-- Actual in the family of the line's category (MONEY-11): cost, or a revenue reduction;
-- nothing for a non-P&L category (a capital purchase) or a purchase for stock (the line
-- says so, or a stock order line, or an Inventory receipt without an order).
select c.family, 'actual', sinl.project_id, null, sinl.category_id,
       case c.family when 'cost' then sinl.amount_net else -sinl.amount_net end, 1.00,
       sinv.issued_on, a.counts_from, null,
       'supplier_invoice_line', sinl.id, sinl.milestone_id
from supplier_invoice_line sinl
join supplier_invoice sinv on sinv.id = sinl.supplier_invoice_id
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
join category c on c.id = sinl.category_id
left join goods_receipt_line grl on grl.id = sinl.goods_receipt_line_id
left join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, sinl.purchase_order_line_id)
where c.family in ('cost', 'revenue') and not sinl.to_stock and not coalesce(pol.to_stock, grl.id is not null)

union all
-- Cash: a counting supplier invoice relieves the order forecast (on the order line's
-- project and category) and opens a payable (on its own). The relief is rounded on the
-- quantity billed so far (MONEY-18), so partial invoices leave no cent in the forecast.
select 'cash', v.stage,
       case v.stage when 'forecast' then pol.project_id else sinl.project_id end, null,
       case v.stage when 'forecast' then pol.category_id else sinl.category_id end,
       case v.stage
           when 'forecast' then round((b.before + sinl.quantity) * t.unit_price * (1 + pol.vat_rate), 2)
                                - round(b.before * t.unit_price * (1 + pol.vat_rate), 2)
           else -(sinl.amount_net + sinl.vat_amount)
       end, 1.00,
       sinv.issued_on, a.counts_from,
       case v.stage when 'forecast' then pol.expected_on + po.payment_terms_days else sinv.due_on end,
       'supplier_invoice_line', sinl.id, case v.stage when 'forecast' then pol.milestone_id else sinl.milestone_id end
from supplier_invoice_line sinl
join supplier_invoice sinv on sinv.id = sinl.supplier_invoice_id
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
left join goods_receipt_line grl on grl.id = sinl.goods_receipt_line_id
left join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, sinl.purchase_order_line_id)
left join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
left join purchase_order po on po.id = pol.purchase_order_id
cross join lateral (  -- quantity of the order line billed by invoices that counted earlier
    select coalesce(sum(o.quantity), 0) as before
    from supplier_invoice_line o
    join supplier_invoice_approval oa on oa.supplier_invoice_id = o.supplier_invoice_id and oa.counts_from is not null
    left join goods_receipt_line og on og.id = o.goods_receipt_line_id
    where coalesce(og.purchase_order_line_id, o.purchase_order_line_id) = pol.id
      and (oa.counts_from, o.id) < (a.counts_from, sinl.id)
) b
cross join lateral (values ('forecast'), ('open')) v(stage)
where v.stage = 'open' or pol.id is not null

union all
-- Supplier advance request (proforma): an open payable, no cost.
select 'cash', 'open', r.project_id, null, r.category_id,
       -r.amount, 1.00,
       r.issued_on, r.recorded_on, r.due_on,
       'supplier_advance_request', r.id, null
from supplier_advance_request r

union all
-- A counting supplier invoice that names an expected-cash item relieves its forecast
-- (on that item's dimensions and cash date) by the invoice's gross.
select 'cash', 'forecast', e.project_id, e.cost_center_id, e.category_id,
       sum(sinl.amount_net + sinl.vat_amount), 1.00,
       sinv.issued_on, a.counts_from, e.cash_on,
       'supplier_invoice', sinv.id, null
from supplier_invoice sinv
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
join expected_cash e on e.id = sinv.expected_cash_id
join supplier_invoice_line sinl on sinl.supplier_invoice_id = sinv.id
group by e.id, sinv.id, a.counts_from

union all
-- A proforma for an order replaces that part of the order's cash forecast: its amount
-- relieves the forecast of the order lines, spread by ordered value like an order advance
-- (rounding remainder to the largest line), at each line's cash date.
select 'cash', 'forecast', x.project_id, null, x.category_id,
       x.share + case when x.position = 1 then x.amount - sum(x.share) over (partition by x.id) else 0 end, 1.00,
       x.issued_on, x.recorded_on, x.cash_on,
       'supplier_advance_request', x.id || ':' || x.line_id, x.milestone_id
from (
    select r.id, r.amount, r.issued_on, r.recorded_on, pol.id as line_id, pol.project_id, pol.category_id, pol.milestone_id,
           pol.expected_on + po.payment_terms_days as cash_on,
           round(r.amount * g.gross / sum(g.gross) over (partition by r.id), 2) as share,
           row_number() over (partition by r.id order by g.gross desc, pol.id) as position
    from supplier_advance_request r
    join purchase_order po on po.id = r.purchase_order_id
    join purchase_order_line pol on pol.purchase_order_id = po.id
    cross join lateral (select round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2) as gross) g
) x;

-- Inventory: stock issues. Receipts into stock never touch cost stages.
create view position_inventory as
-- Stock issue fulfils a request: relieve expected at the request's estimate.
select 'cost' as family, 'expected' as stage, mr.project_id, null::text as cost_center_id, mrl.category_id,
       -rf.quantity * mrl.estimated_unit_price as amount, 1.00 as probability,
       si.issued_on as effective_on, greatest(rf.recorded_on, si.recorded_on) as recorded_on, null::date as cash_on,
       'request_fulfilment' as source_type, rf.id as source_id, null::text as milestone_id
from request_fulfilment rf
join material_request_line mrl on mrl.id = rf.material_request_line_id
join material_request mr on mr.id = mrl.material_request_id
join stock_issue_line sil on sil.id = rf.stock_issue_line_id
join stock_issue si on si.id = sil.stock_issue_id

union all
-- Stock issued: actual cost at inventory valuation.
select 'cost', 'actual', si.project_id, null, sil.category_id,
       sil.quantity * sil.unit_cost, 1.00,
       si.issued_on, si.recorded_on, null,
       'stock_issue_line', sil.id, null
from stock_issue_line sil
join stock_issue si on si.id = sil.stock_issue_id;

-- People helper: payroll cost as attributed, in the order it was recorded (REDTEAM-1).
-- Each cost line counts in full when the run is posted; each allocation, when it is
-- recorded, moves its part from the cost line's dimensions to the project of the hours.
-- Nothing recorded earlier changes, so a late allocation never rewrites an earlier read.
create view payroll_cost_unit as
select 'payroll_cost_line' as unit_type, pc.id as unit_id, pc.payroll_line_id,
       pc.project_id, pc.cost_center_id, pc.category_id, pc.amount, pr.posted_on as recorded_on
from payroll_cost_line pc
join payroll_line pl on pl.id = pc.payroll_line_id
join payroll_run pr on pr.id = pl.payroll_run_id
union all
select 'payroll_allocation', a.id, pc.payroll_line_id,
       x.project_id, pc.cost_center_id, pc.category_id, x.sign * a.amount, greatest(a.recorded_on, pr.posted_on)
from payroll_allocation a
join payroll_cost_line pc on pc.id = a.payroll_cost_line_id
join payroll_line pl on pl.id = pc.payroll_line_id
join payroll_run pr on pr.id = pl.payroll_run_id
join timesheet_entry te on te.id = a.timesheet_entry_id
cross join lateral (values (pc.project_id, -1), (te.project_id, 1)) x(project_id, sign);

-- People: timesheets and payroll.
create view position_people as
-- Hours worked: incurred cost at the standard rate, forecast as wage cash on the
-- 12th of the next month (assumed payday).
select v.family, v.stage, te.project_id, null::text as cost_center_id, 'labour' as category_id,
       v.sign * te.hours * r.hourly_rate as amount, 1.00 as probability,
       te.worked_on as effective_on, te.recorded_on,
       case v.family when 'cash' then (date_trunc('month', te.worked_on) + interval '1 month 11 days')::date end as cash_on,
       'timesheet_entry' as source_type, te.id as source_id, null::text as milestone_id
from timesheet_entry te
cross join lateral (
    select hourly_rate from employee_cost_rate
    where employee_id = te.employee_id and valid_from <= te.worked_on
    order by valid_from desc limit 1
) r
cross join lateral (values ('cost', 'incurred', 1), ('cash', 'forecast', -1)) v(family, stage, sign)

union all
-- Payroll allocated to hours relieves their incurred estimate and wage forecast.
select v.family, v.stage, te.project_id, null, 'labour',
       v.sign * pa.hours * r.hourly_rate, 1.00,
       (pr.period_month + interval '1 month - 1 day')::date, greatest(pa.recorded_on, pr.posted_on),
       case v.family when 'cash' then (date_trunc('month', te.worked_on) + interval '1 month 11 days')::date end,
       'payroll_allocation', pa.id, null
from payroll_allocation pa
join payroll_cost_line pc on pc.id = pa.payroll_cost_line_id
join payroll_line pl on pl.id = pc.payroll_line_id
join payroll_run pr on pr.id = pl.payroll_run_id
join timesheet_entry te on te.id = pa.timesheet_entry_id
cross join lateral (
    select hourly_rate from employee_cost_rate
    where employee_id = te.employee_id and valid_from <= te.worked_on
    order by valid_from desc limit 1
) r
cross join lateral (values ('cost', 'incurred', -1), ('cash', 'forecast', 1)) v(family, stage, sign)

union all
-- Payroll cost as attributed: actual cost, and an open wage liability due on the pay date.
select v.family, v.stage, u.project_id, u.cost_center_id, u.category_id,
       case v.family when 'cost' then u.amount else -u.amount end, 1.00,
       (pr.period_month + interval '1 month - 1 day')::date, u.recorded_on,
       case v.family when 'cash' then pr.paid_on end,
       u.unit_type, u.unit_id, null
from payroll_cost_unit u
join payroll_line pl on pl.id = u.payroll_line_id
join payroll_run pr on pr.id = pl.payroll_run_id
cross join lateral (values ('cost', 'actual'), ('cash', 'open')) v(family, stage)
where u.amount <> 0;

-- CRM: opportunities.
create view position_crm as
-- Opportunity opened: expected revenue, weighted by probability in reports.
select 'revenue' as family, 'expected' as stage, o.project_id, null::text as cost_center_id, o.category_id,
       o.amount_net as amount, o.probability,
       o.opened_on as effective_on, o.recorded_on, null::date as cash_on,
       'opportunity' as source_type, o.id as source_id, null::text as milestone_id
from opportunity o

union all
-- Opportunity won or lost: expected revenue closed in full.
select 'revenue', 'expected', o.project_id, null, o.category_id,
       -o.amount_net, o.probability,
       oo.decided_on, oo.recorded_on, null,
       'opportunity_outcome', oo.opportunity_id, null
from opportunity_outcome oo
join opportunity o on o.id = oo.opportunity_id;

-- Sales: orders and customer invoices.
create view position_sales as
-- Sales order: committed (contracted) revenue, forecast as cash after terms.
select v.family, v.stage, so.project_id, null::text as cost_center_id, sol.category_id,
       case v.family
           when 'revenue' then sol.quantity * sol.unit_price
           else round(sol.quantity * sol.unit_price * (1 + sol.vat_rate), 2)
       end as amount, 1.00 as probability,
       so.ordered_on as effective_on, so.recorded_on,
       case v.family when 'cash' then sol.expected_on + so.payment_terms_days end as cash_on,
       'sales_order_line' as source_type, sol.id as source_id, sol.milestone_id as milestone_id
from sales_order_line sol
join sales_order so on so.id = sol.sales_order_id
cross join lateral (values ('revenue', 'committed'), ('cash', 'forecast')) v(family, stage)

union all
-- Customer invoice linked to an order line: relieve committed revenue and the
-- cash forecast at order price, on the order's project and category (the cash relief
-- rounded on the quantity invoiced so far, MONEY-18).
select v.family, v.stage, so.project_id, null, sol.category_id,
       case v.family
           when 'revenue' then -cil.quantity * sol.unit_price
           else round(b.before * sol.unit_price * (1 + sol.vat_rate), 2)
                - round((b.before + cil.quantity) * sol.unit_price * (1 + sol.vat_rate), 2)
       end, 1.00,
       ci.issued_on, ci.recorded_on,
       case v.family when 'cash' then sol.expected_on + so.payment_terms_days end,
       'customer_invoice_line', cil.id, sol.milestone_id
from customer_invoice_line cil
join customer_invoice ci on ci.id = cil.customer_invoice_id
join sales_order_line sol on sol.id = cil.sales_order_line_id
join sales_order so on so.id = sol.sales_order_id
cross join lateral (  -- quantity of the order line invoiced by earlier invoices
    select coalesce(sum(o.quantity), 0) as before
    from customer_invoice_line o join customer_invoice oc on oc.id = o.customer_invoice_id
    where o.sales_order_line_id = sol.id and (oc.recorded_on, o.id) < (ci.recorded_on, cil.id)
) b
cross join lateral (values ('revenue', 'committed'), ('cash', 'forecast')) v(family, stage)

union all
-- Every customer invoice line, with or without an order: a receivable, and actual in the
-- family of its category (MONEY-11): revenue, or a cost reduction for a re-invoiced cost.
select v.family, v.stage, cil.project_id, null, cil.category_id,
       case v.family when 'revenue' then cil.amount_net when 'cost' then -cil.amount_net
                     else cil.amount_net + cil.vat_amount end, 1.00,
       ci.issued_on, ci.recorded_on,
       case v.family when 'cash' then ci.due_on end,
       'customer_invoice_line', cil.id, cil.milestone_id
from customer_invoice_line cil
join customer_invoice ci on ci.id = cil.customer_invoice_id
join category c on c.id = cil.category_id
cross join lateral (values (c.family, 'actual'), ('cash', 'open')) v(family, stage)
where v.stage = 'open' or c.family in ('cost', 'revenue')

union all
-- A customer invoice that names an expected-cash item relieves its forecast (on that
-- item's dimensions and cash date) by the invoice's gross.
select 'cash', 'forecast', e.project_id, e.cost_center_id, e.category_id,
       -sum(cil.amount_net + cil.vat_amount), 1.00,
       ci.issued_on, ci.recorded_on, e.cash_on,
       'customer_invoice', ci.id, null
from customer_invoice ci
join expected_cash e on e.id = ci.expected_cash_id
join customer_invoice_line cil on cil.customer_invoice_id = ci.id
group by e.id, ci.id;

-- Treasury: a settlement spread over the lines it settles. Rounding remainders go to
-- the largest line, so settled amounts always equal the bank or the offset.
-- Settlements: bank payments of invoices, payroll, proformas and order advances, and
-- advance applications (an advance offset against the final invoice, no bank movement).
create view settlement_line as
with target as (
    select 'payment_allocation' as settlement_type, pa.id as settlement_id, pa.amount as paid,
           'supplier_invoice_line' as line_type, l.id as line_id, l.amount_net + l.vat_amount as line_amount
    from payment_allocation pa
    join supplier_invoice_line l on l.supplier_invoice_id = pa.supplier_invoice_id
    union all
    select 'payment_allocation', pa.id, pa.amount, 'customer_invoice_line', l.id, l.amount_net + l.vat_amount
    from payment_allocation pa
    join customer_invoice_line l on l.customer_invoice_id = pa.customer_invoice_id
    union all
    -- Payroll payments settle the cost lines as posted; allocations follow them (below).
    select 'payment_allocation', pa.id, pa.amount, 'payroll_cost_line', pc.id, pc.amount
    from payment_allocation pa
    join payroll_line pl on pl.payroll_run_id = pa.payroll_run_id
    join payroll_cost_line pc on pc.payroll_line_id = pl.id and pc.amount <> 0
    union all
    select 'payment_allocation', pa.id, pa.amount, 'supplier_advance_request', r.id, r.amount
    from payment_allocation pa
    join supplier_advance_request r on r.id = pa.supplier_advance_request_id
    union all
    -- Advances are spread over the order lines by ordered value (never zero, even if
    -- the supplier later rejects the order).
    select 'payment_allocation', pa.id, pa.amount, 'purchase_order_line', pol.id,
           round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
    from payment_allocation pa
    join purchase_order_line pol on pol.purchase_order_id = pa.purchase_order_id
    union all
    -- An advance application reduces the invoice's payable (over its lines) and moves
    -- the advance off its own lines (the order lines or the proforma, spread as the
    -- advance was) onto the invoice's lines.
    select 'advance_application_open', aa.id, aa.amount, 'supplier_invoice_line', l.id, l.amount_net + l.vat_amount
    from advance_application aa
    join supplier_invoice_line l on l.supplier_invoice_id = aa.supplier_invoice_id
    union all
    select 'advance_application_advance', aa.id, aa.amount, 'purchase_order_line', pol.id,
           round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
    from advance_application aa
    join payment_allocation adv on adv.id = aa.advance_allocation_id
    join purchase_order_line pol on pol.purchase_order_id = adv.purchase_order_id
    union all
    select 'advance_application_advance', aa.id, aa.amount, 'supplier_advance_request', r.id, r.amount
    from advance_application aa
    join payment_allocation adv on adv.id = aa.advance_allocation_id
    join supplier_advance_request r on r.id = adv.supplier_advance_request_id
    union all
    -- A proforma for an order, once applied, hands its forecast relief back to the order
    -- lines (spread as the proforma was), because the invoice now relieves that forecast.
    select 'advance_application_order', aa.id, aa.amount, 'purchase_order_line', pol.id,
           round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
    from advance_application aa
    join payment_allocation adv on adv.id = aa.advance_allocation_id
    join supplier_advance_request r on r.id = adv.supplier_advance_request_id
    join purchase_order_line pol on pol.purchase_order_id = r.purchase_order_id
),
shared as (
    select *,
           round(paid * line_amount / sum(line_amount) over (partition by settlement_type, settlement_id), 2) as share,
           row_number() over (partition by settlement_type, settlement_id order by line_amount desc, line_id) as position
    from target
)
select settlement_type, settlement_id, line_type, line_id,
       share + case when position = 1
                    then paid - sum(share) over (partition by settlement_type, settlement_id)
                    else 0 end as amount
from shared;

create view position_treasury as
-- Payment of an invoice, payroll or proforma: the open item (dated by its due date)
-- becomes settled (dated by the bank).
select 'cash' as family, v.stage, x.project_id, x.cost_center_id, x.category_id,
       v.sign * x.direction * s.amount as amount, 1.00 as probability,
       bt.booked_on as effective_on, greatest(pa.recorded_on, bt.recorded_on) as recorded_on,
       case v.stage when 'open' then x.due_on else bt.booked_on end as cash_on,
       'payment_allocation' as source_type, pa.id || ':' || s.line_id as source_id, x.milestone_id as milestone_id
from settlement_line s
join payment_allocation pa on s.settlement_type = 'payment_allocation' and pa.id = s.settlement_id
join bank_transaction bt on bt.id = pa.bank_transaction_id
join lateral (
    select l.project_id, null::text as cost_center_id, l.category_id, si.due_on, -1 as direction, l.milestone_id
    from supplier_invoice_line l join supplier_invoice si on si.id = l.supplier_invoice_id
    where s.line_type = 'supplier_invoice_line' and l.id = s.line_id
    union all
    select l.project_id, null, l.category_id, ci.due_on, 1, l.milestone_id
    from customer_invoice_line l join customer_invoice ci on ci.id = l.customer_invoice_id
    where s.line_type = 'customer_invoice_line' and l.id = s.line_id
    union all
    select pc.project_id, pc.cost_center_id, pc.category_id, pr.paid_on, -1, null
    from payroll_cost_line pc
    join payroll_line pl on pl.id = pc.payroll_line_id
    join payroll_run pr on pr.id = pl.payroll_run_id
    where s.line_type = 'payroll_cost_line' and pc.id = s.line_id
    union all
    select r.project_id, null, r.category_id, r.due_on, -1, null
    from supplier_advance_request r
    where s.line_type = 'supplier_advance_request' and r.id = s.line_id
) x on true
cross join lateral (values ('open', -1), ('settled', 1)) v(stage, sign)

union all
-- A payroll allocation takes its share of the cost line's cash with it. Allocations and
-- payments fill each cost line in the order they were recorded; where an allocation's
-- part overlaps a payment's part, that amount moves from open to settled on the project
-- of the hours (and back on the cost line), counted once both are recorded.
select 'cash', v.stage, x.project_id, m.cost_center_id, m.category_id,
       v.sign * x.sign * m.amount, 1.00,
       greatest(m.booked_on, m.period_end), greatest(m.allocation_recorded_on, m.payment_recorded_on),
       case v.stage when 'open' then m.paid_on else m.booked_on end,
       'payment_allocation', m.payment_id || ':' || m.allocation_id, null
from (
    select al.id as allocation_id, p.id as payment_id, al.cost_center_id, al.category_id,
           al.from_project_id, al.to_project_id, al.period_end, al.paid_on, al.recorded_on as allocation_recorded_on,
           p.recorded_on as payment_recorded_on, p.booked_on,
           least(al.upto, p.upto) - greatest(al.upto - al.amount, p.upto - p.amount) as amount
    from (select a.id, a.payroll_cost_line_id, a.amount, pc.cost_center_id, pc.category_id,
                 pc.project_id as from_project_id, te.project_id as to_project_id, pr.paid_on,
                 (pr.period_month + interval '1 month - 1 day')::date as period_end,
                 greatest(a.recorded_on, pr.posted_on) as recorded_on,
                 sum(a.amount) over (partition by a.payroll_cost_line_id
                                     order by greatest(a.recorded_on, pr.posted_on), a.id) as upto
          from payroll_allocation a
          join payroll_cost_line pc on pc.id = a.payroll_cost_line_id
          join payroll_line pl on pl.id = pc.payroll_line_id
          join payroll_run pr on pr.id = pl.payroll_run_id
          join timesheet_entry te on te.id = a.timesheet_entry_id) al
    join (select pa.id, s.line_id, s.amount, greatest(pa.recorded_on, bt.recorded_on) as recorded_on, bt.booked_on,
                 sum(s.amount) over (partition by s.line_id
                                     order by greatest(pa.recorded_on, bt.recorded_on), pa.id) as upto
          from settlement_line s
          join payment_allocation pa on s.settlement_type = 'payment_allocation' and pa.id = s.settlement_id
          join bank_transaction bt on bt.id = pa.bank_transaction_id
          where s.line_type = 'payroll_cost_line') p
      on p.line_id = al.payroll_cost_line_id
) m
cross join lateral (values (m.from_project_id, -1), (m.to_project_id, 1)) x(project_id, sign)
cross join lateral (values ('open', 1), ('settled', -1)) v(stage, sign)
where m.amount > 0

union all
-- Advance paid against an order: settled now, and the order's cash forecast is
-- relieved by the same amount (at the order's cash date).
select 'cash', v.stage, pol.project_id, null, pol.category_id,
       case v.stage when 'forecast' then s.amount else -s.amount end, 1.00,
       bt.booked_on, greatest(pa.recorded_on, bt.recorded_on),
       case v.stage when 'forecast' then pol.expected_on + po.payment_terms_days else bt.booked_on end,
       'payment_allocation', pa.id || ':' || s.line_id, pol.milestone_id
from settlement_line s
join payment_allocation pa on s.settlement_type = 'payment_allocation' and pa.id = s.settlement_id
join bank_transaction bt on bt.id = pa.bank_transaction_id
join purchase_order_line pol on s.line_type = 'purchase_order_line' and pol.id = s.line_id
join purchase_order po on po.id = pol.purchase_order_id
cross join lateral (values ('forecast'), ('settled')) v(stage)

union all
-- Advance applied to the final invoice, once that invoice counts: the payable shrinks,
-- and the advance's settled cash moves onto the invoice's lines (at the advance's bank date)...
select 'cash', v.stage, l.project_id, null, l.category_id,
       case v.stage when 'open' then s.amount else -s.amount end, 1.00,
       aa.applied_on, greatest(aa.recorded_on, a.counts_from),
       case v.stage when 'open' then si.due_on else abt.booked_on end,
       'advance_application', aa.id || ':' || l.id, l.milestone_id
from settlement_line s
join advance_application aa on s.settlement_type = 'advance_application_open' and aa.id = s.settlement_id
join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
join payment_allocation adv on adv.id = aa.advance_allocation_id
join bank_transaction abt on abt.id = adv.bank_transaction_id
join supplier_invoice_line l on l.id = s.line_id
join supplier_invoice si on si.id = l.supplier_invoice_id
cross join lateral (values ('open'), ('settled')) v(stage)

union all
-- ...off the advance's own lines. For an order advance, the advance's relief of the
-- order forecast is also handed back, because the invoice now relieves that forecast.
select 'cash', v.stage, x.project_id, null, x.category_id,
       case v.stage when 'forecast' then -s.amount else s.amount end, 1.00,
       aa.applied_on, greatest(aa.recorded_on, a.counts_from),
       case v.stage when 'forecast' then x.forecast_on else abt.booked_on end,
       'advance_application', aa.id || ':' || s.line_id, x.milestone_id
from settlement_line s
join advance_application aa on s.settlement_type = 'advance_application_advance' and aa.id = s.settlement_id
join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
join payment_allocation adv on adv.id = aa.advance_allocation_id
join bank_transaction abt on abt.id = adv.bank_transaction_id
join lateral (
    select pol.project_id, pol.category_id, pol.expected_on + po.payment_terms_days as forecast_on, pol.milestone_id
    from purchase_order_line pol join purchase_order po on po.id = pol.purchase_order_id
    where s.line_type = 'purchase_order_line' and pol.id = s.line_id
    union all
    select r.project_id, r.category_id, null, null
    from supplier_advance_request r
    where s.line_type = 'supplier_advance_request' and r.id = s.line_id
) x on true
cross join lateral (values ('forecast'), ('settled')) v(stage)
where v.stage = 'settled' or x.forecast_on is not null

union all
-- ...and a proforma for an order hands its forecast relief back to the order lines.
select 'cash', 'forecast', pol.project_id, null, pol.category_id,
       -s.amount, 1.00,
       aa.applied_on, greatest(aa.recorded_on, a.counts_from),
       pol.expected_on + po.payment_terms_days,
       'advance_application', aa.id || ':' || pol.id, pol.milestone_id
from settlement_line s
join advance_application aa on s.settlement_type = 'advance_application_order' and aa.id = s.settlement_id
join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
join purchase_order_line pol on pol.id = s.line_id
join purchase_order po on po.id = pol.purchase_order_id

union all
-- Classified bank line with no document: settled cash; actual cost or revenue when
-- the category is a P&L one; relief of the expected-cash item it pays (on that item's
-- dimensions and cash date).
select case v.stage when 'actual' then cat.family else 'cash' end, v.stage,
       case v.stage when 'forecast' then e.project_id else c.project_id end,
       case v.stage when 'forecast' then e.cost_center_id else c.cost_center_id end,
       case v.stage when 'forecast' then e.category_id else c.category_id end,
       case v.stage
           when 'settled' then c.amount
           when 'forecast' then -c.amount
           else case cat.family when 'cost' then -c.amount else c.amount end
       end, 1.00,
       bt.booked_on, greatest(c.recorded_on, bt.recorded_on),
       case v.stage when 'settled' then bt.booked_on when 'forecast' then e.cash_on end,
       'bank_line_classification', c.id, null
from bank_line_classification c
join bank_transaction bt on bt.id = c.bank_transaction_id
left join category cat on cat.id = c.category_id
left join expected_cash e on e.id = c.expected_cash_id
cross join lateral (values ('settled'), ('forecast'), ('actual')) v(stage)
where v.stage = 'settled'
   or (v.stage = 'forecast' and e.id is not null)
   or (v.stage = 'actual' and cat.family in ('cost', 'revenue'))

union all
-- Expected-cash item: a Treasury forecast.
select 'cash', 'forecast', e.project_id, e.cost_center_id, e.category_id,
       e.amount, 1.00,
       e.recorded_on, e.recorded_on, e.cash_on,
       'expected_cash', e.id, null
from expected_cash e;

-- Accounting: internal document lines with a cost or revenue category are actuals.
create view position_accounting as
select c.family, 'actual' as stage, l.project_id, l.cost_center_id, l.category_id,
       case c.family when 'cost' then l.debit - l.credit else l.credit - l.debit end as amount, 1.00 as probability,
       d.issued_on as effective_on, d.recorded_on, null::date as cash_on,
       'internal_document_line' as source_type, l.id as source_id, null::text as milestone_id
from internal_document_line l
join internal_document d on d.id = l.internal_document_id
join category c on c.id = l.category_id
where c.family in ('cost', 'revenue')

union all
-- An accrual or WIP line linked to an order line or sales order line relieves that
-- line's committed amount, and one linked to a receipt line its incurred amount, by the
-- accrual's own amount (an accrual has no quantity), on the linked record's project and
-- category; its reversal restores it.
select c.family, x.stage, x.project_id, null, x.category_id,
       -case c.family when 'cost' then l.debit - l.credit else l.credit - l.debit end, 1.00,
       d.issued_on, d.recorded_on, null,
       'internal_document_line', l.id, x.milestone_id
from internal_document_line l
join internal_document d on d.id = l.internal_document_id
join category c on c.id = l.category_id
join lateral (
    select 'committed' as stage, pol.project_id, pol.category_id, pol.milestone_id
    from purchase_order_line pol where pol.id = l.purchase_order_line_id
    union all
    select 'incurred', pol.project_id, pol.category_id, pol.milestone_id
    from goods_receipt_line grl join purchase_order_line pol on pol.id = grl.purchase_order_line_id
    where grl.id = l.goods_receipt_line_id
    union all
    select 'committed', so.project_id, sol.category_id, sol.milestone_id
    from sales_order_line sol join sales_order so on so.id = sol.sales_order_id
    where sol.id = l.sales_order_line_id
) x on true
where c.family in ('cost', 'revenue');

-- FP&A: management-only adjustments are actuals in the family of their category.
create view position_fpa as
select c.family, 'actual' as stage, m.project_id, m.cost_center_id, m.category_id,
       m.amount, 1.00 as probability,
       m.effective_on, m.recorded_on, null::date as cash_on,
       'management_adjustment' as source_type, m.id as source_id, m.milestone_id
from management_adjustment m
join category c on c.id = m.category_id
where c.family in ('cost', 'revenue');

-- The platform unions the views of all domains.
create view position_entry as
select family, stage, project_id, milestone_id, cost_center_id, category_id, round(amount, 2)::numeric(14, 2) as amount,
       probability, effective_on, recorded_on, cash_on, source_type, source_id
from (
    select * from position_crm
    union all select * from position_sales
    union all select * from position_procurement
    union all select * from position_inventory
    union all select * from position_people
    union all select * from position_treasury
    union all select * from position_accounting
    union all select * from position_fpa
) domains;

-- Bitemporal read: what was valid on `valid_on`, as the system knew it on `known_on`.
create function position_as_of(valid_on date, known_on date)
returns setof position_entry
language sql stable
as $$
    select * from position_entry
    where effective_on <= valid_on and recorded_on <= known_on
$$;

-- One shared report shape: every dashboard groups this by the dimensions it needs.
create function position_summary(valid_on date, known_on date)
returns table (
    family text, project_id text, category_id text,
    expected numeric, expected_weighted numeric, committed numeric, incurred numeric, actual numeric,
    forecast numeric, open numeric, settled numeric
)
language sql stable
as $$
    select family, project_id, category_id,
           sum(amount) filter (where stage = 'expected'),
           sum(amount * probability) filter (where stage = 'expected'),
           sum(amount) filter (where stage = 'committed'),
           sum(amount) filter (where stage = 'incurred'),
           sum(amount) filter (where stage = 'actual'),
           sum(amount) filter (where stage = 'forecast'),
           sum(amount) filter (where stage = 'open'),
           sum(amount) filter (where stage = 'settled')
    from position_as_of(valid_on, known_on)
    group by family, project_id, category_id
$$;

-- Budget control and estimate at completion against any plan version.
-- remaining_plan = what is left of the plan after everything already expected,
-- committed, incurred or actual (never negative). It is not added on top of them.
-- Plan lines and positions with a cost center but no project belong to cost-center
-- control (a GROUP BY on cost_center_id), not here (ARCH-5), so project and cost-center
-- budgets in one version never count twice.
create function project_control(plan_version text, valid_on date, known_on date)
returns table (
    project_id text, category_id text, family text, plan numeric,
    expected numeric, committed numeric, incurred numeric, actual numeric,
    consumed numeric, available numeric, remaining_plan numeric, estimate_at_completion numeric
)
language sql stable
as $$
    with plan as (
        select pl.project_id, pl.category_id, sum(pl.amount_net) as plan
        from plan_line pl
        where pl.plan_version_id = plan_version and pl.family = 'pnl'
          and (pl.project_id is not null or pl.cost_center_id is null)
        group by pl.project_id, pl.category_id
    ),
    pos as (
        select e.project_id, e.category_id, e.family,
               coalesce(sum(e.amount) filter (where e.stage = 'expected'), 0) as expected,
               coalesce(sum(e.amount) filter (where e.stage = 'committed'), 0) as committed,
               coalesce(sum(e.amount) filter (where e.stage = 'incurred'), 0) as incurred,
               coalesce(sum(e.amount) filter (where e.stage = 'actual'), 0) as actual
        from position_as_of(valid_on, known_on) e
        where e.family in ('cost', 'revenue')
          and (e.project_id is not null or e.cost_center_id is null)
        group by e.project_id, e.category_id, e.family
    )
    select coalesce(p.project_id, pos.project_id), coalesce(p.category_id, pos.category_id),
           coalesce(pos.family, c.family),
           coalesce(p.plan, 0),
           -- expected revenue (pipeline) is shown but not consumed: it is not contracted.
           coalesce(pos.expected, 0), coalesce(pos.committed, 0), coalesce(pos.incurred, 0), coalesce(pos.actual, 0),
           x.consumed,
           coalesce(p.plan, 0) - x.consumed,
           greatest(coalesce(p.plan, 0) - x.consumed, 0),
           x.consumed + greatest(coalesce(p.plan, 0) - x.consumed, 0)
    from plan p
    full join pos on coalesce(pos.project_id, '-') = coalesce(p.project_id, '-') and pos.category_id = p.category_id
    join category c on c.id = coalesce(p.category_id, pos.category_id)
    cross join lateral (
        select case c.family
                   when 'cost' then coalesce(pos.expected, 0) + coalesce(pos.committed, 0)
                                    + coalesce(pos.incurred, 0) + coalesce(pos.actual, 0)
                   else coalesce(pos.committed, 0) + coalesce(pos.incurred, 0) + coalesce(pos.actual, 0)
               end as consumed
    ) x
$$;
