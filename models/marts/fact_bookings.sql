with staging as (
    select * from {{ ref('stg_bookings') }}
),

customers as (
    select * from {{ ref('dim_customer') }}
),

hotels as (
    select * from {{ ref('dim_hotel') }}
),

dates as (
    select * from {{ ref('dim_date') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['s.booking_id']) }} as booking_key,
    s.booking_id,
    coalesce(c.customer_key, {{ dbt_utils.generate_surrogate_key(["'GUEST'"]) }}) as customer_key,
    coalesce(h.hotel_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as hotel_key,
    d_in.date_key as check_in_date_key,
    d_out.date_key as check_out_date_key,
    d_create.date_key as booking_created_date_key,
    s.room_type,
    s.nights,
    s.booking_status,
    s.channel,
    s.booking_source,
    s.rate_per_night,
    s.currency,
    s.discount_pct,
    s.is_loyalty_member,
    s.gross_revenue_idr,
    s.net_revenue_idr,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from staging s
left join customers c
    on s.customer_id = c.customer_id
left join hotels h
    on s.hotel_name = h.hotel_name
left join dates d_in
    on s.check_in_date = d_in.date_day
left join dates d_out
    on s.check_out_date = d_out.date_day
left join dates d_create
    on s.booking_created_at = d_create.date_day
