#!/usr/bin/env bash
set -euo pipefail

# Fase A: Docker del host (Docker Desktop)

echo "[0] Contexto inicial de Docker (host)..."
docker context ls || true

# 1. Inicia Minikube con driver Docker (idempotente)
echo "[1] Iniciando Minikube con driver Docker..."
minikube start --driver=docker

# 1b. Limpia cualquier contenedor previo de prueba
echo "[1b] Eliminando contenedor previo 'telnet-server' (si existe) en Docker del host..."
docker rm -f telnet-server 2>/dev/null || true

# 1c. Construye imagen en Docker del host
echo "[1c] Construyendo imagen dftd/telnet-server:v1 en Docker del host..."
docker build -t dftd/telnet-server:v1 .

# 1d. Arranca contenedor de prueba en Docker del host
echo "[1d] Arrancando contenedor telnet-server (2323/TCP, 9000/TCP) en Docker del host..."
docker run -p 2323:2323 \
           -p 9000:9000 \
           -d \
           --name telnet-server \
           dftd/telnet-server:v1

# 1e. Lista contenedores para verificar
echo "[1e] Contenedores en ejecución (host, filtrando por telnet-server)..."
docker container ls -f name=telnet-server

# 1f. Variables de entorno dentro del contenedor (host)
echo "[1f] Variables de entorno dentro del contenedor (host)..."
docker exec telnet-server env

# 1g. Shell interactiva opcional para debug (host)
echo "[1g] Shell dentro del contenedor (host) - sal con 'exit' cuando termines..."
docker exec -it telnet-server /bin/sh || true

# 1h. Historial de la imagen y uso de recursos (host)
echo "[1h] Historial de la imagen dftd/telnet-server:v1 (host)..."
docker history dftd/telnet-server:v1 || true

echo "[1i] Uso de recursos (stats) del contenedor telnet-server (host)..."
docker stats --no-stream telnet-server || true

# 1j. Prueba de conexión Telnet (host -> contenedor host)
echo "[1j] Probando Telnet a localhost:2323 (Docker del host)..."
echo ">>> Telnet a localhost 2323 (puerto mapeado en el host)"
echo "    (cierra la sesión con 'q' o como defina el servidor, luego CTRL+] y 'quit' si hace falta)"
telnet localhost 2323 || true

# 1k. Detiene y elimina el contenedor de prueba en el host
echo "[1k] Deteniendo y eliminando contenedor de prueba 'telnet-server' en el host..."
docker stop telnet-server || true
docker rm telnet-server || true

# Fase B: Docker dentro de Minikube

# 2. Apunta Docker al daemon de Minikube
echo "[2] Configurando docker-env para usar el daemon de Minikube..."
eval "$(minikube -p minikube docker-env --shell bash)"

# 3. Comprueba versiones (útil para diagnosticar problemas de compatibilidad)
echo "[3] Versiones de Docker (cliente/servidor) dentro de Minikube..."
docker version

# 4. Construye la imagen del telnet-server dentro de Minikube
echo "[4] Construyendo imagen dftd/telnet-server:v1 dentro del daemon de Minikube..."
docker build -t dftd/telnet-server:v1 .

# 5. Lista la imagen resultante en el daemon de Minikube
echo "[5] Imágenes filtradas por dftd/telnet-server (daemon Minikube)..."
docker image ls dftd/telnet-server

echo "----------------------------------------"
echo "deploy.sh completado."
echo
echo "Fase A: Imagen probada en Docker del host (contenedor de prueba arrancó, se probó y se eliminó)."
echo "Fase B: Imagen dftd/telnet-server:v1 disponible dentro de Minikube para Deployments de Kubernetes."
echo
echo "Siguiente paso sugerido:"
echo "  -> Ejecutar: ./k8s-commands.sh"
echo "     para aplicar los manifiestos de kubernetes/ y exponer el servicio via LoadBalancer + minikube tunnel."
