{{
  config(
    materialized='table',
    tags=['external']
  )
}}

-- For brands where API scraping returned nothing usable (CORTEX_INTEL method,
-- or raw HTML that needs parsing), use Cortex AI_COMPLETE to discover locations.
--
-- Two modes:
-- 1. CORTEX_INTEL: ask the model for known locations from its training data.
-- 2. HTML parsing: give the model the scraped HTML and ask it to extract locations.

with needs_cortex as (
    select distinct brand_name, raw_content, scrape_method
    from {{ ref('ext_scraped_locations') }}
    where raw_content like 'CORTEX_INTEL_REQUIRED:%'
       or (country is null and raw_content is not null and raw_content not like 'ERROR:%')
),

-- Mode 1: model-based intelligence (no HTML, just ask)
intel_brands as (
    select brand_name
    from needs_cortex
    where raw_content like 'CORTEX_INTEL_REQUIRED:%'
),

cortex_intel as (
    select
        brand_name,
        snowflake.cortex.complete(
            'claude-4-sonnet',
            'You are a location intelligence analyst. List ALL known physical store/hotel/restaurant locations '
            || 'for the brand "' || brand_name || '" worldwide. '
            || 'Return ONLY a JSON array where each element has: '
            || '{"country":"XX","city":"CityName","address":"street address if known","store_name":"name"}. '
            || 'Include at least 50 locations if the brand has that many. Return valid JSON only, no explanation.'
        ) as cortex_response,
        'CORTEX_INTEL' as source_tier
    from intel_brands
),

-- Mode 2: HTML extraction (give Cortex the raw HTML and ask it to extract)
html_brands as (
    select brand_name, raw_content
    from needs_cortex
    where raw_content not like 'CORTEX_INTEL_REQUIRED:%'
      and raw_content not like 'ERROR:%'
),

cortex_html as (
    select
        brand_name,
        snowflake.cortex.complete(
            'claude-4-sonnet',
            'Extract all store/hotel/restaurant locations from this web page content for "'
            || brand_name || '". '
            || 'Return ONLY a JSON array: [{"country":"XX","city":"CityName","address":"...","store_name":"..."}]. '
            || 'If no locations found, return []. Content (truncated): '
            || left(raw_content, 30000)
        ) as cortex_response,
        'CORTEX_HTML_EXTRACT' as source_tier
    from html_brands
),

combined as (
    select * from cortex_intel
    union all
    select * from cortex_html
)

-- Parse the JSON response into rows
select
    c.brand_name,
    f.value:country::string                         as country,
    f.value:city::string                            as city,
    f.value:address::string                         as address,
    f.value:store_name::string                      as store_name,
    c.source_tier,
    current_timestamp()                             as discovered_at
from combined c,
lateral flatten(input => try_parse_json(c.cortex_response)) f
where f.value:country is not null
