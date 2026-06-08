with source as (
    select * from {{ source('raw_data', 'raw_pos_transactions') }}
),

deduped as (
    select
        *,
        row_number() over (
            partition by pos_transaction_id 
            order by transaction_date desc
        ) as rn
    from source
),

filtered as (
    select * from deduped where rn = 1
),

cleaned_fields as (
    select
        trim(pos_transaction_id) as pos_transaction_id,
        trim(outlet_name) as outlet_name,
        trim(hotel_name) as hotel_name_raw,
        trim(transaction_date) as transaction_date_raw,
        trim(customer_id) as customer_id,
        
        case
            when lower(trim(item_name)) in ('nasi goreng spesial', 'nasi_goreng', 'nasi goreng') then 'Nasi Goreng'
            when lower(trim(item_name)) in ('coctail', 'cocktail') then 'Cocktail'
            when lower(trim(item_name)) in ('coffee', 'coffee (hot)', 'kopi') then 'Coffee'
            else initcap(trim(item_name))
        end as item_name,
        
        trim(category) as category_raw,
        safe_cast(quantity as int64) as quantity,
        safe_cast(unit_price as numeric) as unit_price_raw,
        
        safe_cast(
            trim(
                replace(
                    replace(total_amount, 'IDR', ''),
                    ',', ''
                )
            ) as numeric
        ) as total_amount_raw,
        
        case
            when lower(trim(payment_method)) = 'cash' then 'Cash'
            when lower(trim(payment_method)) in ('credit card', 'cc') then 'Credit Card'
            when lower(trim(payment_method)) = 'dana' then 'Dana'
            when lower(trim(payment_method)) = 'gopay' then 'GoPay'
            when lower(trim(payment_method)) = 'ovo' then 'OVO'
            else coalesce(initcap(trim(payment_method)), 'Unknown')
        end as payment_method,
        
        trim(staff_id) as staff_id
    from filtered
),

hotel_mapped as (
    select
        *,
        case
            when outlet_name in ('The Layar - Pool Bar', 'The Layar - Main Bar', 'The Layar - Restaurant') then 'The Layar Seminyak'
            when outlet_name in ('Katamama Dining', 'Katamama Lobby Bar') then 'Katamama Resort'
            when outlet_name in ('Alaya Cafe', 'Alaya Sky Bar') then 'Alaya Ubud'
            when outlet_name in ('Bisma Restaurant', 'Bisma Rooftop') then 'Bisma Eight'
            when outlet_name in ('Mulia Gelato', 'Mulia Soleil', 'Mulia Lounge') then 'The Mulia Nusa Dua'
            when outlet_name in ('Komaneka Kitchen', 'Komaneka Tea Lounge') then 'Komaneka Bisma'
            else coalesce(nullif(hotel_name_raw, ''), 'Unknown')
        end as hotel_name,
        
        case
            when regexp_contains(transaction_date_raw, r'^\d{4}-\d{2}-\d{2}$') then safe_cast(transaction_date_raw as date)
            when regexp_contains(transaction_date_raw, r'^\d{8}$') then safe.parse_date('%Y%m%d', transaction_date_raw)
            when regexp_contains(transaction_date_raw, r'^\d{2} [A-Za-z]{3} \d{4}$') then safe.parse_date('%d %b %Y', transaction_date_raw)
            when regexp_contains(transaction_date_raw, r'^\d{2}/\d{2}/\d{4}$') then safe.parse_date('%d/%m/%Y', transaction_date_raw)
            when regexp_contains(transaction_date_raw, r'^\d{2}-\d{2}-\d{4}$') then safe.parse_date('%m-%d-%Y', transaction_date_raw)
            else null
        end as transaction_date
    from cleaned_fields
),

category_mapped as (
    select
        *,
        case
            when item_name in ('Club Sandwich', 'Beef Burger', 'Caesar Salad', 'Pasta Carbonara', 'Nasi Goreng') then 'Food'
            when item_name in ('Smoothie', 'Fresh Juice', 'Cocktail', 'Coffee', 'Sparkling Water', 'Bintang Beer') then 'Beverage'
            when item_name in ('Ice Cream', 'Tiramisu', 'Chocolate Lava Cake') then 'Dessert'
            else coalesce(nullif(category_raw, ''), 'Other')
        end as category
    from hotel_mapped
)

select
    pos_transaction_id,
    outlet_name,
    hotel_name,
    transaction_date,
    customer_id,
    item_name,
    category,
    quantity,
    payment_method,
    staff_id,
    coalesce(total_amount_raw, quantity * unit_price_raw) as total_amount,
    coalesce(unit_price_raw, total_amount_raw / quantity) as unit_price
from category_mapped
