#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${BASE_URL:-http://localhost:8000}

echo "Enviando tráfico de prueba a ${BASE_URL} ..."

for i in $(seq 1 20); do
  curl -s "${BASE_URL}/healthz" > /dev/null || true
  curl -s "${BASE_URL}/api/v1/items" > /dev/null || true

  if [ $((i % 5)) -eq 0 ]; then
    curl -s "${BASE_URL}/api/v1/work" > /dev/null || true
    curl -s "${BASE_URL}/api/v1/error" > /dev/null || true
  fi

  sleep 0.5
done

echo "Listo. Revisa Grafana (http://localhost:3000), Prometheus (http://localhost:9090), Loki y Tempo."
