with staging as (
    select * from {{ ref('stg_pos_transactions') }}
),

customers as (
    select * from {{ ref('dim_customer') }}
),

hotels as (
    select * from {{ ref('dim_hotel') }}
),

dates as (
    select * from {{ ref('dim_date') }}
),

products as (
    select * from {{ ref('dim_product') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['s.pos_transaction_id']) }} as pos_transaction_key,
    s.pos_transaction_id,
    coalesce(d.date_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as date_key,
    coalesce(c.customer_key, {{ dbt_utils.generate_surrogate_key(["'GUEST'"]) }}) as customer_key,
    coalesce(h.hotel_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as hotel_key,
    coalesce(p.product_key, {{ dbt_utils.generate_surrogate_key(["'Unknown'"]) }}) as product_key,
    s.staff_id,
    s.quantity,
    s.unit_price,
    s.total_amount,
    s.payment_method,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from staging s
left join dates d
    on s.transaction_date = d.date_day
left join customers c
    on s.customer_id = c.customer_id
left join hotels h
    on s.hotel_name = h.hotel_name
left join products p
    on s.item_name = p.product_name
