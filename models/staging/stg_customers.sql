with source as (
    select * from {{ source('raw_data', 'raw_customers') }}
),

cleaned as (
    select
        trim(customer_id) as customer_id,
        trim(full_name) as full_name,
        lower(replace(trim(email), ' ', '')) as email,
        nullif(trim(cast(phone as string)), '') as phone,
        nullif(trim(city), '') as city,
        nullif(trim(nationality), '') as nationality,
        nullif(initcap(trim(loyalty_tier)), '') as loyalty_tier,
        safe_cast(joined_date as date) as joined_date
    from source
)

select
    customer_id,
    full_name,
    email,
    phone,
    city,
    nationality,
    loyalty_tier,
    joined_date,
    case
        when regexp_contains(email, r'^[^@\s]+@[^@\s]+\.[^@\s]+$') then true
        else false
    end as is_email_valid
from cleaned
