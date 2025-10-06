# Makefile (modo 'bdd'): asume que ya activaste el entorno virtual 'bdd'
# source bdd/bin/activate
# Las herramientas se resuelven desde el PATH del entorno activo.

PY=python
PYTEST=pytest
RUFF=ruff
BANDIT=bandit
SEMGREP=semgrep
PRECOMMIT=pre-commit
COV_MIN=85

.PHONY: deps test lint coverage security semgrep precommit-install gates run pack clean env-check

env-check:
	@command -v $(PYTEST) >/dev/null || (echo 'ERROR: pytest no encontrado en PATH (activa bdd)' && exit 1)
	@command -v $(RUFF)   >/dev/null || (echo 'ERROR: ruff no encontrado en PATH (activa bdd)' && exit 1)

deps:
	@echo 'Entorno preexistente (bdd). Nada que instalar.'

test: env-check
	$(PYTEST)

coverage: env-check
	$(PYTEST) --cov=app --cov-report=term-missing --cov-fail-under=$(COV_MIN)

lint: env-check
	$(RUFF) check app tests

security:
	@command -v $(BANDIT) >/dev/null && $(BANDIT) -r app || echo 'bandit no instalado, omitiendo.'

semgrep:
	@command -v $(SEMGREP) >/dev/null && $(SEMGREP) --config .semgrep/ --error || echo 'semgrep no instalado, omitiendo.'

precommit-install:
	@command -v $(PRECOMMIT) >/dev/null && $(PRECOMMIT) install || echo 'pre-commit no instalado, omitiendo.'

gates: lint coverage
	@echo "Gates OK (bdd)"

run:
	$(PY) -m app.main

pack:
	rm -rf dist out
	mkdir -p dist out
	tar --sort=name --mtime='UTC 2024-01-01' --owner=0 --group=0 \
		--numeric-owner -czf dist/miapp-src.tgz \
		--exclude '.venv' --exclude '__pycache__' --exclude '.pytest_cache' \
		.
	sha256sum dist/miapp-src.tgz | tee dist/miapp-src.tgz.sha256

clean:
	rm -rf .pytest_cache .coverage htmlcov dist out
