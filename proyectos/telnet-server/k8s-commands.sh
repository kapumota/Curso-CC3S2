#!/usr/bin/env bash
set -euo pipefail

# 1. Información del cluster
echo "[1] Info del cluster"
minikube kubectl -- cluster-info

# 2. Explicación de labels en Deployment (documentación embebida de la API)
echo
echo "[2] Explica deployment.metadata.labels"
minikube kubectl -- explain deployment.metadata.labels

# 3. Despliegue / actualización de recursos del directorio kubernetes/
echo
echo "[3] Aplicando manifiestos de kubernetes/"
minikube kubectl -- apply -f kubernetes/

# 4. Inspección de Deployment, Pods y Services
echo
echo "[4] Deployment, Pods, Services"
minikube kubectl -- get deployments.apps telnet-server
minikube kubectl -- get pods -l app=telnet-server
minikube kubectl -- get services -l app=telnet-server

# 5. Abre el túnel en background (necesario para Services tipo LoadBalancer)
echo
echo "[5] Iniciando minikube tunnel en background..."
minikube tunnel & TUNNEL_PID=$!
echo "Tunnel PID: ${TUNNEL_PID}"

# 6. Verificación de Service y Endpoints
echo
echo "[6] Services & Endpoints (telnet-server)"
minikube kubectl -- get services telnet-server
minikube kubectl -- get endpoints -l app=telnet-server
minikube kubectl -- get pods -l app=telnet-server

# 7. Simula caída de un Pod y recuperación automática por el Deployment
echo
echo "[7] Eliminando un Pod para observar la autorecuperación..."
POD="$(minikube kubectl -- get pods -l app=telnet-server -o jsonpath='{.items[0].metadata.name}')"
echo "Borrando pod: ${POD}"
minikube kubectl -- delete pod "${POD}"

echo "Pods actuales tras la eliminación:"
minikube kubectl -- get pods -l app=telnet-server

# 8. Escalado del Deployment (por ejemplo, a 3 réplicas)
echo
echo "[8] Escalando deployment telnet-server a 3 replicas..."
minikube kubectl -- scale deployment telnet-server --replicas=3
minikube kubectl -- get deployments.apps telnet-server

echo "Pods tras el escalado:"
minikube kubectl -- get pods -l app=telnet-server

# 9. Logs de uno de los Pods
echo
echo "[9] Logs desde un Pod (todos los contenedores, con prefijo de nombre)..."
FIRST_POD="$(minikube kubectl -- get pods -l app=telnet-server -o name | head -n1 | cut -d'/' -f2)"
echo "Primer pod encontrado: ${FIRST_POD}"
minikube kubectl -- logs "${FIRST_POD}" --all-containers=true --prefix=true

# 10. Cierre del túnel
echo
echo "[10] Cerrando el túnel de Minikube..."
kill "${TUNNEL_PID}" || true

echo "----------------------------------------"
echo "k8s-commands.sh completado."
