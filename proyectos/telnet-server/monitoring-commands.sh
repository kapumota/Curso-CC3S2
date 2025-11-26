#!/usr/bin/env bash
set -euo pipefail

echo "[1] Creando / actualizando namespace 'monitoring'..."
minikube kubectl -- apply -f monitoring/00_namespace.yaml

echo
echo "[2] Desplegando Prometheus..."
# -R (--recursive) por si hay subcarpetas (rules, configmaps, etc.)
minikube kubectl -- apply -R -f monitoring/prometheus/

echo
echo "[3] Desplegando Grafana (deployment + datasources + dashboards)..."
# Importante: -R para que también aplique monitoring/grafana/dashboard/*.yaml
minikube kubectl -- apply -R -f monitoring/grafana/

echo
echo "[4] Desplegando Alertmanager..."
minikube kubectl -- apply -R -f monitoring/alertmanager/

echo
echo "[5] Listando Pods en el namespace 'monitoring'..."
minikube kubectl -- get pods -n monitoring

echo
echo "[5b] Esperando a que los Pods de 'monitoring' estén en Ready (hasta 180s)..."
# Espera a que todos los pods del namespace monitoring alcancen condition=Ready
minikube kubectl -- wait --for=condition=ready pod -n monitoring --all --timeout=180s \
  || echo "Algunos Pods de 'monitoring' no llegaron a Ready en el tiempo esperado"

echo
echo "[6] Listando Services en el namespace 'monitoring'..."
minikube kubectl -- get svc -n monitoring

echo
echo "[7] Obteniendo URLs de acceso (minikube service --url)..."
PROM_URL="$(minikube service prometheus-service   -n monitoring --url 2>/dev/null || true)"
GRAFANA_URL="$(minikube service grafana-service    -n monitoring --url 2>/dev/null || true)"
ALERT_URL="$(minikube service alertmanager-service -n monitoring --url 2>/dev/null || true)"

if [ -n "${PROM_URL}" ]; then
  echo "Prometheus URL     : ${PROM_URL}"
else
  echo "Prometheus URL     : (no disponible todavía)"
fi

if [ -n "${GRAFANA_URL}" ]; then
  echo "Grafana URL        : ${GRAFANA_URL}"
else
  echo "Grafana URL        : (no disponible todavía)"
fi

if [ -n "${ALERT_URL}" ]; then
  echo "Alertmanager URL   : ${ALERT_URL}"
else
  echo "Alertmanager URL   : (no disponible todavía)"
fi

echo
echo "[8] Revisión rápida de reglas de alerta cargadas en Prometheus (via API)..."
if [ -n "${PROM_URL}" ]; then
  PROM_HTTP_BASE="${PROM_URL%%,*}"   # por si minikube imprime varias URLs separadas por coma
  curl -s "${PROM_HTTP_BASE}/api/v1/rules" | head -n 20 || true
else
  echo "Prometheus no está disponible aún; se omite la llamada a /api/v1/rules."
fi

echo
echo "----------------------------------------"
echo "monitoring-commands.sh completado."
echo "Abre en el navegador las URLs anteriores para Prometheus, Grafana y Alertmanager cuando estén disponibles."
