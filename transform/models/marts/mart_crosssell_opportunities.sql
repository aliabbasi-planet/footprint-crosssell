-- Rule-based cross-sell opportunities per merchant, scored and suppression-aware.
with sow as (
    select * from {{ ref('mart_share_of_wallet') }}
),

volume as (
    select merchant, vertical, sum(gateway_volume_eur) as annual_volume_eur
    from {{ ref('int_internal_estate') }}
    group by 1, 2
),

open_opp as (
    select distinct bc.merchant
    from {{ ref('int_brand_canonical') }} bc
    join {{ ref('stg_sf_opportunity') }} o on bc.sf_account_id = o.sf_account_id
),

opportunities as (
    -- Acquiring gap: on the gateway but not acquiring
    select
        sow.merchant, 'ACQUIRING_GAP' as opportunity_type,
        'Has Planet gateway but no acquiring relationship' as rationale
    from sow where sow.has_gateway and not sow.has_acquiring

    union all
    -- Tax Free gap
    select sow.merchant, 'TAXFREE_GAP',
        'No Tax Free issuance despite an eligible retail/hospitality footprint'
    from sow where not sow.has_tax_free

    union all
    -- DCC leakage: eligible volume not converting
    select sow.merchant, 'DCC_LEAKAGE',
        'DCC-eligible volume is under-converting (<50% penetration)'
    from sow where sow.dcc_eligible_eur > 0 and coalesce(sow.dcc_penetration_pct, 0) < 50

    union all
    -- PMS gap for hospitality
    select sow.merchant, 'PMS_GAP',
        'Hospitality merchant without Planet PMS/hospitality software'
    from sow
    join volume v on sow.merchant = v.merchant
    where v.vertical = 'Hospitality' and not sow.has_pms
)

select
    o.merchant,
    v.vertical,
    o.opportunity_type,
    o.rationale,
    v.annual_volume_eur,
    sow.products_used,
    sow.portfolio_coverage,
    sow.total_revenue,
    sow.dcc_penetration_pct,
    (o.merchant in (select merchant from open_opp))          as has_open_sf_opportunity,
    -- Priority: annual volume weighted by how few products they currently hold.
    round(
        ln(greatest(v.annual_volume_eur, 1)) * (1 + ({{ 4 }} - sow.products_used)), 1
    )                                                        as priority_score,
    case
        when v.annual_volume_eur >= 1000000 then 'HIGH'
        when v.annual_volume_eur >= 100000  then 'MEDIUM'
        else 'LOW'
    end                                                     as confidence_band
from opportunities o
join volume v on o.merchant = v.merchant
join sow on o.merchant = sow.merchant
order by priority_score desc
