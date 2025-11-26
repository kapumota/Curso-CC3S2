#!/usr/bin/env bash
set -euo pipefail

# 1. Inicia Minikube con driver Docker (idempotente: si ya está arriba, simplemente valida el estado)
echo "[1] Iniciando Minikube con driver Docker..."
minikube start --driver=docker

# 2. Apunta Docker al daemon de Minikube
echo "[2] Configurando docker-env para usar el daemon de Minikube..."
eval "$(minikube -p minikube docker-env --shell bash)"

# 3. Comprueba versiones (útil para diagnosticar problemas de compatibilidad)
echo "[3] Versiones de Docker (cliente/servidor):"
docker version

# 4. Construye la imagen del telnet-server
echo "[4] Construyendo imagen dftd/telnet-server:v1 ..."
docker build -t dftd/telnet-server:v1 .

# 5. Lista la imagen resultante
echo "[5] Imágenes filtradas por dftd/telnet-server..."
docker image ls dftd/telnet-server

# 6. Arranca el contenedor exponiendo puertos de servicio (2323) y métricas (9000)
echo "[6] Arrancando contenedor telnet-server (2323/TCP, 9000/TCP)..."
docker run -p 0.0.0.0:2323:2323 \
           -p 0.0.0.0:9000:9000 \
           -d \
           --name telnet-server \
           dftd/telnet-server:v1

# 7. Lista contenedores para verificar que está en ejecución
echo "[7] Contenedores en ejecución (filtrando por telnet-server)..."
docker container ls -f name=telnet-server

# 8. Información interna del contenedor (variables de entorno)
echo "[8] Variables de entorno dentro del contenedor..."
docker exec telnet-server env

# 9. Shell interactiva opcional para debug
echo "[9] Shell dentro del contenedor (sal con 'exit' cuando termines)..."
docker exec -it telnet-server /bin/sh || true

# 10. Historial de capas y métricas de recursos
echo "[10] Historial de la imagen dftd/telnet-server:v1..."
docker history dftd/telnet-server:v1

echo "[10b] Uso de recursos (stats) del contenedor telnet-server..."
docker stats --no-stream telnet-server

# 11. Prueba de conexión Telnet - localhost vs IP de Minikube
echo "[11] Probando Telnet a localhost:2323 y a Minikube IP:2323..."

MINIKUBE_IP="$(minikube ip)"
echo "Minikube IP: ${MINIKUBE_IP}"

echo ">>> Telnet a localhost 2323 (puerto mapeado en el host)"
echo "    (cierra la sesión con 'q' o como defina el servidor)"
telnet localhost 2323 || true

echo ">>> Telnet a ${MINIKUBE_IP} 2323 (cuando el contenedor corre con docker-env de Minikube)"
telnet "${MINIKUBE_IP}" 2323 || true

# 12. Logs del contenedor
echo "[12] Logs del contenedor telnet-server..."
docker logs telnet-server

echo "----------------------------------------"
echo "deploy.sh completado."
echo "Contenedor 'telnet-server' sigue en ejecución."
echo "Puedes detenerlo con: docker stop telnet-server"
