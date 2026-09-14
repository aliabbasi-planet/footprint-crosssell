-- Tax Free store master, keyed back to CCL UID by stripping the '-TRS' suffix.
select
    {{ strip_trs_suffix('trs_uid') }}   as uid,
    trs_brand                           as trs_brand,
    trs_country                         as trs_country,
    trs_store,
    trs_cust_name
from {{ source('curated', 'curated_tf_all_sources_stores') }}
where {{ strip_trs_suffix('trs_uid') }} in (select uid from {{ ref('stg_ccl_customer') }})
