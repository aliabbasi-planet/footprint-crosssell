-- ============================================================================
-- 01_external_access_setup.sql
-- ONE-TIME setup by ACCOUNTADMIN to enable native web scraping for the
-- Footprint Intelligence PoC. Give this file to your admin.
-- After running, DATA_SCIENTIST can create Python UDFs that reach the internet.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- 1. Network rule: allow outbound HTTPS to brand store-finder domains
--    and the Google Places API for location enrichment.
CREATE OR REPLACE NETWORK RULE DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.CROSSSELL_EGRESS_RULE
  MODE   = EGRESS
  TYPE   = HOST_PORT
  VALUE_LIST = (
    -- F&B store finders
    'www.starbucks.com',
    'www.starbucks.co.uk',
    'use1-prod-sb.starbucks.com',         -- Starbucks store-locator API
    'www.bk.com',
    'czqk28jt.apicdn.sanity.io',          -- BK store-locator API (Sanity CMS)
    'www.foodtravelexperts.com',           -- SSP
    -- Hospitality
    'all.accor.com',
    'api.accor.com',
    'www.marriott.com',
    'www.fourseasons.com',
    -- Retail
    'www.dolcegabbana.com',
    'store.dolcegabbana.com',
    'www.subdued.com',
    'www.luxottica.com',
    'www.sunglasshut.com',
    'www.ray-ban.com',
    -- Google Places API (location enrichment / discovery fallback)
    'maps.googleapis.com',
    'places.googleapis.com'
  )
  COMMENT = 'Outbound HTTPS for Cross-Sell Footprint PoC store-finder scraping.';

-- 2. (Optional) Secret for Google Maps / Places API key.
--    Replace the placeholder with your actual key, or skip if not using Google.
-- CREATE OR REPLACE SECRET DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.GOOGLE_MAPS_API_KEY
--   TYPE          = GENERIC_STRING
--   SECRET_STRING = '<YOUR_GOOGLE_MAPS_API_KEY>'
--   COMMENT       = 'Google Places API key for location discovery fallback.';

-- 3. External Access Integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION CROSSSELL_WEB_ACCESS
  ALLOWED_NETWORK_RULES       = (DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.CROSSSELL_EGRESS_RULE)
  -- ALLOWED_AUTHENTICATION_SECRETS = (DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.GOOGLE_MAPS_API_KEY)
  ENABLED = TRUE
  COMMENT = 'Enables Python UDFs in the Cross-Sell PoC to fetch brand store-finder pages.';

-- 4. Grant USAGE to DATA_SCIENTIST so the PoC developer can create UDFs that use it.
GRANT USAGE ON INTEGRATION CROSSSELL_WEB_ACCESS TO ROLE DATA_SCIENTIST;

-- 5. Verify
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'CROSSSELL_WEB_ACCESS';
SELECT 'External Access Integration created and granted. DATA_SCIENTIST can now create scraping UDFs.' AS status;
