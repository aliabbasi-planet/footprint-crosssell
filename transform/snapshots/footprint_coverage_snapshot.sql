{% snapshot footprint_coverage_snapshot %}
{{
    config(
        unique_key="merchant",
        strategy="check",
        check_cols=[
            'planet_stores', 'planet_countries', 'store_coverage_pct',
            'country_coverage_pct', 'country_whitespace_count'
        ]
    )
}}
-- SCD2 history of portfolio coverage. Each dbt snapshot run records how a
-- merchant's served stores/countries and coverage ratios move over time, so the
-- team can see whether footprint gaps are closing between refreshes.
select
    merchant,
    vertical,
    planet_stores,
    planet_countries,
    brand_total_units,
    brand_total_countries,
    store_coverage_pct,
    country_coverage_pct,
    country_whitespace_count,
    current_timestamp() as captured_at
from {{ ref('mart_footprint_coverage') }}
{% endsnapshot %}
