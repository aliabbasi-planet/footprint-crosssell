-- MART INTEGRITY (hard fail).
-- Construction invariants for the white-space mart. If any fail, the valuation
-- logic has regressed and the numbers cannot be trusted.
--   1. a "white-space" row must have zero internal stores (by definition)
--   2. capture tiers must be monotonically ordered: full >= 25% >= 10%
--   3. a positive gap must carry a non-null per-store benchmark (else value is a
--      silent zero)
select 'whitespace_row_has_internal_stores' as failure, merchant, country
from {{ ref('mart_country_whitespace') }}
where is_whitespace and internal_stores > 0

union all

select 'capture_tiers_not_monotonic' as failure, merchant, country
from {{ ref('mart_country_whitespace') }}
where value_full_eur < value_25pct_eur
   or value_25pct_eur < value_10pct_eur

union all

select 'positive_gap_missing_benchmark' as failure, merchant, country
from {{ ref('mart_country_whitespace') }}
where gap_units > 0 and benchmark_per_store_eur is null
