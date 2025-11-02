### Actividad: Reforzamiento de DevSecOps con contenedores

Esta actividad sirve para operar y **endurecer** un stack con Docker/Compose (Airflow + Postgres + tu `etl-app`), aplicar **12-Factor (Config)**, ejecutar **pruebas en contenedor**, generar **SBOM + escaneo**, y dejar **evidencia verificable**. El foco es reproducibilidad y seguridad.


> Utiliza como referencia el código entregado en el [laboratorio 9](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio9) del curso.

> Todo el código y comandos aquí mostrados son referenciales y pueden requerir ajustes según tu entorno (SO, versiones de Docker/Compose, imágenes base, rutas y variables). 
> No subas secretos ni `.env` reales. Usa `tags/digests` propios y valida siempre con tus pruebas y políticas de seguridad.

#### Parte 1 - Operar, observar y documentar

#### 1.1 Levantamiento y verificación

Comienza construyendo las imágenes, levantando los servicios en segundo plano y verificando su estado. Captura toda la salida en archivos dentro de `evidencia/` para que se pueda reproducir y auditar.

```bash
# Build (captura la salida completa)
docker compose build 2>&1 | tee Actividad18-CC3S2/evidencia/00_build.txt

# Up en segundo plano (captura la salida completa)
docker compose up -d 2>&1 | tee Actividad18-CC3S2/evidencia/01_up.txt

# Estado resumido y tabla con nombres/imagen/estado/puertos
docker compose ps           | tee Actividad18-CC3S2/evidencia/02_ps.txt
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' \
  | tee -a Actividad18-CC3S2/evidencia/02_ps.txt
```

Si tus servicios tienen healthcheck, espera unos segundos y vuelve a consultar el estado para confirmar que cambian a `healthy`. Cuando necesites un chequeo más preciso, inspecciona cada contenedor:

```bash
for c in $(docker compose ps -q); do
  name=$(docker inspect --format '{{.Name}}' $c | sed 's#^/##')
  health=$(docker inspect $c | grep -A2 '"Health":' -n || true)
  printf "\n %s \n" "$name"
  echo "$health"
done | tee -a Actividad18-CC3S2/evidencia/02_ps.txt
```

**Criterio de aceptación:** todos los servicios se mantienen `healthy` (si tienen healthcheck) o `Up` sin reinicios en bucle.
**Evidencia:** `00_build.txt`, `01_up.txt`, `02_ps.txt`.

#### 1.2 Topología y superficie expuesta

Describe cómo se conectan los servicios, qué redes existen, qué puertos están publicados hacia el host y cómo se resuelven los nombres dentro de la red de Docker. 
Descubre el nombre real de la red por defecto del proyecto y documenta su inspección junto con una prueba de DNS interno.

```bash
# Detecta la red _default del proyecto
NET=$(docker network ls | awk '/_default/{print $2; exit}')
echo "NET=$NET" | tee Actividad18-CC3S2/evidencia/05_net_inspect.txt

# Inspección completa de la red
docker network inspect "$NET" >> Actividad18-CC3S2/evidencia/05_net_inspect.txt

# Tabla rápida de puertos publicados por servicio
docker ps --format '{{.Names}}\t{{.Ports}}' \
  | tee -a Actividad18-CC3S2/evidencia/05_net_inspect.txt

# Prueba de DNS interno y reachability dentro de la red del proyecto
docker run --rm -it --network "$NET" alpine sh -lc '
  apk add --no-cache curl >/dev/null 2>&1 || true
  echo "[DNS] airflow-webserver:"; getent hosts airflow-webserver || true
  echo "[DNS] postgres:"; getent hosts postgres || true
  echo "[HTTP] webserver /health:"; curl -s -o /dev/null -w "%{http_code}\n" http://airflow-webserver:8080/health || true
' | tee -a Actividad18-CC3S2/evidencia/05_net_inspect.txt
```

Redacta un resumen breve (200-300 palabras) en `04_topologia.md` que incluya: redes presentes, servicios y relaciones (quién habla con quién), puertos publicados y la justificación de por qué **algunos servicios no deberían exponer puertos** (por ejemplo, Postgres y `etl-app` solo requieren comunicación interna). Explica también el uso del **DNS interno por nombre de servicio** y, si aún no existe, propone mover el proyecto a una **user-defined bridge** exclusiva para aislar tráfico y reducir exposición.

**Evidencia:** `04_topologia.md`, `05_net_inspect.txt`.


#### 1.3 Observabilidad mínima

Extrae los logs recientes del **webserver** y del **scheduler** (y del **worker** si existe) y resalta algunas líneas que prueben **vida sana** del sistema. 
Por **vida sana** entendemos que los componentes clave están operativos y responden como se espera: la **UI** devuelve **HTTP 200** en `/health`, al menos  **un DAG fue cargado** correctamente (aparece en el DagBag) y el **scheduler** emite su **heartbeat** con regularidad. 
El **heartbeat** es el "latido" periódico del scheduler que indica que sigue activo, haciendo *polling* de DAGs y despachando tareas, si falta o se interrumpe, el sistema puede estar detenido o atascado. 
Recuerda **sanitizar** la salida (oculta contraseñas, tokens o secretos) antes de guardarla en la evidencia.

Ejemplos útiles de líneas a marcar:

* `webserver /health: 200` (la UI está respondiendo bien)
* `Loaded DAG: etl_pipeline` o `DagBag size: N` (DAGs cargados)
* `Scheduler heartbeat` / `Processor heartbeat` (latido periódico del scheduler)


```bash
# Webserver (últimos 200, con sanitización básica)
docker compose logs --tail=200 airflow-webserver \
  | sed -E 's/(password|token|secret)=\S+/REDACTED/g' \
  | tee Actividad18-CC3S2/evidencia/03_logs_airflow.txt

# Scheduler
docker compose logs --tail=200 airflow-scheduler \
  | sed -E 's/(password|token|secret)=\S+/REDACTED/g' \
  | tee -a Actividad18-CC3S2/evidencia/03_logs_airflow.txt

# Worker (si existe; ajusta el nombre del servicio según tu stack)
docker compose logs --tail=200 airflow-worker 2>/dev/null \
  | sed -E 's/(password|token|secret)=\S+/REDACTED/g' \
  | tee -a Actividad18-CC3S2/evidencia/03_logs_airflow.txt

# Comprobación explícita del /health del webserver (añádelo al archivo de logs)
docker run --rm --network "$NET" byrnedo/alpine-curl \
  curl -s -o /dev/null -w "webserver /health: %{http_code}\n" http://airflow-webserver:8080/health \
  | tee -a Actividad18-CC3S2/evidencia/03_logs_airflow.txt
```

Para facilitar la revisión, añade al final del archivo tres líneas "marcadas" que resuman los indicadores clave que encontraste:

```bash
{
  echo "[MARCA] DAG cargado: etl_pipeline"
  echo "[MARCA] webserver /health: 200"
  echo "[MARCA] Scheduler heartbeat detectado"
} >> Actividad18-CC3S2/evidencia/03_logs_airflow.txt
```

**Evidencia:** `03_logs_airflow.txt` (sanitizado, con marcas claras al final).


#### Errores comunes

* Usar imágenes con `:latest` y perder reproducibilidad, etiqueta con versión o `GIT_SHA` y documenta el tag en el `README.md`.
* Asumir que la red se llama `proyecto_default`, detecta el nombre real con `docker network ls | grep _default`.
* Definir healthchecks que apuntan a endpoints inexistentes o tardan demasiado en responder, valida con `curl` dentro del contenedor y ajusta `interval`/`retries`.
* Subir logs con secretos, aplica filtros (`sed`, `grep -v`) y revisa el archivo antes del commit.

#### Parte 2 - Endurecimiento del Compose/Dockerfile

#### 2.1 Healthchecks razonables

**Qué hacer (paso a paso)**

1. Usa comandos **reales** que verifiquen *readiness*.
2. Añade `start_period` si el servicio tarda en arrancar (evita falsos negativos).
3. Si tu base es Alpine, valida que tienes `curl`/`wget`; si no, usa `CMD-SHELL` con utilidades disponibles.
4. Conecta `depends_on: condition: service_healthy` para encadenar dependencias.

**Ejemplo robusto (Airflow + Postgres):**

```yaml
services:
  airflow-webserver:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 15s
      timeout: 3s
      retries: 10
      start_period: 30s

  postgres:
    healthcheck:
      # Nota: $$ para escapar $ en YAML (se evalúa dentro del contenedor)
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB -h localhost"]
      interval: 10s
      timeout: 3s
      retries: 10
      start_period: 20s

  etl-app:
    depends_on:
      postgres:
        condition: service_healthy
      airflow-webserver:
        condition: service_healthy
```

**Variantes útiles**

* Si **no** hay `curl` dentro del contenedor:

  ```yaml
  healthcheck:
    test: ["CMD", "wget", "-q", "-O", "-", "http://localhost:8080/health"]
  ```
* Para un servicio Python con puerto interno:

  ```yaml
  healthcheck:
    test: ["CMD-SHELL", "exec 3<>/dev/tcp/localhost/8000 || exit 1"]
  ```

**Verificación (captura de evidencia):**

```bash
# Vuelve a crear/levantar para activar healthchecks
docker compose up -d --build

# Estado (debe aparecer "healthy" tras el warm-up)
docker compose ps | tee -a Actividad18-CC3S2/evidencia/02_ps.txt

# Inspect solo del status de health por contenedor
for c in $(docker compose ps -q); do
  name=$(docker inspect --format '{{.Name}}' $c | sed 's#^/##')
  status=$(docker inspect --format '{{json .State.Health.Status}}' $c 2>/dev/null || echo '"no-healthcheck"')
  echo "$name $status"
done | tee Actividad18-CC3S2/evidencia/10_health_status.txt
```

**Criterio de aceptación**
`docker compose ps` muestra "healthy" en los servicios con healthcheck tras el período de calentamiento.

**Evidencia**

* `evidencia/10_compose_diff.md` (explica qué añadiste y por qué)
* `evidencia/10_health_status.txt` (salida de la verificación)

**Errores frecuentes y fixes**

* *Endpoint incorrecto*: compruébalo con `docker compose exec <svc> curl -i http://localhost:8080/health`.
* *Sin `start_period` y timeouts prematuros*: añade `start_period` y aumenta `retries`.
* *Olvidar `$$` en variables dentro de `test`:* en YAML debes escapar `$` -> usa `$$`.


#### 2.2 Límites de recursos

> **Importante:** `deploy.resources.limits` **no** aplica en Docker Compose local (es para Swarm). Para Compose local usa `mem_limit`, `cpus` y/o `cpuset`. Mantén **una sola** estrategia (no mezcles).

**Compose local (recomendado):**

```yaml
services:
  airflow-webserver:
    mem_limit: "1g"
    cpus: "1.0"
  postgres:
    mem_limit: "1g"
    cpus: "0.5"
  etl-app:
    mem_limit: "512m"
    cpus: "0.5"
```

**Si usas Swarm/Stacks (informativo):**

```yaml
deploy:
  resources:
    limits:
      cpus: "1.0"
      memory: 1g
```

**Verificación con `inspect` (captura la evidencia):**

```bash
for s in airflow-webserver postgres etl-app; do
  id=$(docker compose ps -q $s)
  echo "$s ($id)"
  docker inspect $id \
    --format 'Memory={{.HostConfig.Memory}} Bytes  NanoCpus={{.HostConfig.NanoCpus}}  CpuQuota={{.HostConfig.CpuQuota}}  CpuPeriod={{.HostConfig.CpuPeriod}}'
done | tee Actividad18-CC3S2/evidencia/11_limits_check.txt
```

> **Interpretación rápida**:
>
> * `Memory` > 0 => límite aplicado.
> * `NanoCpus` > 0 => fracción de CPU (por ejemplo, `1000000000` = 1 CPU).
> * `CpuQuota/CpuPeriod` => límites alternativos en kernels antiguos.

**Criterio**
El `inspect` muestra límites ≠ 0 para cada servicio.

**Evidencia**
`evidencia/11_limits_check.txt`

**Errores frecuentes y fixes**

* *Poner `deploy.*` y esperar efecto en Compose local:* usa `mem_limit`/`cpus`.
* *Valores sin unidad en memoria:* añade `m`/`g` (por ejemplo, `512m`, `1g`).

#### 2.3 Usuario no-root

**Construcción segura del Dockerfile (base Debian/Alpine):**

```dockerfile
# Ejemplo base
FROM python:3.11-slim

# Crea usuario/grupo sin privilegios
RUN addgroup --system app && adduser --system --ingroup app app

# Crea directorios y ajusta propiedad
WORKDIR /app
COPY --chown=app:app pyproject.toml poetry.lock* /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copia el código con ownership correcto (evita chmod 777)
COPY --chown=app:app . /app

# Opcional: crea directorio de datos temp y márcalo tmpfs en Compose
RUN mkdir -p /app/.cache && chown -R app:app /app/.cache

USER app
CMD ["python", "pipeline.py"]
```

**Si tu Dockerfile usa `COPY` sin `--chown`:**

```dockerfile
COPY . /app
RUN chown -R app:app /app
USER app
```

**Verificaciones (captura la evidencia):**

```bash
# Usuario efectivo dentro del contenedor
docker compose exec etl-app sh -lc 'id && whoami' \
  | tee Actividad18-CC3S2/evidencia/12_user_check.txt

# Intento de escritura en / (debería fallar si usas read-only en runtime)
# (Añade read_only: true en Compose para reforzar)
```

**Refuerzo en Compose (opcional):**

```yaml
services:
  etl-app:
    user: "1000:1000"         # si mapeas al UID/GID del host
    read_only: true           # sistema de archivos de solo lectura
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

**Criterio**
`id`/`whoami` reportan un usuario no-root, no usas `chmod 777`.

**Evidencia**
`evidencia/12_user_check.txt`

**Errores frecuentes y fixes**

* *Cambiar a `USER app` antes de copiar deps:* si necesitas instalar paquetes de sistema, hazlo **antes** de bajar privilegios.
* *Propiedad incorrecta del `WORKDIR`*: usa `--chown` en `COPY` o `chown` explícito.


#### 2.4 Config por variables de entorno (12-Factor)

**Limpieza de código y Compose**

* Elimina secretos hardcodeados del código/DAG/Compose.
* Declara variables en `.env.example` con valores dummy y documenta su propósito en el `README.md`.
* Prefiere `env_file: .env` (no subir `.env` real) y usa `environment:` para *valores no sensibles* o defaults.

**Ejemplo Compose:**

```yaml
services:
  etl-app:
    env_file:
      - .env
    environment:
      # Valores no sensibles o defaults
      APP_LOG_LEVEL: "INFO"
  postgres:
    env_file:
      - .env
    # Evita credenciales inline:
    # environment:
    #   POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

**Plantilla `.env.example` (sugerida):**

```
# --- Airflow ---
AIRFLOW__CORE__EXECUTOR=LocalExecutor
AIRFLOW__WEBSERVER__RBAC=True

# --- Base de datos (dummy) ---
POSTGRES_DB=etl_db
POSTGRES_USER=etl_user
POSTGRES_PASSWORD=example_password

# --- ETL ---
ETL_INPUT=/app/data/input.csv
ETL_OUTPUT=/app/data/output.csv
```

**Verificación y auditoría (captura la evidencia):**

```bash
# 1) Dentro de etl-app, lista variables relevantes (sanitiza en archivo)
docker compose exec etl-app sh -lc 'printenv | sort | grep -E "^(AIRFLOW__|POSTGRES_|ETL_)"' \
  | sed -E 's/(PASSWORD|SECRET)=.*/\1=REDACTED/g' \
  | tee Actividad18-CC3S2/evidencia/13_env_audit.txt

# 2) Asegura que no hay secretos "pegados" en el repositorio
grep -R --line-number -E '(PASSWORD|SECRET|TOKEN)=' . \
  | grep -v '\.env' \
  | tee -a Actividad18-CC3S2/evidencia/13_env_audit.txt || true
```

**Criterio**
Las configuraciones sensibles provienen del entorno (no están hardcodeadas). Hay un `.env.example` con documentación breve.

**Evidencia**

* `evidencia/13_env_audit.txt`
* 3-4 líneas explicativas en `evidencia/10_compose_diff.md` sobre cómo migraste config a ENV.

**Errores frecuentes y fixes**

* *Usar `.env` real en Git:* ignóralo en `.gitignore` y entrega **solo** `.env.example`.
* *Variables definidas en `environment:` y distintas del `.env`:* unifica o documenta precedencias.


#### Parte 3 - Pruebas en contenedor + Gate de supply chain

#### 3.1 Pruebas

La idea es que tus pruebas se ejecuten **dentro** de contenedores, con dependencias reales (Postgres, etc.) y que el proceso **falle con exit code ≠ 0** si 
algo rompe.

**Opción A - Compose de pruebas con SUT (recomendada):**

```bash
# Levanta y corre pruebas; captura todo en evidencia/20_tests.txt
docker compose -f docker-compose.test.yml up \
  --build \
  --abort-on-container-exit \
  --exit-code-from sut 2>&1 \
  | tee Actividad18-CC3S2/evidencia/20_tests.txt

# Limpia contenedores de test y volúmenes efímeros
docker compose -f docker-compose.test.yml down -v
```

**Opción B - Makefile (si ya lo tienes):**

```bash
make test 2>&1 | tee Actividad18-CC3S2/evidencia/20_tests.txt
```

**Extras de calidad (opcionales):**

* **Cobertura**: configura tu SUT para guardar `.coverage`/`coverage.xml` en un volumen de salida.

  * Evidencia sugerida: `evidencia/20_coverage.txt` (resumen) y/o `evidencia/20_coverage.xml`.
* **JUnit/XML**: si usas pytest, agrega `--junitxml=/out/junit.xml` (monta `/out`).

  * Evidencia: `evidencia/20_junit.xml`.
* **Perfil de tests**: si tu Compose soporta *profiles*, corre `--profile test` para levantar solo lo necesario.

**Criterio**

* La ejecución devuelve **exit code 0** (o justificas una falla puntual y adjuntas plan).
* `20_tests.txt` incluye nombres de tests, tiempos y resumen final (passed/failed/errored/skipped).

**Errores típicos y cómo evitarlos**

* "Flaky tests" por dependencia no *ready*: agrega `depends_on: condition: service_healthy` en tu `docker-compose.test.yml`.
* Pruebas que leen rutas del host: usa **volúmenes** y `WORKDIR` consistentes.


#### 3.2 SBOM + escaneo (tu gate de supply chain)

Genera **SBOM** de tu **imagen final** y corre un **escaneo** de vulnerabilidades. Si puedes, escanea también la **imagen base** y el **filesystem** del directorio (para dependencias vendorizadas).

#### 3.2.1 Obtener el **digest** (recomendado)

Trabaja con **digest** y no solo con tags, para que el reporte sea inmutable:

```bash
# Etiqueta final (ejemplo)
IMG=mi_etl_app:1.0.0

# Obtén digest y guárdalo
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' $IMG)
echo "IMG=$IMG"        | tee Actividad18-CC3S2/evidencia/21_meta.txt
echo "DIGEST=$DIGEST" | tee -a Actividad18-CC3S2/evidencia/21_meta.txt
```
> el digest es el identificador inmutable de una imagen de contenedor calculado como un hash SHA-256 del contenido (manifiesto).
> A diferencia del tag (:1.0.0, :latest), que puede cambiar y apuntar mañana a otra imagen, el digest no cambia jamás mientras el contenido sea el mismo.

#### 3.2.2 SBOM (Syft o Trivy) -Opcional

**Con Syft (formato SPDX JSON):**

```bash
syft packages "$IMG" -o spdx-json \
  > Actividad18-CC3S2/evidencia/21_sbom.spdx.json
```

**Con Trivy SBOM (alternativa):**

```bash
trivy sbom --format spdx-json --output Actividad18-CC3S2/evidencia/21_sbom.spdx.json "$IMG"
```

> Si puedes, genera también SBOM del **filesystem** del repo (para dependencias fuera del paquete):

```bash
syft dir:. -o spdx-json > Actividad18-CC3S2/evidencia/21_sbom_fs.spdx.json
```

#### 3.2.3 Escaneo (Grype o Trivy) -Opcional

**Con Grype (imagen):**

```bash
grype "$IMG" \
  --add-cpes-if-none \
  --fail-on high \
  --only-fixed=false \
  --scope AllLayers \
  > Actividad18-CC3S2/evidencia/22_scan.txt || true
```

**Con Trivy (imagen):**

```bash
trivy image --scanners vuln --vuln-type os,library \
  --severity HIGH,CRITICAL \
  --ignore-unfixed=false \
  --exit-code 1 \
  --format table \
  --output Actividad18-CC3S2/evidencia/22_scan.txt \
  "$IMG" || true
```

**(Opcional) Escanea la imagen base y compara:**

```bash
BASE=python:3.11-slim
trivy image --severity HIGH,CRITICAL "$BASE" \
  > Actividad18-CC3S2/evidencia/22_scan_base.txt || true
```

**(Opcional) Escaneo del filesystem (dependencias vendorizadas):**

```bash
trivy fs --scanners vuln --severity HIGH,CRITICAL \
  --exit-code 0 \
  --format table . \
  > Actividad18-CC3S2/evidencia/22_scan_fs.txt || true
```

> **Nota**: usamos `|| true` para que el *pipeline* no se corte al escribir la evidencia, pero **el gate** debe aplicarse al final con una verificación explícita (ver abajo).

#### 3.2.4 Gate (falla si hay findings >= HIGH sin plan) (opcional)

Una manera simple: **parsea** el reporte y falla si detectas vulnerabilidades **HIGH/CRITICAL** sin excepción documentada.

**Gate básico con Trivy (exit code ya controla):**

* Si usaste `--exit-code 1` y el comando devolvió `1`, entonces tienes findings **severos**. Registra eso y **exige** plan en `23_cve_plan.md`.

**Gate básico con Grype (manual):**

```bash
# Falla si hay "High" o "Critical" en el reporte y NO hay plan
if grep -E "(High|Critical)" Actividad18-CC3S2/evidencia/22_scan.txt >/dev/null; then
  echo "CVE severos encontrados. Requiere 23_cve_plan.md" \
    | tee -a Actividad18-CC3S2/evidencia/22_scan.txt
fi
```

#### 3.2.5 Plan de acción

Crea `Actividad18-CC3S2/evidencia/23_cve_plan.md` con la siguiente **plantilla mínima**:

```md
# Plan de acción CVE (HIGH/CRITICAL) - Imagen: mi_etl_app:1.0.0 @ <digest>

- Hallazgos clave:
  - CVE-YYYY-XXXX en <paquete> (<versión>) - Severidad: HIGH - Componente: sistema/biblioteca
  - CVE-YYYY-YYYY en <paquete> (<versión>) - Severidad: CRITICAL

- Remediación técnica:
  1) Actualizar base image a <nueva_base:tag> (ETA: <fecha>).
  2) Fijar versión de <paquete> a >= X.Y.Z donde el CVE está parchado.
  3) Ejecutar re-build y re-scan. Adjuntar nuevo SBOM y scan.

- Excepción temporal (si aplica):
  - Justificación: el paquete no se ejecuta en ruta explotable (argumento técnico).
  - Ticket: <ID/enlace interno> - Revisión: <fecha límite> (<= 30 días).

- Criterios de cierre:
  - Trivy/Grype sin HIGH/CRITICAL en imagen final.
  - Documentación de digest nuevo y evidencia de remediación.
```

#### Parte 4 - DAG funcional + control de ejecución

#### 4.1 Resumen del DAG

Redacta `Actividad18-CC3S2/evidencia/30_dag_resumen.md` incluyendo:

* **Tareas** (extract/transform/load u otras), **dependencias** (por ejemplo `extract >> transform >> load`).
* **Configuración** por ENV/Connections: variables (`ETL_INPUT`, `ETL_OUTPUT`), conexiones Airflow (`Conn Id`, tipo, host/DB).
* **Dónde** se registran logs y **cómo** detectar éxito/fallo.

> Manténlo operativo: no cuentes la historia del ETL, cuenta **cómo lo corro** y **cómo sé que pasó**.

#### 4.2 Disparo y verificación

**Disparo del DAG (run manual "para hoy"):**

```bash
# Lista DAGs para confirmar nombre
docker compose exec airflow-scheduler airflow dags list \
  | tee Actividad18-CC3S2/evidencia/31_dag_run.txt

# Trigger
docker compose exec airflow-scheduler airflow dags trigger etl_pipeline \
  | tee -a Actividad18-CC3S2/evidencia/31_dag_run.txt

# Ver estructura de tareas
docker compose exec airflow-scheduler airflow tasks list etl_pipeline --tree \
  | tee -a Actividad18-CC3S2/evidencia/31_dag_run.txt
```

**Obtener el execution_date/Run ID (útil para logs de tareas):**

```bash
docker compose exec airflow-scheduler airflow dags list-runs -d etl_pipeline --no-backfill \
  | tee -a Actividad18-CC3S2/evidencia/31_dag_run.txt
```

**(Opcional) Logs de tarea específica (si puedes capturar):**

```bash
# Ajusta <run_id> o usa el más reciente
RUN_ID=$(docker compose exec airflow-scheduler airflow dags list-runs -d etl_pipeline \
  | awk 'NR==2{print $1}' 2>/dev/null) # adapta según formato de tu versión

# Si tu versión expone "airflow tasks logs":
docker compose exec airflow-scheduler airflow tasks logs etl_pipeline extract "$RUN_ID" \
  | tee -a Actividad18-CC3S2/evidencia/31_dag_run.txt
```

**Verificación de éxito (indicadores):**

* En `31_dag_run.txt` se ve:

  * `Task ... succeeded` para cada tarea clave.
  * Último estado del DAG: `success` (si puedes capturarlo con `list-runs`).
* El **/health** del webserver responde `200` (puedes re-usar verificación de Parte 1).

**(Opcional) Verificación con Postgres (ETL resultó):**

```bash
# Dentro de la red del proyecto, consulta si hay filas nuevas en la tabla destino
NET=$(docker network ls | awk '/_default/{print $2; exit}')
docker run --rm --network "$NET" alpine sh -lc '
  apk add --no-cache postgresql-client >/dev/null 2>&1
  psql -h postgres -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM <tabla_destino>;"
' 2>&1 | tee -a Actividad18-CC3S2/evidencia/31_dag_run.txt
```

#### 4.3 Timeout razonable

**Cambios mínimos en el DAG (ejemplo):**

```python
# dags/etl_pipeline.py
from datetime import timedelta

PythonOperator(
    task_id="extract",
    python_callable=extract_fn,
    execution_timeout=timedelta(minutes=5),
)
```

**Plantilla de diff/explicación (`32_timeout_diff.md`):**

```md
# Timeout aplicado a tareas críticas

- Archivo: `dags/etl_pipeline.py`
- Cambio: se agregó `execution_timeout=timedelta(minutes=5)` a la tarea `extract`.
- Razón: evitar colgados. 5 min es razonable para fuentes locales/CSV. Si se excede, la tarea falla de forma explícita, acelera diagnóstico y evita consumo infinito.
- Impacto: el scheduler marca la tarea como `failed` si supera el timeout, reintentos siguen política del DAG (si aplica).
```

**Errores comunes**

* Tocar la **lógica** del DAG en lugar de parámetros operacionales.
* Poner timeout irreal: para ETLs locales de ejemplo, **3-10 min** suele ser razonable.


#### Estructura de entrega

Debes entregar una carpeta llamada Actividad18-CC3S2 dentro de tu repositorio personal, con la siguiente estructura:

```
Actividad18-CC3S2/
  README.md
  cambios/
    compose.patch | compose_diff.md
    dockerfile.patch | dockerfile_diff.md
    makefile.patch (si aplica)
  evidencia/
    00_build.txt
    01_up.txt
    02_ps.txt
    03_logs_airflow.txt
    04_topologia.md
    05_net_inspect.txt
    10_compose_diff.md
    11_limits_check.txt
    12_user_check.txt
    13_env_audit.txt
    20_tests.txt
    21_sbom.spdx.json
    22_scan.txt
    23_cve_plan.md
    30_dag_resumen.md
    31_dag_run.txt
    32_timeout_diff.md
  .env.example
```

**README.md (sugerencia)**

* Resumen (~ 400 palabras).
* "Cómo reproducir" (3-6 pasos).
* Decisiones de seguridad clave (no-root, límites, red).
* Cómo correr pruebas y gates (SBOM/scan).
* Qué retos hiciste y cómo validarlos.

* **Timeout extremo**: 3-10 min es razonable para tareas Python normales.

