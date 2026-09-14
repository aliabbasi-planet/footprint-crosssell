-- 3C location detail, joined only to PoC locations.
select
    ccc.location_no,
    ccc.merchant_id      as ccc_merchant_id,
    ccc.address1,
    ccc.address2,
    ccc.post_code,
    ccc.city             as ccc_city,
    ccc.country_code,
    ccc.country_name,
    ccc.operating_environment,
    ccc.is_dcc,
    ccc.is_web2pay,
    ccc.industry_name,
    ccc.last_transaction_date,
    ccc.date_installation
from {{ source('datamart', 'dim_ccc_customer') }} ccc
where ccc.location_no in (
    select uid from {{ ref('stg_ccl_customer') }} where data_source = '3C'
)
