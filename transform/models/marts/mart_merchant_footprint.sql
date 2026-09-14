-- Footprint: served locations + volume by merchant x country x product family.
with estate as (
    select
        merchant,
        vertical,
        country,
        count(distinct location_no)                as served_locations,
        count(distinct iff(is_active, location_no, null)) as active_locations,
        sum(gateway_volume_eur)                    as gateway_volume_eur,
        sum(txn_count)                             as txn_count,
        min(first_seen)                            as first_seen,
        max(last_seen)                             as last_seen
    from {{ ref('int_internal_estate') }}
    group by 1, 2, 3
),

channel as (
    select merchant, country, channel_position
    from {{ ref('int_channel_classification') }}
)

select
    e.merchant,
    e.vertical,
    e.country,
    'Gateway'                        as product_family,
    e.served_locations,
    e.active_locations,
    e.gateway_volume_eur,
    e.txn_count,
    e.first_seen,
    e.last_seen,
    coalesce(c.channel_position, 'UNKNOWN') as channel_position
from estate e
left join channel c on e.merchant = c.merchant and e.country = c.country
