{#
  Compliance / licence gate for external data sources.

  The `external_source_registry` seed is the system-of-record for *which* source
  tiers are legally cleared and switched on. Option A (A) is active now; the
  licensed/scraped tiers (B Google Places, C Marketplace POI, D/E scraping) are
  parked until Legal + licence sign-off.

  Row-level enablement is enforced in-SQL by joining to the registry. This macro
  gates whole adapter *models* at compile time, driven by the
  `enabled_source_tiers` dbt var, so parked adapters never run (and never incur
  cost or touch external integrations) before approval.

      vars:
        enabled_source_tiers: ['A']        # flip to ['A','B'] when Places is licensed
#}
{% macro source_tier_enabled(tier) -%}
    {%- set tiers = var('enabled_source_tiers', ['A']) -%}
    {{ return(tier in tiers) }}
{%- endmacro %}
