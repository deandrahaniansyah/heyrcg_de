with staging as (
    select * from {{ ref('stg_marketing_performance') }}
),

campaigns as (
    select * from {{ ref('dim_campaign') }}
),

hotels as (
    select * from {{ ref('dim_hotel') }}
),

dates as (
    select * from {{ ref('dim_date') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['s.row_id']) }} as marketing_key,
    s.row_id,
    coalesce(c.campaign_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as campaign_key,
    coalesce(h.hotel_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as hotel_key,
    coalesce(d.date_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as date_key,
    s.platform,
    s.impressions,
    s.clicks,
    s.spend_idr,
    s.conversions,
    s.bookings_generated,
    s.revenue_generated_idr,
    s.ad_creative_id,
    s.target_audience,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from staging s
left join campaigns c
    on s.campaign_name = c.campaign_name
left join hotels h
    on s.hotel_name = h.hotel_name
left join dates d
    on s.campaign_date = d.date_day
