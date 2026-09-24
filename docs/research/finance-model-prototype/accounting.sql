-- Accounting product: posts statutory journal entries from the same typed records.
-- It never reads position_entry. Already posted sources are skipped (idempotent).
-- Account codes follow Czech chart-of-accounts groups and are illustrative only.
set search_path = finance_model;

create procedure post_to_ledger()
language plpgsql
as $$
begin
    -- Supplier invoices, once they count (approved, or no approval needed): expense by
    -- project (or stock for stock purchases), deductible VAT, self-assessed reverse-charge
    -- VAT (declared and deducted in the same entry), payable.
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || si.id, si.issued_on, a.counts_from, 'supplier_invoice', si.id
        from supplier_invoice si
        join supplier_invoice_approval a on a.supplier_invoice_id = si.id and a.counts_from is not null
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id, case when pol.to_stock then '112' else a.code end, l.project_id, l.amount_net, 0
    from new_entry ne
    join supplier_invoice_line l on l.supplier_invoice_id = ne.source_id
    join account a on a.category_id = l.category_id
    left join goods_receipt_line grl on grl.id = l.goods_receipt_line_id
    left join purchase_order_line pol on pol.id = coalesce(grl.purchase_order_line_id, l.purchase_order_line_id)
    union all
    select ne.id, '343', null, v.debit, v.credit
    from new_entry ne
    join supplier_invoice_line l on l.supplier_invoice_id = ne.source_id
    cross join lateral (values (l.self_assessed_vat, 0.00), (0.00, l.self_assessed_vat)) v(debit, credit)
    where l.self_assessed_vat <> 0
    union all
    select ne.id, '343', null, sum(l.vat_amount), 0
    from new_entry ne
    join supplier_invoice_line l on l.supplier_invoice_id = ne.source_id
    group by ne.id
    having sum(l.vat_amount) <> 0
    union all
    select ne.id, '321', null, 0, sum(l.amount_net + l.vat_amount)
    from new_entry ne
    join supplier_invoice_line l on l.supplier_invoice_id = ne.source_id
    group by ne.id;

    -- Stock issues: consumption by project out of stock.
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || s.id, s.issued_on, s.recorded_on, 'stock_issue', s.id
        from stock_issue s
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id, a.code, s.project_id, l.quantity * l.unit_cost, 0
    from new_entry ne
    join stock_issue s on s.id = ne.source_id
    join stock_issue_line l on l.stock_issue_id = s.id
    join account a on a.category_id = l.category_id
    union all
    select ne.id, '112', null, 0, l.quantity * l.unit_cost
    from new_entry ne
    join stock_issue_line l on l.stock_issue_id = ne.source_id;

    -- Payroll runs: personnel cost split by the payroll allocation, dated at period end.
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || r.id, (r.period_month + interval '1 month - 1 day')::date, r.posted_on, 'payroll_run', r.id
        from payroll_run r
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id, '521', te.project_id, pa.amount, 0
    from new_entry ne
    join payroll_line pl on pl.payroll_run_id = ne.source_id
    join payroll_allocation pa on pa.payroll_line_id = pl.id
    join timesheet_entry te on te.id = pa.timesheet_entry_id
    union all
    select ne.id, '331', null, 0, sum(pl.employer_cost)
    from new_entry ne
    join payroll_line pl on pl.payroll_run_id = ne.source_id
    group by ne.id;

    -- Customer invoices: receivable, revenue by project, output VAT (none under reverse charge).
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || ci.id, ci.issued_on, ci.recorded_on, 'customer_invoice', ci.id
        from customer_invoice ci
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id, '311', null, sum(l.amount_net + l.vat_amount), 0
    from new_entry ne
    join customer_invoice_line l on l.customer_invoice_id = ne.source_id
    group by ne.id
    union all
    select ne.id, a.code, l.project_id, 0, l.amount_net
    from new_entry ne
    join customer_invoice_line l on l.customer_invoice_id = ne.source_id
    join account a on a.category_id = l.category_id
    union all
    select ne.id, '343', null, 0, sum(l.vat_amount)
    from new_entry ne
    join customer_invoice_line l on l.customer_invoice_id = ne.source_id
    group by ne.id
    having sum(l.vat_amount) <> 0;

    -- Bank transactions: settle payables, receivables and payroll liabilities, or pay advances.
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || bt.id, bt.booked_on, bt.recorded_on, 'bank_transaction', bt.id
        from bank_transaction bt
        where exists (select 1 from payment_allocation pa where pa.bank_transaction_id = bt.id)
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id,
           case when pa.supplier_invoice_id is not null or d.direction = 'received' then '321'
                when pa.payroll_run_id is not null then '331'
                when pa.purchase_order_id is not null then '314'
                else '221' end,
           null, pa.amount, 0
    from new_entry ne
    join payment_allocation pa on pa.bank_transaction_id = ne.source_id
    left join accounting_source_document d on d.id = pa.accounting_source_document_id
    union all
    select ne.id,
           case when pa.customer_invoice_id is not null or d.direction = 'issued' then '311' else '221' end,
           null, 0, pa.amount
    from new_entry ne
    join payment_allocation pa on pa.bank_transaction_id = ne.source_id
    left join accounting_source_document d on d.id = pa.accounting_source_document_id;

    -- Advance applications: the advance paid is offset against the supplier's payable.
    -- (VAT on advances, shifted by the tax document for a received payment, is not modelled.)
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || aa.id, aa.applied_on, greatest(aa.recorded_on, a.counts_from), 'advance_application', aa.id
        from advance_application aa
        join supplier_invoice_approval a on a.supplier_invoice_id = aa.supplier_invoice_id and a.counts_from is not null
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id, v.account_code, null, v.debit, v.credit
    from new_entry ne
    join advance_application aa on aa.id = ne.source_id
    cross join lateral (values ('321', aa.amount, 0.00), ('314', 0.00, aa.amount)) v(account_code, debit, credit);

    -- Source documents Accounting captured itself: received invoices as payables,
    -- issued invoices as receivables, reverse-charge VAT self-assessed as for suppliers.
    with new_entry as (
        insert into journal_entry (id, entry_date, recorded_on, source_type, source_id)
        select 'JE-' || d.id, d.issued_on, d.recorded_on, 'accounting_source_document', d.id
        from accounting_source_document d
        on conflict (source_type, source_id) do nothing
        returning id, source_id
    )
    insert into journal_line (journal_entry_id, account_code, project_id, debit, credit)
    select ne.id, a.code, l.project_id,
           case d.direction when 'received' then l.amount_net else 0 end,
           case d.direction when 'issued' then l.amount_net else 0 end
    from new_entry ne
    join accounting_source_document d on d.id = ne.source_id
    join accounting_source_document_line l on l.accounting_source_document_id = d.id
    join account a on a.category_id = l.category_id
    union all
    select ne.id, '343', null,
           case d.direction when 'received' then sum(l.vat_amount) else 0 end,
           case d.direction when 'issued' then sum(l.vat_amount) else 0 end
    from new_entry ne
    join accounting_source_document d on d.id = ne.source_id
    join accounting_source_document_line l on l.accounting_source_document_id = d.id
    group by ne.id, d.direction
    having sum(l.vat_amount) <> 0
    union all
    select ne.id, '343', null, v.debit, v.credit
    from new_entry ne
    join accounting_source_document_line l on l.accounting_source_document_id = ne.source_id
    cross join lateral (values (l.self_assessed_vat, 0.00), (0.00, l.self_assessed_vat)) v(debit, credit)
    where l.self_assessed_vat <> 0
    union all
    select ne.id, case d.direction when 'received' then '321' else '311' end, null,
           case d.direction when 'issued' then sum(l.amount_net + l.vat_amount) else 0 end,
           case d.direction when 'received' then sum(l.amount_net + l.vat_amount) else 0 end
    from new_entry ne
    join accounting_source_document d on d.id = ne.source_id
    join accounting_source_document_line l on l.accounting_source_document_id = d.id
    group by ne.id, d.direction;
end
$$;
