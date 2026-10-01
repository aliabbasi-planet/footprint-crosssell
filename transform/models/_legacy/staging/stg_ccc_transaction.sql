-- 3C gateway volume aggregated per location + terminal type (for channel + DCC signals).
-- TRANSACTION_DATE is a YYYYMM string (e.g. '202607'); append '01' and parse as YYYYMMDD.
with txn as (
    select
        location_no,
        terminal_type_name,
        try_to_date(transaction_date || '01', 'YYYYMMDD') as txn_date,
        transaction_amount_eur,
        total_transaction_count,
        is_dcc,
        is_dcc_eligible,
        is_dcc_offered
    from {{ source('datamart', 'fact_ccc_transaction') }}
    where location_no in (select uid from {{ ref('stg_ccl_customer') }} where data_source = '3C')
)

select
    location_no,
    terminal_type_name,
    sum(transaction_amount_eur)                                          as gateway_volume_eur,
    sum(total_transaction_count)                                         as txn_count,
    min(txn_date)                                                        as first_seen,
    max(txn_date)                                                        as last_seen,
    sum(iff(is_dcc_eligible, transaction_amount_eur, 0))                 as dcc_eligible_eur,
    sum(iff(is_dcc, transaction_amount_eur, 0))                          as dcc_converted_eur
from txn
where txn_date >= dateadd('month', -{{ var('lookback_months') }}, current_date())
group by 1, 2
