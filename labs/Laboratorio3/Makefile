# Declaración de targets que no corresponden a archivos reales
.PHONY: help test cov lint rgr red green refactor

# Muestra una lista de los comandos disponibles y su descripción
help:
	@echo "Targets:"
	@echo "  make test      # Ejecuta todas las pruebas (AAA + RGR) con pytest"
	@echo "  make cov       # Ejecuta las pruebas con un resumen de cobertura"
	@echo "  make lint      # Analiza el código fuente y las pruebas con pylint"
	@echo "  make rgr       # Alias: ejecuta las pruebas rápidamente (usado en ciclos Red/Green)"
	@echo "  make red       # Paso 1 de RGR: asegura que al menos una prueba falle (retorna código de salida no cero)"
	@echo "  make green     # Paso 2 de RGR: ejecuta las pruebas hasta que pasen (estado verde)"
	@echo "  make refactor  # Paso 3 de RGR: ejecuta las pruebas después de refactorizar (deben seguir en verde)"

# Ejecuta todas las pruebas automáticamente, buscando archivos test_*.py en el repositorio
test:
	@pytest -q

# Ejecuta las pruebas y genera un informe de cobertura, mostrando las líneas no cubiertas
cov:
	@pytest --cov=. --cov-report=term-missing

# Analiza el código fuente y las pruebas con pylint, ignorando advertencias de docstrings para mantener un enfoque pragmático en TDD
lint:
	@pylint --disable=C0114,C0115,C0116 *.py test_*.py || true

# Alias para ejecutar las pruebas rápidamente, útil durante los ciclos Red/Green/Refactor
rgr: test

# Paso "red" de RGR: verifica que al menos una prueba falle (código de salida no cero).
# Si todas las pruebas pasan, muestra un mensaje indicando que se debe escribir una prueba fallida primero.
red:
	@if pytest -q; then \
		echo 'Todas las pruebas están en verde — ¡escribe primero una prueba que falle (RED)!'; exit 1; \
	else \
		echo 'Bien, estás en RED. Implementa lo mínimo para pasar, luego haz verde.'; \
	fi

# Paso "green" de RGR: ejecuta las pruebas hasta que todas pasen, mostrando un mensaje de confirmación
green:
	@pytest -q && echo 'VERDE, refactoriza de manera segura.'

# Paso "refactor" de RGR: ejecuta las pruebas tras refactorizar, asegurando que sigan pasando
refactor:
	@pytest -q && echo 'REFACTORIZACIÓN, mantén el diseño limpio; las pruebas siguen en verde.'