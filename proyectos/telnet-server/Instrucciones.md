### Microservicio Telnet con Kubernetes y Observabilidad (Prometheus/Grafana/Alertmanager)

#### 0. Requisitos previos

En **Windows 10/11**:

1. **Docker Desktop**

   * Activar backend de **WSL2** y asegurarte de que Docker está corriendo.

2. **Minikube** (v1.17.1 o superior)

   * Instalado y en el `PATH`.

3. **kubectl**

   * Opcionalmente puedes usar siempre el de Minikube:

     ```bash
     minikube kubectl -- version
     ```

4. **Skaffold** (para la parte de CI/CD local)

   * Instalado y en el `PATH`.

5. **Cliente Telnet**

   * En Windows, activar "Cliente Telnet" desde *Características de Windows* o usar `telnet` de WSL.

6. Opcional: entorno Python `bdd` (solo si lo usas para otras cosas).

### 1. Obtener el proyecto y entrar al directorio

```bash
# Clonar el repositorio (o descomprimir el zip en una carpeta)
git clone <URL_DEL_REPO> telnet-server
cd telnet-server
```

(En tu caso asegúrate de estar dentro de la carpeta `telnet-server/` donde están `Dockerfile`, `deploy.sh`, `k8s-commands.sh`, `monitoring/`, `skaffold.yaml`, etc.)

### 2. Probar localmente solo con Docker (opcional, pero muy útil)

#### 2.1. Construir la imagen

```bash
docker build -t dftd/telnet-server:v1 .
```

Ver la imagen:

```bash
docker images | grep telnet-server
```

#### 2.2. Ejecutar y probar Telnet

```bash
docker run --rm -d --name telnet-server -p 2323:2323 -p 9000:9000 dftd/telnet-server:v1
```

* Telnet contra el host:

  ```bash
  telnet localhost 2323
  ```

* Ver logs:

  ```bash
  docker logs -f telnet-server
  ```

* Probar métricas en el navegador o con curl:

  ```bash
  curl http://localhost:9000/metrics
  ```

#### 2.3. Entrar al contenedor (debug)

En **PowerShell/CMD**:

```bash
docker exec -it telnet-server sh
```

En **Git Bash** (si da el error del `sh` de Git):

```bash
winpty docker exec -it telnet-server sh
```

Para parar el contenedor:

```bash
docker stop telnet-server
```

> Esto te ayuda a entender el binario y `/metrics` antes de meterlo en Kubernetes.

### 3. Preparar Minikube + Docker dentro de Minikube

Abre una consola **como Administrador** (PowerShell, CMD o Git Bash).

#### 3.1. Iniciar Minikube con driver Docker

```bash
minikube start --driver=docker
```

> Si ves warnings de `overlayfs` vs `overlay2`, es tema de rendimiento, no un error fatal. Idealmente en Docker Desktop configurar `overlay2` en `daemon.json`, pero no bloquea el laboratorio.

#### 3.2. Apuntar Docker al demonio de Minikube

En **Git Bash/WSL/bash**:

```bash
eval "$(minikube -p minikube docker-env --shell bash)"
```

En **PowerShell**:

```powershell
minikube -p minikube docker-env --shell powershell
# Copias y ejecutas las líneas que imprime (SET/ENV)
```

A partir de aquí, **`docker build` y `docker run` actúan dentro del entorno de Minikube**, no en el host.

### 4. Script `deploy.sh` (flujo "rápido" de despliegue en Docker/Minikube)

Usaremos este script como flujo estándar:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Inicia Minikube con driver Docker (idempotente)
echo "[1] Iniciando Minikube con driver Docker..."
minikube start --driver=docker

# 2. Apunta Docker al daemon de Minikube
echo "[2] Configurando docker-env para usar el daemon de Minikube..."
eval "$(minikube -p minikube docker-env --shell bash)"

# 3. Comprueba versiones
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
telnet localhost 2323 || true

echo ">>> Telnet a ${MINIKUBE_IP} 2323 (cuando el contenedor corre con docker-env de Minikube)"
telnet "${MINIKUBE_IP}" 2323 || true

# 12. Logs del contenedor
echo "[12] Logs del contenedor telnet-server..."
docker logs telnet-server

echo "-"
echo "deploy.sh completado."
echo "Contenedor 'telnet-server' sigue en ejecución."
echo "Puedes detenerlo con: docker stop telnet-server"
```

#### 4.1. Dar permisos y ejecutar

```bash
chmod +x deploy.sh
./deploy.sh
```

### 5. Conexiones Telnet: `localhost` vs `minikube ip`

#### 5.1. Caso 1: contenedor en el host

Si el contenedor corre así:

```bash
docker run -p 2323:2323 -d dftd/telnet-server:v1
```

* Funciona: `telnet localhost 2323`
* **NO** funciona: `telnet $(minikube ip) 2323`
  porque el contenedor está en el host, no "dentro" de la VM de Minikube.

#### 5.2. Caso 2: contenedor usando el Docker de Minikube

Con `docker-env` activo:

```bash
eval "$(minikube -p minikube docker-env --shell bash)"
docker run -p 2323:2323 -d --name telnet-server dftd/telnet-server:v1
```

Ahora puedes hacer:

```bash
minikube ip
# Ejemplo: 192.168.49.2
telnet 192.168.49.2 2323
```

También puedes usar `0.0.0.0` para bind:

```bash
docker run -p 0.0.0.0:2323:2323 -d dftd/telnet-server:v1
```

### 6. Script `k8s-commands.sh`: revisar el Deployment y el Service

Usaremos este script como "laboratorio de Kubernetes":

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Información del cluster
echo "[1] Info del cluster"
minikube kubectl -- cluster-info

# 2. Explicación de labels en Deployment
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

# 5. Abre el túnel en background (Services tipo LoadBalancer)
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

# 7. Simula caída de un Pod y recuperación automática
echo
echo "[7] Eliminando un Pod para observar la autorecuperación..."
POD="$(minikube kubectl -- get pods -l app=telnet-server -o jsonpath='{.items[0].metadata.name}')"
echo "Borrando pod: ${POD}"
minikube kubectl -- delete pod "${POD}"

echo "Pods actuales tras la eliminación:"
minikube kubectl -- get pods -l app=telnet-server

# 8. Escalado del Deployment (a 3 réplicas)
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

echo "-"
echo "k8s-commands.sh completado."
```

#### 6.1. Dar permisos y ejecutar

```bash
chmod +x k8s-commands.sh
./k8s-commands.sh
```

### 7. Despliegue de monitoreo: Prometheus, Grafana y Alertmanager

#### 7.0. Script `monitoring-commands.sh`

Para no escribir todo a mano cada vez, usaremos este script:

```bash
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

echo "Prometheus URL   : ${PROM_URL}"
echo "Grafana URL      : ${GRAFANA_URL}"
echo "Alertmanager URL : ${ALERT_URL}"

echo
echo "[8] Revisión rápida de reglas de alerta cargadas en Prometheus (via API)..."
PROM_HTTP_BASE="${PROM_URL%%,*}"   # por si minikube imprime varias URLs
curl -s "${PROM_HTTP_BASE}/api/v1/rules" | head -n 20 || true

echo
echo "-"
echo "monitoring-commands.sh completado."
echo "Abre en el navegador las URLs anteriores para Prometheus, Grafana y Alertmanager."
```

#### Uso

```bash
chmod +x monitoring-commands.sh
./monitoring-commands.sh
```

Salidas típicas:

* `created` / `configured` para los recursos de Prometheus/Grafana/Alertmanager.
* `get pods -n monitoring` mostrando los pods `prometheus-deployment-...`, `grafana-deployment-...`, `alertmanager-deployment-...` en `Running`.
* `get svc -n monitoring` mostrando `prometheus-service`, `grafana-service`, `alertmanager-service` (NodePort).
* URLs tipo `http://192.168.49.2:30090` (Prometheus), `:30030` (Grafana), `:30093` (Alertmanager).
* El JSON de `/api/v1/rules` con tus reglas de alerta (`telnet-server-golden-signals`, etc.) truncado a ~20 líneas.

#### 7.1. (Opcional) Comandos manuales equivalentes

Si prefieres hacerlo sin script, los comandos sueltos son los mismos que antes:

```bash
minikube kubectl -- apply -f monitoring/00_namespace.yaml
minikube kubectl -- apply -f monitoring/prometheus/
minikube kubectl -- apply -f monitoring/grafana/
minikube kubectl -- apply -f monitoring/alertmanager/
minikube kubectl -- get pods -n monitoring
minikube kubectl -- get svc  -n monitoring
```

Y acceso con:

```bash
minikube service prometheus-service -n monitoring
minikube service grafana-service -n monitoring
minikube service alertmanager-service -n monitoring
```

o `kubectl port-forward` si lo prefieres.

### 8. Flujo con `skaffold.yaml` (build -> test -> deploy)

#### 8.1. Ejecutar Skaffold

Con Minikube activo y `docker-env` apuntando a Minikube:

```bash
skaffold dev --cleanup=false
```

Skaffold hará:

1. **Build**

   ```yaml
   build:
     local: {}
     artifacts:
       - image: dftd/telnet-server
   ```

2. **Test** (unit tests + container-structure-test):

   ```yaml
   test:
     - image: dftd/telnet-server
       custom:
         - command: "go test ./... -v"
         - command: "docker run … container-structure-test ... --image={{.IMAGE}} …"
   ```

3. **Deploy** con tus manifests:

   ```yaml
   deploy:
     kubectl:
       manifests:
         - kubernetes/*
   ```

4. Se queda viendo cambios en el código. Si editas Go/Dockerfile, reconstruye y redepliega.

Cuando quieras limpiar todo:

```bash
skaffold delete
```

### 9. Script `check_and_rollback.sh` (inspección y rollback)

Crea este archivo en la raíz:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Services: telnet-server"
minikube kubectl -- get services telnet-server

echo; echo "Historia rollout: telnet-server"
minikube kubectl -- rollout history deployment telnet-server

echo; echo "Rollback a revision 1"
minikube kubectl -- rollout undo deployment telnet-server --to-revision=1

echo; echo "Pods despues de undo"
minikube kubectl -- get pods
```

Dar permisos y ejecutar:

```bash
chmod +x check_and_rollback.sh
./check_and_rollback.sh
```
Con esto ya tienes las **instrucciones completas** integrando:

* `deploy.sh`
* `k8s-commands.sh`
* `monitoring-commands.sh`
* `check_and_rollback.sh`
* y el flujo con Docker, Minikube, Kubernetes, Prometheus, Grafana, Alertmanager y Skaffold.
