# Declaración de targets que no corresponden a archivos reales
.PHONY: help test cov lint rgr red green refactor
PYTHON ?= python
PYTEST := $(PYTHON) -m pytest -q -c pytest.ini
PYLINT := $(PYTHON) -m pylint -j 0
PYLINT_FLAGS := --disable=C0114,C0115,C0116

help:
	@echo "Targets:"
	@echo "  make test      # Ejecuta todas las pruebas (AAA + RGR) con pytest"
	@echo "  make cov       # Ejecuta las pruebas con resumen de cobertura"
	@echo "  make lint      # Analiza src/ y tests/ con pylint (sin globs)"
	@echo "  make rgr       # Alias rápido para el ciclo Red/Green"
	@echo "  make red       # Asegura que al menos una prueba falle (estado RED)"
	@echo "  make green     # Ejecuta pruebas hasta que pasen (estado GREEN)"
	@echo "  make refactor  # Ejecuta pruebas tras refactor (deben seguir en verde)"

test:
	@$(PYTEST)

cov:
	@$(PYTHON) -m pytest --cov=. --cov-report=term-missing -c pytest.ini

lint:
	@$(PYLINT) $(PYLINT_FLAGS) src tests

rgr: test

red:
	@if $(PYTEST); then \
		echo 'Todas las pruebas estan en verde, escribe primero una prueba que falle (RED)!'; exit 1; \
	else \
		echo 'Bien, estas en RED. Implementa lo minimo para pasar, luego haz verde.'; \
	fi

green:
	@$(PYTEST) && echo 'VERDE, refactoriza de manera segura.'

refactor:
	@$(PYTEST) && echo 'REFACTORIZACION, mantiene las pruebas siguen en verde.'
