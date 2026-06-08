with source as (
    select * from {{ source('raw_data', 'raw_bookings') }}
),

formatted as (
    select
        trim(BookingID) as booking_id,
        trim(hotel_name) as hotel_name,
        nullif(initcap(trim(RoomType)), '') as room_type,
        trim(customer_id) as customer_id,
        nullif(trim(CustomerName), '') as customer_name,
        lower(replace(trim(customer_email), ' ', '')) as customer_email,
        safe_cast(CheckInDate as date) as check_in_date,
        safe_cast(check_out_date as date) as check_out_date_raw,
        safe_cast(nights as int64) as nights,
        
        case
            when lower(trim(booking_status)) in ('confirmed', 'confirm') then 'Confirmed'
            when lower(trim(booking_status)) in ('checkedin', 'checked_in', 'checked in', 'checked-in') then 'Checked In'
            when lower(trim(booking_status)) in ('checkedout', 'checked_out', 'checked out', 'completed') then 'Checked Out'
            when lower(trim(booking_status)) in ('canceled', 'cancelled', 'cancel', 'cnx') then 'Cancelled'
            when lower(trim(booking_status)) in ('no_show', 'no show', 'noshow', 'no-show') then 'No Show'
            else 'Unknown'
        end as booking_status,
        
        nullif(initcap(trim(channel)), '') as channel,
        nullif(initcap(trim(BookingSource)), '') as booking_source,
        safe_cast(RatePerNight as numeric) as rate_per_night,
        upper(trim(Currency)) as currency,
        safe_cast(TotalRevenue_IDR as numeric) as total_revenue_idr_raw,
        safe_cast(discount_pct as numeric) as discount_pct,
        
        case
            when lower(trim(is_loyalty_member)) in ('1', 'yes', 'true') then true
            when lower(trim(is_loyalty_member)) in ('0', 'no', 'false') then false
            else false
        end as is_loyalty_member,
        
        safe_cast(created_at as date) as booking_created_at
    from source
),

cleansed_dates as (
    select
        *,
        case
            when check_out_date_raw < check_in_date then date_add(check_in_date, interval nights day)
            else check_out_date_raw
        end as check_out_date
    from formatted
),

currency_calculated as (
    select
        *,
        case
            when currency = 'USD' then 15800.0
            when currency = 'SGD' then 11700.0
            when currency = 'AUD' then 10200.0
            else 1.0
        end as exchange_rate
    from cleansed_dates
)

select
    booking_id,
    hotel_name,
    room_type,
    customer_id,
    customer_name,
    customer_email,
    check_in_date,
    check_out_date,
    nights,
    booking_status,
    channel,
    booking_source,
    rate_per_night,
    currency,
    discount_pct,
    is_loyalty_member,
    booking_created_at,
    coalesce(
        total_revenue_idr_raw,
        rate_per_night * nights * exchange_rate
    ) as gross_revenue_idr,
    coalesce(
        total_revenue_idr_raw,
        rate_per_night * nights * exchange_rate
    ) * (1.0 - coalesce(discount_pct, 0.0)) as net_revenue_idr
from currency_calculated
