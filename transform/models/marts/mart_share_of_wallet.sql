-- Share-of-wallet across Planet's product portfolio, per merchant.
-- "Wallet" = the catalogue of product families Planet can sell. Coverage = how many
-- of them the merchant actually buys. Also carries DCC penetration (within-product leakage).
{% set catalogue_size = 4 %}  {# Gateway, Acquiring, Tax Free, PMS #}

with presence as (
    select
        merchant,
        count(distinct product_family)                                  as products_used,
        listagg(distinct product_family, ', ') within group (order by product_family) as products_list,
        boolor_agg(product_family = 'Gateway')                          as has_gateway,
        boolor_agg(product_family = 'Acquiring')                        as has_acquiring,
        boolor_agg(product_family = 'Tax Free')                         as has_tax_free,
        boolor_agg(product_family = 'PMS')                              as has_pms
    from {{ ref('int_product_presence') }}
    group by 1
),

revenue as (
    select
        c.poc_merchant                      as merchant,
        sum(r.total_revenue)                as total_revenue,
        count(distinct r.product)           as revenue_products
    from {{ ref('stg_ccl_revenue') }} r
    join (select distinct raw_brand, poc_merchant from {{ ref('stg_ccl_customer') }}) c
        on r.brand = c.raw_brand
    group by 1
),

dcc as (
    select
        merchant,
        sum(dcc_eligible_eur)   as dcc_eligible_eur,
        sum(dcc_converted_eur)  as dcc_converted_eur
    from {{ ref('int_internal_estate') }}
    group by 1
)

select
    p.merchant,
    p.products_used,
    {{ catalogue_size }}                                                as products_available,
    round(p.products_used / {{ catalogue_size }}, 2)                    as portfolio_coverage,
    p.products_list,
    p.has_gateway,
    p.has_acquiring,
    p.has_tax_free,
    p.has_pms,
    coalesce(r.total_revenue, 0)                                       as total_revenue,
    coalesce(d.dcc_eligible_eur, 0)                                    as dcc_eligible_eur,
    coalesce(d.dcc_converted_eur, 0)                                   as dcc_converted_eur,
    round(
        div0(coalesce(d.dcc_converted_eur, 0), nullif(d.dcc_eligible_eur, 0)) * 100, 1
    )                                                                  as dcc_penetration_pct
from presence p
left join revenue r on p.merchant = r.merchant
left join dcc d on p.merchant = d.merchant
