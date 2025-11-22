### CI/CD y DevSecOps con GitHub Actions y Docker

#### 1. Núcleo de GitHub Actions: del universo GitHub al workflow real

GitHub es, ante todo, una plataforma de alojamiento de código con control de versiones (Git), colaboración mediante *pull requests* y gestión de issues. Sobre esa base aparece GitHub Actions como un motor de automatización "pegado" al repositorio: cada *push*, *pull request* o evento programado puede disparar un *workflow* que compila, prueba, analiza seguridad o despliega una aplicación.

Un *workflow* de GitHub Actions es un archivo YAML dentro de `.github/workflows/`. Allí se define **cuándo** corre (eventos) y **qué hace** (jobs y steps). Aunque normalmente se usa para CI/CD, en realidad es un orquestador general de tareas: desde generar documentación hasta correr scanners de seguridad o construir imágenes Docker.

#### Ejemplo 1 - Workflow de CI DevSecOps

```yaml
name: CI DevSecOps (local-first, no secrets)

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]
  workflow_dispatch: {}

jobs:
  pipeline:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
      security-events: write

    steps:
      - name: Install dev deps
        run: |
          python -m pip install -U pip
          pip install -r requirements-dev.txt

      - name: Build image
        run: docker build -t python-microservice:dev -f docker/Dockerfile .

      - name: Unit tests
        run: pytest -q

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: devsecops-artifacts
          path: artifacts/**
```

En este ejemplo se ve:

* **Eventos**: `push`, `pull_request`, `workflow_dispatch` (manual).
* **Job** `pipeline` ejecutándose en `ubuntu-latest`.
* **Permissions** explícitos, parte importante de la seguridad de Actions.
* **Steps** con `run` (comandos shell) y `uses` (acciones del marketplace, como `actions/upload-artifact`).

En la práctica, "crear un workflow" puede hacerse desde la UI de GitHub o simplemente agregando el archivo YAML al repo. El editor web ayuda con plantillas, pero lo relevante es entender la estructura YAML:

* Mapas (`key: value`) para secciones como `on`, `jobs`, `permissions`.
* Listas (`- item`) para arrays como `branches: [ "main" ]` o listas de steps.
* Escalares (strings, números, booleanos) como `name: CI DevSecOps`.

Ese mismo YAML define **eventos y disparadores**: `push` y `pull_request` son *webhooks* internos de GitHub. `workflow_dispatch` permite disparar manualmente desde la UI. Se pueden agregar programaciones con `schedule` y cron para tareas periódicas.

Dentro de un job, los **steps** se ejecutan en orden. Cada step puede:

* Ejecutar comandos con `run`.
* Invocar acciones externas con `uses` (desde el marketplace).
* Pasar información a los siguientes steps usando salidas y variables de entorno.

Aunque el ejemplo no usa expresiones, GitHub Actions permite interpolar valores con `\${{ ... }}` y acceder a **contexts** como `github`, `env`, `matrix`, etc. Esto habilita lógicas condicionales (`if:`), selección de ramas, uso de variables de entorno o de secretos.

En workflows más avanzados, se puede usar una **estrategia de matriz** (`strategy.matrix`) para ejecutar el mismo job en múltiples combinaciones de Python/OS, algo típico en proyectos de librerías, aunque no aparezca en este fragmento concreto.

La parte de **secrets y variables** se conecta con la seguridad: valores sensibles se almacenan en `Secrets` del repo o de la organización y se accede en el YAML vía `secrets.MI_SECRETO`. Las variables no sensibles (versiones, flags, nombres de imagen) se pueden guardar como *variables* de Actions y usarse vía `vars.MI_VARIABLE`.

Finalmente, **autoría y depuración** implica usar logs de cada step, `workflow_dispatch` para pruebas manuales, y comandos de depuración (por ejemplo, imprimir variables o habilitar `ACTIONS_STEP_DEBUG`). La combinación de permisos mínimos, uso correcto de secrets y logs claros es clave en un entorno DevSecOps.

#### 2. Actions y Docker: contenedores como unidad de entrega

GitHub Actions puede usar contenedores de dos formas:

1. Ejecutar jobs **"dentro de contenedores"** (por ejemplo, `container: image: ...`).
2. Definir **acciones empaquetadas como imágenes Docker** que encapsulan herramientas.

Aunque aquí no se muestra una *Docker action* como tal, el repositorio expone un flujo completo donde el código corre en un contenedor reproducible. El primer paso es empaquetar el microservicio en una imagen:

#### Ejemplo 2 - Dockerfile no-root para el microservicio

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    SERVICE_NAME=python-microservice \
    PORT=8000

RUN useradd -m appuser
WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --upgrade pip && pip install -r requirements.txt

COPY src ./src

EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=2s --retries=5 \
  CMD python -c "import http.client; c=http.client.HTTPConnection('127.0.0.1',8000,timeout=2); c.request('GET','/health'); r=c.getresponse(); exit(0 if r.status==200 else 1)" || exit 1

USER appuser
CMD ["python", "-m", "src.app"]
```

Este Dockerfile ilustra buenas prácticas que encajan perfectamente con GitHub Actions:

* Imagen base ligera (`python:3.12-slim`).
* Variables de entorno para comportamiento de Python y del servicio.
* Usuario no root (`appuser`), importante en DevSecOps.
* *Healthcheck* contra `/health`, que luego será usado por Docker Compose, ZAP y Kubernetes.
* Comando de arranque simple, apuntando al módulo `src.app`.

La aplicación que se empaqueta es un HTTP server mínimo que usa **variables de entorno** para puerto y nombre de servicio:

#### Ejemplo 3 - Microservicio HTTP parametrizado por entorno

```python
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

PORT = int(os.environ.get("PORT", "8000"))
SERVICE_NAME = os.environ.get("SERVICE_NAME", "python-microservice")


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload, content_type="application/json"):
        body = payload if isinstance(payload, (bytes, bytearray)) else json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self._send(200, {"service": SERVICE_NAME, "ok": True})
        elif self.path == "/health":
            self._send(200, {"status": "healthy"})
        else:
            self._send(404, {"error": "not found"})


def main():
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Sirviendo el servicio '{SERVICE_NAME}' en http://0.0.0.0:{PORT} (CTRL+C para detener)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido por KeyboardInterrupt (CTRL+C).")
    finally:
        server.server_close()
        print("Conexiones cerradas. Servidor apagado correctamente.")
```

Este patrón es ideal para integrarse con Actions: el workflow construye la imagen, ejecuta pruebas, genera SBOMs y realiza *scans* de la imagen (`syft`, `grype`), todo en pasos encadenados.

Además, se usa Docker Compose para levantar el microservicio y ejecutar DAST:

#### Ejemplo 4 - Compose para pruebas y healthcheck

```yaml
# Docker Compose para levantar el microservicio localmente con healthcheck en /health
services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
    environment:
      - SERVICE_NAME=python-microservice
      - PORT=8000
    ports:
      - "8000:8000"
    healthcheck:
      test: ["CMD", "python", "-c",
             "import http.client; c=http.client.HTTPConnection('127.0.0.1',8000,timeout=2); "
             "c.request('GET','/health'); r=c.getresponse(); exit(0 if r.status==200 else 1)"]
      interval: 10s
      timeout: 2s
      retries: 5
      start_period: 5s
```

El workflow usa este compose para lanzar el servicio, comprobar `/health` y correr un ZAP baseline, cerrando luego el stack. El uso de contenedores como unidad de ejecución hace que todo el pipeline sea reproducible tanto en la máquina local (Makefile) como en GitHub Actions.

#### 3. Runners y base para Kubernetes / infraestructura propia

Un *runner* de GitHub Actions es la máquina donde se ejecutan los jobs. En el ejemplo, se usa un **runner hospedado por GitHub**:

```yaml
jobs:
  pipeline:
    runs-on: ubuntu-latest
```

Eso significa que la ejecución ocurre en un entorno Linux con herramientas estándar, donde el propio workflow instala Python, dependencias y utilidades como `syft` o `grype`. 
Para muchos proyectos, esto es suficiente; sin embargo, cuando se integra con Kubernetes o infraestructura propia, entran en juego otros tipos de runners.

Los **runners hospedados por GitHub** ofrecen diferentes sistemas operativos (Ubuntu, Windows, macOS), cada uno con un conjunto de software preinstalado. Si hace falta algo adicional (como las herramientas de seguridad en el ejemplo), se instala en un step del workflow. Este modelo es simple y escalable, aunque no permite acceso directo a redes internas cerradas.

Por eso existen los **runners auto-hospedados**, que se instalan en servidores propios, en un clúster on-premises o incluso dentro de Kubernetes. Allí se puede:

* Tener acceso directo a un **cluster Kubernetes** para desplegar manifiestos.
* Hablar con registries privados o servicios internos.
* Instalar herramientas específicas de la organización.

El mismo microservicio que se levantó con Docker Compose puede desplegarse en Kubernetes con un manifiesto como el siguiente:

#### Ejemplo 5 - Deployment y Service en Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: python-microservice
spec:
  replicas: 1
  selector:
    matchLabels:
      app: python-microservice
  template:
    metadata:
      labels:
        app: python-microservice
    spec:
      containers:
        - name: app
          image: python-microservice:dev
          imagePullPolicy: Never
          env:
            - name: SERVICE_NAME
              value: python-microservice
            - name: PORT
              value: "8000"
          # (liveness/readiness probes sobre /health)

apiVersion: v1
kind: Service
metadata:
  name: python-microservice
spec:
  selector:
    app: python-microservice
  ports:
    - name: http
      port: 8000
      targetPort: 8000
  type: ClusterIP
```

Un runner auto-hospedado con acceso al clúster puede aplicar estos manifiestos como parte del pipeline de CD, ejecutando comandos `kubectl` desde los steps. Esto exige:

* **Configuración segura del runner** (cuentas de servicio restringidas, actualizaciones, control de qué repos pueden usarlo).
* Conciencia de los **riesgos de seguridad**: si un workflow malicioso obtiene acceso al runner, puede acceder a la red interna o a credenciales del cluster.
* **Supervisión del runner y de su acceso de red**, asegurando que solo se conecte a los sistemas necesarios y bajo políticas claras (firewalls, listas de control de acceso, etc.).

En entornos más avanzados se utilizan runners efímeros o de "un solo uso", que se crean para un job y se destruyen al terminar. Esto reduce el riesgo de que quede estado persistente o malware entre ejecuciones. Combinado con un buen monitoreo y segmentación de red, se construye una base sólida para integrar GitHub Actions con Docker y Kubernetes dentro de una estrategia DevSecOps coherente: el mismo pipeline que compila, prueba, genera SBOMs y escanea contenedores, termina desplegando la aplicación en un cluster bajo control estricto de permisos y visibilidad.

#### 4. Tipos de CI y pasos genéricos de un workflow

En integración continua (CI) podemos distinguir, a grandes rasgos, varios "tipos" que suelen convivir en un mismo repositorio:

* **CI de integración**: compila, ejecuta pruebas unitarias y de integración para cada *push* o *pull request*.
* **CI de calidad**: ejecuta *linters*, formateadores y análisis estático.
* **CI de seguridad**: SAST (código), SCA (dependencias), escáneres de contenedores.
* **CI de empaquetado**: construye artefactos listos para ser desplegados (imágenes Docker, bundles, etc.).

Aunque los objetivos cambian, casi todos siguen el mismo flujo genérico:

1. Obtener el código del repositorio.
2. Preparar el entorno (lenguaje, dependencias, herramientas).
3. Construir artefactos (binarios, imágenes, paquetes).
4. Ejecutar pruebas y *checks* (unitarias, SAST, SCA, DAST...).
5. Generar reportes, SBOMs y subir artefactos.

Ese flujo se ve claramente en un pipeline de CI DevSecOps:

#### Ejemplo 6 - Pipeline CI DevSecOps con múltiples tipos de CI

```yaml
name: CI DevSecOps

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]
  workflow_dispatch: {}

jobs:
  pipeline:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
      security-events: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dev deps
        run: |
          python -m pip install -U pip
          pip install -r requirements-dev.txt

      - name: Install syft/grype
        run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

      - name: Build image
        run: docker build -t python-microservice:dev -f docker/Dockerfile .

      - name: Unit tests
        run: pytest -q

      - name: SAST (bandit)
        run: bandit -r src -f json -o artifacts/bandit.json || true

      - name: SAST (semgrep)
        run: semgrep --config .semgrep.yml --error --json --output artifacts/semgrep.json || true

      - name: SCA (pip-audit)
        run: pip-audit -r requirements.txt -f json -o artifacts/pip-audit.json || true

      - name: SBOM (syft project + image)
        run: |
          syft packages dir:. -o json > artifacts/sbom-syft-project.json || true
          syft python-microservice:dev -o json > artifacts/sbom-syft-image.json || true

      - name: Image scan (grype)
        run: grype python-microservice:dev -o sarif > artifacts/grype.sarif || true

      - name: Compose up
        run: docker compose up -d --build

      - name: Smoke test /health
        run: |
          sleep 2
          curl -sf http://127.0.0.1:8000/health

      - name: DAST (OWASP ZAP baseline)
        run: |
          docker run --rm -t --network host \
            owasp/zap2docker-stable zap-baseline.py \
            -t http://127.0.0.1:8000 \
            -J artifacts/zap-baseline.json \
            -r artifacts/zap-report.html || true

      - name: Compose down
        if: always()
        run: docker compose down -v

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: devsecops-artifacts
          path: artifacts/**
```

Aquí se mezclan los tipos de CI: integración (tests), calidad (SAST), seguridad (SCA, escaneo de imagen, DAST) y empaquetado (build de imagen).

#### 5. Preparación para el despliegue e imágenes de contenedor

"Preparar para despliegue" hoy significa:

* Tener artefactos reproducibles (imágenes Docker firmadas o verificables).
* Disponer de un SBOM que describa dependencias.
* Generar reportes de seguridad (SAST, SCA, escaneo de imagen).
* Guardar todo como evidencia y, si aplica, crear *releases*.

El paso de build de imagen y los escaneos automatizados son clave:

#### Ejemplo 7 - Bundling de dependencias de desarrollo y herramientas de seguridad

```txt
# requirements-dev.txt
bandit==1.7.9
semgrep==1.86.0
pip-audit==2.7.3
pytest==8.3.3
requests==2.32.3
```

Estas dependencias permiten que el pipeline no solamente pruebe el código, sino que:

* **Bandit** analice patrones peligrosos en Python.
* **Semgrep** verifique reglas personalizadas de seguridad y estilo.
* **pip-audit** detecte vulnerabilidades en dependencias.

El resultado son artefactos de seguridad (`artifacts/*.json`, `*.sarif`) y SBOMs (`sbom-syft-*.json`) listos para ser consumidos por otras herramientas o por procesos de auditoría.

Cuando el pipeline CI construye y publica imágenes (por ejemplo, en un registry), suele haber un workflow específico de "image build & publish". 
En el **ejemplo 6** ya estamos construyendo la imagen y ejecutando los escaneos de seguridad sobre ella (*build* + *scan*), pero todo se queda en modo **local-first**: la imagen solo existe en el runner.
Cuando se quiera pasar a un escenario real de entrega continua, normalmente se tendrá  **otro workflow (o un job separado)** de *image build & publish* que, además de construir y escanear la imagen como en el ejemplo, haga el **login contra el registry** y 
ejecute el **`docker push`** para publicar la imagen en un registro de contenedores (GHCR, Harbor, etc.).

#### 6. CD, entornos y estrategias de despliegue

En **entrega continua (CD)**, tomamos los artefactos que ya pasaron por CI (binarios, imágenes Docker, charts, etc.) y los hacemos llegar a un entorno real de ejecución. De forma simplificada, el flujo es:

* Descargar el artefacto aprobado (release, imagen, chart).
* Desplegarlo en un entorno (`dev`, `staging`, `prod`).
* Verificar que el despliegue está funcionando correctamente.
* Automatizar, en lo posible, la promoción entre entornos, dejando puntos de aprobación manual cuando sea necesario (por ejemplo, antes de ir a producción).

Para que este proceso sea confiable, los sistemas modernos usan **endpoints de salud**. Un *endpoint de salud* (o *health check endpoint*) es una URL especial, típicamente `/health`, que responde algo muy simple como "estoy OK" cuando el servicio está sano. La idea es que herramientas externas (pipelines, balanceadores, Kubernetes) puedan "preguntarle" al servicio si está bien sin necesidad de ejecutar pruebas complejas.

#### Ejemplo 8 - Microservicio con endpoint `/health` para CD

```python
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

PORT = int(os.environ.get("PORT", "8000"))
SERVICE_NAME = os.environ.get("SERVICE_NAME", "python-microservice")

class Handler(BaseHTTPRequestHandler):
    def _send(self, code, payload, content_type="application/json"):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/":
            self._send(200, {"service": SERVICE_NAME, "ok": True})
        elif self.path == "/health":
            self._send(200, {"status": "healthy"})
        else:
            self._send(404, {"error": "not found"})

def main():
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Sirviendo '{SERVICE_NAME}' en http://0.0.0.0:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido por CTRL+C")
    finally:
        server.server_close()

if __name__ == "__main__":
    main()
```

En este código, el endpoint `/health` devuelve un JSON muy simple con `"status": "healthy"`. Eso permite que:

* El **pipeline de CD** ejecute un *smoke test* después del despliegue, por ejemplo con `curl -sf http://.../health`, y falle rápidamente si el servicio no arranca bien.
* **Kubernetes** configure *liveness* y *readiness probes* apuntando a `/health`. Así el orquestador sabe cuándo un pod está listo para recibir tráfico y cuándo debe reiniciarlo.
* Las estrategias de despliegue como:

  * **Zero-downtime deployment**: se lanza una nueva versión mientras la antigua sigue atendiendo. Kubernetes solo redirige tráfico a pods marcados como sanos según `/health`, de modo que los usuarios no perciben caída.
  * **Red–green (blue–green)**: se mantiene un entorno "red" (actual) y uno "green" (nuevo). Primero se despliega la versión nueva y se comprueba su salud con `/health`. Solo cuando está OK se cambia el tráfico del entorno viejo al nuevo; si falla, se regresa al entorno anterior.
  * **Ring-based deployment**: se despliega la nueva versión por "anillos" o grupos (por ejemplo, un pequeño porcentaje de usuarios, luego más, hasta el 100%). En cada anillo se verifica con `/health` (y otras métricas) que la versión se comporta correctamente antes de avanzar al siguiente grupo.


Además, el uso de **variables de entorno** (`PORT`, `SERVICE_NAME`) facilita que el mismo contenedor sirva distintos entornos y nombres lógicos, sin cambios de código.

En CD solemos utilizar **environments** de GitHub Actions (por ejemplo, `staging`, `prod`) con:

* Variables de entorno específicas (URLs, flags).
* *Secrets* por entorno (tokens, claves).
* Aprobaciones manuales antes de desplegar a producción.

Eso permite modelar flujos como: *merge a main -> CI -> CD a dev automático -> CD a producción con aprobación humana*.


#### 7. Seguridad de CI/CD: entradas, pipelines y supply chain

La capa de DevSecOps añade varias preocupaciones:

1. **Evitar "pwn requests"**: pull requests desde forks o actores no confiables no deben tener acceso a secretos ni a runners con privilegios. Por eso es crítico limitar permisos y separar workflows.
2. **Gestionar entrada no confiable**: valores que vienen de usuarios, archivos o HTTP deben validarse. El análisis estático ayuda a detectar patrones peligrosos.

#### Ejemplo 9 - Regla mínima de Semgrep para evitar `eval`/`exec`

```yaml
# .semgrep.yml
rules:
  - id: no-eval-exec
    pattern-either:
      - pattern: eval(...)
      - pattern: exec(...)
    message: "Evitar eval/exec"
    severity: ERROR
    languages: [python]
```

Este tipo de reglas ayudan a gestionar input no confiable impidiendo construcciones peligrosas en el código.

3. **Seguridad de GitHub Actions**: uso de permisos mínimos (`permissions:` en el job), acciones versionadas (no `@master`), separación de workflows "no confiables" sin secretos, y revisión de qué repositorios pueden usar qué runners.

4. **Supply chain security**: conocer qué hay dentro de tus artefactos y verificar la integridad de la cadena de construcción.

El uso de SBOMs y layouts tipo *in-toto* ayuda a establecer garantías:

#### Ejemplo 10 - Layout mínimo de atestación de build

```json
{
  "_type": "layout",
  "steps": [
    {
      "name": "build",
      "expected_materials": [],
      "expected_products": [
        { "pattern": "artifacts/**" }
      ]
    }
  ]
}
```

Este layout define que el paso "build" debe producir artefactos bajo `artifacts/**`. Combinado con una herramienta de atestación, se puede firmar la evidencia de qué se construyó, cómo y cuándo, acercándose a niveles de supply chain más sólidos (estilo SLSA).

#### 8. Trazabilidad, revisión de pares y workflows obligatorios

Para que una organización tenga confianza en sus entregas, no basta con pases verdes: hace falta **trazabilidad** y **revisión de pares** real.

* **Trazabilidad**: poder ir de una incidencia a un commit, de un commit a un pipeline, de un pipeline a una imagen y de una imagen a un despliegue. El uso de SBOMs, reportes y empaquetado de evidencias ayuda.

#### Ejemplo 11 - Empaquetado de evidencias del pipeline

```make
# Empaquetar evidencias del pipeline (logs, reportes, SBOM, etc.)
evidence-pack:
	@echo ">> Empaquetando evidencias en artifacts/evidence-<timestamp>.tar.gz"
	tar -czf artifacts/evidence-$(shell date +%Y%m%d-%H%M%S).tar.gz artifacts .evidence
```

Un objetivo como este permite guardar en un solo archivo las salidas de CI (reportes, SBOM, logs), útil tanto en local como en un job de Actions.

* **Four-eyes principle**: evitar que la misma persona desarrolle y apruebe su propio cambio sin revisión. En GitHub se suele usar un archivo de propietarios de código:

#### Ejemplo 12 - Ejemplo básico de CODEOWNERS

```txt
# CODEOWNERS
src/**      @equipo-backend
tests/**    @equipo-backend @qa-team
.github/**  @devsecops-team
```

Con reglas en el repositorio, se exige que haya *review* de alguno de esos equipos antes de mergear cambios en esas rutas. Eso refuerza separación de funciones (SoD) en la práctica.

* **Workflows obligatorios**: se puede configurar que ciertas ramas solo acepten merges si determinados workflows han pasado (por ejemplo, CI, escaneo de seguridad, verificación de políticas). En la práctica, esto crea un "gate" de DevSecOps: sin CI verde, sin SBOM y sin escaneos, no hay despliegue.

#### 9. Optimización: volumen, artefactos, caché y runners

Una vez que el pipeline es correcto y seguro, aparece el problema de **escala y coste**:

* **Alto volumen de builds**: muchos commits y PRs pueden saturar los runners. Se puede mitigar con:

  * *Concurrency groups* para cancelar pipelines antiguos cuando llega uno nuevo.
  * Split de workflows (por ejemplo, CI rápido por PR y CI completo nocturno).
  * Runners auto-hospedados o más grandes para colas intensas.

* **Coste de artefactos**: almacenar todos los reportes y artefactos indefinidamente es caro y lento.

  * Subir solo lo necesario (p.ej. últimos N builds).
  * Ajustar la retención de artefactos.
  * Comprimir evidencias como en `evidence-pack`.

* **Mejorar rendimiento con caché**: reutilizar dependencias y resultados intermedios.

  * Caches de `pip`, `npm`, etc.
  * Caches de resultados de linters o builds.
  * Evitar volver a construir imágenes idénticas si no cambió el contexto.

* **Optimización de jobs y runners**:

  * Elegir runners apropiados al tipo de carga (CPU intensivo, IO, etc.).
  * Paralelizar jobs independientes. Usa matrices con cuidado para no disparar costes.
  * Minimizar pasos redundantes (por ejemplo, mover ciertas verificaciones a CI nocturno si no son necesarias en cada commit).

Un ejemplo típico es tener un *target* de Makefile o un job de Actions llamado `pipeline` que encadena solo lo imprescindible, y otros workflows "pesados" que corren menos frecuentemente. El siguiente objetivo ilustra un pipeline completo local-first que luego se refleja en Actions:

#### Ejemplo 13 - Pipeline local-first encadenado

```make
# Pipeline completo: desde build hasta evidencias (devsecops local-first)
pipeline: build unit sast sca sbom scan-image compose-up dast evidence-pack
```

La misma idea se puede replicar en GitHub Actions con jobs o workflows separados y reutilizar cachés para acelerar `build`, `unit` y los análisis, manteniendo el balance entre velocidad, coste y profundidad de las pruebas.


En conjunto, estos bloques definen una visión de CI/CD claramente orientada a DevSecOps: múltiples tipos de CI encadenados, preparación cuidadosa del despliegue, CD con entornos y estrategias de rollout, seguridad de pipelines y supply chain, trazabilidad fuerte y optimización pragmática del rendimiento y costos.
