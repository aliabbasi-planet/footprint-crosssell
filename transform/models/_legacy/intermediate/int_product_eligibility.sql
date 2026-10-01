-- For each merchant, determine which products they're eligible for (by vertical)
-- versus which they actually use. The difference = eligible cross-sell opportunity.
with presence as (
    select distinct merchant, product_family
    from {{ ref('int_product_presence') }}
),

merchants as (
    select distinct poc_merchant as merchant, poc_vertical as vertical
    from {{ ref('stg_ccl_customer') }}
),

eligible as (
    select
        m.merchant,
        m.vertical,
        pe.product_family,
        pe.is_eligible,
        pe.rationale                                       as eligibility_rationale
    from merchants m
    join {{ ref('product_eligibility') }} pe
        on m.vertical = pe.vertical
    where pe.is_eligible = 'TRUE'
),

gaps as (
    select
        e.merchant,
        e.vertical,
        e.product_family,
        e.eligibility_rationale,
        case when p.product_family is not null then true else false end as currently_uses,
        case when p.product_family is null    then true else false end as is_gap
    from eligible e
    left join presence p
        on e.merchant = p.merchant and e.product_family = p.product_family
)

select * from gaps
