{% snapshot opportunities_snapshot %}
{{
    config(
      unique_key="merchant || '-' || opportunity_type",
      strategy="check",
      check_cols=['priority_score', 'confidence_band', 'products_used', 'has_open_sf_opportunity']
    )
}}
select
    merchant,
    opportunity_type,
    priority_score,
    confidence_band,
    products_used,
    has_open_sf_opportunity,
    current_timestamp() as captured_at
from {{ ref('mart_crosssell_opportunities') }}
{% endsnapshot %}
