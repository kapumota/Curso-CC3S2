# Demo DevSecOps con Docker, Compose y Airflow

Este proyecto es una maqueta educativa que cubre:
- Contenedores como unidad de entrega reproducible (Dockerfile con usuario no-root).
- Orquestación local reproducible con `docker compose`.
- Variables de entorno (12-Factor) en `.env`.
- Healthchecks, límites de recursos, red interna privada sin puertos públicos innecesarios.
- Pruebas automáticas en contenedores (`docker-compose.test.yml`).
- SBOM y escaneo de vulnerabilidades (`make sbom`, `make scan`).

## Requisitos previos

- Docker Desktop o Docker Engine + Docker Compose Plugin.
- GNU Make.
- Copiar `.env.example` a `.env` y editar si deseas.

```bash
cp .env.example .env
```

## Levantar el stack

```bash
make build      # construye imágenes con tags fijos (sin latest)
make up         # levanta postgres + airflow + etl-app
make logs       # mira logs del webserver de Airflow
```

Airflow UI debería quedar en http://localhost:8080

## Probar el ETL

El contenedor `etl-app` corre `pipeline.py`, que:
1. Lee `app/data/input.csv`
2. Calcula `value_squared`
3. Inserta resultados en Postgres (`processed_data`)

Puedes volver a lanzar sólo `etl-app` manualmente así:

```bash
docker compose run --rm etl-app python pipeline.py
```

## Pruebas automáticas

```bash
make test
```

Eso levanta un Postgres efímero y corre pytest dentro de `etl-app` sin usar tu sistema host.

## SBOM y escaneo

```bash
make sbom   # genera ./dist/sbom-*.spdx.json (usa scripts/sbom.sh)
make scan   # corre scripts/scan_vulns.sh sobre cada imagen
```

Estos pasos representan gates de supply chain para auditoría y cumplimiento.
