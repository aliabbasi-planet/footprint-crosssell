-- Channel position per merchant x country, derived from TERMINAL_TYPE_NAME keywords.
with txn as (
    select
        e.merchant,
        e.country,
        t.terminal_type_name,
        t.gateway_volume_eur
    from {{ ref('stg_ccc_transaction') }} t
    join {{ ref('int_internal_estate') }} e on t.location_no = e.location_no
),

classified as (
    select
        merchant,
        country,
        coalesce(max(m.channel), 'UNKNOWN') as channel,
        sum(gateway_volume_eur)             as volume_eur
    from txn
    left join {{ ref('channel_terminal_map') }} m
        on txn.terminal_type_name ilike m.keyword
    group by 1, 2, txn.terminal_type_name
)

select
    merchant,
    country,
    boolor_agg(channel = 'CARD_PRESENT') as has_card_present,
    boolor_agg(channel = 'ECOM')         as has_ecom,
    case
        when boolor_agg(channel = 'CARD_PRESENT') and boolor_agg(channel = 'ECOM') then 'BOTH'
        when boolor_agg(channel = 'CARD_PRESENT')                                  then 'CP_ONLY'
        when boolor_agg(channel = 'ECOM')                                          then 'ECOM_ONLY'
        else 'UNKNOWN'
    end                                  as channel_position,
    sum(volume_eur)                      as volume_eur
from classified
group by 1, 2
