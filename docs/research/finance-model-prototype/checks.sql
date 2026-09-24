-- Reports and assertions for the worked example. Any failed assertion aborts the run.
set search_path = finance_model;
set jit = off;  -- tiny data: compiling the projection's plans costs more than running them
\pset footer off

-- Every assertion increments the counter; the run prints the total at the end.
create sequence assertion_count;

create function assert_equal(label text, actual numeric, expected numeric)
returns void
language plpgsql
as $$
begin
    perform nextval('assertion_count');
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
    where c.family in ('cost', 'revenue')
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

\echo '== 12. Backward trace: journal line -> source record -> order -> CRM opportunity'
create temporary view journal_trace as
select jl.id as journal_line_id, je.id as journal_entry_id, jl.account_code, jl.project_id,
       je.source_type, je.source_id, x.order_type, x.order_id, x.opportunity_id
from journal_line jl
join journal_entry je on je.id = jl.journal_entry_id
left join lateral (
    select distinct 'sales_order' as order_type, so.id as order_id, so.opportunity_id
    from customer_invoice_line l
    join sales_order_line sol on sol.id = l.sales_order_line_id
    join sales_order so on so.id = sol.sales_order_id
    where je.source_type = 'customer_invoice' and l.customer_invoice_id = je.source_id
      and (jl.project_id is null or l.project_id = jl.project_id)
    union
    select distinct 'purchase_order', pol.purchase_order_id, null
    from supplier_invoice_line l
    left join goods_receipt_line grl on grl.id = l.goods_receipt_line_id
    join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, l.purchase_order_line_id)
    where je.source_type = 'supplier_invoice' and l.supplier_invoice_id = je.source_id
      and (jl.project_id is null or l.project_id = jl.project_id)
) x on true;
select journal_entry_id, account_code, project_id, source_type, source_id, order_type, order_id, opportunity_id
from journal_trace
where project_id = 'P1' and account_code = '602'
order by journal_entry_id;

-- ---------------------------------------------------------------------------
-- Assertions (results suppressed; a failure raises an error)
-- ---------------------------------------------------------------------------
\o /dev/null

-- Generic invariant: every cost and revenue stage, per project, equals the open
-- remainder of the typed records computed directly (quantity not yet passed on,
-- at the record's own price). It is a consistency check: it re-derives each stage
-- from the same links, so a missing link hides from both sides.
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
left join (select purchase_order_line_id, sum(quantity) as qty from goods_receipt_line
           where supplier_invoice_line_id is null group by 1) r
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
where not pol.to_stock and grl.supplier_invoice_line_id is null
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
where not coalesce(pol.to_stock, grl.id is not null)
group by 3
union all
select 'cost', 'actual', si.project_id, sum(l.quantity * l.unit_cost)
from stock_issue_line l join stock_issue si on si.id = l.stock_issue_id
group by 3
union all
select 'cost', 'actual', x.project_id, sum(x.amount)
from (select project_id, amount from payroll_cost_line
      union all
      select te.project_id, a.amount from payroll_allocation a join timesheet_entry te on te.id = a.timesheet_entry_id
      union all
      select pc.project_id, -a.amount from payroll_allocation a join payroll_cost_line pc on pc.id = a.payroll_cost_line_id) x
group by 3
union all
select c.family, 'actual', b.project_id, sum(case c.family when 'cost' then -b.amount else b.amount end)
from bank_line_classification b join category c on c.id = b.category_id
where c.family in ('cost', 'revenue')
group by c.family, b.project_id
union all
select c.family, 'actual', l.project_id, sum(case c.family when 'cost' then l.debit - l.credit else l.credit - l.debit end)
from internal_document_line l join category c on c.id = l.category_id
where c.family in ('cost', 'revenue')
group by c.family, l.project_id
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

create temporary view stage_difference as
select coalesce(sum(abs(coalesce(p.amount, 0) - coalesce(s.amount, 0))), 0) as difference
from (select family, stage, coalesce(project_id, '-') as project_id, sum(amount) as amount
      from state_position group by 1, 2, 3) s
full join (select family, stage, coalesce(project_id, '-') as project_id, sum(amount) as amount
           from position_entry where family in ('cost', 'revenue') group by 1, 2, 3) p
using (family, stage, project_id);
select assert_equal('every cost and revenue stage equals the open remainder of typed records', difference, 0)
from stage_difference;

-- Cash completeness: settled equals the bank; open equals documents minus settlements.
select assert_equal('cash settled equals bank movements',
    (select sum(amount) from position_entry where family = 'cash' and stage = 'settled'),
    (select sum(amount) from bank_transaction));
select assert_equal('cash open equals unpaid counting documents and payroll',
    (select sum(amount) from position_entry where family = 'cash' and stage = 'open'),
    (select sum(amount_net + vat_amount) from customer_invoice_line)
    - (select sum(l.amount_net + l.vat_amount) from supplier_invoice_line l
       join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null)
    - (select sum(amount) from payroll_cost_line)
    - (select coalesce(sum(amount), 0) from supplier_advance_request)
    - (select coalesce(sum(amount), 0) from payment_allocation where customer_invoice_id is not null)
    + (select coalesce(sum(amount), 0) from payment_allocation
       where supplier_invoice_id is not null or payroll_run_id is not null or supplier_advance_request_id is not null)
    + (select coalesce(sum(aa.amount), 0) from advance_application aa
       join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null));

-- Independent cash invariant (EVIDENCE-1, MONEY-8): what every record finally owes or
-- brings, by stage, recomputed from the raw records without the projection's helper
-- views (accepted terms, invoice approval, settlement spreading, payroll units).
-- Pairs that only move money between stages of one line (a payment, an advance applied)
-- are stated company-wide (no project), so they cancel in the per-project comparison.
create temporary view cash_state as
with counting as (
    select si.id from supplier_invoice si
    where not si.requires_approval
       or exists (select 1 from invoice_response r where r.supplier_invoice_id = si.id and r.response_code in ('AP', 'CA'))
),
accepted as (
    select pol.id, pol.project_id, pol.category_id, pol.vat_rate,
           coalesce(x.quantity, pol.quantity) as quantity, coalesce(x.unit_price, pol.unit_price) as unit_price
    from purchase_order_line pol
    left join lateral (
        select case when r.response_code = 'RE' then 0 else coalesce(rl.accepted_quantity, pol.quantity) end as quantity,
               coalesce(rl.accepted_unit_price, pol.unit_price) as unit_price
        from order_response r
        left join order_response_line rl on rl.order_response_id = r.id and rl.purchase_order_line_id = pol.id
        where r.purchase_order_id = pol.purchase_order_id and r.response_code <> 'AB'
        order by r.recorded_on desc, r.id desc limit 1
    ) x on true
),
invoiced as (
    select l.*, coalesce(grl.purchase_order_line_id, l.purchase_order_line_id) as order_line_id
    from supplier_invoice_line l
    join counting c on c.id = l.supplier_invoice_id
    left join goods_receipt_line grl on grl.id = l.goods_receipt_line_id
),
applied as (
    select aa.amount, adv.purchase_order_id, adv.supplier_advance_request_id
    from advance_application aa
    join counting c on c.id = aa.supplier_invoice_id
    join payment_allocation adv on adv.id = aa.advance_allocation_id
)
-- Orders: accepted gross, less what counting invoices billed at the accepted price.
select 'forecast' as stage, a.project_id, a.category_id,
       -round(a.quantity * a.unit_price * (1 + a.vat_rate), 2)
       + coalesce((select sum(round(i.quantity * a.unit_price * (1 + a.vat_rate), 2))
                   from invoiced i where i.order_line_id = a.id), 0) as amount
from accepted a
union all
select 'open', project_id, category_id, -(amount_net + vat_amount) from invoiced
union all
select 'open', project_id, category_id, -amount from supplier_advance_request
union all
-- Sales orders: ordered gross, less what customer invoices billed at order price.
select 'forecast', so.project_id, sol.category_id,
       round(sol.quantity * sol.unit_price * (1 + sol.vat_rate), 2)
       - coalesce((select sum(round(l.quantity * sol.unit_price * (1 + sol.vat_rate), 2))
                   from customer_invoice_line l where l.sales_order_line_id = sol.id), 0)
from sales_order_line sol join sales_order so on so.id = sol.sales_order_id
union all
select 'open', project_id, category_id, amount_net + vat_amount from customer_invoice_line
union all
-- Hours not yet in payroll, at the standard rate.
select 'forecast', te.project_id, 'labour',
       -(te.hours - coalesce((select sum(a.hours) from payroll_allocation a where a.timesheet_entry_id = te.id), 0))
       * (select hourly_rate from employee_cost_rate
          where employee_id = te.employee_id and valid_from <= te.worked_on order by valid_from desc limit 1)
from timesheet_entry te
union all
-- Payroll cost lines, and the part the hours moved to their projects.
select 'open', project_id, category_id, -amount from payroll_cost_line
union all
select 'open', x.project_id, pc.category_id, x.sign * a.amount
from payroll_allocation a
join payroll_cost_line pc on pc.id = a.payroll_cost_line_id
join timesheet_entry te on te.id = a.timesheet_entry_id
cross join lateral (values (pc.project_id, 1), (te.project_id, -1)) x(project_id, sign)
union all
-- Classified bank lines, and expected cash they have not yet paid.
select 'settled', project_id, category_id, amount from bank_line_classification
union all
select 'forecast', e.project_id, e.category_id,
       e.amount - coalesce((select sum(c.amount) from bank_line_classification c where c.expected_cash_id = e.id), 0)
from expected_cash e
union all
-- Payments move money from open (or, for an order advance, forecast) to settled.
select v.stage, null, null, v.sign * case when pa.customer_invoice_id is not null then -pa.amount else pa.amount end
from payment_allocation pa
cross join lateral (values (case when pa.purchase_order_id is not null then 'forecast' else 'open' end, 1),
                           ('settled', -1)) v(stage, sign)
union all
-- An applied advance reduces the invoice's payable; its settled cash leaves the advance.
select v.stage, null, null, v.amount
from applied ap
cross join lateral (values ('open', ap.amount), ('settled', -ap.amount)) v(stage, amount)
union all
select 'forecast', null, null, -ap.amount from applied ap where ap.purchase_order_id is not null
union all
select 'settled', null, null, ap.amount from applied ap where ap.purchase_order_id is not null
union all
select 'settled', r.project_id, r.category_id, ap.amount
from applied ap join supplier_advance_request r on r.id = ap.supplier_advance_request_id;

create temporary view cash_difference as
select (select coalesce(sum(abs(coalesce(p.amount, 0) - coalesce(s.amount, 0))), 0)
        from (select coalesce(project_id, '-') as project_id, coalesce(category_id, '-') as category_id, sum(amount) as amount
              from cash_state group by 1, 2) s
        full join (select coalesce(project_id, '-') as project_id, coalesce(category_id, '-') as category_id, sum(amount) as amount
                   from position_entry where family = 'cash' group by 1, 2) p
        using (project_id, category_id)) as by_project_category,
       (select coalesce(sum(abs(coalesce(p.amount, 0) - coalesce(s.amount, 0))), 0)
        from (select stage, sum(amount) as amount from cash_state group by 1) s
        full join (select stage, sum(amount) as amount from position_entry where family = 'cash' group by 1) p
        using (stage)) as by_stage;
select assert_equal('EVIDENCE-1: cash per project and category equals what the records finally owe or bring', by_project_category, 0),
       assert_equal('EVIDENCE-1: company cash forecast, open and settled equal the records', by_stage, 0)
from cash_difference;

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
-- MONEY-5: goods may be invoiced before they arrive, so receipts and invoices are each
-- bounded by the accepted quantity. A unit is either received and not yet invoiced
-- (a receipt not matched to an invoice) or invoiced without a receipt, never both.
create temporary view order_fulfilment as
select t.purchase_order_line_id, t.quantity as accepted,
       coalesce(sum(grl.quantity), 0) as received,
       coalesce(sum(grl.quantity) filter (where grl.supplier_invoice_line_id is null), 0) as received_unmatched,
       coalesce((select sum(l.quantity) from supplier_invoice_line l
                 join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
                 left join goods_receipt_line g on g.id = l.goods_receipt_line_id
                 where coalesce(g.purchase_order_line_id, l.purchase_order_line_id) = t.purchase_order_line_id), 0) as billed,
       coalesce((select sum(l.quantity) from supplier_invoice_line l
                 join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id and a.counts_from is not null
                 where l.purchase_order_line_id = t.purchase_order_line_id), 0) as billed_without_receipt
from purchase_order_line_terms t
left join goods_receipt_line grl on grl.purchase_order_line_id = t.purchase_order_line_id
group by t.purchase_order_line_id, t.quantity;
select assert_equal('MONEY-5: orders: received <= accepted', count(*) filter (where received > accepted), 0),
       assert_equal('MONEY-5: orders: billed <= accepted', count(*) filter (where billed > accepted), 0),
       assert_equal('MONEY-5: orders: unmatched receipts + invoices without receipt <= accepted',
                    count(*) filter (where received_unmatched + billed_without_receipt > accepted), 0)
from order_fulfilment;
select assert_equal('MONEY-5: a receipt matches a counting invoice of the same order line, up to its quantity', count(*), 0)
from (select l.id
      from supplier_invoice_line l
      join goods_receipt_line grl on grl.supplier_invoice_line_id = l.id
      left join supplier_invoice_approval a on a.supplier_invoice_id = l.supplier_invoice_id
      group by l.id, l.quantity, l.purchase_order_line_id, a.counts_from
      having a.counts_from is null or sum(grl.quantity) > l.quantity
          or bool_or(grl.purchase_order_line_id is distinct from l.purchase_order_line_id)) x;
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

-- Payroll (ARCH-1): cost lines carry the whole employer cost; hours only re-attribute it.
select assert_equal('ARCH-1: payroll cost lines sum to the employer cost', count(*), 0)
from payroll_line pl
where pl.employer_cost is distinct from (select sum(pc.amount) from payroll_cost_line pc where pc.payroll_line_id = pl.id);
select assert_equal('ARCH-1: timesheet allocations never exceed their cost line', count(*), 0)
from payroll_cost_line pc
where pc.amount < (select coalesce(sum(a.amount), 0) from payroll_allocation a where a.payroll_cost_line_id = pc.id);
select assert_equal('ARCH-1: every journal entry balances', count(*), 0)
from (select journal_entry_id from journal_line group by 1 having sum(debit) <> sum(credit)) x;

-- Bank (ARCH-2, MONEY-2): every bank line is matched or classified in full, and each bank
-- account's ledger account moves exactly with its bank lines.
create temporary view bank_line_unexplained as
select bt.id, bt.amount
       - coalesce((select sum(case when pa.customer_invoice_id is not null then pa.amount else -pa.amount end)
                   from payment_allocation pa where pa.bank_transaction_id = bt.id), 0)
       - coalesce((select sum(c.amount) from bank_line_classification c where c.bank_transaction_id = bt.id), 0) as amount
from bank_transaction bt;
create temporary view bank_ledger_difference as
select coalesce(sum(abs(x.difference)), 0) as difference
from (select ba.id,
             coalesce((select sum(jl.debit - jl.credit) from journal_line jl
                       join journal_entry je on je.id = jl.journal_entry_id
                       join account a on a.code = jl.account_code
                       where a.bank_account_id = ba.id and je.source_type <> 'internal_document'), 0)
             - coalesce((select sum(bt.amount) from bank_transaction bt where bt.bank_account_id = ba.id), 0) as difference
      from bank_account ba) x;
select assert_equal('ARCH-2: every bank line is fully matched or classified', count(*), 0)
from bank_line_unexplained where amount <> 0;
select assert_equal('MONEY-2: each bank account in the ledger moves exactly with its bank lines', difference, 0)
from bank_ledger_difference;

-- Internal documents (ARCH-3): the only source of ledger-only postings.
select assert_equal('ARCH-3: every journal entry points to an existing source record', count(*), 0)
from journal_entry je
where not exists (
    select 1 from supplier_invoice x where je.source_type = 'supplier_invoice' and x.id = je.source_id
    union all select 1 from customer_invoice x where je.source_type = 'customer_invoice' and x.id = je.source_id
    union all select 1 from stock_issue x where je.source_type = 'stock_issue' and x.id = je.source_id
    union all select 1 from payroll_run x where je.source_type = 'payroll_run' and x.id = je.source_id
    union all select 1 from payment_allocation x where je.source_type = 'payment_allocation' and x.id = je.source_id
    union all select 1 from bank_line_classification x where je.source_type = 'bank_line_classification' and x.id = je.source_id
    union all select 1 from advance_application x where je.source_type = 'advance_application' and x.id = je.source_id
    union all select 1 from internal_document x where je.source_type = 'internal_document' and x.id = je.source_id);
select assert_equal('ARCH-3: the opening balance is an internal document', count(*), 1)
from journal_entry where source_type = 'internal_document' and source_id = 'OB-2026';
select assert_equal('ARCH-3: internal document lines carry the management category of their account', count(*), 0)
from internal_document_line l join account a on a.code = l.account_code
where l.category_id is distinct from a.category_id;

-- Plans (ARCH-5): P&L plan lines use cost or revenue categories.
select assert_equal('ARCH-5: P&L plan lines use cost or revenue categories', count(*), 0)
from plan_line pl join category c on c.id = pl.category_id
where pl.family = 'pnl' and c.family = 'cash';

-- Backward trace (item 14): P1's milestone-1 revenue line leads to SO1 and OPP1.
select assert_equal('TRACE: CI1 revenue line traces to one order', count(distinct order_id), 1),
       assert_equal('TRACE: CI1 revenue line traces to SO1', count(*) filter (where order_id = 'SO1'), 1),
       assert_equal('TRACE: CI1 revenue line traces to CRM opportunity OPP1', count(*) filter (where opportunity_id = 'OPP1'), 1)
from journal_trace
where source_type = 'customer_invoice' and source_id = 'CI1' and account_code = '602' and project_id = 'P1';

-- Regression probes from the final review (each rolled back).
begin;
insert into purchase_order values ('PX1', 'SUPPLIER_A', '2026-05-01', '2026-05-01', 14);
insert into purchase_order_line values ('PX1-1', 'PX1', 'panels', 'P1', false, 'materials', 5, 100, 0.21, '2026-05-10');
insert into bank_transaction values ('BX1', 'BA1', '2026-05-02', -605, 'advance, order later rejected', '2026-05-02');
insert into payment_allocation (id, bank_transaction_id, purchase_order_id, amount) values ('PAX1', 'BX1', 'PX1', 605);
insert into order_response values ('ORX1', 'PX1', 'RE', '2026-05-03', '2026-05-03');
select assert_equal('rejected order with an advance: projection readable, advance settled', sum(amount), -605)
from position_entry where source_id like 'PAX1:%' and stage = 'settled';
select assert_equal('rejected order with an advance: forecast shows the refund due', sum(amount), 605)
from position_entry where family = 'cash' and stage = 'forecast'
  and (source_id = 'PX1-1' or source_id like 'ORX1:%' or source_id like 'PAX1:%');
rollback;

begin;
insert into supplier_invoice values ('VX1', 'SUPPLIER_C', '2026-05-20', '2026-06-19', '2026-05-20', false, null, 'C-2026-X1');
insert into supplier_invoice_line (id, supplier_invoice_id, project_id, category_id, quantity, amount_net, vat_amount)
values ('VX1-1', 'VX1', 'P1', 'subcontracting', 0, 10000, 0);
insert into bank_transaction values ('BX2', 'BA1', '2026-05-05', -1000, 'advance on PO3', '2026-05-05');
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
insert into supplier_invoice values ('R1', 'SUPPLIER_A', '2026-05-01', '2026-05-31', '2026-05-01', false, null, 'A-26-R1');
insert into supplier_invoice_line (id, supplier_invoice_id, project_id, category_id, quantity, amount_net, vat_amount) values
    ('R1-1', 'R1', 'P1', 'materials', 0, 100, 0),
    ('R1-2', 'R1', 'P1', 'materials', 0, 100, 0),
    ('R1-3', 'R1', 'P1', 'materials', 0, 100, 0);
insert into bank_transaction values ('RB1', 'BA1', '2026-05-10', -100, 'rounding probe', '2026-05-10');
insert into payment_allocation (id, bank_transaction_id, supplier_invoice_id, amount) values ('RPA1', 'RB1', 'R1', 100);
select assert_equal('rounding: settled equals the payment', sum(amount), -100)
from position_entry where source_id like 'RPA1:%' and stage = 'settled';
rollback;

-- ARCH-1 / REDTEAM-10 / MONEY-6: payroll without timesheets. May payroll: E1's 3 300 is
-- re-attributed to TS5 on P1; the office manager E2 (50 000, cost center ADMIN) has no hours.
begin;
insert into employee values ('E2', 'Office manager');
insert into payroll_run values ('PR-2026-05', '2026-05-01', '2026-06-10', '2026-06-12');
insert into payroll_line values ('PL-05-E1', 'PR-2026-05', 'E1', 3300), ('PL-05-E2', 'PR-2026-05', 'E2', 50000);
insert into payroll_cost_line values
    ('PC-05-E1', 'PL-05-E1', 'labour', null, null, 3300),
    ('PC-05-E2', 'PL-05-E2', 'labour', null, 'ADMIN', 50000);
insert into payroll_allocation values ('PA-05-1', 'PC-05-E1', 'TS5', 6, 3300);
insert into bank_transaction values ('BX-PAY-05', 'BA1', '2026-06-12', -53300, 'Payroll May', '2026-06-12');
insert into payment_allocation (id, bank_transaction_id, payroll_run_id, amount) values ('PAX-05', 'BX-PAY-05', 'PR-2026-05', 53300);
call post_to_ledger();
select assert_equal('ARCH-1: payroll without timesheets posts a balanced entry', sum(debit) - sum(credit), 0),
       assert_equal('ARCH-1: the ledger debits exactly the cost lines', sum(debit) filter (where account_code = '521'), 53300)
from journal_line where journal_entry_id = 'payroll_run:PR-2026-05';
select assert_equal('ARCH-1: salaried cost is actual labour on its cost center', sum(amount), 50000)
from position_entry where family = 'cost' and stage = 'actual' and cost_center_id = 'ADMIN';
select assert_equal('MONEY-6: P1 carries only its re-attributed payroll cash', sum(amount), -3300)
from position_entry where family = 'cash' and project_id = 'P1' and (source_id like 'PAX-05:%' or source_id in ('PC-05-E1', 'PA-05-1'))
  and stage in ('open', 'settled');
select assert_equal('ARCH-1: TS5 incurred relieved by payroll', sum(incurred), 0)
from position_summary('2026-05-31', '2026-06-10') where project_id = 'P1' and family = 'cost' and category_id = 'labour';
select assert_equal('ARCH-1: settled equals bank with payroll without timesheets',
    (select sum(amount) from position_entry where family = 'cash' and stage = 'settled'), (select sum(amount) from bank_transaction));
select assert_equal('ARCH-1: reconciliation stays exact', sum(abs(difference)), 0) from reconciliation;
select assert_equal('ARCH-1: stages still equal the typed records', difference, 0) from stage_difference;
select assert_equal('ARCH-1: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
rollback;

-- ARCH-2 / MONEY-7 / REDTEAM-3 (bank part): lines with no document. A bank fee, a transfer
-- to our own savings account (through 261 cash in transit) and back.
begin;
insert into bank_account values ('BA2', 'Savings account');
insert into account values ('2212', 'Bank accounts: savings', null, 'BA2');
insert into bank_transaction values
    ('BX-FEE', 'BA1', '2026-05-31', -150, 'Bank fee May', '2026-05-31'),
    ('BX-T1', 'BA1', '2026-05-28', -100000, 'Transfer to savings', '2026-05-28'),
    ('BX-T2', 'BA2', '2026-05-29', 100000, 'Transfer from current account', '2026-05-29');
insert into bank_line_classification (id, bank_transaction_id, category_id, account_code, amount) values
    ('CL-FEE', 'BX-FEE', 'bank_fees', null, -150),
    ('CL-T1', 'BX-T1', null, '261', -100000),
    ('CL-T2', 'BX-T2', null, '261', 100000);
call post_to_ledger();
select assert_equal('ARCH-2: settled equals bank with document-less lines',
    (select sum(amount) from position_entry where family = 'cash' and stage = 'settled'), (select sum(amount) from bank_transaction));
select assert_equal('ARCH-2: every bank line is matched or classified', count(*), 0) from bank_line_unexplained where amount <> 0;
select assert_equal('ARCH-2: each bank account in the ledger equals its bank lines', difference, 0) from bank_ledger_difference;
select assert_equal('ARCH-2: bank fee is actual cost', sum(amount), 150)
from position_entry where family = 'cost' and stage = 'actual' and category_id = 'bank_fees';
select assert_equal('ARCH-2: own-account transfer nets to zero in cash', sum(amount), 0)
from position_entry where family = 'cash' and source_id in ('CL-T1', 'CL-T2');
select assert_equal('ARCH-2: own-account transfer nets to zero in 261', sum(debit) - sum(credit), 0)
from journal_line where account_code = '261';
select assert_equal('ARCH-2: reconciliation stays exact', sum(abs(difference)), 0) from reconciliation;
select assert_equal('ARCH-2: ledger balances', sum(debit) - sum(credit), 0) from journal_line;
select assert_equal('ARCH-2: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
rollback;

-- MONEY-2: one bank line matched in two steps, posted after each step.
begin;
insert into bank_transaction values ('BX9', 'BA1', '2026-06-01', 200000, 'Client X', '2026-06-01');
insert into payment_allocation (id, bank_transaction_id, customer_invoice_id, amount) values ('PAX9-CI2', 'BX9', 'CI2', 150000);
call post_to_ledger();
insert into payment_allocation (id, bank_transaction_id, customer_invoice_id, amount) values ('PAX9-CI3', 'BX9', 'CI3', 50000);
call post_to_ledger();
select assert_equal('MONEY-2: a late allocation reaches the ledger bank account', difference, 0) from bank_ledger_difference;
select assert_equal('MONEY-2: receivables in the ledger follow the late allocation', sum(debit) - sum(credit), 0)
from journal_line where account_code = '311';
rollback;

-- MONEY-5: goods invoiced before they arrive. The receipt names the invoice line.
begin;
insert into purchase_order values ('PX9', 'SUPPLIER_A', '2026-05-01', '2026-05-01', 30);
insert into purchase_order_line values ('PX9-1', 'PX9', 'doors', 'P2', false, 'materials', 5, 2000, 0.21, '2026-05-12');
insert into supplier_invoice values ('VX9', 'SUPPLIER_A', '2026-05-05', '2026-06-04', '2026-05-05', false, null, 'A-26-X9');
insert into supplier_invoice_line (id, supplier_invoice_id, purchase_order_line_id, project_id, category_id, quantity, amount_net, vat_amount)
values ('VX9-1', 'VX9', 'PX9-1', 'P2', 'materials', 5, 10000, 2100);
insert into goods_receipt values ('GX9', '2026-05-12', '2026-05-12');
insert into goods_receipt_line (id, goods_receipt_id, purchase_order_line_id, quantity, supplier_invoice_line_id)
values ('GX9-1', 'GX9', 'PX9-1', 5, 'VX9-1');
select assert_equal('MONEY-5: invoice before receipt, committed relieved once', coalesce(committed, 0), 0),
       assert_equal('MONEY-5: invoice before receipt, nothing incurred', coalesce(incurred, 0), 0),
       assert_equal('MONEY-5: invoice before receipt, margin counts the cost once', coalesce(actual, 0) + coalesce(incurred, 0), 10000)
from position_summary('2026-05-31', '2026-05-31') where project_id = 'P2' and family = 'cost' and category_id = 'materials';
select assert_equal('MONEY-5: fulfilment checks pass', count(*), 0)
from order_fulfilment where received > accepted or billed > accepted or received_unmatched + billed_without_receipt > accepted;
select assert_equal('MONEY-5: stages still equal the typed records', difference, 0) from stage_difference;
-- The same receipt without the match would count the doors twice: the guard catches it.
update goods_receipt_line set supplier_invoice_line_id = null where id = 'GX9-1';
select assert_equal('MONEY-5: an unmatched receipt of invoiced goods is caught', count(*), 1)
from order_fulfilment where received_unmatched + billed_without_receipt > accepted;
rollback;

-- ARCH-3 / REDTEAM-3 (internal document part): a month-end accrual for subcontract work done
-- but not yet billed, posted from an internal document, counts as management actual.
begin;
insert into internal_document values ('ACR-2026-05', '2026-05-31', '2026-05-31', 'Accrued subcontract work, May');
insert into internal_document_line values
    ('ACR-2026-05-1', 'ACR-2026-05', '518', 'subcontracting', 'P1', null, 5000, 0),
    ('ACR-2026-05-2', 'ACR-2026-05', '383', null, null, null, 0, 5000);
call post_to_ledger();
select assert_equal('ARCH-3: accrual counts as actual', actual, 95000)
from position_summary('2026-05-31', '2026-05-31') where project_id = 'P1' and family = 'cost' and category_id = 'subcontracting';
select assert_equal('ARCH-3: reconciliation stays exact with an internal document', sum(abs(difference)), 0) from reconciliation;
select assert_equal('ARCH-3: stages still equal the typed records', difference, 0) from stage_difference;
select assert_equal('ARCH-3: the accrual has a source record', count(*), 1)
from journal_entry where source_type = 'internal_document' and source_id = 'ACR-2026-05';
rollback;

-- ARCH-5 / REDTEAM-9: Treasury expected cash (a tax payment) feeds the forecast and is
-- relieved by the classified bank line that pays it; FP&A plans company, cost center and cash.
begin;
insert into expected_cash values ('EC-TAX-06', null, 'taxes', null, null, -30000, '2026-06-25', '2026-05-20', 'Road tax 2026');
select assert_equal('ARCH-5: expected cash is in the June forecast', sum(amount), -30000)
from position_entry where family = 'cash' and stage = 'forecast' and category_id = 'taxes' and date_trunc('month', cash_on) = '2026-06-01';
insert into bank_transaction values ('BX-TAX', 'BA1', '2026-06-24', -30000, 'Road tax', '2026-06-24');
insert into bank_line_classification (id, bank_transaction_id, category_id, expected_cash_id, amount)
values ('CL-TAX', 'BX-TAX', 'taxes', 'EC-TAX-06', -30000);
call post_to_ledger();
select assert_equal('ARCH-5: the paid tax is relieved from the forecast', sum(amount), 0)
from position_entry where family = 'cash' and stage = 'forecast' and category_id = 'taxes';
select assert_equal('ARCH-5: the paid tax is settled', sum(amount), -30000)
from position_entry where family = 'cash' and stage = 'settled' and category_id = 'taxes';
select assert_equal('ARCH-5: the tax payment posts to its account', sum(debit) - sum(credit), 30000)
from journal_line where account_code = '342';
select assert_equal('ARCH-5: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
insert into plan_line (plan_version_id, family, project_id, cost_center_id, category_id, period_month, amount_net) values
    ('B1', 'pnl', null, null, 'labour', '2026-04-01', 40000),
    ('B1', 'pnl', null, 'ADMIN', 'bank_fees', '2026-05-01', 200),
    ('B1', 'cash', null, null, 'taxes', '2026-06-01', -30000);
select assert_equal('ARCH-8: company-level plan meets company-level actual (TS4)', plan, 40000),
       assert_equal('ARCH-8: company-level labour actual', actual, 42400)
from project_control('B1', '2026-05-31', '2026-05-31') where project_id is null and category_id = 'labour';
select assert_equal('ARCH-5: cash plan vs actual cash for taxes in June',
    (select sum(amount_net) from plan_line where plan_version_id = 'B1' and family = 'cash' and category_id = 'taxes')
    - (select sum(amount) from position_entry where family = 'cash' and category_id = 'taxes' and date_trunc('month', cash_on) = '2026-06-01'), 0);
insert into bank_transaction values ('BX-FEE-A', 'BA1', '2026-05-31', -150, 'Bank fee May', '2026-05-31');
insert into bank_line_classification (id, bank_transaction_id, category_id, cost_center_id, amount)
values ('CL-FEE-A', 'BX-FEE-A', 'bank_fees', 'ADMIN', -150);
select assert_equal('ARCH-5: cost center ADMIN budget vs actual (plan 200, actual 150)', p.plan - a.actual, 50)
from (select sum(amount_net) as plan from plan_line
      where plan_version_id = 'B1' and family = 'pnl' and cost_center_id = 'ADMIN') p,
     (select sum(amount) as actual from position_entry
      where family = 'cost' and stage = 'actual' and cost_center_id = 'ADMIN') a;
rollback;

-- ARCH-7 / STANDARDS-2: an advance paid on a supplier proforma with no order, then applied
-- to the final invoice.
begin;
insert into supplier_advance_request values
    ('ZF-77', 'SUPPLIER_C', 'P1', 'subcontracting', 12100, '2026-05-02', '2026-05-09', '2026-05-02', 'ZF-2026-77');
insert into bank_transaction values ('BX-ZF', 'BA1', '2026-05-08', -12100, 'Subcontractor C, proforma ZF-2026-77', '2026-05-08');
insert into payment_allocation (id, bank_transaction_id, supplier_advance_request_id, amount) values ('PAX-ZF', 'BX-ZF', 'ZF-77', 12100);
select assert_equal('ARCH-7: a paid proforma is settled, not open', sum(amount) filter (where stage = 'open'), 0),
       assert_equal('ARCH-7: a paid proforma is settled cash', sum(amount) filter (where stage = 'settled'), -12100)
from position_entry where family = 'cash' and (source_id = 'ZF-77' or source_id like 'PAX-ZF:%');
insert into supplier_invoice values ('VX-ZF', 'SUPPLIER_C', '2026-05-20', '2026-06-19', '2026-05-20', false, null, 'C-2026-15');
insert into supplier_invoice_line (id, supplier_invoice_id, project_id, category_id, quantity, amount_net, vat_amount)
values ('VX-ZF-1', 'VX-ZF', 'P1', 'subcontracting', 0, 10000, 2100);
insert into advance_application values ('AAX-ZF', 'PAX-ZF', 'VX-ZF', 12100, '2026-05-20', '2026-05-20');
call post_to_ledger();
select assert_equal('ARCH-7: proforma, payment and invoice together cost 12 100 once', sum(amount), -12100),
       assert_equal('ARCH-7: nothing left open after the advance is applied', sum(amount) filter (where stage = 'open'), 0)
from position_entry where family = 'cash' and (source_id in ('ZF-77', 'VX-ZF-1') or source_id like 'PAX-ZF:%' or source_id like 'AAX-ZF:%');
select assert_equal('ARCH-7: advance account cleared', sum(debit) - sum(credit), 0) from journal_line where account_code = '314';
select assert_equal('ARCH-7: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
rollback;

-- ARCH-5 (Inventory part) / REDTEAM-3 (stock part): stock received without an order is an
-- asset; its invoice posts to stock, not to cost.
begin;
insert into goods_receipt values ('GX-S', '2026-05-21', '2026-05-21');
insert into goods_receipt_line (id, goods_receipt_id, quantity, item) values ('GX-S-1', 'GX-S', 2, 'steel frame');
insert into supplier_invoice values ('VX-S', 'SUPPLIER_B', '2026-05-21', '2026-06-20', '2026-05-21', false, null, 'B-2026-090');
insert into supplier_invoice_line (id, supplier_invoice_id, goods_receipt_line_id, category_id, quantity, amount_net, vat_amount)
values ('VX-S-1', 'VX-S', 'GX-S-1', 'materials', 2, 56000, 11760);
call post_to_ledger();
select assert_equal('ARCH-5: stock bought without an order is not cost', count(*), 0)
from position_entry where family = 'cost' and source_id = 'VX-S-1';
select assert_equal('ARCH-5: stock bought without an order posts to stock', sum(debit), 56000)
from journal_line where journal_entry_id = 'supplier_invoice:VX-S' and account_code = '112';
select assert_equal('ARCH-5: reconciliation stays exact', sum(abs(difference)), 0) from reconciliation;
rollback;

-- ARCH-8: project is optional on sales, CRM, request, stock-issue and plan records.
begin;
insert into opportunity values ('OPPX', 'CLIENT_X', null, 'revenue', 20000, 0.50, '2026-05-01', '2026-05-01');
insert into sales_order values ('SOX', 'CLIENT_X', null, null, '2026-05-02', '2026-05-02', 14);
insert into sales_order_line values ('SOX-1', 'SOX', 'revenue', 'Service', 1, 20000, 0.21, '2026-05-15');
insert into customer_invoice values ('CIX', 'CLIENT_X', '2026-05-15', '2026-05-29', '2026-05-15', 'FV-2026-0099');
insert into customer_invoice_line values ('CIX-1', 'CIX', 'SOX-1', null, 'revenue', 1, 20000, 4200);
insert into material_request values ('MRX', null, '2026-05-03', '2026-05-03');
insert into stock_issue values ('ISSX', null, '2026-05-04', '2026-05-04');
insert into stock_issue_line values ('ISSX-1', 'ISSX', 'steel frame', 'materials', 1, 27500);
call post_to_ledger();
select assert_equal('ARCH-8: company-level sale is actual revenue', sum(amount), 20000)
from position_entry where family = 'revenue' and stage = 'actual' and project_id is null;
select assert_equal('ARCH-8: reconciliation stays exact', sum(abs(difference)), 0) from reconciliation;
select assert_equal('ARCH-8: stages still equal the typed records', difference, 0) from stage_difference;
select assert_equal('ARCH-8: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
rollback;

-- MONEY-4: reliefs use the relieved record's project and category. A company-level order
-- invoiced to P2, and a P2 sales order invoiced on a P1 line.
begin;
insert into purchase_order values ('PX4', 'SUPPLIER_A', '2026-05-01', '2026-05-01', 30);
insert into purchase_order_line values ('PX4-1', 'PX4', 'bolts', null, false, 'materials', 10, 100, 0.21, '2026-05-10');
insert into goods_receipt values ('GX4', '2026-05-10', '2026-05-10');
insert into goods_receipt_line (id, goods_receipt_id, purchase_order_line_id, quantity) values ('GX4-1', 'GX4', 'PX4-1', 10);
insert into supplier_invoice values ('VX4', 'SUPPLIER_A', '2026-05-11', '2026-06-10', '2026-05-11', false, null, 'A-26-X4');
insert into supplier_invoice_line (id, supplier_invoice_id, goods_receipt_line_id, project_id, category_id, quantity, amount_net, vat_amount)
values ('VX4-1', 'VX4', 'GX4-1', 'P2', 'materials', 10, 1000, 210);
insert into sales_order values ('SOX4', 'CLIENT_X', 'P2', null, '2026-05-02', '2026-05-02', 14);
insert into sales_order_line values ('SOX4-1', 'SOX4', 'revenue', 'Extra', 1, 10000, 0.21, '2026-05-15');
insert into customer_invoice values ('CIX4', 'CLIENT_X', '2026-05-15', '2026-05-29', '2026-05-15', 'FV-2026-0098');
insert into customer_invoice_line values ('CIX4-1', 'CIX4', 'SOX4-1', 'P1', 'revenue', 1, 10000, 2100);
select assert_equal('MONEY-4: no phantom forecast on any project for an order invoiced to a project', sum(abs(amount)), 0)
from (select project_id, sum(amount) as amount from position_entry
      where family = 'cash' and stage = 'forecast' and source_id in ('PX4-1', 'VX4-1') group by 1) x;
select assert_equal('MONEY-4: P2 order revenue fully relieved', coalesce(sum(amount), 0), 0)
from position_entry where family = 'revenue' and stage = 'committed' and project_id = 'P2';
select assert_equal('MONEY-4: P2 order cash forecast fully relieved, on every project', sum(abs(amount)), 0)
from (select project_id, sum(amount) as amount from position_entry
      where family = 'cash' and stage = 'forecast' and source_id in ('SOX4-1', 'CIX4-1') group by 1) x;
select assert_equal('MONEY-4: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
select assert_equal('MONEY-4: stages still equal the typed records', difference, 0) from stage_difference;
rollback;

-- MONEY-3: an advance on a two-project order, applied in full to the invoice for one line.
begin;
insert into purchase_order values ('PX3', 'SUPPLIER_A', '2026-05-01', '2026-05-01', 30);
insert into purchase_order_line values
    ('PX3-1', 'PX3', 'panel', 'P1', false, 'materials', 1, 1000, 0.21, '2026-05-10'),
    ('PX3-2', 'PX3', 'panel', 'P2', false, 'materials', 1, 1000, 0.21, '2026-05-10');
insert into bank_transaction values ('BX3A', 'BA1', '2026-05-02', -1210, 'advance PX3', '2026-05-02');
insert into payment_allocation (id, bank_transaction_id, purchase_order_id, amount) values ('PAX3A', 'BX3A', 'PX3', 1210);
insert into goods_receipt values ('GX3', '2026-05-10', '2026-05-10');
insert into goods_receipt_line (id, goods_receipt_id, purchase_order_line_id, quantity) values
    ('GX3-1', 'GX3', 'PX3-1', 1), ('GX3-2', 'GX3', 'PX3-2', 1);
insert into supplier_invoice values
    ('VX3A', 'SUPPLIER_A', '2026-05-11', '2026-06-10', '2026-05-11', false, null, 'A-26-X3A'),
    ('VX3B', 'SUPPLIER_A', '2026-05-11', '2026-06-10', '2026-05-11', false, null, 'A-26-X3B');
insert into supplier_invoice_line (id, supplier_invoice_id, goods_receipt_line_id, project_id, category_id, quantity, amount_net, vat_amount) values
    ('VX3A-1', 'VX3A', 'GX3-1', 'P1', 'materials', 1, 1000, 210),
    ('VX3B-1', 'VX3B', 'GX3-2', 'P2', 'materials', 1, 1000, 210);
insert into advance_application values ('AAX3', 'PAX3A', 'VX3A', 1210, '2026-05-11', '2026-05-11');
insert into bank_transaction values ('BX3B', 'BA1', '2026-05-20', -1210, 'VX3B', '2026-05-20');
insert into payment_allocation (id, bank_transaction_id, supplier_invoice_id, amount) values ('PAX3B', 'BX3B', 'VX3B', 1210);
select assert_equal('MONEY-3: P1 pays its own line', sum(amount) filter (where project_id = 'P1'), -1210),
       assert_equal('MONEY-3: P2 pays its own line', sum(amount) filter (where project_id = 'P2'), -1210),
       assert_equal('MONEY-3: nothing left in forecast or open', sum(abs(amount)) filter (where stage <> 'settled'), 0)
from (select project_id, stage, sum(amount) as amount from position_entry
      where family = 'cash' and (source_id like 'PX3-%' or source_id like 'VX3%' or source_id like 'PAX3%' or source_id like 'AAX3:%')
      group by 1, 2) x;
select assert_equal('MONEY-3: cash invariant holds', by_project_category + by_stage, 0) from cash_difference;
rollback;

-- MONEY-1: a second supplier response on PO5 (before any receipt) must not rewrite what
-- was known on 22 April.
begin;
insert into order_response values ('OR5B', 'PO5', 'CA', '2026-04-25', '2026-04-25');
insert into order_response_line values ('OR5B', 'PO5-1', 45, 1000);
select assert_equal('MONEY-1: 22 Apr as known 22 Apr keeps the first response (committed)', sum(amount) filter (where family = 'cost'), 42000),
       assert_equal('MONEY-1: 22 Apr as known 22 Apr keeps the first response (forecast)', sum(amount) filter (where family = 'cash'), -50820)
from position_as_of('2026-04-22', '2026-04-22')
where stage in ('committed', 'forecast') and (source_id = 'PO5-1' or source_id like 'OR5%:%');
select assert_equal('MONEY-1: 25 Apr as known 25 Apr follows the second response', sum(amount), 45000)
from position_as_of('2026-04-25', '2026-04-25')
where family = 'cost' and stage = 'committed' and (source_id = 'PO5-1' or source_id like 'OR5%:%');
rollback;

-- A received document is registered once, whichever product the customer runs:
-- the same supplier's document number is refused a second time.
do $$
begin
    insert into supplier_invoice values
        ('VBX', 'SUPPLIER_A', '2026-03-31', '2026-04-30', '2026-04-05', false, null, 'A-26-0331');
    raise exception 'FAILED the same supplier document was registered twice';
exception when unique_violation then perform nextval('assertion_count');
end
$$;

\o
select last_value as assertions from assertion_count;
\echo 'ALL ASSERTIONS PASSED'
