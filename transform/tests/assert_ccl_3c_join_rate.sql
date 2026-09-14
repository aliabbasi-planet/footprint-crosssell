-- Fails if the CCL <-> 3C join for PoC merchants drops below 99%.
with ccl as (
    select uid from {{ ref('stg_ccl_customer') }} where data_source = '3C'
),
matched as (
    select count(*) as matched
    from ccl
    join {{ ref('stg_ccc_customer') }} ccc on ccl.uid = ccc.location_no
),
total as (select count(*) as total from ccl)
select 'ccl_3c_join_below_99pct' as failure
from matched, total
where total.total > 0
  and (100.0 * matched.matched / total.total) < 99.0
