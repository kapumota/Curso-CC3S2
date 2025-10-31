# Stage 1: build

FROM python:3.12-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build

COPY requirements.txt .

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential gcc \
 && pip install --upgrade pip \
 && python -m venv /venv \
 && . /venv/bin/activate \
 && pip install -r requirements.txt \
 && apt-get purge -y build-essential gcc \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Stage 2: runtime minimal

FROM python:3.12-slim AS runtime

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Crear usuario no-root
RUN useradd --create-home --uid 10001 etluser
USER etluser

WORKDIR /app

# Copiamos el entorno virtual y el código estrictamente necesario
COPY --from=builder /venv /venv
ENV PATH="/venv/bin:$PATH"

COPY pipeline.py ./pipeline.py
COPY healthcheck.py ./healthcheck.py
COPY data ./data

ENTRYPOINT ["python", "pipeline.py"]
