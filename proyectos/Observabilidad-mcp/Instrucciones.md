### Instrucciones para  `Observabilidad-mcp`

#### 0. Estructura del proyecto

Dentro del directorio del proyecto encontrarás:

* `app/` -> Microservicio **FastAPI** instrumentado con **OpenTelemetry** (métricas, logs, trazas).
* `mcp_server/` -> Servidor "**MCP-style**" que consulta **Prometheus**, **Loki** y **Tempo** y expone `/api/summary` para LLMs/agentes.
* `otel/` -> Configuración del **OpenTelemetry Collector**.
* `prometheus/` -> Configuración de **Prometheus**.
* `promtail/` -> Configuración de **Promtail** (envía logs a Loki).
* `grafana/` -> Datasources preconfigurados (Prometheus, Loki, Tempo).
* `scripts/demo-traffic.sh` -> Script que genera tráfico sintético contra la app.
* `docker-compose.yml` -> Define y levanta todo el stack: app, otel-collector, prometheus, loki, promtail, tempo, grafana, mcp-server.
* `Makefile` -> Atajos (`make ...`) para instalar dependencias, levantar el stack, ejecutar tests, escáneres, etc.

#### 1. Prerrequisitos

Antes de empezar, necesitas tener instalado:

1. **Docker + Docker Compose v2**

   * Verifica que el comando `docker compose` funciona.
2. **make**

   * En Linux/WSL suele venir instalado.
   * En macOS suele venir con Xcode Command Line Tools.
3. **Python 3.10+**

   * Para instalar dependencias y ejecutar tests/escáneres
     (para *solo* ver Grafana/Prometheus, bastaría con Docker).

Comprueba rápidamente en una terminal:

```bash
docker --version
docker compose version
python --version
make --version
```

#### 2. Preparar y activar el entorno Python `bdd` (recomendado)

Se recomienda usar un entorno virtual llamado `bdd` en la raíz del proyecto:

1. Eliminar venv viejo (si hay):

   ```bash
   rm -rf bdd
   ```

2. Crear venv nuevo:

   ```bash
   python -m venv bdd
   ```

3. Activar el entorno:

   * Linux / macOS / WSL:

     ```bash
     source bdd/bin/activate
     ```

   * Windows PowerShell:

     ```powershell
     .\bdd\Scripts\Activate.ps1
     ```

Deberías ver el prompt con algo como:

```bash
(bdd) usuario@maquina:~/Observabilidad-mcp$
```

#### 3. Instalar dependencias con `make deps`

En la raíz del proyecto, con el venv `bdd` activado:

```bash
make deps
```

Este target:

* Actualiza `pip`.
* Instala:

  * Dependencias de la app (`app/requirements.txt` -> FastAPI, Uvicorn, OTEL, etc.).
  * Dependencias de desarrollo (`dev-requirements.txt` -> pytest, bandit, pip-audit, etc.).

Si termina sin errores, ya puedes trabajar.


#### 4. Tests y escáneres de seguridad (opcional, pero recomendado)

#### 4.1. Tests unitarios

```bash
make test
```

Equivale a:

```bash
DISABLE_OTEL=1 python -m pytest
```

* Ejecuta tests de la app (incluye `/healthz`).
* No requiere Docker.

#### 4.2. Escáneres de seguridad para el código Python

```bash
make scan-python
```

Hace:

* Crea `.evidence/` si no existe.
* Ejecuta:

  * `bandit -r app` -> SAST para Python.
  * `pip-audit` -> vulnerabilidades en dependencias.

Reportes:

* `.evidence/bandit.txt`
* `.evidence/pip-audit.txt`

#### 5. Levantar todo el stack con `make up`

En la raíz del proyecto:

```bash
make up
```

Este comando:

1. Crea `.evidence/` (si no existe).
2. Ejecuta:

   ```bash
   docker compose up -d --build
   ```

Se construyen las imágenes:

* `devsecops-observability-demo-app:local` (app FastAPI).
* `devsecops-observability-mcp:local` (gateway MCP).

Y se levantan los servicios:

* `app`
* `otel-collector`
* `prometheus`
* `loki`
* `promtail`
* `tempo`
* `grafana`
* `mcp-server`

Comprueba:

```bash
docker ps
```

Deberías ver los contenedores arriba (`Up`).
Si alguno está en `Restarting`, revisa logs:

```bash
docker compose logs otel-collector
docker compose logs app
```

#### 6. Generar tráfico sintético (se puede ejecutar muchas veces)

Para que haya datos en métricas/logs/trazas:

```bash
make demo-traffic
# o equivalente:
./scripts/demo-traffic.sh
```

El script envía peticiones a:

* `GET /healthz`
* `GET /api/v1/items`
* A veces:

  * `GET /api/v1/work`
  * `GET /api/v1/error` (genera 500)

Verás algo como:

```bash
Enviando tráfico de prueba a http://localhost:8000 ...
Listo. Revisa Grafana (http://localhost:3000), Prometheus (http://localhost:9090), Loki y Tempo.
```

**Muy importante:**

Puedes ejecutar `./scripts/demo-traffic.sh` o `make demo-traffic` **varias veces** durante el laboratorio.
Cada ejecución añade más:

* Peticiones HTTP -> más métricas.
* Logs (incluyendo errores) -> más datos en Loki.
* Trazas -> más spans en Tempo.


#### 7. Microservicio FastAPI: comprobaciones básicas

* API base: [http://localhost:8000](http://localhost:8000)
* Documentación Swagger: [http://localhost:8000/docs](http://localhost:8000/docs)

Prueba:

```bash
curl http://localhost:8000/healthz
curl http://localhost:8000/api/v1/items
curl http://localhost:8000/api/v1/error   # generará un 500
```

Verás respuestas y códigos HTTP correspondientes.


#### 8. Uso detallado de **Prometheus**

#### 8.1. Verificar que el target `otel-collector` está UP

1. Abre: [http://localhost:9090](http://localhost:9090)
2. Arriba, menú **Status -> Target health**.
3. Deberías ver algo como:

   * `otel-collector`
   * Endpoint: `http://otel-collector:8889/metrics`
   * `State: UP`

Si `State` no está en `UP`, revisa el contenedor `otel-collector`.


#### 8.2. Primera consulta básica: `up`

1. Ve a la pestaña **Query**.
2. En el cuadro de expresión escribe:

   ```promql
   up
   ```
3. Haz clic en **Execute**.

Deberías ver al menos una serie con algo como:

* `up{instance="otel-collector:8889", job="otel-collector"} = 1`

Si ves "**Empty query result**":

* Asegúrate de que el rango de tiempo (abajo, a la izquierda de la tabla) sea reciente (por ejemplo, la hora actual).
* Verifica que el contenedor `prometheus` y `otel-collector` están en `Up`.


#### 8.3. Filtrar por `job="otel-collector"`

En la misma pantalla de Query:

```promql
up{job="otel-collector"}
```

Pulsa **Execute**.

* Deberías ver exactamente la serie del `otel-collector`.
* Si obtienes "Empty query result", es una buena oportunidad para que el estudiante compare:

  * Lo que ve en **Status -> Target health** (donde aparece `job="otel-collector"`).
  * Que está consultando la **métrica `up`** con ese `job`.

Esto refuerza el concepto de "metric name + labels" en Prometheus.

#### 8.4. Explorar métricas de HTTP exportadas por OTEL

Para que el estudiante no se invente nombres de métricas:

1. En la pestaña **Query**, haz clic en el campo de expresión y escribe `http_` o `http_server`.

2. Prometheus mostrará una lista desplegable de métricas que empiezan con ese prefijo.

3. Selecciona alguna, por ejemplo:

   ```promql
   http_server_requests_total
   ```

   (Si no existe, prueba con otras: `http_server_duration_seconds_count`, etc.)

4. Ejecuta la consulta:

   * Si ves "Empty query result":

     * Asegúrate de haber ejecutado `./scripts/demo-traffic.sh` hace pocos segundos.
     * Amplía el rango de tiempo a "Last 1h" en la parte inferior.

#### 8.5. Ejemplo: tasa de errores 5xx por servicio

Cuando ya detectes cuál es la métrica de requests HTTP, puedes crear una consulta parecida a esta (ajusta el nombre de métrica y **labels** según lo que veas en el autocompletado):

```promql
sum by (service_name) (
  rate(
    http_server_requests_total{
      service_name="demo-app",
      http_status_code=~"5.."
    }[5m]
  )
)
```

Pasos detallados:

1. Ejecuta la consulta **después** de llamar a `/api/v1/error` varias veces (puedes hacerlo con `./scripts/demo-traffic.sh`).
2. Si obtienes "Empty query result":

   * Comprueba que el nombre de la métrica es exactamente el que Prometheus muestra en el autocompletado.

   * Revisa los nombres de los labels en el desplegable (quizás el label se llama `http_status_code` o `http.response.status_code`).

   * Quita filtros hasta encontrar algo que devuelva datos, por ejemplo:

     ```promql
     http_server_requests_total
     ```

   * Luego ve refinando: añade `{service_name="demo-app"}`, etc.

Esta dinámica enseña a **descubrir** las métricas reales antes de ir directo al query "bonito".

#### 9. Uso detallado de **Grafana + Loki**

Abre Grafana: [http://localhost:3000](http://localhost:3000)
Credenciales:

* Usuario: `admin`
* Password: `devsecops`

#### 9.1. Entrar a Explore con Loki

1. En el menú lateral, haz clic en **Explore**.
2. Arriba, selecciona el data source **Loki** (como en tu captura, donde aparece "Loki" en la pestaña).
3. Verás algo como:

   * Un área "Label filters" con `Select label`, `Select value`.
   * Un campo "Line contains".

#### 9.2. Buscar logs usando el *Label browser*

1. Haz clic en **Label browser** (o `Select label`).
2. Elige un label, por ejemplo `job`.
3. En "Select value", busca algo como `demo-app` (o el valor que aparezca en la lista).
4. Haz clic en **Run query**.

Esto construirá automáticamente una consulta del estilo:

```logql
{job="demo-app"}
```

Si te aparece vacío:

* Asegúrate de que:

  * Ejecutaste `./scripts/demo-traffic.sh` recientemente.
  * El rango de tiempo (arriba a la derecha; por ejemplo "Last 6 hours") incluye el momento actual.
* Cambia el rango a "Last 15 minutes" y vuelve a lanzar tráfico.

#### 9.3. Filtrar por texto en el log

Una vez que ya ves líneas de logs:

1. En el bloque "Line contains", escribe por ejemplo `ERROR`.
2. Ejecuta la consulta.

Verás solo las líneas que contienen `ERROR`, normalmente las originadas por peticiones a `/api/v1/error`.

**Ejercicio:

* Encontrar cuántos errores se generaron en los últimos 5 minutos filtrando por label + texto.
* Probar con otras palabras (`WARNING`, `Health`, etc.).

#### 10. Uso detallado de **Grafana + Tempo (trazas)**

En Grafana:

1. Vuelve a **Explore**.
2. Arriba, selecciona el data source **Tempo** (como en tu captura "Tempo").
3. Verás opciones como:

   * Query type: `Search`, `TraceQL`, `Service Graph`.

#### 10.1. Búsqueda básica por servicio (TraceQL)

1. Selecciona **Query type -> TraceQL**.

2. En el cuadro "Enter a TraceQL query or trace ID…" escribe una consulta como:

   ```text
   { service.name = "demo-app" }
   ```

3. Asegúrate de que el rango de tiempo (por ejemplo "Last 1 hour") incluye el momento en que ejecutaste `./scripts/demo-traffic.sh`.

4. Haz clic en **Run query**.

Deberías ver una tabla de trazas en la parte inferior:

* Cada fila corresponde a una traza (un request).
* Puedes hacer clic en una traza para ver el árbol de spans.

Si ves que no aparece nada:

* Genera tráfico con:

  ```bash
  ./scripts/demo-traffic.sh
  ```

  (especialmente endpoints más "pesados" como `/api/v1/work`).
* Vuelve a ejecutar la consulta.

#### 10.2. Ejercicio: localizar trazas de errores

Si sabes que `/api/v1/error` genera errores, puedes intentar un filtro más específico (dependiendo de cómo queden los atributos. Por ejemplo, en OTEL suele haber algo como `http.target`):

Ejemplo de TraceQL (puede cambiar según la instrumentación):

```text
{ service.name = "demo-app", http.target = "/api/v1/error" }
```

#### 11. Servidor MCP-style / Gateway para LLMs (`mcp-server`)

Este servicio consume Prometheus, Loki y Tempo y devuelve resúmenes listos para un LLM.

* Base URL: [http://localhost:8080](http://localhost:8080)
* Swagger: [http://localhost:8080/docs](http://localhost:8080/docs)

#### 11.1. Endpoints clave

* `GET /healthz` -> estado del gateway.

  ```bash
  curl http://localhost:8080/healthz
  ```

* `GET /api/metrics-summary` -> resumen de métricas (usa Prometheus).

* `GET /api/logs-summary` -> resumen de errores recientes (usa Loki).

* `GET /api/traces-summary` -> resumen de trazas (usa Tempo).

* `GET /api/summary` -> resumen unificado.

Ejemplo:

```bash
curl http://localhost:8080/api/summary | jq .
```

Mira cómo el JSON combina:

* Métricas: tasas de peticiones, ratios de error.
* Logs: ejemplos de mensajes de error.
* Trazas: conteos de trazas recientes, etc.

**Ejercicios:**

* Generar varios errores (ejecutar varias veces `./scripts/demo-traffic.sh`).
* Llamar a `/api/summary`.
* Ver cómo cambian los valores de error rate y los ejemplos de logs.

#### 12. Ver logs de la app desde la terminal (`make logs`)

Si quieres seguir los logs  desde la consola:

```bash
make logs
```

Esto ejecuta:

```bash
docker compose logs -f app
```

Deberías ver:

* Peticiones a endpoints.
* Mensajes de salud, de errores simulados, etc.

Es la misma información que luego recoge Promtail para Loki.


#### 13. Escanear la imagen Docker con Trivy (opcional)

Para integrar la parte DevSecOps:

```bash
make scan-image
```

Este target:

1. Construye la imagen de la app (si no existe):

   ```bash
   docker compose build app
   ```

2. Lanza Trivy:

   ```bash
   docker run --rm aquasec/trivy image devsecops-observability-demo-app:local
   ```

Reporte:

* `.evidence/trivy-image.txt`

**Ejercicio:**

* Busca en el reporte las vulnerabilidades "HIGH/CRITICAL".
* Discute qué significan y cómo se podrían mitigar.


#### 14. Apagar todo el stack (`make down`)

Cuando termines el laboratorio:

```bash
make down
```

Ejecuta:

```bash
docker compose down
```

y detiene todos los contenedores (`app`, `prometheus`, `grafana`, `loki`, `tempo`, etc.).

Si quieres además borrar volúmenes/datos:

```bash
docker compose down -v
```

> Esto borra las métricas/logs/trazas guardadas. Solo úsalo si no las necesitas.


Con esto no solo "ven pantallas vacías", sino que tienen una ruta clara:

1. generar tráfico, 2) comprobar targets en Prometheus, 3) construir queries paso a paso, 4) usar correctamente los exploradores de Loki y Tempo, y 5) relacionar todo con el resumen que entrega el servidor MCP.
