### Actividad: Arquitectura y desarrollo de microservicios con Docker (base) y Kubernetes

> Referencia: [Laboratorio 10](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio10) (material del curso).

La actividad profundiza en conceptos y prácticas de arquitectura de microservicios, asegurando un **flujo base reproducible** con Docker y **SQLite**, y ofreciendo **extensiones opcionales** con Docker Compose y Kubernetes para entornos más complejos.

Tambien se divide en **tres bloques**: conceptualización; empaquetado & verificación; desarrollo & despliegue. Cada bloque incluye:

* **Preguntas teóricas** (discusión y conclusiones en equipo).
* **Tareas prácticas** con comandos y pasos clave (sin pegar código completo).

> **Reglas del laboratorio 10** para esta actividad:
>
> * **Base obligatoria**: Docker + **SQLite** (archivo `app.db`) + puerto **80** en el contenedor + **`pytest -q`**.
> * **Prohibido** usar la etiqueta `latest` en la entrega base (usa SemVer, por ejemplo, `0.1.0`).
> * **Bonus opcional**: Docker Compose y Kubernetes (no reemplazan la base).

### Conceptualización de microservicios

Los monolitos simplifican el arranque inicial, pero se degradan con el crecimiento (despliegues lentos, acoplamiento fuerte, escalado desigual).

#### ¿Por qué microservicios?

* Explica la evolución: **Monolito -> SOA -> Microservicios**.
* Presenta **2 casos** (por ejemplo, e-commerce con picos estacionales, SaaS multi-tenant) donde el monolito se vuelve costoso de operar.

#### Definiciones clave

* **Microservicio**: unidad de despliegue independiente, **una capacidad de negocio** por servicio, contrato definido por **API**.
* **Aplicación de microservicios**: colección de servicios + **gateway**, **balanceo de carga**, **observabilidad** (métricas, logs, trazas).

#### Críticas al monolito

* Dos problemas típicos: **cadencia de despliegue** reducida y **acoplamiento** que impide escalar partes de forma independiente.

#### Popularidad y beneficios

* Cita por qué empresas grandes los adoptaron (por ejemplo, **aislamiento de fallos**, **escalado granular**, **autonomía de equipos**).

#### Desventajas y retos

* Menciona 4 desafíos: **redes/seguridad**, **orquestación**, **consistencia de datos**, **testing distribuido**.
* Mitigaciones: **OpenAPI/contratos**, **pruebas contractuales**, **trazabilidad (Jaeger)**, **patrones de sagas**.

#### Principios de diseño

* **DDD**: límites contextuales para delimitar servicios.
* **DRY** en microservicios: equilibrar librerías comunes vs **duplicación controlada** para reducir acoplamiento.
* Criterios de tamaño: **una capacidad de negocio por servicio** es mejor que reglas rígidas (evita dogmas como "una tabla por servicio").

**Entregable (Bloque 1)**: Conclusiones con ejemplos y decisiones de diseño.

### Empaquetado y verificación con Docker (base obligatoria)

El repositorio de referencia incluye `Dockerfile` y pruebas. Aquí se describen conceptos y pasos; **no se pega código completo**.

#### Dockerfile (multi-stage recomendado)

* **Etapa builder**: compilación de dependencias y artefactos.
* **Etapa runtime**: imagen **slim** (por ejemplo, `python:3.11-slim`), usuario **no-root** (por ejemplo `appuser`), variables de entorno útiles (`PYTHONDONTWRITEBYTECODE=1`, `PYTHONUNBUFFERED=1`), y `ENTRYPOINT` explícito y claro.

#### Imagen, etiquetas y Makefile

* Nombre de imagen **fijo** (ejemplo: `ejemplo-microservice`) y **tag con SemVer** (ejemplo: `0.1.0`). **Evitar `latest`**.
* Targets mínimos en **Makefile**: `build`, `run`, `stop`, `logs`, `clean` (y opcionalmente `test` si encapsula `pytest`).

**Comandos de referencia** (capturar evidencias):

* Construcción:  
  `docker build --no-cache -t ejemplo-microservice:0.1.0 .`
* Ejecución (mapear **80:80**):  
  `docker run --rm -d --name ejemplo-ms -p 80:80 ejemplo-microservice:0.1.0`
* Verificación HTTP:  
  `curl -i http://localhost/api/items/`  -> **200 OK**
* Logs:  
  `docker logs -n 200 ejemplo-ms`
* Limpieza:  
  `docker rm -f ejemplo-ms && docker image prune -f`

#### Base de datos: **SQLite** (obligatoria)

* El servicio **persiste** datos en un archivo `app.db` **dentro del contenedor** (o en un volumen montado para persistencia local).
* **No usar Postgres** en la implementación base.  
  *Bonus teórico*: SQLite es ideal para desarrollo y pruebas por su simplicidad (archivo único, sin servidor), pero Postgres ofrece concurrencia robusta, replicación y soporte ACID en entornos distribuidos.

#### Pruebas (`pytest -q`)

* Cobertura mínima:  
  - `GET /api/items` -> **200 OK** con listado.  
  - `POST /api/items` -> **201 Created** con persistencia verificada.
* Ejecución: `pytest -q` (o `make test` si está configurado).


**Entregable (Bloque 2)**:

* Evidencias en texto plano de: `build`, `run`, `curl`, `logs` y `pytest -q`.
* Breve explicación de por qué **no** se usa `latest` y cómo **SemVer** garantiza reproducibilidad.

#### ¿Por qué no usar `latest`?

El tag `latest` es ambiguo: no indica versión, cambios ni compatibilidad. Puede romper entornos al actualizarse inesperadamente.  
**SemVer** (`MAJOR.MINOR.PATCH`) permite:  
- **Reproducibilidad**: reconstruir exactamente la misma imagen.  
- **Trazabilidad**: saber qué cambios introdujo cada versión.  
- **Despliegues seguros**: promover versiones probadas (por ejemplo de `0.1.0` a `0.1.1` sin sorpresas).

### Desarrollo y despliegue (Compose/K8s como **bonus opcional**)

#### Docker Compose para desarrollo (bonus)

**Teórico**

* Ventajas sobre `docker run` aislado: **declaratividad**, gestión automática de **redes**, **dependencias entre servicios**, soporte para **perfiles** (`profiles`) y entornos reproducibles.
* Conceptos clave: `services`, `volumes`, `networks`, `depends_on`, variables de entorno, **bind mounts** (para recarga en vivo) vs **named volumes** (para datos persistentes).

**Ejercicios (redacción)**

1. **Tres escenarios donde Compose mejora el flujo diario**:
   - **Staging local**: simular producción con múltiples servicios (API + caché + base de datos) en una sola instrucción.
   - **Pruebas de integración**: orquestar dependencias reales (por ejemplo Redis) sin configurar manualmente contenedores.
   - **Recarga en vivo**: bind mount del código fuente para desarrollo rápido con `uvicorn --reload`.

2. **Por qué usar perfiles**:
   - Separa entornos: `dev` (con recarga y volúmenes locales) vs `test` (imágenes limpias, sin bind mounts).
   - Evita ejecutar servicios innecesarios: `docker compose --profile test up`.

3. **Fragmento conceptual de `docker-compose.yml`** (sin código completo):
   - Servicio **api**: imagen personalizada, puerto `8080:80`, bind mount `./app:/app`, comando `uvicorn main:app --reload --host 0.0.0.0 --port 80`.
   - Servicio **cache** (por ejemplo Redis): imagen oficial, puerto interno 6379.
   - `depends_on: [cache]` en el servicio API para garantizar orden de arranque.

**Comandos clave (propósito y efectos)**

* `docker compose up --build`: reconstruye imágenes si cambian, inicia todos los servicios del perfil activo.
* `docker compose logs -f api`: seguimiento en tiempo real de logs del servicio `api` (útil en desarrollo).
* `docker compose down --volumes`: detiene y elimina contenedores, redes y volúmenes nombrados (limpieza total).

#### Comunicación entre microservicios (bonus)

**Teórico**

* **REST vs gRPC**:
  - REST: basado en HTTP/JSON, legible, ampliamente soportado, mayor overhead.
  - gRPC: binario (Protocol Buffers), contratos estrictos, streaming bidireccional, menor latencia (~30-50% menos en payloads grandes).
* **RabbitMQ vs Kafka**:
  - RabbitMQ: colas tradicionales, ACK manual, ideal para tareas puntuales.
  - Kafka: log distribuido, retención configurable, orden garantizado por partición, alta escalabilidad en eventos.

**Ejercicios**

1. **gRPC superior a REST**: procesamiento de transacciones financieras en tiempo real (miles de ops/segundo, payloads estructurados, necesidad de streaming).
2. **Kafka preferible a RabbitMQ**: auditoría de eventos de dominio (por ejemplo `OrderCreated`, `PaymentProcessed`) donde se requiere replay, retención a largo plazo y múltiples consumidores (fraude, analítica, notificaciones).
3. **Plan de pruebas con stubs**:
   - Usar `responses` o `httpx.MockTransport` en `pytest` para simular servicio externo.
   - Flujo:  
     ```python
     def test_create_item_with_external_dependency(mocked_responses):
         mocked_responses.post("http://inventory/api/stock", json={"available": True})
         response = client.post("/api/items", json={"name": "test"})
         assert response.status_code == 201
     ```
   - Validar que el servicio principal no falla si el stub responde con error 500 (resiliencia).


#### Despliegue en Kubernetes local (bonus)

**Teórico**

* Carga de imágenes locales:
  - **kind**: `kind load docker-image ejemplo-ms:0.1.0`
  - **minikube**: `eval $(minikube docker-env)` -> build directo en el clúster.
* Manifiestos mínimos:
  - `Deployment`: réplicas, selector, `readinessProbe` y `livenessProbe` (HTTP `/health`).
  - `Service`: tipo `NodePort` para acceso local.

**Ejercicios**

1. **Paso a paso**:
   - `docker build -t ejemplo-ms:0.1.0 .`
   - `kind load docker-image ejemplo-ms:0.1.0` (o build dentro de minikube).
2. **Estructura de manifiestos** (redacción conceptual):
   - **Deployment**: 2 réplicas, probe HTTP GET `/health` en puerto 80, período 10s, umbrales 3.
   - **Service**: tipo `NodePort`, selector coincide con el deployment, puerto target 80, nodo expone rango 30000-32767.
3. **Operaciones**:
   - `kubectl apply -f k8s/`
   - `kubectl get pods,svc -o wide`
   - `kubectl port-forward svc/ejemplo-ms 8080:80`
   - `kubectl logs <pod-name> -f` -> verificar arranque y salud de cada réplica.


**CI/CD (discursivo)**

**Flujo propuesto (GitHub Actions o similar) opcional**:

1. **Trigger**: push a `main`.
2. **Jobs**:
   - `build`: `docker build -t ejemplo-ms:${{ github.sha }} .`
   - `test`: `docker compose -f compose.test.yml up --abort-on-container-exit`
   - `deploy-staging` (solo si pruebas pasan):
     - Push imagen a registry (o cargar en kind/minikube).
     - `kubectl set image deployment/ejemplo-ms app=ejemplo-ms:${{ github.sha }}`
     - `kubectl rollout status deployment/ejemplo-ms`
3. **Rollback**: `kubectl rollout undo deployment/ejemplo-ms`
4. **Visibilidad**: notificar en Slack/Discord con logs de `kubectl rollout` y enlace a `kubectl describe pod`.


#### Entrega

**Estructura sugerida en tu repositorio personal**

```
Actividad19-CC3S2/
├─ RESPUESTAS.md  # teoría + pasos clave (sin pegar código completo)
└─ evidencia/
   ├─ 01_build.txt
   ├─ 02_run.txt           # ejecución con -p 80:80 + 'docker ps'
   ├─ 03_health.txt        # curl -i http://localhost/api/items -> 200 OK
   ├─ 04_persistencia.txt  # POST + GET posterior con datos nuevos
   ├─ 05_logs.txt          # logs de arranque sin errores
   └─ 06_tests.txt         # salida completa de pytest -q
```

**Bonus** (no sustituye la base):  
- `docker-compose.yml` funcional y documentado.  
- Manifiestos K8s en `k8s/` con `kind` o `minikube` verificados.  
- Flujo CI/CD descrito en `.github/workflows/deploy.yml` (opcional).
