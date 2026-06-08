with unioned as (
    select hotel_name from {{ ref('stg_bookings') }} where hotel_name is not null
    union distinct
    select hotel_name from {{ ref('stg_pos_transactions') }} where hotel_name is not null and hotel_name != 'Unknown'
    union distinct
    select hotel_name from {{ ref('stg_marketing_performance') }} where hotel_name is not null
),

final as (
    select distinct
        hotel_name
    from unioned
)

select
    {{ dbt_utils.generate_surrogate_key(['hotel_name']) }} as hotel_key,
    hotel_name,
    'Bali' as location,
    'Indonesia' as country,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from final
