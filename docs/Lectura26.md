### **Observabilidad** en **DevSecOps**

En un entorno de **DevSecOps** moderno no basta con saber solo si el sistema está disponible o caído, es decir, si responde o no a las solicitudes. La **observabilidad** busca responder con rapidez a preguntas del tipo **qué está pasando** y **por qué está pasando**, utilizando **métricas**, **logs** y **trazas distribuidas**, además de otros tipos de **telemetría** que ayudan a entender el comportamiento interno del sistema.

El **monitoreo** tradicional suele centrarse en paneles que muestran si un servicio está operativo. La **observabilidad** va un paso más allá y se diseña desde el código y la arquitectura para poder inferir el estado interno del sistema a partir de sus salidas.

En **DevSecOps** esto se traduce en cuatro ejes:

* **Fiabilidad:**
  Podemos relacionar errores en producción con cambios recientes en el código o en la infraestructura, detectar regresiones y medir objetivos de **SLO** y **SLI**.

* **Seguridad:**
  Los **logs de seguridad** y los **eventos de auditoría** permiten detectar intentos de ataque, abuso de credenciales o configuraciones peligrosas.

* **Estrategias de despliegue:**
  En despliegues **canary**, **blue green**, **shadow** o pruebas **A/B**, las **métricas** y **trazas** permiten decidir si un cambio es seguro antes de exponerlo a todos los usuarios.

* **Postmortems y mejora continua:**
  Tras un incidente, los datos de **métricas**, **logs** y **trazas distribuidas** permiten reconstruir la historia y aprender de forma sistemática.

Código de ejemplo de un microservicio en Python que desde el primer día piensa en observabilidad:

```python
from flask import Flask, jsonify
import logging
import json
import sys
import time
from prometheus_client import Counter, Histogram, generate_latest

app = Flask(__name__)

# Métrica de negocio
REQUEST_COUNT = Counter(
    "api_requests_total",
    "Número total de solicitudes por endpoint y método",
    ["endpoint", "method"]
)

# Métrica de rendimiento
REQUEST_LATENCY = Histogram(
    "api_request_latency_seconds",
    "Latencia de la solicitud en segundos",
    ["endpoint"]
)

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "service": "api-service",
            "environment": "prod",
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S")
        }
        # Si el log trae campos extra, los agregamos
        if hasattr(record, "extra_data"):
            log_record.update(record.extra_data)
        return json.dumps(log_record)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())

logger = logging.getLogger("api")
logger.setLevel(logging.INFO)
logger.handlers = [handler]
logger.propagate = False

@app.route("/health")
def health():
    return jsonify(status="ok")

@app.route("/v1/items")
def list_items():
    start = time.time()

    REQUEST_COUNT.labels(endpoint="/v1/items", method="GET").inc()

    logger.info(
        "Listando items",
        extra={
            "extra_data": {
                "endpoint": "/v1/items",
                "operation": "list_items"
            }
        }
    )

    items = [{"id": 1, "name": "demo"}]

    latency = time.time() - start
    REQUEST_LATENCY.labels(endpoint="/v1/items").observe(latency)

    logger.info(
        "Respuesta enviada",
        extra={
            "extra_data": {
                "endpoint": "/v1/items",
                "operation": "list_items",
                "latency_seconds": latency
            }
        }
    )

    return jsonify(items=items)

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": "text/plain"}

```

Este servicio expone métricas para Prometheus, escribe logs estructurados en formato JSON y tiene un endpoint de salud, lo que lo hace apto para pipelines y despliegues controlados y para ser integrado con soluciones como Grafana Loki.

La **observabilidad** se construye a partir de diferentes tipos de **telemetría** que el sistema emite de forma continua. A grandes rasgos tenemos:

* **Métricas:**
  Valores numéricos agregados en el tiempo que permiten ver tendencias y disparar alertas.

* **Logs:**
  Mensajes detallados que describen eventos discretos, generalmente con contexto especializado.

* **Trazas distribuidas:**
  Representan el recorrido de una solicitud a través de múltiples servicios mediante **spans** encadenados.

* Otros tipos de telemetría:

  * **Perfiles** de CPU y memoria para entender consumo de recursos.
  * **Eventos de auditoría** para seguridad y cumplimiento.
  * **Heartbeats** y **health checks** para saber si los componentes clave siguen vivos.

En un sistema de **DevSecOps**, un evento importante debería dejar rastro en al menos dos tipos de telemetría. Por ejemplo, un error crítico en una API genera una entrada en el **log**, incrementa una **métrica de errores** y se refleja en una **traza distribuida**.

**Ejemplo conceptual** en pseudocódigo Python que combina **métricas**, **logs estructurados** y **trazas distribuidas**.  Se asume que `logger` ya está configurado con un formateador JSON como en los ejemplos anteriores y que `REQUESTS_TOTAL`, `ERRORS_TOTAL` y `tracer` están definidos.

```python
import logging

# Se asume que este logger ya está configurado con un JsonFormatter
logger = logging.getLogger("payments")

def process_payment(user_id, amount):
    span = tracer.start_as_current_span("process_payment")
    try:
        # Métrica de peticiones al flujo de pago
        REQUESTS_TOTAL.labels(endpoint="process_payment").inc()

        # Log estructurado de inicio de operación
        logger.info(
            "Procesando pago",
            extra={
                "extra_data": {
                    "user_id": user_id,
                    "amount": amount,
                    "operation": "process_payment"
                }
            }
        )

        # Llamada a la pasarela o lógica de cobro
        charge_card(user_id, amount)

        # Atributos de la traza
        span.set_attribute("payment.status", "success")
        span.set_attribute("payment.amount", amount)

    except Exception as exc:
        # Métrica de errores en el flujo de pago
        ERRORS_TOTAL.labels(endpoint="process_payment").inc()

        # Log estructurado de error
        logger.error(
            "Error procesando pago",
            extra={
                "extra_data": {
                    "user_id": user_id,
                    "amount": amount,
                    "operation": "process_payment",
                    "error": str(exc)
                }
            }
        )

        span.set_attribute("payment.status", "error")
        span.set_attribute("payment.error", str(exc))
        raise

    finally:
        span.end()
```

Aquí se ve cómo un mismo flujo afecta a **métricas**, **logs** y **trazas** de forma coherente.

### Concepto de **métricas** y buenas prácticas

Las **métricas** son la base del monitoreo cuantitativo en un sistema orientado a **DevSecOps**. Una métrica es un valor numérico que se registra con una **marca de tiempo** y, normalmente, acompañado de **etiquetas** que aportan contexto como el servicio, el entorno o el endpoint. 
Al almacenar estos valores en el tiempo se obtienen **series temporales** que permiten ver tendencias, detectar anomalías y disparar alertas de forma automatizada.

Existen varios tipos básicos de métricas, cada uno con un propósito diferente:

* **Counters:**
  Un **counter** es una métrica que solo puede **aumentar** o volver a cero cuando se reinicia el proceso. Es ideal para contar cosas como el **número de peticiones** HTTP procesadas, el **número de errores** o el **número de intentos de inicio de sesión**. A partir de un counter se pueden calcular tasas de eventos por segundo o por minuto, que son muy útiles para detectar picos de tráfico o aumentos en errores.

* **Gauges:**
  Un **gauge** es una métrica que puede **subir y bajar** en el tiempo. Se usa para representar estados actuales como **conexiones activas**, **tamaño de una cola**, **uso de memoria** o **número de hilos en ejecución**. Es una fotografía del valor en un momento dado y permite ver cómo se comporta un recurso en función de la carga.

* **Histograms:**
  Un **histogram** agrupa observaciones en **rangos o buckets**. Esto es fundamental para entender la **distribución de latencias** u otros valores de rendimiento. En lugar de saber solo el promedio, un histograma permite ver qué porcentaje de peticiones fue más rápido que cien milisegundos, cuánto fue más lento que uno o dos segundos y así identificar colas largas o comportamientos patológicos.

* **Summaries:**
  Un **summary** calcula **cuantiles** y otros agregados de forma local en el cliente. Puede devolver directamente valores como el p90 o p99 de la latencia. En entornos donde se usa **Prometheus** de forma centralizada se suele preferir **histograms**, porque permiten combinar datos de muchos servicios de manera más flexible en el servidor de métricas.

En **DevSecOps** no se trata solo de recolectar métricas, sino de organizarlas siguiendo marcos conceptuales que ayuden a priorizar qué medir:

* **Golden Signals:** Se centran en cuatro señales esenciales:
  
  - **Latencia** para medir cuánto tarda en responder el sistema.
  - **Tráfico** para saber cuánta carga está recibiendo.
  - **Errores** para detectar fallos funcionales o técnicos.
  - **Saturación** para ver qué tan cerca está el sistema de su límite de capacidad.

* Patrón **RED**: Diseñado para microservicios, se basa en tres componentes:

  - **Rate** que es la tasa de peticiones procesadas.
  - **Errors** que representa la tasa de peticiones fallidas.
  - **Duration** que refleja la duración de las peticiones.

* Patrón **USE**:  Enfocado en componentes de infraestructura como discos o CPU.
  
  - **Utilización** para indicar qué porcentaje del recurso se está usando.
  - **Saturación** para mostrar colas o esperas cuando el recurso está al límite.
  - **Errores** para capturar fallos de hardware o problemas de operación.

Respecto a protocolos y formatos, en la práctica suelen usarse:

* El formato de texto de **Prometheus** y **OpenMetrics** para exponer métricas en endpoints HTTP que pueden ser recolectados por scrapers.
* **OpenTelemetry Metrics** cuando se busca una instrumentación más agnóstica del backend y se desea enviar la telemetría a distintos sistemas de observabilidad usando un **collector**.

Al definir métricas en un contexto de **DevSecOps** es fundamental seguir ciertas buenas prácticas:

* **Nombres y convenciones:**
  Diseñar nombres descriptivos y consistentes. Por ejemplo:
  **service_http_requests_total** indica que es una métrica de un servicio, relacionada con peticiones HTTP y que es un total acumulado.
  Cuando aplica, incluir la **unidad** en el nombre, como **service_http_request_duration_seconds** para dejar claro que la duración está en segundos.

* **Etiquetas y cardinalidad:**
  Utilizar **labels** para capturar dimensiones relativamente estables como **endpoint**, **método HTTP**, **código de estado**, **servicio** o **entorno**.
  Evitar etiquetas con valores muy variables como identificadores de usuario, direcciones IP únicas o identificadores de sesión, ya que eso dispara la **cardinalidad** y puede hacer que el sistema de métricas sea costoso de almacenar y difícil de operar.

* **Métricas de negocio y técnicas:**
  No basta con medir solo errores de infraestructura o de código. Es importante incluir **métricas de negocio** como **pagos fallidos**, **órdenes incompletas**, **ratio de conversión** o **registros de usuario fallidos**.
  Esto permite conectar la salud técnica del sistema con el impacto real sobre el negocio y la experiencia del usuario.

* **Métricas por servicio y entorno:**
  Incluir siempre etiquetas que indiquen el **servicio** y el **entorno** como **service** y **environment**.
  Esto facilita separar métricas de **producción**, **staging** y **entornos de prueba**, y además ayuda a filtrar por microservicio cuando se investigan incidentes o se revisan paneles de observabilidad.

Con este enfoque, las **métricas** dejan de ser números sueltos y pasan a ser un lenguaje común entre desarrollo, operaciones y seguridad dentro de un equipo de **DevSecOps**, lo que permite tomar decisiones informadas sobre rendimiento, confiabilidad y riesgo.


Ejemplo de definición de métricas con buenas prácticas en Python:

```python
from prometheus_client import Counter, Histogram

HTTP_REQUESTS_TOTAL = Counter(
    "service_http_requests_total",
    "Número total de solicitudes HTTP por método, código y servicio",
    ["service", "method", "code", "environment"]
)

HTTP_REQUEST_DURATION = Histogram(
    "service_http_request_duration_seconds",
    "Histograma de duración de solicitudes HTTP en segundos",
    ["service", "endpoint", "environment"],
    buckets=[0.05, 0.1, 0.25, 0.5, 1, 2, 5]
)

def track_request(service, endpoint, method, code, environment, duration):
    HTTP_REQUESTS_TOTAL.labels(
        service=service,
        method=method,
        code=code,
        environment=environment
    ).inc()

    HTTP_REQUEST_DURATION.labels(
        service=service,
        endpoint=endpoint,
        environment=environment
    ).observe(duration)
```

Este tipo de diseño facilita luego la construcción de **SLI** y **alertas** coherentes.

#### Monitoreo de **métricas** con **Prometheus**

**Prometheus** se ha convertido en una pieza central para el monitoreo de **métricas** en muchos entornos de **DevSecOps**, porque combina recolección de datos, almacenamiento en una base de series temporales y un lenguaje de consultas pensado para detectar problemas de forma temprana y automatizable.

Su modelo de funcionamiento se apoya en varios conceptos clave.

* **Modelo pull:**
  Prometheus utiliza un **modelo pull**, lo que significa que es el propio servidor de Prometheus el que **consulta periódicamente** a los servicios y componentes que queremos monitorear, llamados **targets**, para obtener las métricas.
  Cada target expone un endpoint HTTP de solo lectura, normalmente `/metrics`, donde publica sus métricas en formato de texto compatible con **Prometheus**. El servidor Prometheus hace peticiones a esos endpoints en intervalos configurables, por ejemplo cada quince segundos, y va almacenando los valores que recibe con su marca de tiempo.

  Este enfoque facilita el control desde el lado de la plataforma, simplifica la seguridad en muchos escenarios y encaja bien con entornos donde los servicios son efímeros, como en Kubernetes.

* **Targets y jobs:**
  Un **target** es una instancia concreta de un servicio o componente, por ejemplo `api-service-1` escuchando en `api-service-1:8000`. En la configuración de Prometheus se agrupan uno o más targets bajo un **job**, que representa un conjunto lógico de instancias que comparten propósito y configuración de scraping.
  Por ejemplo, todas las instancias del servicio de API pueden pertenecer al job `api-service`, mientras que las instancias de la base de datos pueden estar en otro job llamado `db-metrics`. Esto permite aplicar una frecuencia de scrape distinta, reglas de descubrimiento de servicios diferentes o etiquetas por defecto para cada grupo.

  En entornos modernos, los targets suelen descubrirse de forma automática mediante mecanismos de **service discovery** integrados con Kubernetes, sistemas de registro de servicios o configuraciones dinámicas, lo que hace que la lista de targets se adapte a los despliegues y escalados sin cambios manuales.

* **Series temporales y etiquetas:**
  Internamente, Prometheus almacena las métricas como **series temporales**. Cada serie temporal se identifica por el **nombre de la métrica** y por un conjunto de **etiquetas** o **labels** que aportan contexto, como el servicio, el entorno, el método HTTP o el código de estado.

  Por ejemplo, la métrica:

  `service_http_requests_total{service="api-service", method="GET", code="200", environment="prod"}`

  representa una serie concreta que cuenta el número de peticiones GET exitosas en producción para el servicio de API. Otra combinación de etiquetas, por ejemplo `code="500"`, sería otra serie distinta.

  Este modelo basado en **labels** permite filtrar y agrupar fácilmente los datos en consultas posteriores con **PromQL**, de modo que se pueden construir gráficos, indicadores de nivel de servicio y alertas específicas por servicio, entorno, ruta o cualquier dimensión que se haya modelado mediante etiquetas, lo que resulta especialmente útil en escenarios de **DevSecOps** con muchos microservicios y despliegues frecuentes.


Ejemplo mínimo de configuración de **Prometheus** para un microservicio:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "api-service"
    static_configs:
      - targets:
          - "api-service:8000"
        labels:
          environment: "prod"
          service: "api-service"
```

La **PromQL** es el lenguaje de consultas de **Prometheus**. Permite calcular tasas, promedios, percentiles y combinaciones complejas.

Ejemplos de consultas **PromQL** típicas en DevSecOps:

```promql
# Tasa de errores 5xx en la API
sum by (service) (
  rate(service_http_requests_total{code=~"5..", environment="prod"}[5m])
)

# Latencia p95 de un endpoint específico
histogram_quantile(
  0.95,
  sum by (le) (
    rate(
      service_http_request_duration_seconds_bucket{
        endpoint="/v1/items",
        environment="prod"
      }[5m]
    )
  )
)

# Error budget usado en los últimos treinta minutos
1 - (
  sum(
    rate(service_http_requests_total{code=~"2..", environment="prod"}[30m])
  )
  /
  sum(
    rate(service_http_requests_total{environment="prod"}[30m])
  )
)
```

Las reglas de grabación y las alertas se definen en archivos de configuración:

```yaml
groups:
  - name: api_rules
    rules:
      - record: job:http_request_errors_5xx_rate
        expr: |
          sum by (service) (
            rate(service_http_requests_total{code=~"5..", environment="prod"}[5m])
          )

      - alert: HighErrorRate
        expr: job:http_request_errors_5xx_rate > 0.05
        for: 10m
        labels:
          severity: "critical"
        annotations:
          summary: "Tasa alta de errores 5xx en la API"
          description: "La tasa de errores 5xx supera cinco por ciento por más de diez minutos"
```

Con esto se conecta el mundo de las **métricas** con la operación diaria y la respuesta a incidentes.

#### **Logs** con **Grafana Loki**

En **DevSecOps** los **logs** dejan de ser simples líneas de texto que alguien revisa a mano solo cuando hay problemas. Se convierten en una fuente de **telemetría central**, diseñada para ser consultada, agregada y correlacionada con **métricas** y 
**trazas** de forma sistemática.

Dentro de un sistema moderno podemos distinguir varios tipos de **logs** que aportan perspectivas complementarias:

* **Logs de aplicación:**
  Son los mensajes que genera el **código de negocio**. Idealmente se escriben en formato estructurado como JSON y siempre incluyen **contexto** relevante.
  Por ejemplo:

  * Identificadores de la operación como el endpoint o el comando ejecutado.
  * Información del usuario o cliente cuando es apropiado y permitido.
  * Resultado de la operación como éxito, error de validación o fallo interno.
    Estos logs permiten responder preguntas como "qué estaba haciendo la aplicación cuando se produjo este error" o "cuántas veces falló este flujo de negocio en la última hora". En un enfoque de **DevSecOps** son muy útiles para análisis de incidentes y para entender el impacto real de un fallo sobre los usuarios.

* **Logs de infraestructura:**
  Son los mensajes que provienen de componentes como **contenedores**, **orquestadores**, **nodos de Kubernetes**, **proxies** o **balanceadores de carga**.
  Incluyen información sobre:

  * Inicios y paradas de contenedores.
  * Reemplazo de pods durante despliegues.
  * Errores de red o de resolución de nombres.
  * Estados de salud de los nodos y servicios de plataforma.
    Estos logs ayudan a correlacionar problemas de la aplicación con eventos de la capa de infraestructura. Por ejemplo un incremento en errores de la API puede coincidir con un rolling update o con problemas de conectividad entre servicios.

* **Logs de seguridad y auditoría:**
  Estos logs registran **accesos**, **cambios de configuración**, **eventos de autenticación y autorización**, además de acciones sensibles como escalado de privilegios o modificación de políticas.
  Son fundamentales para:

  * Investigar incidentes de seguridad.
  * Cumplir requisitos de auditoría y normativas.
  * Detectar patrones anómalos como muchos intentos de inicio de sesión fallidos desde la misma dirección IP.
    En un contexto de **DevSecOps** se integran con reglas de detección, paneles de seguridad y flujos de respuesta a incidentes.

**Grafana Loki** está diseñado específicamente para almacenar y consultar **logs** siguiendo una filosofía muy cercana a la de **Prometheus**. En lugar de indexar todo el contenido de los mensajes, Loki se centra en **etiquetas** o **labels** como **service**, **environment**, **cluster** o **level**, y agrupa los logs en **streams** que se identifican por el conjunto de etiquetas.

Este enfoque basado en etiquetas ofrece varias ventajas para **DevSecOps**:

* Facilita la **correlación** con métricas de Prometheus, ya que se usan etiquetas similares. Por ejemplo las métricas de un servicio usan **service="api"** y **environment="prod"**, y los logs del mismo servicio también se etiquetan de esa forma. En Grafana es posible navegar de un panel de métricas a los logs relacionados con un clic.
* Permite controlar mejor la **cardinalidad**. En lugar de indexar cada palabra de los logs se indexan solo las etiquetas. Esto reduce el coste de almacenamiento y hace que el sistema sea más predecible, siempre que se diseñen etiquetas estables y con un número de valores razonable.
* Favorece un diseño de logs **estructurados**. Aunque los mensajes pueden ser texto libre, en la práctica se recomienda enviar JSON u otro formato estructurado, de modo que **LogQL** pueda extraer campos como `user_id` o `order_id` y utilizarlos en filtros y agregaciones cuando se necesite hacer análisis detallado.

En un pipeline de **DevSecOps**, los **logs** enviados a **Loki** permiten construir vistas unificadas por servicio, por entorno y por tipo de evento, alimentar alertas basadas en patrones de log y apoyar tanto a los equipos de desarrollo como a los de operaciones y seguridad en la detección y resolución de problemas.


Ejemplo de log estructurado en Python apto para Loki:

```python
import json
import logging
import sys

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
            "service": "api-service",
            "environment": "prod"
        }
        if hasattr(record, "user_id"):
            log_record["user_id"] = record.user_id
        return json.dumps(log_record)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JsonFormatter())
logger = logging.getLogger("api")
logger.setLevel(logging.INFO)
logger.addHandler(handler)

def login(user_id):
    logger.info("Usuario autenticado", extra={"user_id": user_id})
```

Una vez que estos **logs** llegan a **Loki**, se pueden consultar con **LogQL**. 

**Ejemplos típicos:**

```logql
# Buscar errores de la API
{service="api-service", environment="prod"} |= "ERROR"

# Contar logins por minuto
sum by (service) (
  rate({service="api-service"} |= "Usuario autenticado" [1m])
)

# Extraer campos de un log JSON y filtrar por usuario
{service="api-service", environment="prod"}
| json
| user_id="1234"
```

El diseño de **label sets** en Loki es crítico para controlar el coste y evitar explosiones de cardinalidad. Conviene etiquetar por **servicio**, **entorno**, **nivel de log** y quizá por **cluster**, pero evitar etiquetas con valores demasiado variables.

#### **Trazas distribuidas** con **OpenTelemetry** y **Tempo**

Las **trazas distribuidas** permiten ver el recorrido completo de una solicitud a través de muchos **microservicios**, mostrando cómo va saltando de componente en componente mediante **spans** que juntos forman una **trace**. Cada **span** describe una operación concreta e incluye **atributos** que aportan contexto, **eventos** que marcan hitos importantes y un **estado** que indica si la operación fue exitosa o falló, además de su duración.

**Fundamentos:**

* Un **span** representa una operación específica dentro de un sistema distribuido, por ejemplo una llamada a base de datos, una invocación a otro microservicio o el procesamiento de una cola. En cada span se registran datos como el nombre de la operación, el tiempo de inicio y fin, etiquetas con información de contexto y eventos internos relevantes.

* Una **trace** es el conjunto de spans encadenados que representan el recorrido de una única solicitud a través del sistema. Suele comenzar en el punto de entrada, como una petición HTTP al frontend o a la API, y continúa pasando por todos los servicios que participan en el procesamiento hasta que la respuesta se completa. Esto permite reconstruir la historia de la solicitud de extremo a extremo.

* El **contexto de trazas** se propaga entre servicios a través de **cabeceras estandarizadas** en las peticiones, de modo que cada servicio puede enlazar sus spans con los anteriores. Este contexto incluye identificadores de trace y de span padre, y se transmite en protocolos como HTTP o mensajería. Gracias a esa propagación es posible mantener la continuidad de la trace aunque la solicitud pase por varios procesos, contenedores o nodos.

**OpenTelemetry** proporciona **SDK** y **agentes** que facilitan la instrumentación de servicios para generar estas trazas. Con OpenTelemetry se pueden crear spans de manera automática o manual, añadir atributos y eventos y exportar las trazas mediante el protocolo **OTLP** hacia distintos backends de observabilidad. Todo esto se hace respetando el estándar **W3C Trace Context**, que define cómo deben propagarse los identificadores de trace y span en las cabeceras, lo que garantiza interoperabilidad entre diferentes lenguajes, frameworks y plataformas dentro de un entorno de **DevSecOps**.


Ejemplo básico de instrumentación con **OpenTelemetry** en un servicio FastAPI:

```python
from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

resource = Resource.create(
    {
        "service.name": "api-service",
        "service.environment": "prod"
    }
)

provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(
    OTLPSpanExporter(endpoint="http://otel-collector:4318/v1/traces")
)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

tracer = trace.get_tracer(__name__)
app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

@app.get("/v1/items")
async def list_items():
    with tracer.start_as_current_span("fetch_items_from_db") as span:
        span.set_attribute("db.system", "postgres")
        # Simular operación
        items = [{"id": 1, "name": "demo"}]
        return {"items": items}
```

El **collector de OpenTelemetry** puede enviar estas trazas a **Tempo**, el backend de trazas de la **Grafana stack**. Una vez allí, se consultan con **TraceQL**.

Ejemplos de **TraceQL**:

```text
# Trazas donde la operación principal tardó más de dos segundos
{ span.duration > 2s && span.name = "GET /v1/items" }

# Trazas con código de respuesta cinco cero cero
{ span.attributes["http.status_code"] = 500 }

# Trazas donde hay un span de base de datos lento
{ .span[span.name = "fetch_items_from_db" && span.duration > 500ms] }
```

Buenas prácticas de **tracing** en **DevSecOps**:

* Diseñar atributos estándar como **service.name**, **service.environment**, **deployment.version**.
* Asegurar la **propagación de contexto** entre microservicios mediante cabeceras estándar.
* Controlar el **muestreo** para no saturar el sistema y mantener trazas representativas de las rutas críticas.

#### **Grafana stack** integrado y **alerting**

La **Grafana stack** reúne **Prometheus**, **Loki**, **Tempo** y otros componentes bajo un mismo panel. **Grafana** actúa como **single pane of glass** para **métricas**, **logs** y **trazas distribuidas**.

Con **Grafana** es posible:

* Crear dashboards que combinan **SLI** de disponibilidad, latencia y errores.
* Diseñar paneles por equipo, por ejemplo uno para plataforma, otro para seguridad y otro para producto.
* Hacer drill down desde una métrica a los **logs** y de ahí a la **traza** relevante.

En cuanto a **alerting**, Grafana permite unificar alertas basadas en:

* **Métricas:**
  Por ejemplo porcentaje de errores de una API o uso de CPU.

* **Logs:**
  Detección de patrones específicos como mensajes de error o eventos de seguridad.

* **Trazas:**
  Latencias anómalas en rutas críticas o excesivos reintentos.

Ejemplo de regla de alerta basada en una métrica de **Prometheus** definida en Grafana:

```yaml
apiVersion: 1

groups:
  - orgId: 1
    name: api_alerts
    folder: api
    rules:
      - uid: high_error_rate
        title: "Alta tasa de errores 5xx en api service"
        condition: "A"
        data:
          - refId: A
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: prometheus
            model:
              expr: |
                sum by (service) (
                  rate(service_http_requests_total{code=~"5..", environment="prod"}[5m])
                )
              interval: ""
              legendFormat: "{{service}}"
              refId: A
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Error rate elevada en api service"
          description: "Revisar despliegues recientes y logs de la API"
```

Buenas prácticas de **alerting** en **DevSecOps**:

* Evitar el **ruido** limitando las alertas a condiciones accionables.
* Usar etiquetas como **service**, **environment**, **severity** para agrupar y enrutar.
* Integrar con herramientas de **incident management** y equipos **on call**.

#### Ciclo de vida de **DevSecOps** con **observabilidad** y **métricas**

La **observabilidad** bien diseñada atraviesa todo el ciclo de vida de **DevSecOps**, desde que se escribe el código hasta 
que el sistema está en producción y bajo monitoreo continuo. No es un "add on" al final, sino algo que influye en cómo se programa, cómo se construye la **pipeline** y cómo se operan los servicios.

En el código:

* La **instrumentación** se piensa desde el inicio. Cada servicio se diseña para exponer **métricas**, generar **logs estructurados** y emitir **trazas distribuidas** que permitan entender qué hace el sistema y cómo se comporta bajo carga o ante errores.
* Se definen **métricas de seguridad y cumplimiento** que midan aspectos como **intentos de login fallidos**, **políticas de acceso rechazadas**, **tokens inválidos** o **accesos no autorizados**. Estas métricas ayudan a detectar patrones de ataque, abusos de credenciales o errores de configuración.
* Se cuida la **higiene de logs** evitando **logs sensibles** que contengan datos personales, secretos, tokens o información que pueda usarse para comprometer el sistema. Se favorece el uso de identificadores anónimos o seudónimos cuando es necesario correlacionar eventos sin exponer información privada.

En la pipeline:

* Los **tests de rendimiento** y los **tests de seguridad** no solo generan reportes estáticos, también publican sus resultados como **métricas** visibles en sistemas como **Prometheus** y paneles de **Grafana**. Por ejemplo, se pueden exponer métricas sobre tiempo de respuesta bajo carga, número de vulnerabilidades encontradas o porcentaje de pruebas superadas.
* Los despliegues pueden estar **gobernados por gates** que consultan **métricas** antes de permitir que una nueva versión avance hacia entornos más críticos. Esto convierte la **observabilidad** en un criterio explícito de decisión dentro de la **pipeline de CI CD**.

El siguiente fragmento de código es un ejemplo de un **paso de pipeline** escrito en **bash** que actúa como **gate de calidad**. Este script se ejecuta dentro de la pipeline antes de desplegar a un entorno superior, consulta la **API HTTP de Prometheus**, calcula la tasa de errores en **staging** y decide si el despliegue debe continuar o ser bloqueado en función de esa métrica.

```bash
#!/usr/bin/env bash

ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query" \
  --get \
  --data-urlencode 'query=sum(rate(service_http_requests_total{code=~"5..",environment="staging"}[5m]))')

# Aquí se parsea el resultado y se decide si continuar.
# La lógica real dependería del formato del JSON.

if [ "$(echo "$ERROR_RATE" | jq '.data.result[0].value[1]' -r)" != "0" ]; then
  echo "Demasiados errores en staging. Cancelando despliegue"
  exit 1
fi

echo "Error rate aceptable. Continuando con el despliegue"
```

En este ejemplo:

* La variable **ERROR_RATE** se llena llamando a la **API de consultas de Prometheus** con una expresión **PromQL** que suma la tasa de peticiones que responden con código cinco cero cero en el entorno **staging** durante los últimos cinco minutos.
* El comando **jq** se utiliza para extraer del JSON el valor numérico de la métrica.
* Si la tasa de errores es distinta de cero se imprime un mensaje, el script finaliza con **exit 1** y la **pipeline** marca el paso como fallido, bloqueando el despliegue.
* Si la tasa de errores es aceptable se permite que el flujo continúe y la versión sigue avanzando hacia el siguiente entorno.

En producción:

* Se realiza **monitoreo continuo**, combinando paneles de **SLO** con alertas definidas a partir de **métricas**, **logs** y **trazas distribuidas**. Esto ayuda a detectar desviaciones respecto a los objetivos de disponibilidad, latencia o error definidos por el equipo.
* Estrategias de despliegue como **canary**, **blue green** y **shadow** se apoyan en **métricas de error**, **latencia**, **tráfico** y métricas de negocio como **conversiones** o **tasas de éxito** para decidir si una versión candidata puede ser promocionada a más usuarios o si debe revertirse.
* Los **postmortems** se construyen sobre datos objetivos. Al investigar un incidente se revisan las **métricas históricas**, los **logs estructurados** y las **trazas distribuidas** asociadas al periodo afectado, lo que permite entender la secuencia de eventos, cuantificar el impacto y proponer medidas de mejora basadas en evidencia.
