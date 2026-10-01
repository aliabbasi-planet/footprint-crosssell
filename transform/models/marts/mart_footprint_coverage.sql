-- Portfolio coverage per merchant: what Planet serves today vs the brand's
-- published global footprint. One row per merchant. All external figures carry
-- their brand source + as-of so the number is defensible.
with internal as (
    select
        merchant,
        max(vertical)                                   as vertical,
        count(distinct iff(internal_stores > 0, country, null)) as planet_countries,
        count(distinct iff(internal_stores = 0 and former_stores > 0, country, null)) as former_only_countries,
        sum(internal_stores)                            as planet_stores,
        sum(former_stores)                              as former_stores,
        sum(shared_location_stores)                     as shared_location_stores,
        sum(internal_stores_3c)                         as planet_stores_3c,
        sum(internal_stores_mas)                        as planet_stores_mas,
        sum(stores_in_open_opportunity)                 as planet_stores_in_open_opp
    from {{ ref('int_internal_footprint') }}
    group by 1
),

ext_country as (
    select
        merchant,
        count(distinct country)                     as external_known_countries,
        sum(external_units)                         as external_known_units
    from {{ ref('int_external_footprint') }}
    where granularity = 'country'
    group by 1
),

totals as (
    select * from {{ ref('ext_brand_totals') }}
)

select
    t.merchant,
    coalesce(i.vertical, 'Unknown')                                             as vertical,
    t.unit_type,
    t.operating_model,
    t.brand_total_units,
    t.brand_total_countries,
    coalesce(i.planet_countries, 0)                                             as planet_countries,
    coalesce(i.planet_stores, 0)                                                as planet_stores,
    coalesce(i.shared_location_stores, 0)                                       as shared_location_stores,
    coalesce(i.former_stores, 0)                                                as former_stores,
    coalesce(i.former_only_countries, 0)                                        as former_only_countries,
    coalesce(i.planet_stores_3c, 0)                                             as planet_stores_3c,
    coalesce(i.planet_stores_mas, 0)                                            as planet_stores_mas,
    coalesce(i.planet_stores_in_open_opp, 0)                                    as planet_stores_in_open_opp,
    ec.external_known_countries,
    ec.external_known_units,
    round(div0(i.planet_stores, t.brand_total_units) * 100, 1)                  as store_coverage_pct,
    round(div0(i.planet_countries, t.brand_total_countries) * 100, 1)           as country_coverage_pct,
    greatest(coalesce(t.brand_total_countries, 0) - coalesce(i.planet_countries, 0), 0) as country_whitespace_count,
    t.source_name                                                               as brand_source_name,
    t.source_url                                                                as brand_source_url,
    t.as_of_period                                                              as brand_as_of_period,
    t.source_tier                                                               as brand_source_tier
from totals t
left join internal i on t.merchant = i.merchant
left join ext_country ec on t.merchant = ec.merchant
