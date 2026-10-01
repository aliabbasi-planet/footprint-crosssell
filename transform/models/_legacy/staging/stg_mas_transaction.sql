-- MAS acquiring volume aggregated per merchant_id over the lookback window.
select
    merchant_id,
    sum(total_transaction_amount_eur)   as acquiring_volume_eur,
    sum(total_transaction_count)        as acquiring_txn_count,
    sum(total_dcc_eligible_amount_eur)  as mas_dcc_eligible_eur,
    sum(total_dcc_amount_eur)           as mas_dcc_converted_eur,
    max(country)                        as mas_country,
    max(directvsindirect)               as direct_vs_indirect
from {{ source('datamart', 'fact_mas_transaction') }}
where transaction_date >= dateadd('month', -{{ var('lookback_months') }}, current_date())
group by 1
