with source as (
    select * from {{ ref('stg_marketing_performance') }}
),

campaigns as (
    select distinct
        campaign_name
    from source
)

select
    {{ dbt_utils.generate_surrogate_key(['campaign_name']) }} as campaign_key,
    campaign_name,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from campaigns
