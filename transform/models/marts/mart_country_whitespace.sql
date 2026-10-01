-- Country-level white-space, valued with Planet's OWN realised economics.
-- One row per merchant x country where the brand is published to operate.
-- gap_units      = external units Planet does not yet serve in that country
-- value_full/_25/_10 = gap_units x per-store benchmark at 100% / 25% / 10% capture
--
-- The benchmark is country-level realised revenue-per-store where Planet has
-- data there, otherwise the merchant's blended realised revenue-per-store.
-- Nothing here is an external/estimated revenue figure.
with external_country as (
    select
        merchant,
        country,
        sum(external_units)                 as external_units,
        max(source_name)                    as source_name,
        max(source_url)                     as source_url,
        max(as_of_period)                   as as_of_period,
        max(source_tier)                    as source_tier
    from {{ ref('int_external_footprint') }}
    where granularity = 'country'
    group by 1, 2
),

internal as (
    select
        merchant,
        country,
        sum(internal_stores) as internal_stores,
        sum(former_stores)   as former_stores
    from {{ ref('int_internal_footprint') }}
    group by 1, 2
),

merchant_vertical as (
    select merchant, max(vertical) as vertical
    from {{ ref('int_internal_footprint') }}
    group by 1
),

country_bench as (
    select merchant, country, revenue_per_store_eur
    from {{ ref('int_value_benchmark') }}
),

merchant_bench as (
    select
        merchant,
        div0(sum(ttm_revenue_eur), sum(revenue_stores)) as blended_revenue_per_store_eur
    from {{ ref('int_value_benchmark') }}
    group by 1
),

combined as (
    select
        e.merchant,
        mv.vertical,
        e.country,
        reg.region,
        e.external_units,
        coalesce(i.internal_stores, 0)                                      as internal_stores,
        coalesce(i.former_stores, 0)                                        as former_planet_stores,
        greatest(e.external_units - coalesce(i.internal_stores, 0), 0)      as gap_units,
        (coalesce(i.internal_stores, 0) = 0)                               as is_whitespace,
        case
            when coalesce(i.internal_stores, 0) > 0 then 'DEPTH'
            when coalesce(i.former_stores, 0) > 0   then 'WIN_BACK'
            else 'NEW_COUNTRY'
        end                                                                 as gap_kind,
        coalesce(cb.revenue_per_store_eur, mb.blended_revenue_per_store_eur) as benchmark_per_store_eur,
        case when cb.revenue_per_store_eur is not null then 'COUNTRY_REALISED'
             else 'MERCHANT_BLENDED' end                                    as benchmark_basis,
        e.source_name,
        e.source_url,
        e.as_of_period,
        e.source_tier
    from external_country e
    left join internal i on e.merchant = i.merchant and e.country = i.country
    left join merchant_vertical mv on e.merchant = mv.merchant
    left join country_bench cb on e.merchant = cb.merchant and e.country = cb.country
    left join merchant_bench mb on e.merchant = mb.merchant
    left join {{ ref('dim_country_region') }} reg on e.country = reg.country_canonical
)

select
    merchant,
    vertical,
    country,
    region,
    external_units,
    internal_stores,
    former_planet_stores,
    gap_units,
    is_whitespace,
    gap_kind,
    round(benchmark_per_store_eur, 2)                       as benchmark_per_store_eur,
    benchmark_basis,
    round(gap_units * benchmark_per_store_eur, 0)           as value_full_eur,
    round(gap_units * benchmark_per_store_eur * 0.25, 0)    as value_25pct_eur,
    round(gap_units * benchmark_per_store_eur * 0.10, 0)    as value_10pct_eur,
    source_name,
    source_url,
    as_of_period,
    source_tier
from combined
