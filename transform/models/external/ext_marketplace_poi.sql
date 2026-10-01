{{ config(materialized='table', enabled=source_tier_enabled('C'), tags=['external', 'parked', 'option_c']) }}

-- =============================================================================
-- Option C — Snowflake Marketplace POI (e.g. SafeGraph / Precisely).  PARKED.
--
-- Disabled until `enabled_source_tiers` includes 'C'. Activation:
--   1. Procurement + Legal approve a Marketplace POI listing subscription
--   2. ACCOUNTADMIN mounts the shared database into the account
--   3. set vars.enabled_source_tiers: ['A','C'] and registry.enabled=true for
--      opt_c_marketplace_poi
--   4. implement the body: read the mounted share, filter to the 9 brands, and
--      aggregate to merchant x country counts matching the contract below.
--
-- Contract (must match int_external_footprint):
--   merchant, country, external_units, granularity, source_id,
--   source_name, source_url, as_of_period, source_tier
-- =============================================================================
select
    cast(null as varchar)         as merchant,
    cast(null as varchar)         as country,
    cast(null as number)          as external_units,
    cast('location' as varchar)   as granularity,
    'opt_c_marketplace_poi'       as source_id,
    cast('Marketplace POI share' as varchar) as source_name,
    cast(null as varchar)         as source_url,
    cast(null as varchar)         as as_of_period,
    cast('C' as varchar)          as source_tier
where false
