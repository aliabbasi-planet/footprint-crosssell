{{ config(materialized='table', enabled=source_tier_enabled('B'), tags=['external', 'parked', 'option_b']) }}

-- =============================================================================
-- Option B — Google Places API (New).  PARKED.
--
-- This model is DISABLED until `enabled_source_tiers` includes 'B'
-- (config enabled = source_tier_enabled('B')), which should only happen once:
--   1. Legal/Risk have signed off (see docs/aws_external_data_acquisition_legal_risk_report.md)
--   2. The platform team has provisioned a Google Places API key, stored as a
--      Snowflake SECRET and reachable via an EXTERNAL ACCESS INTEGRATION.
--
-- Activation (no rework elsewhere — int_external_footprint picks it up by tier):
--   * set vars.enabled_source_tiers: ['A', 'B'] in dbt_project.yml
--   * set external_source_registry.enabled = true for opt_b_google_places
--   * implement the body below: call a Places-backed UDF
--     (searchText / nearbySearch) via external access, land geocoded POIs, then
--     aggregate to merchant x country unit counts matching the columns below.
--
-- Contract (must match int_external_footprint):
--   merchant, country, external_units, granularity, source_id,
--   source_name, source_url, as_of_period, source_tier
-- =============================================================================
select
    cast(null as varchar)        as merchant,
    cast(null as varchar)        as country,
    cast(null as number)         as external_units,
    cast('location' as varchar)  as granularity,
    'opt_b_google_places'        as source_id,
    cast('Google Places API (New)' as varchar) as source_name,
    cast(null as varchar)        as source_url,
    cast(null as varchar)        as as_of_period,
    cast('B' as varchar)         as source_tier
where false
