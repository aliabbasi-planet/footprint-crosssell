{{ config(materialized='table', tags=['external', 'option_a']) }}

-- Option A (ACTIVE): operator / franchisee mapping from public registers and
-- brand disclosures — "who runs this brand in this country, and does Planet
-- already have that relationship?". This is the commercial unlock: it turns a
-- footprint gap into a named counterparty and a warm/cold flag.
select
    merchant,
    {{ normalize_country('country') }}      as country,
    operator_name,
    operator_role,
    planet_existing_relationship,
    evidence,
    'opt_a_registers'                       as source_id,
    source_name,
    source_url,
    as_of_period
from {{ ref('ext_operator_map') }}
