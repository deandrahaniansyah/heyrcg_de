with source as (
    select * from {{ ref('stg_pos_transactions') }}
),

summarized as (
    select
        item_name as product_name,
        max(category) as category,
        avg(unit_price) as unit_price_default
    from source
    group by 1
)

select
    {{ dbt_utils.generate_surrogate_key(['product_name']) }} as product_key,
    product_name,
    category,
    coalesce(unit_price_default, 0.0) as unit_price_default,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from summarized
