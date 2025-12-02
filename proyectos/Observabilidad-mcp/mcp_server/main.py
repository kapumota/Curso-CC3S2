import os
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException

PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://prometheus:9090").rstrip("/")
LOKI_URL = os.getenv("LOKI_URL", "http://loki:3100").rstrip("/")
TEMPO_URL = os.getenv("TEMPO_URL", "http://tempo:3200").rstrip("/")

SERVICE_NAME = os.getenv("OBS_SERVICE_NAME", "demo-app")

app = FastAPI(
    title="MCP-style Observability Gateway",
    version="0.1.0",
    description=(
        "Pequeño servidor que resume métricas, logs y trazas en un JSON simple, "
        "pensado para ser consumido por un LLM o un agente."
    ),
)


async def _query_prometheus(query: str) -> float:
    """Ejecuta una consulta instantánea en Prometheus y devuelve un float (o 0.0 si no hay datos)."""
    url = f"{PROMETHEUS_URL}/api/v1/query"
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url, params={"query": query})
            resp.raise_for_status()
    except Exception:
        return 0.0

    data = resp.json()
    if data.get("status") != "success":
        return 0.0

    result = data.get("data", {}).get("result", [])
    if not result:
        return 0.0

    # vector instantáneo: value = [timestamp, "string"]
    value = result[0].get("value", [])
    if len(value) != 2:
        return 0.0

    try:
        return float(value[1])
    except (TypeError, ValueError):
        return 0.0


async def _query_loki_errors(limit: int = 20, window_seconds: int = 300) -> Dict[str, Any]:
    """Devuelve conteo y ejemplos de logs de error desde Loki."""
    now_ns = int(time.time() * 1e9)
    start_ns = now_ns - window_seconds * int(1e9)

    # Consulta: logs del job demo-app que contengan la palabra ERROR
    query = '{job="demo-app"} |= "ERROR"'

    params = {
        "query": query,
        "limit": limit,
        "direction": "backward",
        "start": start_ns,
        "end": now_ns,
    }
    url = f"{LOKI_URL}/loki/api/v1/query_range"

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
    except Exception:
        return {"error_count_5m": 0, "sample_errors": []}

    data = resp.json()
    result = data.get("data", {}).get("result", [])

    sample_errors: List[str] = []
    error_count = 0

    for stream in result:
        values = stream.get("values", [])
        error_count += len(values)
        for ts, line in values:
            # ts viene en ns como string
            try:
                ts_float = int(ts) / 1e9
                ts_iso = datetime.fromtimestamp(ts_float, tz=timezone.utc).isoformat()
            except Exception:
                ts_iso = "unknown"
            sample_errors.append(f"{ts_iso} {line}")
            if len(sample_errors) >= limit:
                break
        if len(sample_errors) >= limit:
            break

    return {
        "error_count_5m": error_count,
        "sample_errors": sample_errors,
    }


async def _query_tempo_counts(window_seconds: int = 300) -> Dict[str, Any]:
    """Intenta hacer un conteo aproximado de trazas recientes y trazas con error.

    La API de Tempo puede variar según la configuración; aquí usamos un endpoint HTTP típico.
    Si la llamada falla, devolvemos valores aproximados en 0.
    """
    now = int(time.time())
    start = now - window_seconds

    base = {
        "recent_traces": 0,
        "error_traces": 0,
        "notes": "Conteo aproximado basado en la API HTTP de Tempo; ajustar a tu despliegue real.",
    }

    # Ejemplo de llamada a la API de búsqueda (puede requerir ajuste según tu stack):
    # GET /api/search?service=demo-app&start=<unix_s>&end=<unix_s>&limit=100
    search_url = f"{TEMPO_URL}/api/search"
    params_recent = {
        "service": SERVICE_NAME,
        "start": start,
        "end": now,
        "limit": 100,
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp_recent = await client.get(search_url, params=params_recent)
            resp_recent.raise_for_status()
            data_recent = resp_recent.json()
    except Exception:
        return base

    traces = data_recent.get("traces", []) or data_recent.get("results", [])
    recent_count = len(traces)

    # Heurística simple: contar trazas con status error si el campo existe
    error_count = 0
    for t in traces:
        # el formato real depende de la versión; intentamos campos típicos
        status = t.get("status") or t.get("traceStatus") or {}
        code = status.get("code") if isinstance(status, dict) else None
        if code in ("ERROR", "Error", 2):
            error_count += 1

    base["recent_traces"] = recent_count
    base["error_traces"] = error_count
    return base


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@app.get("/healthz")
async def healthz() -> Dict[str, str]:
    return {"status": "ok", "component": "mcp-style-gateway"}


@app.get("/api/metrics-summary")
async def metrics_summary() -> Dict[str, Any]:
    """Resumen compacto de métricas clave para demo-app."""
    # Ajusta las métricas a las que realmente exponga tu OTEL exporter
    rps_query = 'sum(rate(http_server_requests_total{service_name="%s"}[5m]))' % SERVICE_NAME
    err_query = (
        'sum(rate(http_server_requests_total{service_name="%s", http_status_code=~"5.."}[5m]))'
        % SERVICE_NAME
    )

    rps = await _query_prometheus(rps_query)
    err = await _query_prometheus(err_query)
    success_ratio = 0.0
    if rps > 0:
        success_ratio = max(0.0, min(1.0, (rps - err) / rps))

    return {
        "generated_at": _now_iso(),
        "service": SERVICE_NAME,
        "requests_per_second": rps,
        "error_rate_per_second": err,
        "success_ratio": success_ratio,
    }


@app.get("/api/logs-summary")
async def logs_summary() -> Dict[str, Any]:
    """Resumen de errores recientes en logs."""
    logs_info = await _query_loki_errors()
    logs_info["generated_at"] = _now_iso()
    logs_info["service"] = SERVICE_NAME
    return logs_info


@app.get("/api/traces-summary")
async def traces_summary() -> Dict[str, Any]:
    """Resumen aproximado de trazas recientes."""
    traces_info = await _query_tempo_counts()
    traces_info["generated_at"] = _now_iso()
    traces_info["service"] = SERVICE_NAME
    return traces_info


@app.get("/api/summary")
async def full_summary() -> Dict[str, Any]:
    """Resumen unificado (métricas + logs + trazas) amigable para LLMs."""
    metrics = await metrics_summary()
    logs = await logs_summary()
    traces = await traces_summary()

    # Quitamos campos duplicados en niveles internos
    metrics_clean = {k: v for k, v in metrics.items() if k not in ("service", "generated_at")}
    logs_clean = {k: v for k, v in logs.items() if k not in ("service", "generated_at")}
    traces_clean = {k: v for k, v in traces.items() if k not in ("service", "generated_at")}

    return {
        "service": SERVICE_NAME,
        "generated_at": _now_iso(),
        "metrics": metrics_clean,
        "logs": logs_clean,
        "traces": traces_clean,
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8080, reload=False)
