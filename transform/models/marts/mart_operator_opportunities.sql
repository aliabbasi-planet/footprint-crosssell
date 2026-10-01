-- The actionable output: for each brand x country, WHO operates it, whether
-- Planet already has that relationship (here or elsewhere), the un-served unit
-- gap, and a conservative (25%-capture) value — ranked so warm, winnable plays
-- surface first.
--
-- Warmth is assessed at OPERATOR level: if Planet already serves an operator in
-- one country (e.g. AmRest in Germany), that operator's other markets (Poland,
-- Czechia, Hungary, Romania) are warm introductions, not cold new logos.
--
-- gap_status keeps "unknown" distinct from "zero": where the brand's
-- per-country count is not yet sourced, the gap is UNSIZED (a task for the
-- Option A discovery agent), never silently 0.
with operators as (
    select
        merchant,
        country,
        operator_name,
        operator_role,
        planet_existing_relationship,
        evidence,
        source_url,
        as_of_period
    from {{ ref('ext_option_a_operators') }}
),

-- Operators Planet already serves in at least one market.
warm_operators as (
    select
        operator_name,
        listagg(distinct country, ', ') within group (order by country) as served_in
    from operators
    where planet_existing_relationship
    group by 1
),

external_country as (
    select merchant, country, sum(external_units) as external_units
    from {{ ref('int_external_footprint') }}
    where granularity = 'country'
    group by 1, 2
),

internal as (
    select merchant, country, sum(internal_stores) as internal_stores
    from {{ ref('int_internal_footprint') }}
    group by 1, 2
),

country_bench as (
    select merchant, country, revenue_per_store_eur
    from {{ ref('int_value_benchmark') }}
),

merchant_bench as (
    select merchant, div0(sum(ttm_revenue_eur), sum(revenue_stores)) as blended_revenue_per_store_eur
    from {{ ref('int_value_benchmark') }}
    group by 1
),

joined as (
    select
        o.merchant,
        o.country,
        reg.region,
        o.operator_name,
        o.operator_role,
        o.planet_existing_relationship,
        (o.planet_existing_relationship or w.operator_name is not null) as operator_is_planet_client,
        w.served_in                                                      as operator_served_by_planet_in,
        o.evidence,
        o.source_url,
        o.as_of_period,
        ec.external_units,
        coalesce(i.internal_stores, 0)                                   as internal_stores,
        case
            when ec.external_units is null then null
            else greatest(ec.external_units - coalesce(i.internal_stores, 0), 0)
        end                                                              as gap_units,
        coalesce(cb.revenue_per_store_eur, mb.blended_revenue_per_store_eur) as benchmark_per_store_eur
    from operators o
    left join warm_operators w on o.operator_name = w.operator_name
    left join external_country ec on o.merchant = ec.merchant and o.country = ec.country
    left join internal i on o.merchant = i.merchant and o.country = i.country
    left join country_bench cb on o.merchant = cb.merchant and o.country = cb.country
    left join merchant_bench mb on o.merchant = mb.merchant
    left join {{ ref('dim_country_region') }} reg on o.country = reg.country_canonical
),

classified as (
    select
        *,
        round(gap_units * benchmark_per_store_eur * 0.25, 0) as est_gap_value_25pct_eur,
        case
            when country = 'GLOBAL'  then 'PORTFOLIO'
            when gap_units is null   then 'UNSIZED'
            when gap_units = 0       then 'FULLY_COVERED'
            else 'OPEN_GAP'
        end                                                  as gap_status
    from joined
)

select
    merchant,
    country,
    region,
    operator_name,
    operator_role,
    planet_existing_relationship,
    operator_is_planet_client,
    operator_served_by_planet_in,
    external_units,
    internal_stores,
    gap_units,
    gap_status,
    est_gap_value_25pct_eur,
    case
        when country = 'GLOBAL'           then 'PORTFOLIO_RELATIONSHIP'
        when planet_existing_relationship then 'EXPAND_EXISTING_RELATIONSHIP'
        when operator_is_planet_client    then 'WARM_INTRO_EXISTING_OPERATOR'
        when internal_stores > 0          then 'KNOWN_COUNTRY_NEW_OPERATOR'
        else 'NEW_OPERATOR_NEW_COUNTRY'
    end                                                         as opportunity_type,
    -- Winnable plays first (open or unsized gap), warm before cold, then by value.
    row_number() over (
        order by
            case gap_status when 'OPEN_GAP' then 0 when 'UNSIZED' then 1 else 2 end,
            iff(operator_is_planet_client, 0, 1),
            coalesce(est_gap_value_25pct_eur, 0) desc,
            merchant, country
    )                                                           as priority_rank,
    evidence,
    source_url,
    as_of_period
from classified
