{{ config(materialized='table', tags=['cortex']) }}

-- AI commercial briefing per merchant. GROUNDED: the prompt contains ONLY the
-- figures computed in the marts above and explicitly forbids inventing
-- locations/operators/numbers. Uses AI_COMPLETE (not the deprecated
-- SNOWFLAKE.CORTEX.* namespace). Model is pinned via var('cortex_model').
--
-- Values are stated at the 25%-capture planning case; the 100% figure is passed
-- only as a labelled ceiling so the model cannot present it as expected revenue.
with coverage as (
    select * from {{ ref('mart_footprint_coverage') }}
),

gaps as (
    select
        merchant,
        country,
        case gap_kind
            when 'NEW_COUNTRY' then 'new country'
            when 'WIN_BACK'    then 'win-back'
            else 'depth: Planet already present'
        end as gap_label,
        gap_units,
        value_25pct_eur,
        value_full_eur,
        row_number() over (partition by merchant order by value_25pct_eur desc nulls last) as rn
    from {{ ref('mart_country_whitespace') }}
    where gap_units > 0
),

gap_totals as (
    select
        merchant,
        count(distinct country) as sized_countries,
        sum(value_25pct_eur)    as total_value_25pct_eur,
        sum(value_full_eur)     as total_value_full_eur
    from gaps
    group by 1
),

gaps_top as (
    select
        merchant,
        listagg(country || ' [' || gap_label || '] ~' || gap_units || ' un-served units, EUR '
                || to_varchar(round(value_25pct_eur)) || ' at 25% capture (ceiling EUR '
                || to_varchar(round(value_full_eur)) || ')', '; ')
            within group (order by rn) as top_gaps
    from gaps
    where rn <= 5
    group by 1
),

-- Countries where Planet only has decommissioned terminals: a re-activation play.
winback as (
    select
        merchant,
        listagg(country || ' (' || former_planet_stores || ' former terminals)', '; ')
            within group (order by former_planet_stores desc) as winback_countries
    from {{ ref('mart_country_whitespace') }}
    where gap_kind = 'WIN_BACK'
    group by 1
),

-- Winnable operator plays only (open or not-yet-sized gaps), ranked per merchant.
operators_ranked as (
    select
        merchant,
        country,
        operator_name,
        opportunity_type,
        gap_status,
        operator_served_by_planet_in,
        row_number() over (partition by merchant order by priority_rank) as rn
    from {{ ref('mart_operator_opportunities') }}
    where gap_status in ('OPEN_GAP', 'UNSIZED')
),

operators_top as (
    select
        merchant,
        listagg(
            operator_name || ' (' || country || ')'
            || case opportunity_type
                   when 'EXPAND_EXISTING_RELATIONSHIP' then ' [existing Planet client in this market]'
                   when 'WARM_INTRO_EXISTING_OPERATOR' then ' [warm: Planet already serves this operator in '
                                                            || operator_served_by_planet_in || ']'
                   else ' [new relationship]'
               end
            || iff(gap_status = 'UNSIZED', ' [market size not yet sourced]', ''),
            '; ') within group (order by rn) as top_operators
    from operators_ranked
    where rn <= 5
    group by 1
),

facts as (
    select
        c.merchant,
        c.vertical,
        c.planet_countries,
        c.planet_stores,
        c.brand_total_units,
        c.brand_total_countries,
        c.store_coverage_pct,
        c.country_coverage_pct,
        c.country_whitespace_count,
        c.brand_source_name,
        c.brand_as_of_period,
        t.sized_countries,
        t.total_value_25pct_eur,
        t.total_value_full_eur,
        g.top_gaps,
        o.top_operators,
        wb.winback_countries
    from coverage c
    left join gap_totals t on c.merchant = t.merchant
    left join gaps_top g on c.merchant = g.merchant
    left join operators_top o on c.merchant = o.merchant
    left join winback wb on c.merchant = wb.merchant
),

prompted as (
    select
        f.*,
        'You are a commercial analyst at Planet, a payments company. Using ONLY the '
        || 'facts below, write a concise 140-word briefing for the sales team on the '
        || 'cross-sell footprint opportunity for ' || f.merchant || '. Do NOT invent any '
        || 'locations, operators, or numbers beyond those given. Cite the key figures. '
        || 'Values are a 25%-capture planning case built from Planet''s own per-store revenue; '
        || 'ceiling figures assume 100% capture and must NOT be presented as expected revenue. '
        || 'Lead with the FIRST operator play listed: plays are pre-ranked with winnable warm '
        || 'introductions first. Facts: '
        || 'Vertical=' || coalesce(f.vertical, 'n/a') || '. '
        || 'Planet serves ' || f.planet_stores || ' active locations across ' || f.planet_countries
        || ' countries. Brand operates ~' || coalesce(to_varchar(f.brand_total_units), 'n/a')
        || ' units in ~' || coalesce(to_varchar(f.brand_total_countries), 'n/a')
        || ' countries (source: ' || coalesce(f.brand_source_name, 'n/a')
        || ', ' || coalesce(f.brand_as_of_period, 'n/a') || '). '
        || 'Country coverage=' || coalesce(to_varchar(f.country_coverage_pct), 'n/a') || '%; '
        || 'countries not yet served=' || f.country_whitespace_count
        || ' (only some have sourced unit counts). '
        || 'Total sized gap value: EUR ' || coalesce(to_varchar(round(f.total_value_25pct_eur)), '0')
        || ' at 25% capture (ceiling EUR ' || coalesce(to_varchar(round(f.total_value_full_eur)), '0')
        || '), across the ' || coalesce(to_varchar(f.sized_countries), '0')
        || ' countries where a sourced unit count shows an un-served gap - do not attribute it to all unserved countries. '
        || 'Largest sized gaps: ' || coalesce(f.top_gaps, 'none sized yet') || '. '
        || 'Win-back countries (Planet served there before, none active now): '
        || coalesce(f.winback_countries, 'none') || '. '
        || 'Operator plays: ' || coalesce(f.top_operators, 'none mapped yet') || '.'
            as prompt
    from facts f
)

select
    merchant,
    vertical,
    planet_countries,
    planet_stores,
    country_whitespace_count,
    total_value_25pct_eur,
    total_value_full_eur,
    top_gaps,
    winback_countries,
    top_operators,
    ai_complete('{{ var('cortex_model', 'claude-4-sonnet') }}', prompt) as narrative,
    '{{ var('cortex_model', 'claude-4-sonnet') }}'                      as model_used,
    prompt                                                             as grounding_prompt,
    current_timestamp()                                                as generated_at
from prompted
