SHELL := /bin/bash
APP_IMG := etl-app:1.0.0
AIRFLOW_IMG := airflow-secure:1.0.0

.PHONY: help
help:
	@echo "Targets disponibles:"
	@echo "  make build        - build de imágenes locales (sin latest)"
	@echo "  make up           - levanta stack local seguro"
	@echo "  make down         - baja stack y mantiene volúmenes"
	@echo "  make logs         - sigue logs de Airflow webserver"
	@echo "  make test         - corre pytest en contenedor aislado"
	@echo "  make sbom         - genera SBOM para auditoría"
	@echo "  make scan         - escaneo rápido de vulns de imagen"

.PHONY: build
build:
	docker build --no-cache -t $(APP_IMG) ./app
	docker build --no-cache -t $(AIRFLOW_IMG) -f airflow/Dockerfile .

.PHONY: up
up:
	docker compose up --build -d

.PHONY: down
down:
	docker compose down

.PHONY: logs
logs:
	docker compose logs -f airflow-webserver

.PHONY: test
test:
	docker compose -f docker-compose.test.yml up --build --exit-code-from sut
	docker compose -f docker-compose.test.yml down -v

.PHONY: sbom
sbom:
	./scripts/sbom.sh $(APP_IMG)  ./dist/sbom-app.spdx.json
	./scripts/sbom.sh $(AIRFLOW_IMG) ./dist/sbom-airflow.spdx.json
	@echo "SBOMs en ./dist"

.PHONY: scan
scan:
	./scripts/scan_vulns.sh $(APP_IMG)
	./scripts/scan_vulns.sh $(AIRFLOW_IMG)
.PHONY: reset-init

reset-init:
	./scripts/airflow_reset_init.sh
