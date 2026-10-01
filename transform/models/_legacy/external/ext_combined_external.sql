{{
  config(
    materialized='table',
    tags=['external']
  )
}}

-- Unified external footprint: API-scraped locations + Cortex-discovered locations.
-- Each row carries a source_tier: API (highest confidence) > CORTEX_HTML_EXTRACT > CORTEX_INTEL.

-- Tier A: successfully scraped via API (have country + city)
select
    brand_name                     as merchant,
    country,
    city,
    address,
    store_name,
    latitude,
    longitude,
    source_url,
    'API'                          as source_tier,
    scraped_at                     as discovered_at
from {{ ref('ext_scraped_locations') }}
where country is not null and raw_content is null

union all

-- Tier B/C: Cortex-discovered locations
select
    brand_name                     as merchant,
    country,
    city,
    address,
    store_name,
    null                           as latitude,
    null                           as longitude,
    null                           as source_url,
    source_tier,
    discovered_at
from {{ ref('ext_cortex_intelligence') }}
