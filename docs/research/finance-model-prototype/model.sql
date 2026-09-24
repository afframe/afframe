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
-- Shared identities (platform). Every product may reference them.
-- ---------------------------------------------------------------------------
create table project (
    id text primary key,
    name text not null
);

create table category (
    id text primary key,
    family text not null check (family in ('revenue', 'cost')),
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
    project_id text not null references project,
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
    project_id text not null references project,
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
    expected_on date not null
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
    project_id text not null references project,
    category_id text not null references category,
    quantity numeric(14, 4) not null,       -- quantity of the order line fulfilled
    amount_net numeric(14, 2) not null,
    vat_amount numeric(14, 2) not null
);

-- ---------------------------------------------------------------------------
-- Procurement
-- ---------------------------------------------------------------------------
create table material_request (
    id text primary key,
    project_id text not null references project,
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
    expected_on date not null
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

create table goods_receipt_line (
    id text primary key,
    goods_receipt_id text not null references goods_receipt,
    purchase_order_line_id text not null references purchase_order_line,
    quantity numeric(14, 4) not null
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
    check (num_nonnulls(goods_receipt_line_id, purchase_order_line_id) <= 1)
);

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

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------
create table stock_issue (
    id text primary key,
    project_id text not null references project,
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

-- Produced by payroll: actual employer cost spread over the period's timesheet hours.
create table payroll_allocation (
    id text primary key,
    payroll_line_id text not null references payroll_line,
    timesheet_entry_id text not null references timesheet_entry,
    hours numeric(8, 2) not null,
    amount numeric(14, 2) not null
);

-- ---------------------------------------------------------------------------
-- Treasury
-- ---------------------------------------------------------------------------
create table bank_transaction (
    id text primary key,
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
    amount numeric(14, 2) not null,         -- positive, settled amount
    check (num_nonnulls(customer_invoice_id, supplier_invoice_id, payroll_run_id, purchase_order_id) = 1)
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

create table plan_line (
    plan_version_id text not null references plan_version,
    project_id text not null references project,
    category_id text not null references category,
    period_month date not null,
    amount_net numeric(14, 2) not null,
    primary key (plan_version_id, project_id, category_id, period_month)
);

-- ---------------------------------------------------------------------------
-- Accounting (statutory book). Posted, immutable, corrected by new entries.
-- ---------------------------------------------------------------------------
create table account (
    code text primary key,
    name text not null,
    category_id text unique references category  -- management mapping for reconciliation
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
-- records and links. Each product contributes one view with the rules for the
-- record types and links it owns; the platform unions the installed ones.
-- family  cost | revenue : amounts are net, positive = cost or revenue
-- family  cash           : amounts are gross, signed (+ in, - out), dated by cash_on
-- stage   expected -> committed -> incurred -> actual   (cost, revenue)
--         forecast -> open -> settled                    (cash)
-- A successor relieves its predecessor at the predecessor's own valuation
-- (quantity x predecessor price), so an open remainder keeps its estimate.
-- A cash relief carries the cash date of what it relieves, so cash buckets net out.
-- Project is a nullable dimension: company-level items stay in the projection.
-- ---------------------------------------------------------------------------

-- Procurement helpers. Accepted terms of each order line after the supplier's latest
-- decisive response, and the moment each supplier invoice starts to count.
create view purchase_order_line_terms as
select pol.id as purchase_order_line_id,
       case when r.response_code = 'RE' then 0 else coalesce(rl.accepted_quantity, pol.quantity) end as quantity,
       coalesce(rl.accepted_unit_price, pol.unit_price) as unit_price,
       r.id as order_response_id, r.responded_on, r.recorded_on as response_recorded_on
from purchase_order_line pol
left join lateral (
    select * from order_response r
    where r.purchase_order_id = pol.purchase_order_id and r.response_code <> 'AB'
    order by r.recorded_on desc, r.id desc limit 1
) r on true
left join order_response_line rl on rl.order_response_id = r.id and rl.purchase_order_line_id = pol.id;

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

-- Procurement: requests, orders, order responses, receipts, supplier invoices.
create view position_procurement as
-- Request approved: expected cost.
select 'cost' as family, 'expected' as stage, mr.project_id, mrl.category_id,
       mrl.quantity * mrl.estimated_unit_price as amount, 1.00 as probability,
       mr.requested_on as effective_on, mr.recorded_on, null::date as cash_on,
       'material_request_line' as source_type, mrl.id as source_id
from material_request_line mrl
join material_request mr on mr.id = mrl.material_request_id

union all
-- Request fulfilled by an order: relieve expected at the request's estimate.
select 'cost', 'expected', mr.project_id, mrl.category_id,
       -rf.quantity * mrl.estimated_unit_price, 1.00,
       po.ordered_on, po.recorded_on, null,
       'request_fulfilment', rf.id
from request_fulfilment rf
join material_request_line mrl on mrl.id = rf.material_request_line_id
join material_request mr on mr.id = mrl.material_request_id
join purchase_order_line pol on pol.id = rf.purchase_order_line_id
join purchase_order po on po.id = pol.purchase_order_id

union all
-- Order placed: committed cost (not for stock: stock is an asset until issued),
-- and a cash forecast for every line, paid after terms.
select v.family, v.stage, pol.project_id, pol.category_id,
       case v.family
           when 'cost' then pol.quantity * pol.unit_price
           else -round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
       end, 1.00,
       po.ordered_on, po.recorded_on,
       case v.family when 'cash' then pol.expected_on + po.payment_terms_days end,
       'purchase_order_line', pol.id
from purchase_order_line pol
join purchase_order po on po.id = pol.purchase_order_id
cross join lateral (values ('cost', 'committed'), ('cash', 'forecast')) v(family, stage)
where v.family = 'cash' or not pol.to_stock

union all
-- Supplier's response changed or rejected a line: the order is relieved at its own
-- terms and the accepted terms are committed instead.
select v.family, v.stage, pol.project_id, pol.category_id,
       case v.family
           when 'cost' then t.quantity * t.unit_price - pol.quantity * pol.unit_price
           else round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
                - round(t.quantity * t.unit_price * (1 + pol.vat_rate), 2)
       end, 1.00,
       t.responded_on, t.response_recorded_on,
       case v.family when 'cash' then pol.expected_on + po.payment_terms_days end,
       'order_response', t.order_response_id || ':' || pol.id
from purchase_order_line pol
join purchase_order po on po.id = pol.purchase_order_id
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
cross join lateral (values ('cost', 'committed'), ('cash', 'forecast')) v(family, stage)
where t.order_response_id is not null
  and (t.quantity, t.unit_price) is distinct from (pol.quantity, pol.unit_price)
  and (v.family = 'cash' or not pol.to_stock)

union all
-- Goods received: committed -> incurred at the accepted order price.
select 'cost', v.stage, pol.project_id, pol.category_id,
       v.sign * grl.quantity * t.unit_price, 1.00,
       gr.received_on, gr.recorded_on, null,
       'goods_receipt_line', grl.id
from goods_receipt_line grl
join goods_receipt gr on gr.id = grl.goods_receipt_id
join purchase_order_line pol on pol.id = grl.purchase_order_line_id
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
cross join lateral (values ('committed', -1), ('incurred', 1)) v(stage, sign)
where not pol.to_stock

union all
-- Supplier invoice, once it counts: relieve incurred (after a receipt) or committed
-- (services, no receipt) at the accepted order price; record actual at invoice price.
select 'cost', case when sinl.goods_receipt_line_id is null then 'committed' else 'incurred' end,
       pol.project_id, pol.category_id,
       -sinl.quantity * t.unit_price, 1.00,
       sinv.issued_on, a.counts_from, null,
       'supplier_invoice_line', sinl.id
from supplier_invoice_line sinl
join supplier_invoice sinv on sinv.id = sinl.supplier_invoice_id
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
left join goods_receipt_line grl on grl.id = sinl.goods_receipt_line_id
join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, sinl.purchase_order_line_id)
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
where not pol.to_stock

union all
select 'cost', 'actual', sinl.project_id, sinl.category_id,
       sinl.amount_net, 1.00,
       sinv.issued_on, a.counts_from, null,
       'supplier_invoice_line', sinl.id
from supplier_invoice_line sinl
join supplier_invoice sinv on sinv.id = sinl.supplier_invoice_id
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
left join goods_receipt_line grl on grl.id = sinl.goods_receipt_line_id
left join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, sinl.purchase_order_line_id)
where not coalesce(pol.to_stock, false)

union all
-- Cash: a counting supplier invoice relieves the order forecast and opens a payable.
select 'cash', v.stage, sinl.project_id, sinl.category_id,
       case v.stage
           when 'forecast' then round(sinl.quantity * t.unit_price * (1 + pol.vat_rate), 2)
           else -(sinl.amount_net + sinl.vat_amount)
       end, 1.00,
       sinv.issued_on, a.counts_from,
       case v.stage when 'forecast' then pol.expected_on + po.payment_terms_days else sinv.due_on end,
       'supplier_invoice_line', sinl.id
from supplier_invoice_line sinl
join supplier_invoice sinv on sinv.id = sinl.supplier_invoice_id
join supplier_invoice_approval a on a.supplier_invoice_id = sinv.id and a.counts_from is not null
left join goods_receipt_line grl on grl.id = sinl.goods_receipt_line_id
left join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, sinl.purchase_order_line_id)
left join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
left join purchase_order po on po.id = pol.purchase_order_id
cross join lateral (values ('forecast'), ('open')) v(stage)
where v.stage = 'open' or pol.id is not null;

-- Inventory: stock issues. Receipts into stock never touch cost stages.
create view position_inventory as
-- Stock issue fulfils a request: relieve expected at the request's estimate.
select 'cost' as family, 'expected' as stage, mr.project_id, mrl.category_id,
       -rf.quantity * mrl.estimated_unit_price as amount, 1.00 as probability,
       si.issued_on as effective_on, si.recorded_on, null::date as cash_on,
       'request_fulfilment' as source_type, rf.id as source_id
from request_fulfilment rf
join material_request_line mrl on mrl.id = rf.material_request_line_id
join material_request mr on mr.id = mrl.material_request_id
join stock_issue_line sil on sil.id = rf.stock_issue_line_id
join stock_issue si on si.id = sil.stock_issue_id

union all
-- Stock issued: actual cost at inventory valuation.
select 'cost', 'actual', si.project_id, sil.category_id,
       sil.quantity * sil.unit_cost, 1.00,
       si.issued_on, si.recorded_on, null,
       'stock_issue_line', sil.id
from stock_issue_line sil
join stock_issue si on si.id = sil.stock_issue_id;

-- People: timesheets and payroll.
create view position_people as
-- Hours worked: incurred cost at the standard rate, forecast as wage cash on the
-- 12th of the next month (assumed payday).
select v.family, v.stage, te.project_id, 'labour' as category_id,
       v.sign * te.hours * r.hourly_rate as amount, 1.00 as probability,
       te.worked_on as effective_on, te.recorded_on,
       case v.family when 'cash' then (date_trunc('month', te.worked_on) + interval '1 month 11 days')::date end as cash_on,
       'timesheet_entry' as source_type, te.id as source_id
from timesheet_entry te
cross join lateral (
    select hourly_rate from employee_cost_rate
    where employee_id = te.employee_id and valid_from <= te.worked_on
    order by valid_from desc limit 1
) r
cross join lateral (values ('cost', 'incurred', 1), ('cash', 'forecast', -1)) v(family, stage, sign)

union all
-- Payroll allocated to hours: incurred (standard) -> actual (payroll); the hours
-- forecast becomes an open wage liability due on the payroll pay date.
select v.family, v.stage, te.project_id, 'labour',
       case v.stage
           when 'incurred' then -pa.hours * r.hourly_rate
           when 'actual' then pa.amount
           when 'forecast' then pa.hours * r.hourly_rate
           else -pa.amount
       end, 1.00,
       (pr.period_month + interval '1 month - 1 day')::date, pr.posted_on,
       case v.stage
           when 'forecast' then (date_trunc('month', te.worked_on) + interval '1 month 11 days')::date
           when 'open' then pr.paid_on
       end,
       'payroll_allocation', pa.id
from payroll_allocation pa
join payroll_line pl on pl.id = pa.payroll_line_id
join payroll_run pr on pr.id = pl.payroll_run_id
join timesheet_entry te on te.id = pa.timesheet_entry_id
cross join lateral (
    select hourly_rate from employee_cost_rate
    where employee_id = te.employee_id and valid_from <= te.worked_on
    order by valid_from desc limit 1
) r
cross join lateral (values ('cost', 'incurred'), ('cost', 'actual'), ('cash', 'forecast'), ('cash', 'open')) v(family, stage);

-- CRM: opportunities.
create view position_crm as
-- Opportunity opened: expected revenue, weighted by probability in reports.
select 'revenue' as family, 'expected' as stage, o.project_id, o.category_id,
       o.amount_net as amount, o.probability,
       o.opened_on as effective_on, o.recorded_on, null::date as cash_on,
       'opportunity' as source_type, o.id as source_id
from opportunity o

union all
-- Opportunity won or lost: expected revenue closed in full.
select 'revenue', 'expected', o.project_id, o.category_id,
       -o.amount_net, o.probability,
       oo.decided_on, oo.recorded_on, null,
       'opportunity_outcome', oo.opportunity_id
from opportunity_outcome oo
join opportunity o on o.id = oo.opportunity_id;

-- Sales: orders and customer invoices.
create view position_sales as
-- Sales order: committed (contracted) revenue, forecast as cash after terms.
select v.family, v.stage, so.project_id, sol.category_id,
       case v.family
           when 'revenue' then sol.quantity * sol.unit_price
           else round(sol.quantity * sol.unit_price * (1 + sol.vat_rate), 2)
       end as amount, 1.00 as probability,
       so.ordered_on as effective_on, so.recorded_on,
       case v.family when 'cash' then sol.expected_on + so.payment_terms_days end as cash_on,
       'sales_order_line' as source_type, sol.id as source_id
from sales_order_line sol
join sales_order so on so.id = sol.sales_order_id
cross join lateral (values ('revenue', 'committed'), ('cash', 'forecast')) v(family, stage)

union all
-- Customer invoice linked to an order line: relieve committed revenue and the
-- cash forecast at order price.
select v.family, v.stage, cil.project_id, cil.category_id,
       case v.family
           when 'revenue' then -cil.quantity * sol.unit_price
           else -round(cil.quantity * sol.unit_price * (1 + sol.vat_rate), 2)
       end, 1.00,
       ci.issued_on, ci.recorded_on,
       case v.family when 'cash' then sol.expected_on + so.payment_terms_days end,
       'customer_invoice_line', cil.id
from customer_invoice_line cil
join customer_invoice ci on ci.id = cil.customer_invoice_id
join sales_order_line sol on sol.id = cil.sales_order_line_id
join sales_order so on so.id = sol.sales_order_id
cross join lateral (values ('revenue', 'committed'), ('cash', 'forecast')) v(family, stage)

union all
-- Every customer invoice line, with or without an order: actual revenue and a receivable.
select v.family, v.stage, cil.project_id, cil.category_id,
       case v.family when 'revenue' then cil.amount_net else cil.amount_net + cil.vat_amount end, 1.00,
       ci.issued_on, ci.recorded_on,
       case v.family when 'cash' then ci.due_on end,
       'customer_invoice_line', cil.id
from customer_invoice_line cil
join customer_invoice ci on ci.id = cil.customer_invoice_id
cross join lateral (values ('revenue', 'actual'), ('cash', 'open')) v(family, stage);

-- Treasury: a settlement spread over the lines it settles. Rounding remainders go to
-- the largest line, so settled amounts always equal the bank or the offset.
-- Settlements: bank payments of invoices, payroll and order advances, and advance
-- applications (an advance offset against the final invoice, no bank movement).
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
    select 'payment_allocation', pa.id, pa.amount, 'payroll_allocation', a.id, a.amount
    from payment_allocation pa
    join payroll_line pl on pl.payroll_run_id = pa.payroll_run_id
    join payroll_allocation a on a.payroll_line_id = pl.id
    union all
    -- Advances are spread over the order lines by ordered value (never zero, even if
    -- the supplier later rejects the order).
    select 'payment_allocation', pa.id, pa.amount, 'purchase_order_line', pol.id,
           round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
    from payment_allocation pa
    join purchase_order_line pol on pol.purchase_order_id = pa.purchase_order_id
    union all
    -- An advance application reduces the invoice's payable (over its lines) and hands
    -- back the advance's forecast relief (over the advance's own order lines).
    select 'advance_application_open', aa.id, aa.amount, 'supplier_invoice_line', l.id, l.amount_net + l.vat_amount
    from advance_application aa
    join supplier_invoice_line l on l.supplier_invoice_id = aa.supplier_invoice_id
    union all
    select 'advance_application_forecast', aa.id, aa.amount, 'purchase_order_line', pol.id,
           round(pol.quantity * pol.unit_price * (1 + pol.vat_rate), 2)
    from advance_application aa
    join payment_allocation adv on adv.id = aa.advance_allocation_id
    join purchase_order_line pol on pol.purchase_order_id = adv.purchase_order_id
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
-- Payment of an invoice or payroll: the open item (dated by its due date) becomes
-- settled (dated by the bank).
select 'cash' as family, v.stage, x.project_id, x.category_id,
       v.sign * x.direction * s.amount as amount, 1.00 as probability,
       bt.booked_on as effective_on, bt.recorded_on,
       case v.stage when 'open' then x.due_on else bt.booked_on end as cash_on,
       'payment_allocation' as source_type, pa.id || ':' || s.line_id as source_id
from settlement_line s
join payment_allocation pa on s.settlement_type = 'payment_allocation' and pa.id = s.settlement_id
join bank_transaction bt on bt.id = pa.bank_transaction_id
join lateral (
    select l.project_id, l.category_id, si.due_on, -1 as direction
    from supplier_invoice_line l join supplier_invoice si on si.id = l.supplier_invoice_id
    where s.line_type = 'supplier_invoice_line' and l.id = s.line_id
    union all
    select l.project_id, l.category_id, ci.due_on, 1
    from customer_invoice_line l join customer_invoice ci on ci.id = l.customer_invoice_id
    where s.line_type = 'customer_invoice_line' and l.id = s.line_id
    union all
    select te.project_id, 'labour', pr.paid_on, -1
    from payroll_allocation a
    join timesheet_entry te on te.id = a.timesheet_entry_id
    join payroll_line pl on pl.id = a.payroll_line_id
    join payroll_run pr on pr.id = pl.payroll_run_id
    where s.line_type = 'payroll_allocation' and a.id = s.line_id
) x on true
cross join lateral (values ('open', -1), ('settled', 1)) v(stage, sign)

union all
-- Advance paid against an order: settled now, and the order's cash forecast is
-- relieved by the same amount (at the order's cash date).
select 'cash', v.stage, pol.project_id, pol.category_id,
       case v.stage when 'forecast' then s.amount else -s.amount end, 1.00,
       bt.booked_on, bt.recorded_on,
       case v.stage when 'forecast' then pol.expected_on + po.payment_terms_days else bt.booked_on end,
       'payment_allocation', pa.id || ':' || s.line_id
from settlement_line s
join payment_allocation pa on s.settlement_type = 'payment_allocation' and pa.id = s.settlement_id
join bank_transaction bt on bt.id = pa.bank_transaction_id
join purchase_order_line pol on s.line_type = 'purchase_order_line' and pol.id = s.line_id
join purchase_order po on po.id = pol.purchase_order_id
cross join lateral (values ('forecast'), ('settled')) v(stage)

union all
-- Advance applied to the final invoice, once that invoice counts: the payable shrinks...
select 'cash', 'open', l.project_id, l.category_id,
       s.amount, 1.00,
       aa.applied_on, greatest(aa.recorded_on, a.counts_from), si.due_on,
       'advance_application', aa.id || ':' || l.id
from settlement_line s
join advance_application aa on s.settlement_type = 'advance_application_open' and aa.id = s.settlement_id
join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
join supplier_invoice_line l on l.id = s.line_id
join supplier_invoice si on si.id = l.supplier_invoice_id

union all
-- ...and the advance's relief of its order's forecast is handed back, because the
-- invoice now relieves that forecast itself.
select 'cash', 'forecast', pol.project_id, pol.category_id,
       -s.amount, 1.00,
       aa.applied_on, greatest(aa.recorded_on, a.counts_from), pol.expected_on + po.payment_terms_days,
       'advance_application', aa.id || ':' || pol.id
from settlement_line s
join advance_application aa on s.settlement_type = 'advance_application_forecast' and aa.id = s.settlement_id
join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
join purchase_order_line pol on pol.id = s.line_id
join purchase_order po on po.id = pol.purchase_order_id;

-- The platform unions the views of the installed products.
create view position_entry as
select family, stage, project_id, category_id, round(amount, 2)::numeric(14, 2) as amount,
       probability, effective_on, recorded_on, cash_on, source_type, source_id
from (
    select * from position_crm
    union all select * from position_sales
    union all select * from position_procurement
    union all select * from position_inventory
    union all select * from position_people
    union all select * from position_treasury
) installed;

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
        where pl.plan_version_id = plan_version
        group by pl.project_id, pl.category_id
    ),
    pos as (
        select s.project_id, s.category_id, s.family,
               coalesce(s.expected, 0) as expected, coalesce(s.committed, 0) as committed,
               coalesce(s.incurred, 0) as incurred, coalesce(s.actual, 0) as actual
        from position_summary(valid_on, known_on) s
        where s.family in ('cost', 'revenue')
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
    full join pos on pos.project_id = p.project_id and pos.category_id = p.category_id
    join category c on c.id = coalesce(p.category_id, pos.category_id)
    cross join lateral (
        select case c.family
                   when 'cost' then coalesce(pos.expected, 0) + coalesce(pos.committed, 0)
                                    + coalesce(pos.incurred, 0) + coalesce(pos.actual, 0)
                   else coalesce(pos.committed, 0) + coalesce(pos.incurred, 0) + coalesce(pos.actual, 0)
               end as consumed
    ) x
$$;
