-- CCL bridge, restricted to the 9 PoC merchants via the seed patterns.
with ccl as (
    select
        sf_account_id,
        sf_account_name,
        brand              as raw_brand,
        brand_id,
        data_source,
        uid,
        country,
        city,
        store,
        address            as ccl_address,
        sf_vertical,
        sf_new_vertical,
        sf_opportunity_id,
        dccprovider
    from {{ source('datamart', 'dim_ccl_customer') }}
    where brand is not null
),

targets as (
    select vertical, merchant, match_pattern
    from {{ ref('poc_target_merchants') }}
),

tagged as (
    select
        ccl.*,
        t.merchant  as poc_merchant,
        t.vertical  as poc_vertical
    from ccl
    join targets t
        on ccl.raw_brand ilike t.match_pattern
)

select * from tagged
