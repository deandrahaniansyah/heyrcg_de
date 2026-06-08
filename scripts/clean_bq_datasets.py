import os
import sys
from google.cloud import bigquery
from google.oauth2 import service_account

base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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

datasets_to_delete = [
    f"{project_id}.analytics_mart_raw",
    f"{project_id}.analytics_mart"
]

def delete_dataset(dataset_ref):
    print(f"Deleting dataset: {dataset_ref} and all its tables/views...")
    try:
        client.delete_dataset(dataset_ref, delete_contents=True, not_found_ok=True)
        print(f"Successfully cleaned/deleted dataset: {dataset_ref}")
    except Exception as e:
        print(f"Error deleting dataset {dataset_ref}: {e}", file=sys.stderr)

def main():
    print(f"Target Google Cloud Project: {project_id}")
    confirm = input("Are you sure you want to delete the staging and mart datasets? (y/N): ")
    if confirm.lower() not in ['y', 'yes']:
        print("Cleanup cancelled.")
        return

    for dataset_id in datasets_to_delete:
        delete_dataset(dataset_id)
    print("BigQuery datasets cleanup finished successfully!")

if __name__ == "__main__":
    main()
