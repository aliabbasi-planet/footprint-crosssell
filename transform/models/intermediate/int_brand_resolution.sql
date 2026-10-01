-- =============================================================================
-- int_brand_resolution  —  THE merchant-matching fix.
--
-- The legacy approach matched DIM_CCL_CUSTOMER.BRAND ILIKE a single seed pattern.
-- That produced BOTH:
--   * false positives  (Dolce -> "Dolce by Wyndham"; "passport" -> SSP;
--                        "Four Seasons Vegetables" -> Four Seasons)
--   * false negatives  (sub-brands missed: Sheraton/Westin -> Marriott,
--                        Ibis/Novotel -> Accor, Sunglass Hut/LensCrafters -> Luxottica)
--
-- Each CCL row is resolved against the brand_resolution_rules seed, matching
-- across brand + customer_name + account (macros/rule_match.sql):
--   include / subbrand : direct brand tokens and operating banners
--   exclude            : per-merchant kill-list; merchant '*' = all merchants
--                        (e.g. third-party parking operators)
--   country_scope      : rule applies only in the listed countries
--   match_mode         : ilike / word / prefix / leading
--
-- Grain: one row per (CCL row, merchant). A location that carries two PoC
-- brands (an SSP-run Starbucks, a Starbucks inside a Westin) is credited to
-- EACH brand and flagged is_shared_location — every brand's published unit
-- count includes such units, so forcing a single owner would undercount one.
--
-- Decommissioned / test terminals (### / DECOM / *DNU* / TEST / CLOSED markers)
-- are kept but flagged, so served counts exclude them and countries Planet
-- used to serve surface as win-back.
-- =============================================================================

with ccl as (
    select
        {{ dbt_utils.generate_surrogate_key(['sf_account_id', 'uid', 'data_source', 'country', 'city', 'store']) }} as row_id,
        c.*,
        {{ normalize_country('c.country') }} as country_canon,
        lower(
            coalesce(raw_brand, '') || ' | '
            || coalesce(customer_name, '') || ' | '
            || coalesce(sf_account_name, '')
        ) as match_text,
        lower(coalesce(customer_name, raw_brand, '')) as outlet_name
    from {{ ref('stg_ccl_customer') }} c
),

rules as (
    select
        merchant,
        vertical,
        rule_type,
        match_mode,
        lower(pattern)        as pattern,
        upper(country_scope)  as country_scope
    from {{ ref('brand_resolution_rules') }}
),

-- Positive signals per (row, merchant): DIRECT beats SUBBRAND when both hit.
positive as (
    select
        c.row_id,
        r.merchant,
        r.vertical,
        min(case when r.rule_type = 'include' then 1 else 2 end) as match_priority
    from ccl c
    join rules r
        on r.rule_type in ('include', 'subbrand')
       and {{ rule_match('c.match_text') }}
       and {{ rule_in_scope('c.country_canon') }}
    group by 1, 2, 3
),

-- Per-merchant vetoes.
excluded as (
    select distinct c.row_id, r.merchant
    from ccl c
    join rules r
        on r.rule_type = 'exclude'
       and r.merchant <> '*'
       and {{ rule_match('c.match_text') }}
       and {{ rule_in_scope('c.country_canon') }}
),

-- Vetoes that apply to every merchant.
excluded_all as (
    select distinct c.row_id
    from ccl c
    join rules r
        on r.rule_type = 'exclude'
       and r.merchant = '*'
       and {{ rule_match('c.match_text') }}
       and {{ rule_in_scope('c.country_canon') }}
),

candidates as (
    select p.*
    from positive p
    left join excluded e
        on p.row_id = e.row_id and p.merchant = e.merchant
    left join excluded_all x
        on p.row_id = x.row_id
    where e.row_id is null
      and x.row_id is null
),

shared as (
    select
        row_id,
        count(*)                                                  as merchant_count,
        listagg(merchant, ' + ') within group (order by merchant) as merchants_at_location
    from candidates
    group by 1
)

select
    ccl.row_id,
    ccl.sf_account_id,
    ccl.sf_account_name,
    ccl.raw_brand,
    ccl.customer_name,
    ccl.data_source,
    ccl.acquirer,
    ccl.uid,
    ccl.country                                  as country_raw,
    ccl.country_canon                            as country,
    ccl.city,
    ccl.store,
    ccl.ccl_address,
    ccl.sf_vertical,
    ccl.sf_opportunity_id,
    ccl.dccprovider,
    cand.merchant,
    cand.vertical,
    case when cand.match_priority = 1 then 'DIRECT' else 'SUBBRAND' end as resolution_method,
    (s.merchant_count > 1)                       as is_shared_location,
    s.merchants_at_location,
    (
        left(ccl.outlet_name, 1) in ('#', '*')
        or ccl.outlet_name like '%decom%'
        or ccl.outlet_name like '%dnu*%'
        or ccl.outlet_name like '%do not use%'
        or regexp_instr(ccl.outlet_name, '(^|[^a-z])(test|closed)([^a-z]|$)') > 0
    )                                            as is_decommissioned
from candidates cand
join ccl on ccl.row_id = cand.row_id
join shared s on s.row_id = cand.row_id
