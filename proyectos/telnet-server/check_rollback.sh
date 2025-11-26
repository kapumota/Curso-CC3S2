#!/usr/bin/env bash
set -euo pipefail

echo "Services: telnet-server"
minikube kubectl -- get services telnet-server

echo
echo "Historia Rollout: telnet-server"
minikube kubectl -- rollout history deployment telnet-server

echo
echo "A revision 1 (rollback si aplica)..."
minikube kubectl -- rollout undo deployment telnet-server --to-revision=1 || \
  echo "No se aplicó rollback (ya estamos en la revision 1 o no existe esa revisión)."

echo
echo "Pods despues de undo"
minikube kubectl -- get pods

echo
echo "Escalando deployments blue/green a 0 replicas para ahorrar recursos..."
# Estos comandos no deben romper el script si alguno de los deployments no existe
minikube kubectl -- scale deployment telnet-server-blue  --replicas=0 || \
  echo "Deployment telnet-server-blue no existe o ya estaba en 0 replicas."
minikube kubectl -- scale deployment telnet-server-green --replicas=0 || \
  echo "Deployment telnet-server-green no existe o ya estaba en 0 replicas."

echo
echo "Pods despues de escalar blue/green a 0"
minikube kubectl -- get pods

echo
echo "check_rollback.sh completado."
