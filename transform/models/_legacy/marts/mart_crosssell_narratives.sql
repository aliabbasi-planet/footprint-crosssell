-- Cortex-written commercial narratives grounded on the intelligence report.
-- One narrative per merchant summarising BOTH footprint gaps and eligible cross-sell.
with per_merchant as (
    select
        merchant,
        footprint_gap_count,
        crosssell_gap_count,
        has_open_sf_opportunity,
        listagg(distinct missing_product, ', ') within group (order by missing_product) as missing_products,
        max(annual_gateway_eur)                                        as annual_gateway_eur,
        listagg(
            distinct case when intelligence_type = 'FOOTPRINT_GAP' then location_detail end, '; '
        ) within group (order by location_detail)                      as sample_gap_locations
    from {{ ref('mart_intelligence_report') }}
    where not has_open_sf_opportunity
    group by merchant, footprint_gap_count, crosssell_gap_count, has_open_sf_opportunity
)

select
    merchant,
    footprint_gap_count,
    crosssell_gap_count,
    missing_products,
    annual_gateway_eur,
    snowflake.cortex.complete(
        'claude-4-sonnet',
        'You are a Planet commercial intelligence analyst. Write a 3-4 sentence briefing for a '
        || 'sales team about cross-sell opportunities for "' || merchant || '". '
        || 'Use ONLY these facts — do not invent locations or numbers: '
        || 'Footprint gaps (locations they operate that Planet does not serve): ' || to_varchar(footprint_gap_count) || '. '
        || 'Sample gap locations: ' || coalesce(left(sample_gap_locations, 500), 'none discovered') || '. '
        || 'Eligible products they do NOT use: ' || coalesce(missing_products, 'none') || '. '
        || 'Annual Planet gateway volume: EUR ' || coalesce(to_varchar(round(annual_gateway_eur)), 'unknown') || '. '
        || 'Be specific, actionable, and honest about confidence levels.'
    )                                                                  as narrative
from per_merchant
where footprint_gap_count > 0 or crosssell_gap_count > 0
