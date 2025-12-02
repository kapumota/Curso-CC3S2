FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN adduser --disabled-password --gecos "" appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

USER appuser

ENV PROMETHEUS_URL=http://prometheus:9090 \
    LOKI_URL=http://loki:3100 \
    TEMPO_URL=http://tempo:3200 \
    OBS_SERVICE_NAME=demo-app

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
