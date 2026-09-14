-- Location-level revenue by PRODUCT — the primary share-of-wallet source.
select
    uid,
    brand,
    country,
    product,
    datemonth,
    total_revenue,
    count_transactions
from {{ source('curated', 'curated_ccl_revenue') }}
where uid in (select uid from {{ ref('stg_ccl_customer') }})
   or brand in (select distinct raw_brand from {{ ref('stg_ccl_customer') }})
