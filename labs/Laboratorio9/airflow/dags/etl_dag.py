"""
DAG simple que ejecuta el pipeline ETL dentro del contenedor Airflow.

En entorno real usaríamos KubernetesPodOperator / DockerOperator / etc.
Aquí hacemos un PythonOperator directo para demostrar idea.
"""

from datetime import datetime
from airflow import DAG
from airflow.operators.python import PythonOperator
import sys

# Aseguramos que Airflow vea el código del ETL
sys.path.append("/opt/airflow/app")
from pipeline import run_etl  # noqa: E402


with DAG(
    dag_id="etl_pipeline_demo",
    start_date=datetime(2025, 1, 1),
    schedule="@daily",
    catchup=False,
    default_args={"owner": "devsecops"},
    tags=["devsecops", "etl"],
):
    run_etl_task = PythonOperator(
        task_id="run_etl",
        python_callable=run_etl,
    )
