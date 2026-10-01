-- FALSE-POSITIVE GUARD (hard fail).
-- No row that survived brand resolution may match an exclude rule that applies
-- to it: its own merchant's kill-list or an all-merchant ('*') rule, within the
-- rule's country scope. This is what stops known bugs returning: "Dolce by
-- Wyndham" -> D&G, "passport" -> SSP, Towne Park valet terminals -> Marriott,
-- "Amoblando Pullman" furniture -> Accor. Uses the same macros as the model.
with resolved as (
    select
        merchant,
        country,
        lower(
            coalesce(raw_brand, '') || ' | '
            || coalesce(customer_name, '') || ' | '
            || coalesce(sf_account_name, '')
        ) as match_text
    from {{ ref('int_brand_resolution') }}
),

exclusions as (
    select
        merchant,
        match_mode,
        lower(pattern)       as pattern,
        upper(country_scope) as country_scope
    from {{ ref('brand_resolution_rules') }}
    where rule_type = 'exclude'
)

select
    'resolved_row_hits_exclude_rule' as failure,
    r.merchant,
    r.country,
    e.pattern,
    r.match_text
from resolved r
join exclusions e
    on (e.merchant = r.merchant or e.merchant = '*')
   and {{ rule_match('r.match_text', 'e.match_mode', 'e.pattern') }}
   and {{ rule_in_scope('r.country', 'e.country_scope') }}
