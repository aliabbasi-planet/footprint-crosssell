{#
  Strip the leading single-quote that the CCL UID carries for the MAS source,
  so it matches FACT_MAS_TRANSACTION.MERCHANT_ID. Verified pattern from spec.
#}
{% macro strip_uid(col) -%}
    replace({{ col }}, '''', '')
{%- endmacro %}

{#
  Strip the '-TRS' suffix from Tax Free store UIDs so they match the CCL UID.
#}
{% macro strip_trs_suffix(col) -%}
    replace({{ col }}, '-TRS', '')
{%- endmacro %}
