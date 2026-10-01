-- =============================================================================
-- OPTIONAL: Semantic view over the Option A marts, enabling Cortex Analyst /
-- Cortex Agent natural-language questions ("which warm operators have the
-- biggest un-served gap for Starbucks?"). Deploy AFTER the dbt marts are built.
--
-- This is the SQL-first path. For the dbt-native path, add the dbt_semantic_view
-- package and author a `semantic_view` materialization (see the
-- dbt-projects-on-snowflake skill). Validate in your environment before use.
-- =============================================================================
use schema DEV_PRESENTATION_AAB.CROSSSELL_FOOTPRINT;

create or replace semantic view footprint_crosssell_sv
  tables (
    coverage as mart_footprint_coverage
      primary key (merchant)
      with synonyms = ('portfolio coverage', 'brand coverage')
      comment = 'One row per merchant: Planet coverage vs brand published footprint.',
    whitespace as mart_country_whitespace
      primary key (merchant, country)
      with synonyms = ('white space', 'footprint gaps', 'unserved countries')
      comment = 'Per merchant x country un-served units, valued with Planet economics.',
    operators as mart_operator_opportunities
      primary key (merchant, country, operator_name)
      with synonyms = ('operators', 'who to call', 'franchisees')
      comment = 'Operator per country with existing-relationship flag and value.'
  )
  relationships (
    whitespace_to_coverage as whitespace (merchant) references coverage,
    operators_to_whitespace as operators (merchant, country) references whitespace
  )
  facts (
    coverage.planet_stores as planet_stores,
    coverage.brand_total_units as brand_total_units,
    coverage.country_whitespace_count as country_whitespace_count,
    whitespace.external_units as external_units,
    whitespace.internal_stores as internal_stores,
    whitespace.gap_units as gap_units,
    whitespace.value_full_eur as value_full_eur,
    whitespace.value_25pct_eur as value_25pct_eur,
    operators.gap_units as op_gap_units,
    operators.est_gap_value_25pct_eur as op_value_25
  )
  dimensions (
    coverage.merchant as merchant with synonyms = ('brand') comment = 'Merchant / brand name.',
    coverage.vertical as vertical with synonyms = ('sector') comment = 'F&B / Hospitality / Retail.',
    coverage.operating_model as operating_model,
    whitespace.country as country,
    whitespace.region as region,
    whitespace.is_whitespace as is_whitespace comment = 'True when Planet serves 0 locations in that country.',
    whitespace.source_tier as source_tier,
    operators.operator_name as operator_name,
    operators.operator_role as operator_role,
    operators.opportunity_type as opportunity_type,
    operators.planet_existing_relationship as planet_existing_relationship
      with synonyms = ('warm', 'existing relationship')
  )
  metrics (
    coverage.total_planet_stores as sum(coverage.planet_stores)
      comment = 'Total locations Planet serves.',
    whitespace.total_gap_units as sum(whitespace.gap_units)
      comment = 'Total un-served units across countries.',
    whitespace.total_value_25 as sum(whitespace.value_25pct_eur)
      comment = 'White-space value at 25% capture (EUR).',
    whitespace.total_value_full as sum(whitespace.value_full_eur)
      comment = 'White-space value at 100% capture (EUR).',
    operators.warm_value_25 as sum(operators.est_gap_value_25pct_eur)
      comment = 'Estimated value at 25% capture across operator opportunities.'
  )
  comment = 'Footprint Cross-Sell (Option A): coverage, valued white-space, operator opportunities.';

-- Smoke test once built:
--   select * from semantic_view(
--     footprint_crosssell_sv
--     metrics whitespace.total_value_25
--     dimensions coverage.merchant
--   ) order by 2 desc;
