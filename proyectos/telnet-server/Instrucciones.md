### Instrucciones con `telnet-server`

Esta guía está **alineada exactamente** con los scripts del proyecto:

- `deploy.sh`
- `k8s-commands.sh`
- `monitoring-commands.sh`
- `check_rollback.sh`
- manifiestos en `kubernetes/` y `monitoring/`

La idea es avanzar **por secciones**, entendiendo qué hace cada script y qué deberías observar en cada paso.

#### 0. Requisitos previos

Antes de empezar, asegúrate de tener:

- **Docker** (Docker Desktop en Windows/macOS).
- **Minikube** instalado y funcionando con driver Docker.
- **kubectl** (lo usa internamente `minikube kubectl --`).
- Cliente **telnet**:
  - Ubuntu: `sudo apt-get install telnet`
- Idealmente, **WSL2 + Ubuntu** en Windows, y ejecutar todo desde una terminal Linux.

Ubícate en la raíz del proyecto:

```bash
cd telnet-server
````
#### 1. Mapa de scripts

Para tener el panorama general:

* `deploy.sh`

  * **Fase A (host)**: construye `dftd/telnet-server:v1` en el Docker del host, levanta un contenedor de prueba, inspecciona variables de entorno, hace Telnet y elimina el contenedor.
  * **Fase B (Minikube)**: cambia el contexto de Docker al daemon de Minikube y vuelve a construir **la misma imagen** `dftd/telnet-server:v1` dentro del clúster.

* `k8s-commands.sh`

  * Usa `minikube kubectl --` para:

    * Ver información del clúster.
    * Explicar labels de Deployment.
    * Aplicar `kubernetes/`.
    * Abrir un `minikube tunnel` en background.
    * Ver Services, Endpoints, Pods.
    * Eliminar un Pod para ver autorecuperación.
    * Escalar el Deployment.
    * Ver logs de un Pod.
    * Cerrar el túnel.

* `monitoring-commands.sh`

  * Crea/actualiza `namespace monitoring`.
  * Aplica `monitoring/prometheus/`, `monitoring/grafana/`, `monitoring/alertmanager/`.
  * Espera a que los Deployments estén `Available`.
  * Lista Services.
  * Calcula `MINIKUBE_IP + NodePort` y **muestra las URLs** de Prometheus, Grafana y Alertmanager.
  * Ejecuta un `curl` a `/api/v1/rules` de Prometheus.

* `check_rollback.sh`

  * Muestra Services y `rollout history` del Deployment `telnet-server`.
  * Intenta un `rollout undo` a la revisión 1.
  * Escala a 0 los deployments `telnet-server-blue` y `telnet-server-green` (si existen).
  * Muestra Pods al final.

#### 2. Experimento A - Servidor en Docker del host con `deploy.sh` (Fase A)

En esta sección se recorre el ciclo **imagen -> contenedor -> Telnet -> limpieza** usando Docker del host, tal como lo automatiza `deploy.sh`.

#### Pasos

1. Ejecuta:

   ```bash
   ./deploy.sh
   ```

2. En la salida, fíjate en los pasos:

   * `[0] Contexto inicial de Docker (host)...`

     * Muestra `docker context ls` para ver qué daemon estás usando.

   * `[1] Iniciando Minikube con driver Docker...`

     * Arranca (o reutiliza) Minikube, pero aquí todavía no se usan recursos de Kubernetes, solo se garantiza que el clúster existe.

   * `[1b] Eliminando contenedor previo 'telnet-server'...`

     * Limpieza de cualquier contenedor viejo llamado `telnet-server`.

   * `[1c] Construyendo imagen dftd/telnet-server:v1 en Docker del host...`

     * Construye la imagen **en el Docker del host**.

   * `[1d] Arrancando contenedor telnet-server (2323/TCP, 9000/TCP)...`

     * Levanta un contenedor con:

       * `-p 2323:2323` (Telnet)
       * `-p 9000:9000` (métricas Prometheus)

   * `[1e] Contenedores en ejecución (host...)`

     * `docker container ls -f name=telnet-server`.

   * `[1f] Variables de entorno dentro del contenedor (host)...`

     * `docker exec telnet-server env` para ver `TELNET_PORT`, `METRIC_PORT`, etc.

   * `[1g] Shell dentro del contenedor (host)...`

     * `docker exec -it telnet-server /bin/sh` para depuración interactiva (sal con `exit`).

   * `[1h] Historial de la imagen dftd/telnet-server:v1 (host)...`

     * `docker history dftd/telnet-server:v1`.

   * `[1i] Uso de recursos (stats)...`

     * `docker stats --no-stream telnet-server`.

   * `[1j] Probando Telnet a localhost:2323...`

     * Ejecuta `telnet localhost 2323`.
       Aquí puedes escribir y ver cómo responde el servidor.
       Cierra según tu cliente (`CTRL+]` -> `quit`, etc.).

   * `[1k] Deteniendo y eliminando contenedor...`

     * `docker stop` y `docker rm` limpian el contenedor de prueba.

3. Al finalizar esta sección deberías tener clara la experiencia en local con Docker: construcción, ejecución, prueba con Telnet y limpieza, todo sobre el host.

#### 3. Experimento B - Imagen lista dentro de Minikube (Fase B de `deploy.sh`)

Aquí se prepara el entorno para que Kubernetes pueda usar la imagen **sin** registry externo, dejando `dftd/telnet-server:v1` dentro del daemon de Docker de Minikube.

#### Pasos

1. En la misma ejecución de `./deploy.sh`, después de Fase A, verás:

   * `[2] Configurando docker-env para usar el daemon de Minikube...`

     * Internamente:

       ```bash
       eval "$(minikube -p minikube docker-env --shell bash)"
       ```

     A partir de aquí, el comando `docker` apunta al **Docker interno de Minikube**.

   * `[3] Versiones de Docker (cliente/servidor) dentro de Minikube...`

     * `docker version` usando el daemon de Minikube.

   * `[4] Construyendo imagen dftd/telnet-server:v1 dentro del daemon de Minikube...`

     * De nuevo:

       ```bash
       docker build -t dftd/telnet-server:v1 .
       ```

     pero ahora la imagen queda **dentro del nodo Minikube**.

   * `[5] Imágenes filtradas por dftd/telnet-server (daemon Minikube)...`

     * `docker image ls dftd/telnet-server`.

2. Al final, el script indica algo como:

   ```text
   Fase A: Imagen probada en Docker del host...
   Fase B: Imagen dftd/telnet-server:v1 disponible dentro de Minikube...
   Siguiente paso sugerido:
     -> Ejecutar: ./k8s-commands.sh
   ```

3. Después de este punto, los Deployments de Kubernetes podrán referenciar `dftd/telnet-server:v1` sin necesitar un registro remoto.

#### 4. Experimento C - Despliegue en Kubernetes con `k8s-commands.sh`

En esta parte se despliega `telnet-server` en Kubernetes, se abre un túnel tipo LoadBalancer, se revisan Pods, Services y Endpoints, y se observa autorecuperación y escalado.

#### Pasos

1. Ejecuta:

   ```bash
   ./k8s-commands.sh
   ```

2. Pasos clave:

   * `[1] Info del cluster`

     * `minikube kubectl -- cluster-info`.

   * `[2] Explica deployment.metadata.labels`

     * `minikube kubectl -- explain deployment.metadata.labels`.

   * `[3] Aplicando manifiestos de kubernetes/`

     * `minikube kubectl -- apply -f kubernetes/`
       Crea o actualiza:

       * `Deployment telnet-server`
       * `Service telnet-server` (tipo `LoadBalancer`)
       * `Service telnet-server-metrics` (tipo `ClusterIP` para Prometheus).

   * `[4] Deployment, Pods, Services`

     * `get deployments.apps telnet-server`
     * `get pods -l app=telnet-server`
     * `get services -l app=telnet-server`

   * `[5] Iniciando minikube tunnel en background...`

     * `minikube tunnel & TUNNEL_PID=$!`
       Esto permite que el Service tipo `LoadBalancer` tenga un `EXTERNAL-IP` accesible desde el host.

   * `[6] Services & Endpoints (telnet-server)`

     * `get services telnet-server`
     * `get endpoints -l app=telnet-server`
     * `get pods -l app=telnet-server`

   * `[7] Eliminando un Pod para observar la autorecuperación...`

     * El script elimina uno de los Pods y luego lista de nuevo.
       El Deployment crea otro Pod automáticamente.

   * `[8] Escalando deployment telnet-server a 3 replicas...`

     * `scale deployment telnet-server --replicas=3` y se listan de nuevo los Pods.

   * `[9] Logs desde un Pod...`

     * Obtiene un Pod y ejecuta `logs` con `--all-containers=true`.

   * `[10] Cerrando el túnel de Minikube...`

     * `kill "${TUNNEL_PID}" || true`.

3. Durante el túnel, en otra terminal:

   ```bash
   minikube kubectl -- get svc telnet-server
   ```

   Con el `EXTERNAL-IP` y el puerto `2323`, puedes conectarte:

   ```bash
   telnet <EXTERNAL-IP> 2323
   ```

#### 5. Experimento D - Blue/Green con manifiestos de `kubernetes/`

En esta sección se trabaja directamente con YAML para ver cómo se separan dos versiones (`blue` y `green`) usando `labels` y un único `Service`.

#### Archivos clave

* `kubernetes/deployment-blue-green.yaml`

  * Define `Deployment telnet-server-blue` con:

    * `metadata.labels.app: telnet-server`
    * `metadata.labels.color: blue`
    * `spec.selector.matchLabels.app: telnet-server`
    * `spec.selector.matchLabels.color: blue`

* `kubernetes/service.yaml`

  * Service principal:

    ```yaml
    kind: Service
    metadata:
      name: telnet-server
    spec:
      type: LoadBalancer
      selector:
        app: telnet-server
        color: blue  # cambiar a "green" cuando se quiera pasar al entorno verde
      ports:
        - port: 2323
          name: telnet
    ```

  * Service de métricas:

    ```yaml
    kind: Service
    metadata:
      name: telnet-server-metrics
    spec:
      type: ClusterIP
      selector:
        app: telnet-server
        color: blue  # mismo color que el Service principal
      ports:
        - port: 9000
          name: metrics
    ```

#### Pasos básicos

1. Aplicar Deployment blue y Services:

   ```bash
   minikube kubectl -- apply -f kubernetes/deployment-blue-green.yaml
   minikube kubectl -- apply -f kubernetes/service.yaml
   ```

2. Revisar Pods y Service:

   ```bash
   minikube kubectl -- get pods -l app=telnet-server
   minikube kubectl -- get svc telnet-server
   ```

3. Para simular un entorno `green`:

   * Añade un segundo Deployment en `deployment-blue-green.yaml` llamado `telnet-server-green` con:

     * `labels.color: green`
     * `matchLabels.color: green`
     * (idealmente, otra versión de la imagen o configuración).

   * Reaplica:

     ```bash
     minikube kubectl -- apply -f kubernetes/deployment-blue-green.yaml
     ```

   * Cambia en `service.yaml` los `color: blue` por `color: green` y reaplica:

     ```bash
     minikube kubectl -- apply -f kubernetes/service.yaml
     ```

   A partir de ese cambio, el tráfico del Service `telnet-server` se dirige a Pods con `color=green`.


#### 6. Experimento E - Stack de monitoreo con `monitoring-commands.sh`

Aquí se levanta Prometheus, Grafana y Alertmanager en el namespace `monitoring`, se obtienen las URLs reales y se verifica que Prometheus tiene reglas cargadas.

#### Pasos

1. Ejecuta:

   ```bash
   ./monitoring-commands.sh
   ```

2. Comportamiento principal:

   * Creación/actualización del namespace `monitoring`.

   * Aplicación recursiva de manifiestos:

     * `monitoring/prometheus/`
     * `monitoring/grafana/`
     * `monitoring/alertmanager/`

   * Espera hasta que los Deployments estén `Available`.

   * Lista los Services con sus NodePort.

   * Calcula la IP de Minikube y los puertos para:

     ```text
     Prometheus URL   : http://<MINIKUBE_IP>:<PROM_PORT>
     Grafana URL      : http://<MINIKUBE_IP>:<GRAFANA_PORT>
     Alertmanager URL : http://<MINIKUBE_IP>:<ALERT_PORT>
     ```

   * Hace un `curl` a `<PROM_URL>/api/v1/rules` y muestra las primeras líneas.

3. Con esas URLs, abre en el navegador:

* Prometheus para explorar métricas, incluyendo las expuestas por `telnet-server`.
* Grafana para revisar dashboards provisionados en `monitoring/grafana/`.
* Alertmanager para revisar alertas y su estado.

#### 7. Experimento F - Rollback y apagado de blue/green con `check_rollback.sh`

Esta parte muestra el historial de despliegues y cómo revertir a una revisión anterior, además de apagar entornos `blue` y `green`.

#### Pasos

1. Ejecuta:

   ```bash
   ./check_rollback.sh
   ```

2. Lo que realiza el script:

   * Muestra el Service:

     ```bash
     minikube kubectl -- get services telnet-server
     ```

   * Consulta el historial de despliegue de `telnet-server`:

     ```bash
     minikube kubectl -- rollout history deployment telnet-server
     ```

   * Intenta un rollback a la revisión 1:

     ```bash
     minikube kubectl -- rollout undo deployment telnet-server --to-revision=1
     ```

   * Lista Pods después del `undo`:

     ```bash
     minikube kubectl -- get pods
     ```

   * Escala `telnet-server-blue` y `telnet-server-green` a cero réplicas (sin fallar si no existen):

     ```bash
     minikube kubectl -- scale deployment telnet-server-blue  --replicas=0
     minikube kubectl -- scale deployment telnet-server-green --replicas=0
     ```

   * Lista Pods otra vez para ver el estado final.

#### 8. Limpieza final

Cuando termines tus experimentos:

```bash
# Recursos de la app
minikube kubectl -- delete -f kubernetes/ || true

# Recursos de monitoreo
minikube kubectl -- delete -f monitoring/alertmanager/ || true
minikube kubectl -- delete -f monitoring/grafana/ || true
minikube kubectl -- delete -f monitoring/prometheus/ || true
minikube kubectl -- delete -f monitoring/00_namespace.yaml || true

# Detener Minikube
minikube stop
```

Para un reset completo del clúster:

```bash
minikube delete
```

Con estas secciones se recorre, paso a paso todo esto:

1. `deploy.sh` -> imagen probada en el host y disponible en Minikube.
2. `k8s-commands.sh` -> despliegue, Service tipo LoadBalancer, túnel, autorecuperación y escalado.
3. YAML de `kubernetes/` -> separación blue/green mediante labels.
4. `monitoring-commands.sh` -> Prometheus, Grafana y Alertmanager con URLs calculadas.
5. `check_rollback.sh` -> historial, rollback y apagado de entornos blue/green.
