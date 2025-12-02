import logging
import os
import random
import time

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor


LOG_DIR = "logs"
os.makedirs(LOG_DIR, exist_ok=True)

logger = logging.getLogger("demo-app")
logger.setLevel(logging.INFO)
formatter = logging.Formatter("%(asctime)s %(levelname)s %(message)s")

stream_handler = logging.StreamHandler()
stream_handler.setFormatter(formatter)
logger.addHandler(stream_handler)

file_handler = logging.FileHandler(os.path.join(LOG_DIR, "app.log"))
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

#  OpenTelemetry controlado SOLO por DISABLE_OTEL

DISABLE_OTEL = os.getenv("DISABLE_OTEL", "0") == "1"
provider = None

if not DISABLE_OTEL:
    # Configuración normal de OTEL para runtime (Docker Compose, etc.)
    resource = Resource.create(
        {"service.name": os.getenv("OTEL_SERVICE_NAME", "demo-app")}
    )
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)

    otel_endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "http://otel-collector:4318",
    ).rstrip("/")

    # Exporter HTTP OTLP: sin 'insecure' en esta versión
    span_exporter = OTLPSpanExporter(endpoint=f"{otel_endpoint}/v1/traces")

    span_processor = BatchSpanProcessor(span_exporter)
    provider.add_span_processor(span_processor)

# Si no hay provider configurado, get_tracer usa el no-op por defecto.
tracer = trace.get_tracer(__name__)

#  FastAPI

app = FastAPI(title="DevSecOps Observability Demo", version="0.1.0")

if provider is not None:
    FastAPIInstrumentor.instrument_app(app, tracer_provider=provider)
else:
    # Instrumentación con tracer provider por defecto (no-op)
    FastAPIInstrumentor.instrument_app(app)


class Item(BaseModel):
    id: int
    name: str
    price: float


ITEMS = [
    Item(id=1, name="widget", price=9.99),
    Item(id=2, name="gadget", price=19.99),
    Item(id=3, name="thing", price=3.50),
]


@app.get("/healthz")
async def healthz():
    logger.info("Health check OK")
    return {"status": "ok"}


@app.get("/api/v1/items")
async def list_items():
    with tracer.start_as_current_span("list_items"):
        logger.info("Listing items")
        time.sleep(random.uniform(0.01, 0.2))
        return ITEMS


@app.get("/api/v1/work")
async def do_work():
    with tracer.start_as_current_span("cpu_bound_work") as span:
        logger.info("Simulating CPU bound work")
        total = 0
        for i in range(1, 100_000):
            total += i * i
        span.set_attribute("work.result", total)
        if random.random() < 0.2:
            logger.warning("Slow request simulated")
            time.sleep(0.5)
        return {"status": "done", "result": total}


@app.get("/api/v1/error")
async def error_endpoint():
    with tracer.start_as_current_span("error_endpoint"):
        logger.error("Simulated error endpoint called")
        raise HTTPException(status_code=500, detail="Simulated failure")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
