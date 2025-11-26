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
echo "[5b] Esperando a que los Deployments clave estén disponibles (hasta 120s por componente)..."
# Esperamos a que los Deployments reporten condition=Available.
minikube kubectl -- wait deployment/prometheus   -n monitoring --for=condition=Available --timeout=120s \
  || echo "Prometheus no llegó a Available en el tiempo esperado"

minikube kubectl -- wait deployment/grafana      -n monitoring --for=condition=Available --timeout=120s \
  || echo "Grafana no llegó a Available en el tiempo esperado"

minikube kubectl -- wait deployment/alertmanager -n monitoring --for=condition=Available --timeout=120s \
  || echo "Alertmanager no llegó a Available en el tiempo esperado"

echo
echo "[6] Listando Services en el namespace 'monitoring'..."
minikube kubectl -- get svc -n monitoring

echo
echo "[7] Obteniendo URLs de acceso (usando minikube ip + NodePort)..."
MINIKUBE_IP="$(minikube ip)"

PROM_PORT="$(minikube kubectl -- get svc prometheus-service   -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')"
GRAFANA_PORT="$(minikube kubectl -- get svc grafana-service    -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')"
ALERT_PORT="$(minikube kubectl -- get svc alertmanager-service -n monitoring -o jsonpath='{.spec.ports[0].nodePort}')"

PROM_URL=""
GRAFANA_URL=""
ALERT_URL=""

if [ -n "${PROM_PORT}" ]; then
  PROM_URL="http://${MINIKUBE_IP}:${PROM_PORT}"
  echo "Prometheus URL     : ${PROM_URL}"
else
  echo "Prometheus URL     : (no disponible; no se pudo obtener NodePort)"
fi

if [ -n "${GRAFANA_PORT}" ]; then
  GRAFANA_URL="http://${MINIKUBE_IP}:${GRAFANA_PORT}"
  echo "Grafana URL        : ${GRAFANA_URL}"
else
  echo "Grafana URL        : (no disponible; no se pudo obtener NodePort)"
fi

if [ -n "${ALERT_PORT}" ]; then
  ALERT_URL="http://${MINIKUBE_IP}:${ALERT_PORT}"
  echo "Alertmanager URL   : ${ALERT_URL}"
else
  echo "Alertmanager URL   : (no disponible; no se pudo obtener NodePort)"
fi

echo
echo "[8] Revisión rápida de reglas de alerta cargadas en Prometheus (via API)..."
if [ -n "${PROM_URL}" ]; then
  curl -s "${PROM_URL}/api/v1/rules" | head -n 20 || true
else
  echo "Prometheus no está disponible aún; se omite la llamada a /api/v1/rules."
fi

echo
echo "----------------------------------------"
echo "monitoring-commands.sh completado."
echo "Abre en el navegador las URLs anteriores para Prometheus, Grafana y Alertmanager."
