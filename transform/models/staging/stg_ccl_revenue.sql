-- Location-level revenue by PRODUCT — Planet's realised economics.
-- Clean passthrough: attribution to a PoC merchant happens downstream in
-- int_value_benchmark, which joins on UID to the corrected int_brand_resolution.
select
    uid,
    brand,
    country,
    product,
    datemonth,
    total_revenue,
    count_transactions
from {{ source('curated', 'curated_ccl_revenue') }}
where uid is not null
