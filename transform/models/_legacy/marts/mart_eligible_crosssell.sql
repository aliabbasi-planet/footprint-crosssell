-- ELIGIBLE CROSS-SELL: products each merchant's business type qualifies for
-- but isn't using, with volume context and TRS country eligibility check.
with gaps as (
    select
        merchant,
        vertical,
        product_family,
        eligibility_rationale
    from {{ ref('int_product_eligibility') }}
    where is_gap = true
),

volume as (
    select merchant, sum(gateway_volume_eur) as annual_gateway_eur
    from {{ ref('int_internal_estate') }}
    group by 1
),

-- For Tax Free gaps, check how many of the merchant's countries are TRS-eligible
trs_context as (
    select
        e.merchant,
        count(distinct e.country)                                     as total_countries,
        count(distinct case when t.trs_eligible = 'TRUE' then e.country end) as trs_eligible_countries
    from {{ ref('int_internal_estate') }} e
    left join {{ ref('country_trs_eligible') }} t
        on upper(e.country) = upper(t.country_code)
        or upper(e.country) = upper(t.country_name)
    group by 1
)

select
    g.merchant,
    g.vertical,
    g.product_family                                                  as missing_product,
    g.eligibility_rationale,
    coalesce(v.annual_gateway_eur, 0)                                 as annual_gateway_eur,
    case
        when g.product_family = 'Tax Free' then tc.trs_eligible_countries
        else null
    end                                                               as trs_eligible_country_count,
    case
        when g.product_family = 'Tax Free' then tc.total_countries
        else null
    end                                                               as total_country_count,
    case
        when coalesce(v.annual_gateway_eur, 0) >= 100000000 then 'HIGH'
        when coalesce(v.annual_gateway_eur, 0) >= 10000000  then 'MEDIUM'
        else 'LOW'
    end                                                               as opportunity_size
from gaps g
left join volume v on g.merchant = v.merchant
left join trs_context tc on g.merchant = tc.merchant
