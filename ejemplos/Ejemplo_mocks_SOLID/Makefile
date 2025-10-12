# Makefile (modo 'bdd'): asume que ya activaste el entorno virtual 'bdd'
# source bdd/bin/activate

PY                  := python
PYTEST              := pytest
RUFF                := ruff
BANDIT              := bandit
SEMGREP             := semgrep
PRECOMMIT           := pre-commit

PKG                 ?= app
COV_MIN             ?= 85
PYTEST_OPTS         ?=

.PHONY: deps test lint coverage security semgrep precommit-install gates run pack \
        clean clean-build clean-test clean-pyc clean-caches clean-all nuke env-check help

help:
	@echo "Targets: deps test coverage lint security semgrep gates run pack"
	@echo "         clean clean-build clean-test clean-pyc clean-caches clean-all nuke"

env-check:
	@command -v $(PYTEST) >/dev/null || (echo 'ERROR: pytest no encontrado en PATH (activa bdd)' && exit 1)
	@command -v $(RUFF)   >/dev/null || (echo 'ERROR: ruff no encontrado en PATH (activa bdd)' && exit 1)

deps:
	@echo 'Entorno preexistente (bdd). Nada que instalar.'

test: env-check
	$(PYTEST) $(PYTEST_OPTS)

coverage: env-check
	$(PYTEST) --cov=$(PKG) --cov-report=term-missing --cov-fail-under=$(COV_MIN)

lint: env-check
	$(RUFF) check $(PKG) tests

security:
	@command -v $(BANDIT) >/dev/null && $(BANDIT) -r $(PKG) || echo 'bandit no instalado, omitiendo.'

semgrep:
	@command -v $(SEMGREP) >/dev/null && $(SEMGREP) --config .semgrep/ --error || echo 'semgrep no instalado, omitiendo.'

precommit-install:
	@command -v $(PRECOMMIT) >/dev/null && $(PRECOMMIT) install || echo 'pre-commit no instalado, omitiendo.'

gates: lint coverage
	@echo "Gates OK (bdd)"

run:
	$(PY) -m $(PKG).main

pack:
	rm -rf dist out
	mkdir -p dist out
	tar --sort=name --mtime='UTC 2024-01-01' --owner=0 --group=0 \
		--numeric-owner -czf dist/miapp-src.tgz \
		--exclude '.venv' --exclude 'bdd' --exclude '__pycache__' --exclude '.pytest_cache' \
		.
	sha256sum dist/miapp-src.tgz | tee dist/miapp-src.tgz.sha256

# Limpieza granular y segura
clean: clean-build clean-test clean-pyc clean-caches
	@echo "Clean OK"

# Artefactos de build/packaging
clean-build:
	@rm -rf dist build out .eggs 2>/dev/null || true
	@rm -rf *.egg-info 2>/dev/null || true

# Artefactos de pruebas/cobertura
clean-test:
	@rm -rf .pytest_cache .coverage coverage.xml htmlcov .hypothesis 2>/dev/null || true

# Bytecode y __pycache__
clean-pyc:
	@find . -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*~' \) -delete
	@find . -type d -name '__pycache__' -prune -exec rm -rf {} +

# Caches de linters/tools y basura del sistema
clean-caches:
	@rm -rf .ruff_cache .mypy_cache .cache .benchmarks .nox .tox 2>/dev/null || true
	@find . -type f -name '.DS_Store' -delete

# Limpieza "casi total" (no borra el venv bdd por seguridad)
clean-all: clean
	@rm -rf .venv .env 2>/dev/null || true
	@echo "Nota: el entorno 'bdd/' NO se borra en 'clean-all'."

# Destrucción total (requiere confirmación explícita)
nuke:
	@if [ "$(CONFIRM)" = "YES" ]; then \
		echo "Ejecutando NUKE (todo fuera, incluyendo caches y artefactos)..."; \
		rm -rf dist build out .eggs *.egg-info .venv .env .tox .nox .ruff_cache .mypy_cache .pytest_cache .cache .benchmarks .coverage coverage.xml htmlcov 2>/dev/null || true; \
		find . -type d -name '__pycache__' -prune -exec rm -rf {} +; \
		find . -type f \( -name '*.pyc' -o -name '*.pyo' -o -name '*~' -o -name '.DS_Store' \) -delete; \
		echo "¡NUKE completado! (El venv 'bdd/' se mantiene para evitar roturas accidentales)"; \
	else \
		echo "Protegido. Para ejecutar: make nuke CONFIRM=YES"; \
	fi
