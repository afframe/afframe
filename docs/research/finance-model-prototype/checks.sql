-- Reports and assertions for the worked example. Any failed assertion aborts the run.
set search_path = finance_model;
\pset footer off

create function assert_equal(label text, actual numeric, expected numeric)
returns void
language plpgsql
as $$
begin
    if actual is distinct from expected then
        raise exception 'FAILED %: got %, expected %', label, actual, expected;
    end if;
end
$$;

\echo '== 1. Positions for P1 on 31 May 2026 (one query, every stage)'
select family, category_id, expected, expected_weighted, committed, incurred, actual, forecast, open, settled
from position_summary('2026-05-31', '2026-05-31')
where project_id = 'P1'
order by family, category_id;

\echo '== 2. Budget control and estimate at completion, P1, budget B1'
select category_id, plan, expected, committed, incurred, actual, consumed, available, remaining_plan, estimate_at_completion
from project_control('B1', '2026-05-31', '2026-05-31')
where project_id = 'P1'
order by family desc, category_id;

\echo '== 3. Same, scenario S1 (labour +25 %): only the uncommitted remainder changes'
select category_id, plan, consumed, remaining_plan, estimate_at_completion
from project_control('S1', '2026-05-31', '2026-05-31')
where project_id = 'P1'
order by family desc, category_id;

\echo '== 4. Project P&L for P1 on 31 May 2026'
select sum(actual) filter (where family = 'revenue') as revenue_actual,
       sum(actual) filter (where family = 'cost') as cost_actual,
       sum(incurred) filter (where family = 'cost') as cost_incurred_not_booked,
       sum(actual) filter (where family = 'revenue')
         - sum(coalesce(actual, 0) + coalesce(incurred, 0)) filter (where family = 'cost') as margin_to_date,
       sum(estimate_at_completion) filter (where family = 'revenue')
         - sum(estimate_at_completion) filter (where family = 'cost') as margin_at_completion
from project_control('B1', '2026-05-31', '2026-05-31')
where project_id = 'P1';

\echo '== 5. Budget vs actual by month, P1 (plan store joined to projection on shared dimensions)'
with actual as (
    select category_id, date_trunc('month', effective_on)::date as period_month,
           sum(amount) filter (where stage = 'actual') as actual,
           sum(amount) filter (where stage = 'incurred') as incurred
    from position_entry
    where project_id = 'P1' and family in ('cost', 'revenue') and stage in ('actual', 'incurred')
    group by 1, 2
)
select coalesce(p.category_id, a.category_id) as category_id,
       coalesce(p.period_month, a.period_month) as period_month,
       coalesce(p.amount_net, 0) as budget, coalesce(a.actual, 0) as actual, coalesce(a.incurred, 0) as incurred
from (select * from plan_line where plan_version_id = 'B1' and project_id = 'P1') p
full join actual a on a.category_id = p.category_id and a.period_month = p.period_month
order by 1, 2;

\echo '== 6. As reported on 31 March vs as known today for 31 March, P1 cost'
select 'as reported 2026-03-31' as view, category_id, expected, committed, incurred, actual
from position_summary('2026-03-31', '2026-03-31') where project_id = 'P1' and family = 'cost'
union all
select 'as known 2026-05-31', category_id, expected, committed, incurred, actual
from position_summary('2026-03-31', '2026-05-31') where project_id = 'P1' and family = 'cost'
order by 1 desc, 2;

\echo '== 7. Cash by cash date month, P1 and company (settled = bank, open = invoices and payroll, forecast = orders and hours)'
select date_trunc('month', cash_on)::date as cash_month, stage,
       sum(amount) filter (where project_id = 'P1') as p1,
       sum(amount) as company
from position_entry
where family = 'cash'
group by 1, 2
having sum(amount) <> 0 or sum(amount) filter (where project_id = 'P1') <> 0
order by 1, 2;

\echo '== 8. Statutory trial balance (Accounting product, posted from typed records)'
select account_code, a.name, sum(debit) - sum(credit) as balance
from journal_line jl join account a on a.code = jl.account_code
group by 1, 2 order by 1;

\echo '== 9. Reconciliation: management actuals vs statutory P&L by project, category, month'
create temporary view reconciliation as
with management as (
    select coalesce(project_id, '-') as project_id, category_id,
           date_trunc('month', effective_on)::date as period_month, sum(amount) as amount
    from position_entry
    where family in ('cost', 'revenue') and stage = 'actual'
    group by 1, 2, 3
),
ledger as (
    select coalesce(jl.project_id, '-') as project_id, a.category_id,
           date_trunc('month', je.entry_date)::date as period_month,
           sum(case c.family when 'cost' then jl.debit - jl.credit else jl.credit - jl.debit end) as amount
    from journal_line jl
    join journal_entry je on je.id = jl.journal_entry_id
    join account a on a.code = jl.account_code
    join category c on c.id = a.category_id
    group by 1, 2, 3
)
select project_id, category_id, period_month,
       m.amount as management, l.amount as ledger, coalesce(m.amount, 0) - coalesce(l.amount, 0) as difference
from management m
full join ledger l using (project_id, category_id, period_month);
select * from reconciliation order by 1, 2, 3;

\echo '== 10. Timesheet correction: TS6 on the wrong project, reversed on 28 May'
select known_on, sum(amount) as p1_labour_incurred_may
from (values ('2026-05-27'::date), ('2026-05-31'::date)) k(known_on)
cross join lateral position_as_of('2026-05-31', k.known_on) e
where e.project_id = 'P1' and e.family = 'cost' and e.stage = 'incurred' and e.category_id = 'labour'
group by 1 order by 1;

\echo '== 11. Peppol-style responses: order PO5 accepted with changes, invoices under approval'
select 'order' as document, r.purchase_order_id as id, r.response_code, r.responded_on,
       t.quantity as accepted_quantity, t.unit_price as accepted_price
from order_response r
join purchase_order_line pol on pol.purchase_order_id = r.purchase_order_id
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
union all
select 'supplier invoice', r.supplier_invoice_id, r.response_code, r.responded_on, null, null
from invoice_response r
order by 1, 2, 4;

-- ---------------------------------------------------------------------------
-- Assertions (results suppressed; a failure raises an error)
-- ---------------------------------------------------------------------------
\o /dev/null

-- Generic invariant: every cost and revenue stage, per project, equals the open
-- remainder of the typed records computed directly (quantity not yet passed on,
-- at the record's own price). Together with actual this proves that every unit
-- is counted once, at its most advanced amount.
create temporary view state_position as
select 'cost' as family, 'expected' as stage, mr.project_id,
       sum((mrl.quantity - coalesce(f.qty, 0)) * mrl.estimated_unit_price) as amount
from material_request_line mrl
join material_request mr on mr.id = mrl.material_request_id
left join (select material_request_line_id, sum(quantity) as qty from request_fulfilment group by 1) f
  on f.material_request_line_id = mrl.id
group by 3
union all
select 'cost', 'committed', pol.project_id,
       sum((t.quantity - coalesce(r.qty, 0) - coalesce(d.qty, 0)) * t.unit_price)
from purchase_order_line pol
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
left join (select purchase_order_line_id, sum(quantity) as qty from goods_receipt_line group by 1) r
  on r.purchase_order_line_id = pol.id
left join (select l.purchase_order_line_id, sum(l.quantity) as qty from supplier_invoice_line l
           join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
           group by 1) d
  on d.purchase_order_line_id = pol.id
where not pol.to_stock
group by 3
union all
select 'cost', 'incurred', pol.project_id, sum((grl.quantity - coalesce(i.qty, 0)) * t.unit_price)
from goods_receipt_line grl
join purchase_order_line pol on pol.id = grl.purchase_order_line_id
join purchase_order_line_terms t on t.purchase_order_line_id = pol.id
left join (select l.goods_receipt_line_id, sum(l.quantity) as qty from supplier_invoice_line l
           join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
           group by 1) i
  on i.goods_receipt_line_id = grl.id
where not pol.to_stock
group by 3
union all
select 'cost', 'incurred', te.project_id, sum((te.hours - coalesce(a.hours, 0)) * r.hourly_rate)
from timesheet_entry te
left join (select timesheet_entry_id, sum(hours) as hours from payroll_allocation group by 1) a
  on a.timesheet_entry_id = te.id
cross join lateral (
    select hourly_rate from employee_cost_rate
    where employee_id = te.employee_id and valid_from <= te.worked_on
    order by valid_from desc limit 1
) r
group by 3
union all
select 'cost', 'actual', l.project_id, sum(l.amount_net)
from supplier_invoice_line l
join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
left join goods_receipt_line grl on grl.id = l.goods_receipt_line_id
left join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, l.purchase_order_line_id)
where not coalesce(pol.to_stock, false)
group by 3
union all
select 'cost', 'actual', si.project_id, sum(l.quantity * l.unit_cost)
from stock_issue_line l join stock_issue si on si.id = l.stock_issue_id
group by 3
union all
select 'cost', 'actual', te.project_id, sum(a.amount)
from payroll_allocation a join timesheet_entry te on te.id = a.timesheet_entry_id
group by 3
union all
select 'revenue', 'expected', o.project_id, sum(o.amount_net)
from opportunity o
where not exists (select 1 from opportunity_outcome oo where oo.opportunity_id = o.id)
group by 3
union all
select 'revenue', 'committed', so.project_id, sum((sol.quantity - coalesce(i.qty, 0)) * sol.unit_price)
from sales_order_line sol
join sales_order so on so.id = sol.sales_order_id
left join (select sales_order_line_id, sum(quantity) as qty from customer_invoice_line group by 1) i
  on i.sales_order_line_id = sol.id
group by 3
union all
select 'revenue', 'actual', l.project_id, sum(l.amount_net)
from customer_invoice_line l
group by 3;

select assert_equal('every cost and revenue stage equals the open remainder of typed records',
    sum(abs(coalesce(p.amount, 0) - coalesce(s.amount, 0))), 0)
from (select family, stage, coalesce(project_id, '-') as project_id, sum(amount) as amount
      from state_position group by 1, 2, 3) s
full join (select family, stage, coalesce(project_id, '-') as project_id, sum(amount) as amount
           from position_entry where family in ('cost', 'revenue') group by 1, 2, 3) p
using (family, stage, project_id);

-- Cash completeness: settled equals the bank; open equals documents minus settlements.
select assert_equal('cash settled equals bank movements',
    (select sum(amount) from position_entry where family = 'cash' and stage = 'settled'),
    (select sum(amount) from bank_transaction));
select assert_equal('cash open equals unpaid counting documents and payroll',
    (select sum(amount) from position_entry where family = 'cash' and stage = 'open'),
    (select sum(amount_net + vat_amount) from customer_invoice_line)
    - (select sum(l.amount_net + l.vat_amount) from supplier_invoice_line l
       join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null)
    - (select sum(amount) from payroll_allocation)
    - (select coalesce(sum(amount), 0) from payment_allocation where customer_invoice_id is not null)
    + (select coalesce(sum(amount), 0) from payment_allocation where supplier_invoice_id is not null or payroll_run_id is not null)
    + (select coalesce(sum(aa.amount), 0) from advance_application aa
       join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null));

-- Worked-example figures (copied into the report).
select assert_equal('P1 materials expected (1 open frame at the 30 000 estimate)', expected, 30000),
       assert_equal('P1 materials committed', committed, 0),
       assert_equal('P1 materials incurred', incurred, 0),
       assert_equal('P1 materials actual', actual, 322500)
from position_summary('2026-05-31', '2026-05-31') where project_id = 'P1' and family = 'cost' and category_id = 'materials';

select assert_equal('P1 subcontract committed (40 % not yet billed)', committed, 60000),
       assert_equal('P1 subcontract actual (60 % billed, no receipt)', actual, 90000)
from position_summary('2026-05-31', '2026-05-31') where project_id = 'P1' and family = 'cost' and category_id = 'subcontracting';

select assert_equal('P1 labour incurred (6 h at 500 not yet in payroll)', incurred, 3000),
       assert_equal('P1 labour actual (payroll)', actual, 64400)
from position_summary('2026-05-31', '2026-05-31') where project_id = 'P1' and family = 'cost' and category_id = 'labour';

select assert_equal('P1 pipeline not earned', expected, 150000),
       assert_equal('P1 pipeline weighted', expected_weighted, 75000),
       assert_equal('P1 contracted not invoiced', committed, 300000),
       assert_equal('P1 revenue actual (incl. invoice without order)', actual, 750000)
from position_summary('2026-05-31', '2026-05-31') where project_id = 'P1' and family = 'revenue';

select assert_equal('B1 materials available (overrun)', available, -2500),
       assert_equal('B1 materials EAC', estimate_at_completion, 352500)
from project_control('B1', '2026-05-31', '2026-05-31') where project_id = 'P1' and category_id = 'materials';

select assert_equal('B1 labour available', available, 52600),
       assert_equal('S1 labour EAC', (select estimate_at_completion from project_control('S1', '2026-05-31', '2026-05-31')
                                      where project_id = 'P1' and category_id = 'labour'), 150000)
from project_control('B1', '2026-05-31', '2026-05-31') where project_id = 'P1' and category_id = 'labour';

select assert_equal('B1 revenue over plan', available, -50000),
       assert_equal('B1 revenue EAC', estimate_at_completion, 1050000)
from project_control('B1', '2026-05-31', '2026-05-31') where project_id = 'P1' and category_id = 'revenue';

select assert_equal('P1 cash settled', sum(amount) filter (where stage = 'settled'), 160040),
       assert_equal('P1 cash open', sum(amount) filter (where stage = 'open'), 78610),
       assert_equal('P1 cash forecast', sum(amount) filter (where stage = 'forecast'), 237000)
from position_entry where project_id = 'P1' and family = 'cash';

-- Reliefs carry the relieved item's cash date: fulfilled forecasts and paid items net to zero per month.
select assert_equal('P1 forecast buckets: May subcontract remainder, June milestone and hours',
    sum(abs(amount - case m when '2026-05-01' then -60000 when '2026-06-01' then 297000 else 0 end)), 0)
from (select date_trunc('month', cash_on) as m, sum(amount) as amount from position_entry
      where project_id = 'P1' and family = 'cash' and stage = 'forecast' group by 1) b;
select assert_equal('P1 open buckets: May overdue items, June CI3',
    sum(abs(amount - case m when '2026-05-01' then 28610 when '2026-06-01' then 50000 else 0 end)), 0)
from (select date_trunc('month', cash_on) as m, sum(amount) as amount from position_entry
      where project_id = 'P1' and family = 'cash' and stage = 'open' group by 1) b;

-- As reported on 31 March: the late invoice and March payroll were not yet known.
select assert_equal('31 Mar as reported: expected', sum(expected), 60000),
       assert_equal('31 Mar as reported: committed', sum(committed), 272000),
       assert_equal('31 Mar as reported: incurred', sum(incurred), 148000),
       assert_equal('31 Mar as reported: actual', coalesce(sum(actual), 0), 0)
from position_summary('2026-03-31', '2026-03-31') where project_id = 'P1' and family = 'cost';

select assert_equal('31 Mar as known now: incurred', sum(incurred), 0),
       assert_equal('31 Mar as known now: actual (invoice 128 000 + payroll 22 000)', sum(actual), 150000)
from position_summary('2026-03-31', '2026-05-31') where project_id = 'P1' and family = 'cost';

-- Reconciliation must be exact for every project (including none), category and month.
select assert_equal('management actual vs ledger, total absolute difference', sum(abs(difference)), 0)
from reconciliation;

select assert_equal('ledger balances', sum(debit) - sum(credit), 0) from journal_line;
select assert_equal('bank balance in ledger', sum(debit) - sum(credit), 551640) from journal_line where account_code = '221';
select assert_equal('deductible input VAT (reverse charge nets to zero)', sum(debit) - sum(credit), 73710)
from journal_line where account_code = '343';

-- No double counting, stated for one chain: 6 frames at 32 000 + 2 000 correction,
-- 2 at 29 500, 1 from stock at 27 500, 1 still at the 30 000 estimate, 40 m2 at 1 050.
select assert_equal('materials stages sum to most advanced amounts', sum(amount), 6 * 32000 + 2000 + 2 * 29500 + 27500 + 30000 + 40 * 1050)
from position_entry where project_id = 'P1' and family = 'cost' and category_id = 'materials';

-- Order response: the committed amount follows the supplier's accepted terms.
select assert_equal('PO5 committed as ordered (50 x 1 000) before the response', sum(amount), 50000)
from position_as_of('2026-04-20', '2026-04-20') where family = 'cost' and stage = 'committed'
  and (source_id = 'PO5-1' or source_id like 'OR5:%');
select assert_equal('PO5 committed as accepted (40 x 1 050) after the response', sum(amount), 42000)
from position_as_of('2026-04-21', '2026-04-21') where family = 'cost' and stage = 'committed'
  and (source_id = 'PO5-1' or source_id like 'OR5:%');

-- Invoice approval: VB3 counts only from its acceptance on 12 April; the rejected VB6 never counts.
select assert_equal('10 Apr as known 10 Apr: receipts GR2 and GR3 still incurred', sum(amount), 122000)
from position_as_of('2026-04-10', '2026-04-10') where project_id = 'P1' and family = 'cost'
  and stage = 'incurred' and category_id = 'materials';
select assert_equal('10 Apr as known 12 Apr: VB3 accepted, only GR2 incurred', sum(amount), 64000)
from position_as_of('2026-04-10', '2026-04-12') where project_id = 'P1' and family = 'cost'
  and stage = 'incurred' and category_id = 'materials';
select assert_equal('rejected VB6 has no positions', count(*), 0) from position_entry where source_id like '%VB6%';
select assert_equal('rejection is terminal, only before acceptance, only under approval', count(*), 0)
from invoice_response re
join supplier_invoice si on si.id = re.supplier_invoice_id
where re.response_code = 'RE'
  and (not si.requires_approval
       or exists (select 1 from invoice_response ok where ok.supplier_invoice_id = re.supplier_invoice_id
                  and ok.response_code in ('AP', 'CA')));
select assert_equal('rejected VB6 has no ledger entry', count(*), 0) from journal_entry where source_id = 'VB6';
select assert_equal('payments only settle counting invoices', count(*), 0)
from payment_allocation pa
join bank_transaction bt on bt.id = pa.bank_transaction_id
left join supplier_invoice_approval a on a.supplier_invoice_id = pa.supplier_invoice_id
where pa.supplier_invoice_id is not null and (a.counts_from is null or a.counts_from > bt.recorded_on);

-- Advance: paying half of PO5 before delivery never changes the total cash exposure of the order.
select assert_equal('PO5 cash exposure on 30 Apr (advance paid, rest forecast)', sum(amount), -50820)
from position_as_of('2026-04-30', '2026-04-30') where family = 'cash'
  and (source_id like '%PO5%' or source_id like '%VB7%' or source_id like 'AA1:%');
select assert_equal('PO5 cash exposure on 31 May (all settled)', sum(amount), -50820),
       assert_equal('PO5 nothing left in forecast or open', sum(abs(amount)) filter (where stage <> 'settled'), 0)
from (select stage, sum(amount) as amount from position_entry where family = 'cash'
        and (source_id like '%PO5%' or source_id like '%VB7%' or source_id like 'AA1:%') group by 1) x;
select assert_equal('advance applications never exceed the advance', count(*), 0)
from (select aa.advance_allocation_id from advance_application aa
      join payment_allocation pa on pa.id = aa.advance_allocation_id
      group by aa.advance_allocation_id, pa.amount having sum(aa.amount) > pa.amount) x;

-- Self-billing: a self-billed invoice needs a valid self-billing agreement with that supplier.
select assert_equal('self-billed invoices have a valid agreement', count(*), 0)
from supplier_invoice si
left join agreement ag on ag.id = si.self_billing_agreement_id
where si.self_billing_agreement_id is not null
  and (ag.kind <> 'self_billing' or ag.counterparty_id <> si.counterparty_id
       or si.issued_on < ag.valid_from or si.issued_on > coalesce(ag.valid_to, 'infinity'));

-- Fulfilment never exceeds the obligation (without an explicit exception record).
select assert_equal('requests: fulfilled <= requested', count(*), 0)
from material_request_line mrl
join (select material_request_line_id, sum(quantity) as qty from request_fulfilment group by 1) f
  on f.material_request_line_id = mrl.id
where f.qty > mrl.quantity;
select assert_equal('orders: received or billed <= accepted', count(*), 0)
from purchase_order_line_terms t
left join (select purchase_order_line_id, sum(quantity) as qty from goods_receipt_line group by 1) r
  on r.purchase_order_line_id = t.purchase_order_line_id
left join (select l.purchase_order_line_id, sum(l.quantity) as qty from supplier_invoice_line l
           join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
           group by 1) d on d.purchase_order_line_id = t.purchase_order_line_id
where coalesce(r.qty, 0) + coalesce(d.qty, 0) > t.quantity;
select assert_equal('receipts: billed <= received', count(*), 0)
from goods_receipt_line grl
join (select l.goods_receipt_line_id, sum(l.quantity) as qty from supplier_invoice_line l
      join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
      group by 1) i on i.goods_receipt_line_id = grl.id
where i.qty > grl.quantity;

-- Settlement never exceeds the open obligation; money beyond it must be a recorded advance.
select assert_equal('supplier invoices: payments + advances applied <= gross', count(*), 0)
from supplier_invoice si
join (select supplier_invoice_id, sum(amount_net + vat_amount) as gross from supplier_invoice_line group by 1) g
  on g.supplier_invoice_id = si.id
left join (select supplier_invoice_id, sum(amount) as amount from payment_allocation group by 1) p
  on p.supplier_invoice_id = si.id
left join (select supplier_invoice_id, sum(amount) as amount from advance_application group by 1) aa
  on aa.supplier_invoice_id = si.id
where coalesce(p.amount, 0) + coalesce(aa.amount, 0) > g.gross;
select assert_equal('customer invoices: payments <= gross', count(*), 0)
from (select customer_invoice_id, sum(amount_net + vat_amount) as gross from customer_invoice_line group by 1) g
join (select customer_invoice_id, sum(amount) as amount from payment_allocation group by 1) p
  using (customer_invoice_id)
where p.amount > g.gross;

-- A request cannot stay linked to more than the supplier accepted: when a response cuts
-- an order line, Procurement must return the difference to the request.
select assert_equal('request links <= accepted order quantity', count(*), 0)
from purchase_order_line_terms t
join (select purchase_order_line_id, sum(quantity) as qty from request_fulfilment
      where purchase_order_line_id is not null group by 1) f using (purchase_order_line_id)
where f.qty > t.quantity;

-- Accepted terms are current state, so a response must come before any receipt or invoice
-- on that order (later changes need versioned terms, see report section 11).
select assert_equal('order responses precede fulfilment', count(*), 0)
from order_response r
join purchase_order_line pol on pol.purchase_order_id = r.purchase_order_id
where exists (select 1 from goods_receipt_line grl join goods_receipt gr on gr.id = grl.goods_receipt_id
              where grl.purchase_order_line_id = pol.id and gr.recorded_on < r.recorded_on)
   or exists (select 1 from supplier_invoice_line l join supplier_invoice si on si.id = l.supplier_invoice_id
              where l.purchase_order_line_id = pol.id and si.recorded_on < r.recorded_on);

select assert_equal('advances are only applied to counting invoices', count(*), 0)
from advance_application aa
left join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id
where a.counts_from is null;

-- Regression probes from the final review (each rolled back).
begin;
insert into purchase_order values ('PX1', 'SUPPLIER_A', '2026-05-01', '2026-05-01', 14);
insert into purchase_order_line values ('PX1-1', 'PX1', 'panels', 'P1', false, 'materials', 5, 100, 0.21, '2026-05-10');
insert into bank_transaction values ('BX1', '2026-05-02', -605, 'advance, order later rejected', '2026-05-02');
insert into payment_allocation (id, bank_transaction_id, purchase_order_id, amount) values ('PAX1', 'BX1', 'PX1', 605);
insert into order_response values ('ORX1', 'PX1', 'RE', '2026-05-03', '2026-05-03');
select assert_equal('rejected order with an advance: projection readable, advance settled', sum(amount), -605)
from position_entry where source_id like 'PAX1:%' and stage = 'settled';
select assert_equal('rejected order with an advance: forecast shows the refund due', sum(amount), 605)
from position_entry where family = 'cash' and stage = 'forecast'
  and (source_id = 'PX1-1' or source_id like 'ORX1:%' or source_id like 'PAX1:%');
rollback;

begin;
insert into supplier_invoice values ('VX1', 'SUPPLIER_C', '2026-05-20', '2026-06-19', '2026-05-20', false, null);
insert into supplier_invoice_line (id, supplier_invoice_id, project_id, category_id, quantity, amount_net, vat_amount)
values ('VX1-1', 'VX1', 'P1', 'subcontracting', 0, 10000, 0);
insert into bank_transaction values ('BX2', '2026-05-05', -1000, 'advance on PO3', '2026-05-05');
insert into payment_allocation (id, bank_transaction_id, purchase_order_id, amount) values ('PAX2', 'BX2', 'PO3', 1000);
insert into advance_application values ('AAX2', 'PAX2', 'VX1', 1000, '2026-05-21', '2026-05-21');
select assert_equal('advance applied to an unlinked invoice still reduces the payable', sum(amount), 1000)
from position_entry where source_id like 'AAX2:%' and stage = 'open';
select assert_equal('advance on PO3 nets out of the PO3 forecast', sum(amount), 0)
from position_entry where family = 'cash' and stage = 'forecast'
  and (source_id like 'PAX2:%' or source_id like 'AAX2:PO3%');
rollback;

begin;
update supplier_invoice set requires_approval = true where id = 'VB7';
select assert_equal('advance application to an unapproved invoice has no effect yet', count(*), 0)
from position_entry where source_id like 'AA1:%';
rollback;

-- Regression: a payment spread over lines never loses cents.
begin;
insert into supplier_invoice values ('R1', 'SUPPLIER_A', '2026-05-01', '2026-05-31', '2026-05-01');
insert into supplier_invoice_line (id, supplier_invoice_id, project_id, category_id, quantity, amount_net, vat_amount) values
    ('R1-1', 'R1', 'P1', 'materials', 0, 100, 0),
    ('R1-2', 'R1', 'P1', 'materials', 0, 100, 0),
    ('R1-3', 'R1', 'P1', 'materials', 0, 100, 0);
insert into bank_transaction values ('RB1', '2026-05-10', -100, 'rounding probe', '2026-05-10');
insert into payment_allocation (id, bank_transaction_id, supplier_invoice_id, amount) values ('RPA1', 'RB1', 'R1', 100);
select assert_equal('rounding: settled equals the payment', sum(amount), -100)
from position_entry where source_id like 'RPA1:%' and stage = 'settled';
rollback;

\o
\echo 'ALL ASSERTIONS PASSED'
