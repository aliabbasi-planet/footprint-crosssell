-- ============================================================================
-- 00_sandbox_setup.sql  —  one-time PoC schema setup (run as DATA_SCIENTIST)
-- Creates the FOOTPRINT schema in your writable dev sandbox.
-- ============================================================================
USE ROLE DATA_SCIENTIST;
USE WAREHOUSE DATA_SCIENCE;

CREATE SCHEMA IF NOT EXISTS DEV_PRESENTATION_AAB.FOOTPRINT
  COMMENT = 'Cross-sell footprint & share-of-wallet PoC (native Snowflake).';

-- Optional interim staging schema (staging models are views; can also live here).
CREATE SCHEMA IF NOT EXISTS DEV_STAGING_AAB.FOOTPRINT
  COMMENT = 'Interim/staging for the footprint PoC.';

SHOW SCHEMAS LIKE 'FOOTPRINT' IN DATABASE DEV_PRESENTATION_AAB;
