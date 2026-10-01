-- Trailing-twelve-month realised revenue per served store, by merchant x country.
-- This is Planet's OWN economics (from CURATED_CCL_REVENUE), used to value
-- footprint white-space rather than any external/estimated figure.
--
-- Revenue is attributed to a merchant via the corrected resolution (join on UID),
-- so sub-brands and false positives are handled consistently with the footprint.
with revenue as (
    select
        uid,
        {{ normalize_country('country') }}  as country,
        datemonth,
        total_revenue
    from {{ ref('stg_ccl_revenue') }}
),

bounds as (
    select max(datemonth) as max_month from revenue
),

ttm as (
    select r.uid, r.country, r.total_revenue
    from revenue r
    cross join bounds b
    where r.datemonth > dateadd('month', -12, b.max_month)
      and r.total_revenue is not null
),

resolved as (
    select distinct uid, merchant, vertical
    from {{ ref('int_brand_resolution') }}
),

joined as (
    select
        res.merchant,
        res.vertical,
        ttm.country,
        ttm.uid,
        ttm.total_revenue
    from ttm
    join resolved res on ttm.uid = res.uid
)

select
    merchant,
    vertical,
    country,
    sum(total_revenue)                                   as ttm_revenue_eur,
    count(distinct uid)                                  as revenue_stores,
    div0(sum(total_revenue), count(distinct uid))        as revenue_per_store_eur
from joined
where country is not null
group by 1, 2, 3
