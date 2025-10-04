# Variables de entorno

# Actividad por defecto (se puede sobreescribir: make test ACTIVITY=coverage_pruebas)
ACTIVITY ?= aserciones_pruebas

# Lista de actividades disponibles
ACTIVITIES = aserciones_pruebas coverage_pruebas factories_fakes mocking_objetos \
             practica_tdd pruebas_fixtures pruebas_pytest

# Flags comunes para pytest (puedes ampliarlas)
PYTEST_FLAGS ?= -q
PY_WARNINGS  ?= ignore::DeprecationWarning

# Lint (modo "relajado" por defecto para desarrollo)
LINT_MAX_LINE ?= 88
LINT_IGNORE   ?= E501,W391,W293
# Ignora F401 en reexport del __init__ y E402 solo en archivos de tests
LINT_PER_FILE ?= Actividades/mocking_objetos/models/__init__.py:F401,Actividades/*/tests/*.py:E402

# Ayuda

.PHONY: help
help:
	@echo "Uso: make [comando] [opciones]"
	@echo
	@echo "Comandos disponibles:"
	@echo "  install              Instala dependencias (requirements.txt y opcionalmente requirements-dev.txt)"
	@echo "  lint                 Formatea (ruff), ordena imports (ruff I), autofix y pasa flake8 relajado"
	@echo "  test                 Ejecuta pytest en la actividad indicada (ACTIVITY)"
	@echo "  test_all             Ejecuta pytest en todas las actividades"
	@echo "  coverage             Ejecuta pytest con cobertura unificada (todas las actividades)"
	@echo "  coverage_individual  Ejecuta la cobertura para cada actividad por separado"
	@echo "  clean                Elimina archivos temporales, caches, etc."
	@echo
	@echo "Opciones:"
	@echo "  ACTIVITY=<nombre>    Actividad especifica (por defecto: aserciones_pruebas)"
	@echo "  PYTEST_FLAGS='-q -k expr'  Banderas extra para pytest"
	@echo
	@echo "Ejemplos:"
	@echo "  make install"
	@echo "  make lint"
	@echo "  make test"
	@echo "  make test ACTIVITY=pruebas_pytest"
	@echo "  make coverage"
	@echo "  make coverage_individual"
	@echo
	@echo "Actividades disponibles:"
	@echo "  $(ACTIVITIES)"

# Instalar dependencias

.PHONY: install
install:
	@echo "Instalando dependencias..."
	pip install -r requirements.txt
	@if [ -f requirements-dev.txt ]; then \
		echo "Instalando dependencias de desarrollo..."; \
		pip install -r requirements-dev.txt; \
	fi

# Lint / Formato (una sola diana)

.PHONY: lint
lint:
	@echo "==> Formateando con Ruff..."
	ruff format .
	@echo "==> Ordenando imports (Ruff rule I)..."
	ruff check . --select I --fix
	@echo "==> Autofix de reglas con Ruff (whitespace, etc.)..."
	ruff check . --fix
	@echo "==> Lint con flake8 (relajado: ignora $(LINT_IGNORE); ancho $(LINT_MAX_LINE))..."
	flake8 . \
	    --max-line-length=$(LINT_MAX_LINE) \
	    --extend-ignore=$(LINT_IGNORE) \
	    --per-file-ignores="$(LINT_PER_FILE)"
	@echo "Lint OK"

# Test

.PHONY: test test_all
test:
	@echo "Ejecutando pruebas en la actividad: $(ACTIVITY)"
	cd Actividades/$(ACTIVITY) && PYTHONWARNINGS="$(PY_WARNINGS)" pytest . $(PYTEST_FLAGS)

test_all:
	@echo "Ejecutando pruebas en TODAS las actividades..."
	@set -e; \
	for activity in $(ACTIVITIES); do \
	   echo "EJECUTANDO PRUEBAS EN $$activity"; \
	   ( cd Actividades/$$activity && PYTHONWARNINGS="$(PY_WARNINGS)" pytest . $(PYTEST_FLAGS) ); \
	done

# Coverage

.PHONY: coverage coverage_individual
coverage:
	@echo "Ejecutando cobertura UNIFICADA en todas las actividades..."
	@coverage erase
	@set -e; \
	for activity in $(ACTIVITIES); do \
	   echo "COVERAGE RUN en $$activity"; \
	   ( cd Actividades/$$activity && PYTHONWARNINGS="$(PY_WARNINGS)" coverage run --source=. -m pytest . $(PYTEST_FLAGS) ); \
	done
	@echo "COVERAGE COMBINADO"
	@coverage combine $$(for a in $(ACTIVITIES); do echo Actividades/$$a/.coverage; done) || true
	@coverage report -m
	@coverage html -d htmlcov

coverage_individual:
	@echo "Ejecutando cobertura individual para cada actividad..."
	@set -e; \
	for activity in $(ACTIVITIES); do \
	   echo "Generando cobertura para $$activity"; \
	   ( cd Actividades/$$activity && \
	     coverage erase && \
	     PYTHONWARNINGS="$(PY_WARNINGS)" coverage run --source=. -m pytest . $(PYTEST_FLAGS) && \
	     coverage report -m && \
	     coverage html -d htmlcov_$$activity ); \
	done

# Limpiar

.PHONY: clean
clean:
	@echo "Eliminando archivos de caché y reportes..."
	# caches python/pytest
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache
	# coverage
	rm -rf .coverage htmlcov htmlcov_* Actividades/**/.coverage 2>/dev/null || true
	coverage erase || true
	@echo "Limpieza completa."
