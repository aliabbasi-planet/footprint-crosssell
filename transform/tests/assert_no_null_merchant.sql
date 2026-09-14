-- No mart row should carry a null merchant key.
select 'null_merchant_in_footprint' as failure
from {{ ref('mart_merchant_footprint') }}
where merchant is null
