{{
  config(
    materialized='table',
    tags=['external']
  )
}}

-- Scrape store-finder APIs/pages for each PoC merchant using the Python UDTF.
-- Brands marked CORTEX_INTEL get a marker row; they're handled in ext_cortex_intelligence.
select
    s.brand_name,
    s.country,
    s.city,
    s.address,
    s.store_name,
    s.latitude,
    s.longitude,
    s.source_url,
    s.raw_content,
    sf.scrape_method,
    current_timestamp()                  as scraped_at
from {{ ref('poc_merchant_store_finders') }} sf,
table(DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.SCRAPE_STORE_LOCATOR(
    sf.merchant, coalesce(sf.api_endpoint, sf.store_finder_url), sf.scrape_method
)) s
