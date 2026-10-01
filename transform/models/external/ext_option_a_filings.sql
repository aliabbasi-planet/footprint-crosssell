{{ config(materialized='table', tags=['external', 'option_a']) }}

-- Option A (ACTIVE): brand-published / regulatory-filing footprint counts.
-- Source rows are version-controlled in the ext_country_units seed; every row
-- carries source_url + as_of_period + source_tier (A/B) and is PR-reviewed.
-- No scraping, no paid API, no model free-recall.
select
    merchant,
    {{ normalize_country('country') }}  as country,
    external_units,
    granularity,
    'opt_a_directories'                 as source_id,
    source_name,
    source_url,
    as_of_period,
    source_tier
from {{ ref('ext_country_units') }}
where external_units is not null
