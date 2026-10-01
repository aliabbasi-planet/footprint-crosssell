-- Salesforce account URLs for PoC merchants — supplementary external signal.
select distinct
    ccl.poc_merchant                     as merchant,
    sf.account_id                        as sf_account_id,
    sf.website,
    sf.trac_rtc_website_domain_c         as domain,
    sf.website_origin_pc                 as website_origin
from {{ ref('stg_ccl_customer') }} ccl
join {{ source('curated', 'curated_salesforce_account') }} sf
    on ccl.sf_account_id = sf.account_id
where coalesce(sf.website, sf.trac_rtc_website_domain_c, sf.website_origin_pc) is not null
