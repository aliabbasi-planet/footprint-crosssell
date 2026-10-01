-- Internal footprint at merchant x canonical-country grain: how many locations,
-- cities and accounts Planet actually serves for each PoC merchant. Built on the
-- corrected int_brand_resolution (not the legacy BRAND-only match).
--
-- internal_stores counts ACTIVE locations only. Decommissioned / test terminals
-- are reported separately (former_stores) so a country Planet used to serve
-- shows up as a win-back rather than as served or as never-served.
select
    merchant,
    vertical,
    country,
    count(distinct iff(not is_decommissioned, uid, null))                              as internal_stores,
    count(distinct iff(is_decommissioned, uid, null))                                  as former_stores,
    count(distinct iff(not is_decommissioned, city, null))                             as internal_cities,
    count(distinct iff(not is_decommissioned, sf_account_id, null))                    as internal_accounts,
    count(distinct iff(not is_decommissioned and data_source = '3C', uid, null))       as internal_stores_3c,
    count(distinct iff(not is_decommissioned and data_source = 'MAS', uid, null))      as internal_stores_mas,
    count(distinct iff(not is_decommissioned and data_source = 'TRS', uid, null))      as internal_stores_trs,
    count(distinct iff(not is_decommissioned and sf_opportunity_id is not null, uid, null)) as stores_in_open_opportunity,
    count(distinct iff(not is_decommissioned and is_shared_location, uid, null))       as shared_location_stores
from {{ ref('int_brand_resolution') }}
where country is not null
group by 1, 2, 3
