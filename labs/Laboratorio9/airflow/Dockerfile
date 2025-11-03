FROM apache/airflow:2.9.1-python3.11
USER root

# Copiamos sólo lo necesario al runtime
COPY airflow/dags /opt/airflow/dags
COPY app          /opt/airflow/app

# Volvemos al usuario airflow (no root en runtime)
USER airflow

# Instalamos dependencias en el venv interno de Airflow
ARG AIRFLOW_VERSION=2.9.1
ARG PYTHON_VERSION=3.11
ARG CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

RUN pip install --no-cache-dir \
    --constraint "${CONSTRAINT_URL}" \
    pandas psycopg2-binary
