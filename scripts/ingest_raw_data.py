import os
import sys
from google.cloud import bigquery
from google.oauth2 import service_account

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
data_dir = os.path.join(base_dir, "data")

keyfile_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
if not keyfile_path:
    relative_path = os.path.join(base_dir, "credentials", "bq-sa.json")
    if os.path.exists(relative_path):
        keyfile_path = relative_path

if keyfile_path:
    print(f"Initializing BigQuery client with keyfile: {keyfile_path}")
    credentials = service_account.Credentials.from_service_account_file(keyfile_path)
    client = bigquery.Client(credentials=credentials, project=credentials.project_id)
else:
    print("Initializing BigQuery client with Application Default Credentials")
    client = bigquery.Client()

project_id = client.project
dataset_id = f"{project_id}.analytics_mart_raw"

tables_schema = {
    "raw_bookings": [
        bigquery.SchemaField("BookingID", "STRING"),
        bigquery.SchemaField("hotel_name", "STRING"),
        bigquery.SchemaField("RoomType", "STRING"),
        bigquery.SchemaField("customer_id", "STRING"),
        bigquery.SchemaField("CustomerName", "STRING"),
        bigquery.SchemaField("customer_email", "STRING"),
        bigquery.SchemaField("CheckInDate", "STRING"),
        bigquery.SchemaField("check_out_date", "STRING"),
        bigquery.SchemaField("nights", "INTEGER"),
        bigquery.SchemaField("booking_status", "STRING"),
        bigquery.SchemaField("channel", "STRING"),
        bigquery.SchemaField("BookingSource", "STRING"),
        bigquery.SchemaField("RatePerNight", "FLOAT64"),
        bigquery.SchemaField("Currency", "STRING"),
        bigquery.SchemaField("TotalRevenue_IDR", "FLOAT64"),
        bigquery.SchemaField("discount_pct", "FLOAT64"),
        bigquery.SchemaField("is_loyalty_member", "STRING"),
        bigquery.SchemaField("created_at", "STRING"),
    ],
    "raw_customers": [
        bigquery.SchemaField("customer_id", "STRING"),
        bigquery.SchemaField("full_name", "STRING"),
        bigquery.SchemaField("email", "STRING"),
        bigquery.SchemaField("phone", "STRING"),
        bigquery.SchemaField("city", "STRING"),
        bigquery.SchemaField("nationality", "STRING"),
        bigquery.SchemaField("loyalty_tier", "STRING"),
        bigquery.SchemaField("joined_date", "STRING"),
    ],
    "raw_pos_transactions": [
        bigquery.SchemaField("pos_transaction_id", "STRING"),
        bigquery.SchemaField("outlet_name", "STRING"),
        bigquery.SchemaField("hotel_name", "STRING"),
        bigquery.SchemaField("transaction_date", "STRING"),
        bigquery.SchemaField("customer_id", "STRING"),
        bigquery.SchemaField("item_name", "STRING"),
        bigquery.SchemaField("category", "STRING"),
        bigquery.SchemaField("quantity", "INTEGER"),
        bigquery.SchemaField("unit_price", "FLOAT64"),
        bigquery.SchemaField("total_amount", "STRING"),
        bigquery.SchemaField("payment_method", "STRING"),
        bigquery.SchemaField("staff_id", "STRING"),
    ],
    "raw_marketing_performance": [
        bigquery.SchemaField("row_id", "INTEGER"),
        bigquery.SchemaField("campaign_name", "STRING"),
        bigquery.SchemaField("Platform", "STRING"),
        bigquery.SchemaField("hotel", "STRING"),
        bigquery.SchemaField("Date", "STRING"),
        bigquery.SchemaField("impressions", "INTEGER"),
        bigquery.SchemaField("clicks", "INTEGER"),
        bigquery.SchemaField("spend_idr", "FLOAT64"),
        bigquery.SchemaField("conversions", "INTEGER"),
        bigquery.SchemaField("bookings_generated", "INTEGER"),
        bigquery.SchemaField("Revenue_Generated_IDR", "FLOAT64"),
        bigquery.SchemaField("ad_creative_id", "STRING"),
        bigquery.SchemaField("target_audience", "STRING"),
    ],
}

def create_dataset():
    dataset = bigquery.Dataset(dataset_id)
    dataset.location = "asia-southeast2"
    try:
        dataset = client.create_dataset(dataset, exists_ok=True)
        print(f"Dataset {dataset_id} is ready (Location: {dataset.location}).")
    except Exception as e:
        print(f"Error creating dataset {dataset_id}: {e}", file=sys.stderr)
        sys.exit(1)

def load_csv(table_name, schema):
    csv_file = os.path.join(data_dir, f"{table_name}.csv")
    if not os.path.exists(csv_file):
        print(f"CSV file not found: {csv_file}", file=sys.stderr)
        sys.exit(1)

    table_ref = f"{dataset_id}.{table_name}"
    
    job_config = bigquery.LoadJobConfig(
        schema=schema,
        skip_leading_rows=1,
        source_format=bigquery.SourceFormat.CSV,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    
    print(f"Loading {csv_file} into {table_ref}...")
    with open(csv_file, "rb") as source_file:
        load_job = client.load_table_from_file(
            source_file, table_ref, job_config=job_config
        )
    
    load_job.result()
    destination_table = client.get_table(table_ref)
    print(f"Loaded {destination_table.num_rows} rows into {table_ref} successfully.")

def main():
    create_dataset()
    for table_name, schema in tables_schema.items():
        load_csv(table_name, schema)
    print("All raw tables loaded successfully to BigQuery!")

if __name__ == "__main__":
    main()
