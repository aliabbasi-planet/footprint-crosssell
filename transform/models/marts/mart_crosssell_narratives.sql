-- Cortex-written commercial narrative per opportunity. Grounded ONLY on the
-- deterministic opportunity row — the model rephrases facts, it never invents figures.
-- Limited to HIGH/MEDIUM bands to keep Cortex cost negligible.
with opps as (
    select *
    from {{ ref('mart_crosssell_opportunities') }}
    where confidence_band in ('HIGH', 'MEDIUM')
      and not has_open_sf_opportunity
)

select
    merchant,
    vertical,
    opportunity_type,
    priority_score,
    confidence_band,
    annual_volume_eur,
    products_used,
    rationale,
    snowflake.cortex.complete(
        'claude-4-sonnet',
        'You are a Planet commercial analyst. Write a concise 2-3 sentence cross-sell '
        || 'recommendation using ONLY these facts. Do not invent numbers or locations. '
        || 'Merchant: ' || merchant
        || '. Vertical: ' || vertical
        || '. Opportunity: ' || opportunity_type
        || '. Rationale: ' || rationale
        || '. Annual Planet gateway volume (EUR): ' || to_varchar(round(annual_volume_eur))
        || '. Products currently used: ' || to_varchar(products_used) || ' of 4.'
    )                                                       as narrative
from opps
