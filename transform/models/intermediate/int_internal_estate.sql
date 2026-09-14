-- The internal estate: one row per served 3C location with volume, channel and DCC signals.
with ccl_3c as (
    select
        poc_merchant,
        poc_vertical,
        sf_account_id,
        uid as location_no,
        country,
        city,
        store
    from {{ ref('stg_ccl_customer') }}
    where data_source = '3C'
),

txn as (
    select
        location_no,
        sum(gateway_volume_eur)     as gateway_volume_eur,
        sum(txn_count)              as txn_count,
        min(first_seen)             as first_seen,
        max(last_seen)              as last_seen,
        sum(dcc_eligible_eur)       as dcc_eligible_eur,
        sum(dcc_converted_eur)      as dcc_converted_eur
    from {{ ref('stg_ccc_transaction') }}
    group by 1
)

select
    ccl.poc_merchant                                            as merchant,
    ccl.poc_vertical                                            as vertical,
    ccl.sf_account_id,
    ccl.location_no,
    ccl.country,
    ccl.city,
    ccl.store,
    ccc.operating_environment,
    ccc.is_dcc                                                  as location_is_dcc,
    coalesce(txn.gateway_volume_eur, 0)                         as gateway_volume_eur,
    coalesce(txn.txn_count, 0)                                  as txn_count,
    txn.first_seen,
    txn.last_seen,
    coalesce(txn.dcc_eligible_eur, 0)                           as dcc_eligible_eur,
    coalesce(txn.dcc_converted_eur, 0)                          as dcc_converted_eur,
    iff(txn.last_seen >= dateadd('month', -{{ var('lookback_months') }}, current_date()), true, false) as is_active
from ccl_3c ccl
left join {{ ref('stg_ccc_customer') }} ccc on ccl.location_no = ccc.location_no
left join txn on ccl.location_no = txn.location_no
