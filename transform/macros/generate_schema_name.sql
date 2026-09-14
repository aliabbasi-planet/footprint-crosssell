{#
  Keep dbt from prefixing the target schema. We always build into a single
  FOOTPRINT schema per environment (schema is set by the profile/dbt_project).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
