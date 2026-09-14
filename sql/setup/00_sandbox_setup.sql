-- ============================================================================
-- 00_sandbox_setup.sql  —  one-time PoC schema setup (run as DATA_SCIENTIST)
-- Creates the CROSSSELL_FOOTPRINT schema in your writable dev sandbox.
-- All output tables, semantic views, agents, stages, etc. land here.
-- ============================================================================
USE ROLE DATA_SCIENTIST;
USE WAREHOUSE DATA_SCIENCE;

CREATE SCHEMA IF NOT EXISTS DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT
  COMMENT = 'Cross-sell footprint & share-of-wallet PoC — all output objects live here (tables, semantic views, agents, stages).';

-- Internal stages for dbt seeds, artifacts, and any file-based assets.
CREATE STAGE IF NOT EXISTS DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.STG_SEEDS
  COMMENT = 'dbt seed CSVs and lookup files.';

CREATE STAGE IF NOT EXISTS DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.STG_ARTIFACTS
  COMMENT = 'Model cards, run logs, exported reports.';

CREATE STAGE IF NOT EXISTS DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.STG_EXTERNAL_EVIDENCE
  COMMENT = 'Future: external evidence files (Phase 2+). Empty for the internal PoC.';

SHOW SCHEMAS LIKE 'CROSSSELL_FOOTPRINT' IN DATABASE DEV_PRESENTATION_AAB;
