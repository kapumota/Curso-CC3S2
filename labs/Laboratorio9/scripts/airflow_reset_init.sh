#!/usr/bin/env bash
set -euo pipefail

# Resetea la metadata de Airflow en Postgres (pierdes DAG runs, users, etc.)
# Úsalo solo en entornos desechables/de desarrollo.

# 1) Levanta Postgres y espera red
docker compose up -d postgres

# 2) Obtiene la URL de conexión desde .env
DB_URL="$(grep '^SQLALCHEMY_CONN=' .env | cut -d= -f2- || true)"
if [[ -z "${DB_URL:-}" ]]; then
  echo "ERROR: SQLALCHEMY_CONN no encontrado en .env"; exit 1
fi

# 3) Reset + init + crea usuario admin (idempotente en la creación)
docker compose run --rm \
  -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="$DB_URL" \
  airflow-webserver bash -lc '
    echo "DB URL: $AIRFLOW__DATABASE__SQL_ALCHEMY_CONN";
    airflow db reset -y &&
    airflow db init &&
    airflow users create \
      --username admin \
      --firstname Admin \
      --lastname User \
      --role Admin \
      --email admin@example.com \
      --password admin || true
  '
