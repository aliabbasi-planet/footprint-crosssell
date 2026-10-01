-- =============================================================================
-- Data observability for the Option A marts, via Snowflake Data Metric Functions.
-- Deploy AFTER the dbt pipeline has built the marts. Run as a role with:
--   USAGE on the DB/schema, and the privileges to create/attach DMFs
--   (CREATE DATA METRIC FUNCTION on the schema; EXECUTE DATA METRIC FUNCTION on
--    the account or SNOWFLAKE.CORE DMFs). Adjust the schema if not DEV.
-- Results land in SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS.
-- =============================================================================
use schema DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT;

-- Custom DMF: how many rows are missing provenance (should always be 0).
-- This is the anti-fabrication rule enforced continuously at the table level,
-- complementing the dbt test assert_external_has_source.
create or replace data metric function missing_provenance_count(
    arg_t table(source_url varchar)
)
returns number
as
$$
    select count(*) from arg_t where source_url is null or trim(source_url) = ''
$$;

-- Schedule metric evaluation (hourly when the table changes).
alter table mart_country_whitespace     set data_metric_schedule = 'USING CRON 0 * * * * UTC';
alter table mart_operator_opportunities  set data_metric_schedule = 'USING CRON 0 * * * * UTC';
alter table mart_footprint_coverage      set data_metric_schedule = 'USING CRON 0 * * * * UTC';

-- Freshness + volume (built-in system DMFs).
alter table mart_country_whitespace     add data metric function snowflake.core.row_count on ();
alter table mart_operator_opportunities add data metric function snowflake.core.row_count on ();
alter table mart_footprint_coverage     add data metric function snowflake.core.row_count on ();

-- Provenance completeness (custom DMF) on the externally-sourced marts.
alter table mart_country_whitespace     add data metric function missing_provenance_count on (source_url);
alter table mart_operator_opportunities add data metric function missing_provenance_count on (source_url);
alter table mart_footprint_coverage     add data metric function missing_provenance_count on (brand_source_url);

-- Inspect recent results:
--   select * from table(snowflake.local.data_quality_monitoring_results(
--     ref_entity_name => 'DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT.MART_COUNTRY_WHITESPACE',
--     ref_entity_domain => 'TABLE'))
--   order by measurement_time desc;
