-- Product presence per merchant, mapping raw DATA_SOURCE values into Planet product families.
with ccl as (
    select poc_merchant as merchant, data_source, uid, country
    from {{ ref('stg_ccl_customer') }}
),

mapped as (
    select
        merchant,
        case
            when data_source = '3C'                                       then 'Gateway'
            when data_source in ('Qlik/MAS')                              then 'Acquiring'
            when data_source in ('TRS', 'AX', 'PTF')                      then 'Tax Free'
            when data_source in ('Odoo', 'Odoo_Historical', 'Eclipse')    then 'PMS'
            when data_source in ('Datatrans', 'Proximis', 'PCI Proxy')    then 'Gateway'
            else 'Other'
        end                                     as product_family,
        uid,
        country
    from ccl
)

select
    merchant,
    product_family,
    count(distinct uid)      as location_count,
    count(distinct country)  as country_count
from mapped
where product_family <> 'Other'
group by 1, 2
