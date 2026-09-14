-- One row per PoC merchant with its canonical name (from the seed) and SF vertical.
select distinct
    poc_merchant       as merchant,
    poc_vertical       as vertical,
    sf_account_id,
    sf_vertical
from {{ ref('stg_ccl_customer') }}
