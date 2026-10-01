-- ANTI-FABRICATION GATE (hard fail).
-- No external footprint figure or operator mapping may exist without a
-- resolvable source_url and an as_of_period. This is the control that keeps the
-- pipeline honest: a number with no provenance must never reach a mart.
select
    'external_footprint_missing_provenance' as failure,
    merchant,
    country,
    source_id
from {{ ref('int_external_footprint') }}
where source_url is null
   or as_of_period is null
   or trim(source_url) = ''

union all

select
    'operator_map_missing_provenance' as failure,
    merchant,
    country,
    'opt_a_registers' as source_id
from {{ ref('ext_option_a_operators') }}
where source_url is null
   or as_of_period is null
   or trim(source_url) = ''
