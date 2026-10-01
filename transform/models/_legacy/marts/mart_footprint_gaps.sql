-- FOOTPRINT GAPS: external locations that Planet does NOT serve or know about.
-- Grain: merchant × country × city. Each row is a location the brand operates
-- where Planet has no matching internal record.
with gaps as (
    select
        merchant,
        country                                      as ext_country,
        ext_city,
        ext_address,
        ext_store,
        source_tier,
        discovered_at
    from {{ ref('int_location_matching') }}
    where match_status = 'UNMATCHED'
),

-- Count internal locations per merchant × country for context
internal_context as (
    select merchant, country, count(*) as internal_location_count
    from {{ ref('int_internal_estate') }}
    group by 1, 2
)

select
    g.merchant,
    g.ext_country                                    as country,
    g.ext_city                                       as city,
    g.ext_address                                    as address,
    g.ext_store                                      as store_name,
    g.source_tier,
    g.discovered_at,
    coalesce(ic.internal_location_count, 0)          as planet_locations_in_country,
    case
        when ic.internal_location_count is null then 'NEW_COUNTRY'
        else 'NEW_LOCATION_IN_KNOWN_COUNTRY'
    end                                              as gap_type
from gaps g
left join internal_context ic
    on g.merchant = ic.merchant and upper(g.ext_country) = upper(ic.country)
