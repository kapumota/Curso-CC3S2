### Actividad 20: Kubernetes y DevOps local-first con Minikube

#### 1. Contexto

Partimos del material entregado en [Laboratorio11](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio11) que ya incluye:

* `Makefile`, `server.py`, `healthcheck.py`, `docker/Dockerfile.python-template`.
* `docker-compose.*.yml` para pruebas locales.
* Manifiestos Kubernetes en `k8s/user-service/` y `k8s/order-service/`.
* Scripts en `scripts/` para tags, smoke tests, etc.
* Carpeta `artifacts/` para dejar YAMLs, SBOM, tars, etc.
* Instrucciones que cubren el flujo general de build, pruebas y despliegue.

El objetivo de la actividad es **reforzar y mejorar las partes relacionadas con Kubernetes y DevOps**, asegurando que **todo funcione 100% en local, sin proveedores nube** (sin AWS, sin GCP, sin registries remotos).

#### 2. Estructura y ubicación en el repositorio

En tu **repositorio personal del curso** crea la carpeta:

```bash
Actividad20-CC3S2/
```

Dentro de ella coloca al menos:

```text
Actividad20-CC3S2/
  README.md                 # este enunciado + resumen de tu solución
  Laboratorio11/            # copia del laboratorio original, modificada por ti
  evidencia/                # salidas de comandos y pruebas
    comandos.txt
    kubectl-get.txt
    smoke-tests.txt
    sbom-lista.txt
```

> No modifiques el laboratorio 11 original en su repositorio fuente: trabaja sobre una **copia** de `Laboratorio11/` dentro de `Actividad20-CC3S2`.


#### 3. Objetivos

1. **Kubernetes (local)**

   * Revisar y, si es necesario, mejorar los despliegues para `user-service` y `order-service` aplicando buenas prácticas:

     * Probes `/health`, `imagePullPolicy: IfNotPresent`, recursos, seguridad.

2. **DevOps local-first**

   * Tener un **Makefile** y scripts que automaticen:

     * `build -> pruebas con Docker Compose -> SBOM/SCA -> despliegue en Minikube -> smoke test`.
   * Sin depender de proveedores nube ni registries externos.

3. **Evidencias y reproducibilidad**

   * Dejar un conjunto mínimo de comandos y salidas reproducibles en la carpeta `evidencia/`.

#### 4. Parte A - Mejoras en Kubernetes

Trabaja dentro de:

* `Laboratorio11/k8s/user-service/deployment-and-service.yaml`
* `Laboratorio11/k8s/order-service/deployment-and-service.yaml`

El objetivo es **verificar y, cuando haga falta, endurecer** los manifiestos para que sigan buenas prácticas de Kubernetes y DevSecOps.

##### A.1. Contenedores y variables

Para cada servicio, asegúrate de que el `spec.template.spec.containers` cumpla:

* `name: user-service` / `order-service`.
* `image:` debe ser **parametrizable** (evitar hardcodear `latest` o un tag fijo).

  * Puedes usar un marcador tipo `IMAGE_PLACEHOLDER` o similar que luego se reemplace desde el Makefile.
* `ports:` acordes:

  * `user-service`: `containerPort: 8000`
  * `order-service`: `containerPort: 8001`
* Variables de entorno mínimas:

  * `PORT` (`"8000"` o `"8001"`)
  * `SERVICE_NAME` (`"user-service"` o `"order-service"`).

Si ya existen, revísalas y ajústalas para que reflejen correctamente la configuración real.

##### A.2. Probes de salud

Verifica que cada contenedor tenga:

* **livenessProbe** y **readinessProbe**:

  * `httpGet` a `path: /health` y `port: 8000/8001`.
  * `initialDelaySeconds`, `periodSeconds` razonables (por ejemplo 5-10s).

Si faltan probes o están muy laxos, agrégales o ajústalos.

##### A.3. Recursos y seguridad

Revisa y, si es necesario, agrega:

* `resources`:

  * `requests` (por ejemplo `cpu: "50m"`, `memory: "64Mi"`)
  * `limits` (por ejemplo `cpu: "200m"`, `memory: "128Mi"`).

* `securityContext`:

  * `runAsNonRoot: true`
  * `runAsUser: 1000` (alineado con el usuario `app` creado en el Dockerfile).
  * `allowPrivilegeEscalation: false`
  * `readOnlyRootFilesystem: true` (si es viable para tu servicio).

##### A.4. Nombre de namespace (opcional pero recomendado)

Puedes dejarlo en `default`, o agregar (en los manifiestos o como overlay) un namespace dedicado como `devsecops-lab11`.
Si lo haces, asegúrate de que tus comandos `kubectl` lo incluyan (`-n devsecops-lab11`).


#### 5. Parte B - Makefile y pipeline DevOps local

Trabaja en:

* `Laboratorio11/Makefile`
* Scripts de `Laboratorio11/scripts/`, en especial:

  * `minikube_smoke.sh`
  * `pipeline.sh`
  * `muestra_salidas.sh`

La meta es que el flujo DevOps sea **local-first**, reproducible y alineado con Minikube.

##### B.1. Local-first: sin proveedores nube ni registries remotos

En esta actividad:

* **No** se debe usar:

  * AWS, GCP, Azure, EKS, GKE, etc.
  * Registros externos (`ghcr.io`, `docker.io` privado, etc.)

* Todas las imágenes deben ser accesibles por Kubernetes de forma **local**, por ejemplo:

  * Usando el daemon de Docker de Minikube:

    ```bash
    eval $(minikube -p minikube docker-env)
    docker build -t user-service:TAG .
    ```

  * O usando:

    ```bash
    minikube image load user-service:TAG
    minikube image load order-service:TAG
    ```

> La actividad pide que **priorices** que el Makefile y los scripts soporten este flujo **sin necesidad de push al registry**.

##### B.2. Targets mínimos del Makefile a verificar/mejorar

Asegúrate de que el `Makefile` permita, como mínimo:

1. `env`

   * Inicializa variables (`SERVICE`, `TAG`, `IMAGE`, etc.), pudiendo reutilizar `scripts/env.sh`.

2. `build`

   * Hace `docker build` de la imagen para el `SERVICE` actual.
   * Debe soportar el modo "uso minikube" (`eval $(minikube docker-env)`), según la configuración del entorno.

3. `test`

   * Lanza `docker-compose.user.test.yml` o `docker-compose.order.test.yml` según `SERVICE`.
   * Verifica que `/health` responde OK (por ejemplo, vía script o `curl`).

4. `sbom` y `scan` (opcional pero recomendado si cuentas con las herramientas)

   * `sbom`: genera `artifacts/${SERVICE}-sbom.json` con `syft ${IMAGE}`.
   * `scan`: genera `artifacts/${SERVICE}-grype.sarif` con `grype ${IMAGE}`.

5. `k8s-prepare`

   * Copia los YAML de `k8s/` a `artifacts/`.
   * Reemplaza el marcador de imagen (`IMAGE_PLACEHOLDER`) con el valor de `${IMAGE}` actual, si estás usando esa convención.

6. `minikube-up` y `k8s-apply`

   * `minikube-up`: configura y levanta Minikube con driver `docker`, CPU y RAM del Makefile.
   * `k8s-apply`: aplica `artifacts/user-service.yaml` y `artifacts/order-service.yaml` al clúster.

7. `smoke`

   * Invoca `scripts/minikube_smoke.sh` para comprobar que el servicio responde (`/health`).

8. `dev`

   * Flujo mínimo para un servicio:

     ```text
     env -> build -> test -> k8s-prepare -> minikube-up -> k8s-apply -> smoke
     ```

> El target `ci` puede mantenerse; en esta actividad se evalúa **principalmente** que el flujo `dev` funcione **100% local**.

##### B.3. Uso de los scripts de apoyo

1. `scripts/minikube_smoke.sh`

   * Utilízalo (y ajústalo si es necesario) para:

     * Resolver namespace (`NS`), URL de prueba, número de intentos, `sleep`.
     * Buscar el pod correcto con `kubectl get pods -l app=...`.
     * Hacer `port-forward` local y probar `/health`.

2. `scripts/pipeline.sh`

   * Debe orquestar el flujo completo para un servicio, por ejemplo:

     * `make env SERVICE=...`
     * `make dev SERVICE=...`
     * (Opcional) Generar SBOM/SCA si no se hace desde el Makefile.

3. `scripts/muestra_salidas.sh`

   * Úsalo para mostrar recursos relevantes (deploy, services, EndpointSlices, etc.) de `order-service` y `user-service`.
   * Si deseas, puedes extender su salida para que sea más útil como evidencia.

#### 6. Parte C-Evidencias y documentación

En la carpeta:

```text
Actividad20-CC3S2/evidencia/
```

debes incluir:

1. `comandos.txt`

   * Lista ordenada de los comandos que usaste (mínimo):

     * Creación/activación de entorno.
     * Builds locales.
     * Pruebas con docker-compose.
     * Levantamiento de Minikube.
     * Aplicación de manifiestos.
     * Smoke tests.

2. `kubectl-get.txt`

   * Salidas de:

     ```bash
     kubectl get deploy,svc,pod -o wide
     ```

     (en el namespace usado).

3. `smoke-tests.txt`

   * Salida de `scripts/minikube_smoke.sh` para:

     * `user-service` (puerto 8000)
     * `order-service` (puerto 8001)

4. `sbom-lista.txt` (si aplicas SBOM/SCA)

   * Listado de archivos `*-sbom.json` y `*-grype.sarif` generados.

Al final de `Actividad20-CC3S2/README.md` agrega:

* Un resumen de **qué mejoraste** respecto al material base, por ejemplo:

  * "Endurecí los Deployment con probes y `securityContext`, ajusté el Makefile para trabajar 100% con Minikube local y reforcé los scripts de smoke test."
