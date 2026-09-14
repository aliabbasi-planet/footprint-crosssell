-- ============================================================================
-- 91_schedule_task.sql  —  weekly refresh of the PoC via a Snowflake Task
-- Runs the native dbt project on a schedule. Adjust CRON as needed.
-- ============================================================================
USE ROLE DATA_SCIENTIST;
USE SCHEMA DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT;

CREATE OR REPLACE TASK DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.TASK_FOOTPRINT_WEEKLY
  WAREHOUSE = DATA_SCIENCE
  SCHEDULE  = 'USING CRON 0 6 * * MON Europe/London'
  COMMENT   = 'Weekly rebuild of the footprint cross-sell PoC marts.'
AS
  EXECUTE DBT PROJECT DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.FOOTPRINT_CROSSSELL
    ARGS = 'build --target dev';

-- Tasks are created suspended; resume when ready:
-- ALTER TASK DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.TASK_FOOTPRINT_WEEKLY RESUME;
