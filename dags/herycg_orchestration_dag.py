from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    'owner': 'heyrcg_data_team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

with DAG(
    'herycg_orchestration_dag',
    default_args=default_args,
    description='End-to-end HeyRCG boutique hotels ingestion and data mart pipeline',
    schedule_interval=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=['heyrcg', 'dbt', 'bigquery'],
) as dag:

    ingest_raw = BashOperator(
        task_id='ingest_raw_data',
        bash_command='python /opt/airflow/dbt/scripts/ingest_raw_data.py',
    )

    dbt_deps = BashOperator(
        task_id='dbt_deps',
        bash_command='dbt deps --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt',
    )

    dbt_build = BashOperator(
        task_id='dbt_build',
        bash_command='dbt build --project-dir /opt/airflow/dbt --profiles-dir /opt/airflow/dbt',
    )

    ingest_raw >> dbt_deps >> dbt_build
