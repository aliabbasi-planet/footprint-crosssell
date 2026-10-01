{#
  True when a lower-cased text matches one brand-resolution rule.
    ilike  : SQL LIKE with % wildcards (pattern already lower-cased)
    word   : whole word, so 'ssp' does not hit 'passport'
    prefix : word-start only, so 'ibis' keeps 'ibis budget' / 'ibisbudget' but
             drops 'hibiscus', and 'aloft' drops 'kasaloft'
    leading: a field (brand / customer name / account) must START with the
             token, so 'courtyard' keeps 'Courtyard Miami' but drops
             'Arabian Courtyard Hotel'. Fields are joined with ' | ' upstream.
  word / prefix / leading patterns are embedded in a regex: keep them to
  letters, digits and spaces. A plain substring LIKE runs first as a cheap
  pre-filter so the regex only evaluates on candidate rows.
  Shared by int_brand_resolution and the assert_no_excluded_brands test so the
  model and its guard can never drift apart.
#}
{% macro rule_match(field, mode='r.match_mode', pattern='r.pattern') -%}
(
    ({{ mode }} = 'ilike' and {{ field }} like {{ pattern }})
    or ({{ mode }} = 'word'
        and {{ field }} like '%' || {{ pattern }} || '%'
        and regexp_instr({{ field }}, '(^|[^a-z0-9])' || {{ pattern }} || '([^a-z0-9]|$)') > 0)
    or ({{ mode }} = 'prefix'
        and {{ field }} like '%' || {{ pattern }} || '%'
        and regexp_instr({{ field }}, '(^|[^a-z0-9])' || {{ pattern }}) > 0)
    or ({{ mode }} = 'leading'
        and {{ field }} like '%' || {{ pattern }} || '%'
        and regexp_instr({{ field }}, '(^|[|] )' || {{ pattern }}) > 0)
)
{%- endmacro %}

{#
  True when a rule applies in this (canonical) country. country_scope is NULL
  for global rules, else a pipe-delimited list, e.g. 'NORWAY|SWEDEN|DENMARK'.
#}
{% macro rule_in_scope(country, scope='r.country_scope') -%}
(
    {{ scope }} is null
    or position('|' || {{ country }} || '|' in '|' || {{ scope }} || '|') > 0
)
{%- endmacro %}
