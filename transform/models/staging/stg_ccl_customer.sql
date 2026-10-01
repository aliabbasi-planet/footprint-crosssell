-- CCL bridge, cleaned 1:1 passthrough of DIM_CCL_CUSTOMER.
-- Merchant tagging is intentionally NOT done here: it moves to
-- int_brand_resolution, which matches across brand + customer_name +
-- sf_account_name with include / exclude / sub-brand rules. SF_ACCOUNT_ID is
-- the only cross-source key.
select
    sf_account_id,
    sf_account_name,
    brand              as raw_brand,
    customer_name,
    brand_id,
    acquirer,
    data_source,
    uid,
    country,
    city,
    store,
    address            as ccl_address,
    sf_vertical,
    sf_new_vertical,
    sf_opportunity_id,
    dccprovider
from {{ source('datamart', 'dim_ccl_customer') }}
where coalesce(brand, customer_name, sf_account_name) is not null
