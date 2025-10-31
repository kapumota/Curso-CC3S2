#!/usr/bin/env bash
set -euo pipefail

IMG="${1:?imagen requerida}"
OUT="${2:?ruta de salida requerida}"

mkdir -p "$(dirname "$OUT")"

echo "[SBOM] Generando SBOM para $IMG en $OUT"
# Ejemplo real:
# syft "$IMG" -o spdx-json > "$OUT"

echo "{ \"sbom_for\": \"$IMG\", \"status\": \"PLACEHOLDER\" }" > "$OUT"
