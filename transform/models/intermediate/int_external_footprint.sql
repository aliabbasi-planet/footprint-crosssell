-- Unified external footprint, gated by the external_source_registry + the
-- enabled_source_tiers var. Option A (brand filings/directories) is active now.
-- Google Places (B) and Marketplace POI (C) are unioned in automatically once
-- their tier is enabled — no rework, just flip `enabled_source_tiers`.
with filings as (
    select
        merchant,
        country,
        external_units,
        granularity,
        source_id,
        source_name,
        source_url,
        as_of_period,
        source_tier
    from {{ ref('ext_option_a_filings') }}
),

unioned as (
    select * from filings
    {% if source_tier_enabled('B') %}
    union all
    select
        merchant, country, external_units, granularity, source_id,
        source_name, source_url, as_of_period, source_tier
    from {{ ref('ext_google_places') }}
    {% endif %}
    {% if source_tier_enabled('C') %}
    union all
    select
        merchant, country, external_units, granularity, source_id,
        source_name, source_url, as_of_period, source_tier
    from {{ ref('ext_marketplace_poi') }}
    {% endif %}
),

-- Row-level compliance gate: only sources switched on in the registry survive.
registry as (
    select source_id
    from {{ ref('external_source_registry') }}
    where enabled = true
)

select u.*
from unioned u
join registry r on u.source_id = r.source_id
