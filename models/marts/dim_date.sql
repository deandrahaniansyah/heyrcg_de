with date_spine as (
    select date_day
    from unnest(generate_date_array('2020-01-01', '2024-12-31')) as date_day
)

select
    {{ dbt_utils.generate_surrogate_key(['date_day']) }} as date_key,
    date_day,
    extract(year from date_day) as year,
    extract(month from date_day) as month,
    extract(day from date_day) as day,
    extract(quarter from date_day) as quarter,
    format_date('%A', date_day) as day_name,
    format_date('%B', date_day) as month_name,
    format_date('%Y-%m', date_day) as year_month,
    case
        when extract(dayofweek from date_day) in (1, 7) then true
        else false
    end as is_weekend,
    current_timestamp() as created_at,
    current_timestamp() as updated_at
from date_spine
