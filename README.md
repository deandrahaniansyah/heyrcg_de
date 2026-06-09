# HeyRCG Boutique Hotels — Q1 2024 Data Pipeline

dbt + BigQuery + Airflow pipeline that cleans 4 raw data sources and builds a Kimball star schema data mart.

## Setup

### Prerequisites
- Docker & Docker Compose
- BigQuery service account key at `credentials/bq-sa.json` (gitignored)
- Project ID defaults to `fleet-tractor-421109` (override via `.env`)

### Running the pipeline

```bash
docker compose up -d --build
```

Open [localhost:8080](http://localhost:8080) (Airflow UI, login: admin/admin), find `herycg_orchestration_dag`, toggle it on and trigger it.

The DAG runs 3 tasks in sequence:
1. `ingest_raw_data` — Python script uploads CSVs to BigQuery (`analytics_mart_raw`)
2. `dbt_deps` — installs dbt packages
3. `dbt_build` — builds all models and runs tests

To tear down:
```bash
docker compose down -v
```

---

## Architecture

### Star Schema

```
  dim_customer ──┐         ┌── dim_hotel
  dim_date ──────┤  FACTS  ├── dim_product
  dim_campaign ──┘         └── dim_date

  fact_bookings          → one row per booking
  fact_pos_transactions  → one row per POS line item
  fact_marketing_daily   → one row per campaign/hotel/day
```

All dimensions use surrogate keys (`dbt_utils.generate_surrogate_key`). Facts reference dimensions via these keys. Every table has `created_at` and `updated_at` audit columns.

### Staging layer
Staging models are materialized as **views** — they clean and standardize the raw data without storing copies:
- Standardize dates to `YYYY-MM-DD` (POS has 5 different formats, parsed with regex)
- Strip "IDR" prefix from `total_amount`, cast to numeric
- Normalize statuses (`cnx` → Cancelled), booleans (`Yes/True/1` → true), payment methods (`cc` → Credit Card)
- Rename all columns to `snake_case`
- Deduplicate POS by `pos_transaction_id`

### Mart layer
Mart models are materialized as **tables** — pre-computed and ready for analyst queries.

---

## Data Quality Decisions

### Customer deduplication
~50 customer IDs have duplicate records with slightly different profiles. I ranked them by profile completeness (non-null phone/city/loyalty_tier) and email validity, keeping the best record per ID.

Risk: if a customer genuinely has two profiles (work vs personal email), we lose one. In production I'd consider SCD Type 2 tracking instead.

### POS date parsing
Transaction dates came in 5 formats (`2024-01-01`, `20240101`, `01 Jan 2024`, `01/01/2024`, `01-15-2024`). I verified that dash-dates are `MM-DD-YYYY` and slash-dates are `DD/MM/YYYY` by checking for impossible day values (>12), then wrote a CASE expression to parse each format.

### Booking revenue
140 bookings had null `TotalRevenue_IDR`. I back-calculated it from `RatePerNight * nights * exchange_rate`. The exchange rates (USD=15800, SGD=11700, AUD=10200) were derived from the data — they're consistent across all non-null rows. I also added `net_revenue_idr` after discount.

### Checkout dates
122 bookings had checkout before check-in. Instead of dropping them, I corrected to `check_in_date + nights` since the `nights` column was reliable.

### Invalid rows — general approach
I went with "keep and flag" rather than dropping:
- Unparseable dates → kept as NULL (still flow through staging, get an 'Unknown' surrogate key in facts)
- Invalid emails → flagged with `is_email_valid = false`, not dropped
- Null marketing spend → coalesced to 0 per the assignment spec
- POS duplicates → removed via `ROW_NUMBER()`

---

## Sample Queries

### Monthly revenue by hotel
```sql
select
    h.hotel_name, d.year_month,
    sum(f.gross_revenue_idr) as gross_revenue,
    sum(f.net_revenue_idr) as net_revenue
from analytics_mart.fact_bookings f
join analytics_mart.dim_hotel h on f.hotel_key = h.hotel_key
join analytics_mart.dim_date d on f.check_in_date_key = d.date_key
group by 1, 2
order by 1, 2;
```

### F&B spend per guest
```sql
select
    sum(pos.total_amount) / count(distinct b.booking_id) as fb_per_booking
from analytics_mart.fact_bookings b
join analytics_mart.fact_pos_transactions pos
    on b.customer_key = pos.customer_key and b.hotel_key = pos.hotel_key
where b.booking_status in ('Checked In', 'Checked Out');
```

### Booking conversion by channel
```sql
select
    channel,
    count(*) as total,
    round(100.0 * sum(case when booking_status in ('Checked In','Checked Out') then 1 else 0 end) / count(*), 1) as completion_pct
from analytics_mart.fact_bookings
group by 1 order by total desc;
```

### Marketing ROAS by campaign
```sql
select
    c.campaign_name,
    sum(f.revenue_generated_idr) / nullif(sum(f.spend_idr), 0) as roas
from analytics_mart.fact_marketing_daily f
join analytics_mart.dim_campaign c on f.campaign_key = c.campaign_key
group by 1 order by roas desc;
```

---

## Known Limitations & Future Improvements

- **Full table overwrite on ingestion** — the Python script uses `WRITE_TRUNCATE` on every run, which is fine for a quarterly snapshot but wouldn't scale to daily. For production, I'd switch to `WRITE_APPEND` with a watermark column (e.g., `created_at`) to only ingest new rows.
- **No incremental models** — all mart tables are full rebuilds. At higher data volumes, I'd convert fact tables to dbt `incremental` materialization with `merge` strategy and use `{% if is_incremental() %}` to only process new records since the last run.
- **Exchange rates are hardcoded** — derived from the data but not from a live FX source. In production I'd pull from a daily rate table or API.
- **SCD Type 1 only** — customer changes are overwritten, not tracked historically. Would need SCD Type 2 with valid_from/valid_to columns if we care about loyalty tier change history.
- **Hotel metadata is sparse** — `dim_hotel` only has name/location/country since the source data doesn't provide more attributes like star rating or room count.

