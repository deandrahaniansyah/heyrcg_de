with source as (
    select * from {{ source('raw_data', 'raw_marketing_performance') }}
)

select
    safe_cast(row_id as int64) as row_id,
    upper(trim(campaign_name)) as campaign_name,
    nullif(initcap(trim(Platform)), '') as platform,
    trim(hotel) as hotel_name,
    safe_cast(Date as date) as campaign_date,
    safe_cast(impressions as int64) as impressions,
    safe_cast(Clicks as int64) as clicks,
    coalesce(safe_cast(spend_idr as numeric), 0.0) as spend_idr,
    safe_cast(conversions as int64) as conversions,
    safe_cast(bookings_generated as int64) as bookings_generated,
    safe_cast(Revenue_Generated_IDR as numeric) as revenue_generated_idr,
    nullif(trim(ad_creative_id), '') as ad_creative_id,
    nullif(initcap(trim(target_audience)), '') as target_audience
from source
