-- Match external discovered locations against Planet's internal estate.
-- An external location is "matched" if we find an internal location for the same
-- merchant + country + similar city (JAROWINKLER >= 0.8). Unmatched = footprint gap.
with external as (
    select * from {{ ref('ext_combined_external') }}
),

internal as (
    select distinct merchant, country, city, store, location_no
    from {{ ref('int_internal_estate') }}
),

matched as (
    select
        e.merchant,
        e.country,
        e.city                                                        as ext_city,
        e.address                                                     as ext_address,
        e.store_name                                                  as ext_store,
        e.source_tier,
        e.discovered_at,
        i.city                                                        as int_city,
        i.store                                                       as int_store,
        i.location_no                                                 as int_location_no,
        case
            when i.location_no is not null
                 and jarowinkler_similarity(lower(coalesce(e.city,'')), lower(coalesce(i.city,''))) >= 80
                then 'MATCHED'
            when i.location_no is not null
                then 'WEAK_MATCH'
            else 'UNMATCHED'
        end                                                           as match_status,
        jarowinkler_similarity(
            lower(coalesce(e.city,'')), lower(coalesce(i.city,''))
        )                                                             as city_similarity
    from external e
    left join internal i
        on e.merchant = i.merchant
       and upper(e.country) = upper(i.country)
    qualify row_number() over (
        partition by e.merchant, e.country, e.city, e.address
        order by city_similarity desc nulls last
    ) = 1
)

select * from matched
