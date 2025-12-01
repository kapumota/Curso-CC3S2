#!/usr/bin/env bash
set -euo pipefail

# Imagen por defecto usada en:
# - deploy.sh
# - kubernetes/deployment*.yaml
# - skaffold.yaml
IMAGE="${IMAGE:-dftd/telnet-server:v1}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
CST_CONFIG="${CST_CONFIG:-container-tests/command-and-metadata-test.yaml}"

echo "[build] Iniciando build para imagen: ${IMAGE}"

echo
echo "[1] Ejecutando pruebas de Go (unit/integration)..."
go test ./... -v

echo
echo "[2] Construyendo imagen Docker (${IMAGE})..."

# Preferimos buildx, pero hacemos fallback a docker build clásico
if docker buildx version >/dev/null 2>&1; then
  echo "    -> Usando 'docker buildx build --load'"
  docker buildx build \
    --load \
    --file "${DOCKERFILE}" \
    --tag "${IMAGE}" \
    .
else
  echo "    -> 'docker buildx' no disponible, usando 'docker build'"
  docker build \
    --file "${DOCKERFILE}" \
    --tag "${IMAGE}" \
    .
fi

echo
echo "[3] Listando imagen recién construida..."
docker image ls "${IMAGE}" || true

echo
echo "[4] Pruebas de contenedor (container-structure-test)..."
if command -v container-structure-test >/dev/null 2>&1; then
  if [ -f "${CST_CONFIG}" ]; then
    echo "    -> Ejecutando container-structure-test con ${CST_CONFIG}"
    container-structure-test test \
      --image "${IMAGE}" \
      --config "${CST_CONFIG}"
  else
    echo "    -> Config ${CST_CONFIG} no encontrada; se salta esta fase."
  fi
else
  echo "    -> 'container-structure-test' no está instalado; se salta esta fase."
fi

echo
echo "----------------------------------------"
echo "build.sh completado."
echo "Imagen disponible en el daemon actual: ${IMAGE}"
echo
echo "Siguientes pasos típicos en el flujo completo:"
echo "  1) ./deploy.sh              # Prueba la imagen en Docker del host y la construye dentro de Minikube"
echo "  2) ./k8s-commands.sh        # Aplica kubernetes/, abre túnel y prueba el servicio"
echo "  3) ./monitoring-commands.sh # Despliega Prometheus + Grafana + Alertmanager"
echo
echo "También puedes usar 'skaffold dev' o 'skaffold run' (imagen: dftd/telnet-server) según tu flujo."
