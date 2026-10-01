-- INTELLIGENCE REPORT: unified view combining footprint gaps + eligible cross-sell,
-- suppressed by open Salesforce opportunities.
with footprint as (
    select
        merchant, 'FOOTPRINT_GAP' as intelligence_type,
        country || ': ' || coalesce(city, '?') as location_detail,
        gap_type as detail_type,
        source_tier,
        null as missing_product,
        null::float as annual_gateway_eur,
        null as opportunity_size
    from {{ ref('mart_footprint_gaps') }}
),

crosssell as (
    select
        merchant, 'ELIGIBLE_CROSSSELL' as intelligence_type,
        null as location_detail,
        eligibility_rationale as detail_type,
        null as source_tier,
        missing_product,
        annual_gateway_eur,
        opportunity_size
    from {{ ref('mart_eligible_crosssell') }}
),

combined as (
    select * from footprint
    union all
    select * from crosssell
),

-- Suppress merchants with open SF opportunities
open_opp as (
    select distinct bc.merchant
    from {{ ref('int_brand_canonical') }} bc
    join {{ ref('stg_sf_opportunity') }} o on bc.sf_account_id = o.sf_account_id
),

gap_counts as (
    select merchant,
        count(case when intelligence_type = 'FOOTPRINT_GAP' then 1 end)     as footprint_gap_count,
        count(case when intelligence_type = 'ELIGIBLE_CROSSSELL' then 1 end) as crosssell_gap_count
    from combined
    group by merchant
)

select
    c.merchant,
    c.intelligence_type,
    c.location_detail,
    c.detail_type,
    c.source_tier,
    c.missing_product,
    c.annual_gateway_eur,
    c.opportunity_size,
    gc.footprint_gap_count,
    gc.crosssell_gap_count,
    (c.merchant in (select merchant from open_opp)) as has_open_sf_opportunity
from combined c
join gap_counts gc on c.merchant = gc.merchant
