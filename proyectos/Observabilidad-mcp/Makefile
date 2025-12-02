.PHONY: help deps test build up down logs scan-python scan-image demo-traffic

help:
	@echo "Targets:"
	@echo "  deps          - Instalar dependencias en el entorno ACTUAL (bdd)"
	@echo "  test          - Ejecutar pruebas con pytest"
	@echo "  build         - Construir imagen de la app"
	@echo "  up            - Levantar stack completo con Docker Compose"
	@echo "  down          - Bajar stack completo"
	@echo "  logs          - Ver logs de la app"
	@echo "  scan-python   - Ejecutar Bandit + pip-audit (SAST + deps)"
	@echo "  scan-image    - Escanear imagen Docker con Trivy"
	@echo "  demo-traffic  - Generar tráfico sintético contra la API"

# IMPORTANTE:
#   - No creamos venv aquí.
#   - Asumimos que YA activaste el entorno bdd antes de ejecutar 'make'.

deps:
	python -m pip install --upgrade pip
	python -m pip install -r app/requirements.txt -r dev-requirements.txt

test:
	DISABLE_OTEL=1 python -m pytest

build:
	docker compose build app

up:
	mkdir -p .evidence
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f app

scan-python:
	mkdir -p .evidence
	bandit -r app | tee .evidence/bandit.txt
	pip-audit | tee .evidence/pip-audit.txt

scan-image:
	mkdir -p .evidence
	docker compose build app
	docker run --rm aquasec/trivy image devsecops-observability-demo-app:local | tee .evidence/trivy-image.txt || true

demo-traffic:
	./scripts/demo-traffic.sh
