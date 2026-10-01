-- Open Salesforce opportunities, used to suppress gaps already in a sales motion.
select
    account_id      as sf_account_id,
    opportunity_id,
    stage_name,
    is_closed,
    is_won
from {{ source('curated', 'curated_salesforce_opportunity') }}
where coalesce(is_closed, false) = false
