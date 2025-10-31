#!/usr/bin/env bash
set -euo pipefail

IMG="${1:?imagen requerida}"

echo "[SCAN] Escaneando vulnerabilidades en $IMG"
# Ejemplo real:
# trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMG"

echo "[SCAN] Placeholder: pasa si no hay HIGH/CRITICAL registradas"
