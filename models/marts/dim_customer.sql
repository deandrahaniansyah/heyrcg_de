with staging as (
    select * from {{ ref('stg_customers') }}
),

ranked as (
    select
        *,
        (
            case when phone is not null then 1 else 0 end +
            case when city is not null then 1 else 0 end +
            case when loyalty_tier is not null then 1 else 0 end
        ) as completeness_score,
        
        row_number() over (
            partition by customer_id
            order by
                is_email_valid desc,
                (
                    case when phone is not null then 1 else 0 end +
                    case when city is not null then 1 else 0 end +
                    case when loyalty_tier is not null then 1 else 0 end
                ) desc,
                joined_date desc,
                email asc
        ) as rn
    from staging
),

deduped as (
    select
        customer_id,
        full_name,
        email,
        phone,
        city,
        nationality,
        coalesce(loyalty_tier, 'Bronze') as loyalty_tier,
        joined_date
    from ranked
    where rn = 1
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
        customer_id,
        full_name,
        email,
        phone,
        city,
        nationality,
        loyalty_tier,
        joined_date,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
    from deduped
    
    union all
    
    select
        {{ dbt_utils.generate_surrogate_key(["'GUEST'"]) }} as customer_key,
        'GUEST' as customer_id,
        'Guest' as full_name,
        null as email,
        null as phone,
        null as city,
        null as nationality,
        'Bronze' as loyalty_tier,
        cast('2024-01-01' as date) as joined_date,
        current_timestamp() as created_at,
        current_timestamp() as updated_at
)

select * from final
