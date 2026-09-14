-- ============================================================================
-- 90_deploy_dbt_project.sql  —  native "dbt Projects on Snowflake" deployment
-- Run AFTER pushing the repo and connecting a git-synced Workspace, OR use the
-- Snowflake CLI equivalent shown in the plan (snow dbt deploy).
-- ============================================================================
USE ROLE DATA_SCIENTIST;
USE WAREHOUSE DATA_SCIENCE;
USE SCHEMA DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT;

-- Option A: from a git-synced Workspace, create the DBT PROJECT object from the
-- transform/ folder, then execute it. (Create the DBT PROJECT in Snowsight UI or
-- via CREATE DBT PROJECT ... FROM @<git_stage>/transform once your repo is linked.)

-- Build everything (seed + run + test + snapshot):
-- EXECUTE DBT PROJECT DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.FOOTPRINT_CROSSSELL
--   ARGS = 'build --target dev';

-- Or step-by-step:
-- EXECUTE DBT PROJECT ... ARGS='deps';
-- EXECUTE DBT PROJECT ... ARGS='seed';
-- EXECUTE DBT PROJECT ... ARGS='run';
-- EXECUTE DBT PROJECT ... ARGS='test';
-- EXECUTE DBT PROJECT ... ARGS='snapshot';

SELECT 'Deploy the DBT PROJECT via git-synced Workspace or snow dbt deploy, then EXECUTE DBT PROJECT.' AS note;
