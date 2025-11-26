#!/usr/bin/env bash
set -euo pipefail

echo "[1] Creando / actualizando namespace 'monitoring'..."
minikube kubectl -- apply -f monitoring/00_namespace.yaml

echo
echo "[2] Desplegando Prometheus..."
minikube kubectl -- apply -f monitoring/prometheus/

echo
echo "[3] Desplegando Grafana..."
minikube kubectl -- apply -f monitoring/grafana/

echo
echo "[4] Desplegando Alertmanager..."
minikube kubectl -- apply -f monitoring/alertmanager/

echo
echo "[5] Listando Pods en el namespace 'monitoring'..."
minikube kubectl -- get pods -n monitoring

echo
echo "[6] Listando Services en el namespace 'monitoring'..."
minikube kubectl -- get svc -n monitoring

echo
echo "[7] Obteniendo URLs de acceso (minikube service --url)..."
PROM_URL="$(minikube service prometheus-service -n monitoring --url)"
GRAFANA_URL="$(minikube service grafana-service -n monitoring --url)"
ALERT_URL="$(minikube service alertmanager-service -n monitoring --url)"

echo "Prometheus URL: ${PROM_URL}"
echo "Grafana URL   : ${GRAFANA_URL}"
echo "Alertmanager URL: ${ALERT_URL}"

echo
echo "[8] Revisión rápida de reglas de alerta cargadas en Prometheus (via API)..."
# Nota: asume que el primer URL de Prometheus es accesible desde el host
PROM_HTTP_BASE="${PROM_URL%%,*}"   # por si minikube imprime varias URLs
curl -s "${PROM_HTTP_BASE}/api/v1/rules" | head -n 20 || true

echo
echo "----------------------------------------"
echo "monitoring-commands.sh completado."
echo "Abre en el navegador las URLs anteriores para Prometheus, Grafana y Alertmanager."
