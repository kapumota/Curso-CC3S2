### Actividad 9: pytest + coverage + fixtures + factories + mocking + TDD

Debes resolver **todas** las actividades incluidas en [Laboratorio4/Actividades](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio4/Actividades) dentro de una sola entrega reproducible, demostrando dominio de:

* ejecución de pruebas con **pytest**
* **aserciones**
* **fixtures** y datos de prueba
* **coverage**
* **factory & fakes**
* **mocking / patching**
* ciclo **TDD** básico

#### Estructura de la entrega

Crear en tu repo una carpeta en la **raíz**:

```
Actividad9-CC3S2/
├─ README.md
├─ Makefile
├─ requirements.txt              # puedes copiarlo del Laboratorio4/requirements.txt
├─ src/                          # si necesitas módulos propios de apoyo
├─ evidencias/
│  ├─ sesion_pytest.txt          # log de una corrida completa (script -c "make test_all")
│  ├─ cobertura_resumen.txt      # salida de coverage para coverage_pruebas
│  └─ capturas/                  # (opcional) screenshots de htmlcov
└─ soluciones/
   ├─ aserciones_pruebas/        # resolución de esta actividad
   ├─ pruebas_pytest/
   ├─ pruebas_fixtures/
   ├─ coverage_pruebas/
   ├─ factories_fakes/
   ├─ mocking_objetos/
   └─ practica_tdd/
```

> **Importante:** No modifiques los archivos fuente de `Laboratorio4` original. Copia cada subcarpeta de `Laboratorio4/Actividades/*` a `Actividad9-CC3S2/soluciones/<misma_carpeta>/` y trabaja allí.

#### Alcance (qué se debe resolver)

Incluye **siete** sub-actividades:

1. `aserciones_pruebas`
2. `pruebas_pytest`
3. `pruebas_fixtures`
4. `coverage_pruebas`
5. `factories_fakes`
6. `mocking_objetos`
7. `practica_tdd`

Tu entrega debe **hacer pasar todas las pruebas** incluidas en cada directorio. Donde corresponda, debes **completar/ajustar** el código para satisfacer los tests (enfoque TDD inverso si el test ya está dado).

#### Requisitos técnicos

* Python 3.10+.
* Crear y usar **venv**:

  ```bash
  python -m venv .venv
  source .venv/bin/activate   # en Windows: .venv\Scripts\activate
  pip install -r requirements.txt
  ```
* Copia `Laboratorio4/requirements.txt` a `Actividad9-CC3S2/requirements.txt` y añade complementos si hiciera falta.

#### Makefile (mínimo requerido)

Incluye un `Makefile` en `Actividad9-CC3S2/` con como mínimo estos objetivos:

```make
VENV=.venv
PY=$(VENV)/bin/python
PIP=$(VENV)/bin/pip
PYTEST=$(VENV)/bin/pytest

.PHONY: venv deps test_all test_unit cov clean

venv:
	python -m venv $(VENV)

deps: venv
	$(PIP) install -r requirements.txt

# Ejecuta pytest en cada sub-actividad
test_all: deps
	cd soluciones/aserciones_pruebas   && $(PYTEST) -q || exit 1
	cd soluciones/pruebas_pytest       && $(PYTEST) -q || exit 1
	cd soluciones/pruebas_fixtures     && $(PYTEST) -q || exit 1
	cd soluciones/coverage_pruebas     && $(PYTEST) --cov=models --cov-report term-missing -q || exit 1
	cd soluciones/factories_fakes      && $(PYTEST) -q || exit 1
	cd soluciones/mocking_objetos      && $(PYTEST) -q || exit 1
	cd soluciones/practica_tdd         && $(PYTEST) -q || exit 1

# Atajo para correr sólo unidad si decides marcar tests con -m "unit"
test_unit:
	cd soluciones && $(PYTEST) -m "unit" -q

# Cobertura sólo para coverage_pruebas (puedes extender a otras)
cov:
	cd soluciones/coverage_pruebas && $(PYTEST) --cov=models --cov-report term-missing -q

clean:
	rm -rf .pytest_cache **/__pycache__ htmlcov .coverage
```

> Puedes agregar un `make rgr` si deseas simular el ciclo **Red-Green-Refactor** con una receta que falle primero (red), luego pase (green), y finalmente haga refactor.

#### Criterios de aceptación por componente

* **aserciones_pruebas / pruebas_pytest**:

  * Todos los tests **verdes** (`pytest -q` sin fails).
* **pruebas_fixtures**:

  * Uso correcto de **fixtures** (modulares / de función / de clase cuando aplique).
  * Tests verdes.
* **coverage_pruebas**:

  * Ejecutar: `pytest --cov=models --cov-report term-missing`.
  * **Criterio**: cobertura **≥ 85%** en el paquete objetivo (si el enunciado interno exige un valor distinto, respeta el más estricto).
  * Guardar resumen en `evidencias/cobertura_resumen.txt`.
* **factories_fakes**:

  * Uso de **Factory** para generar instancias consistentes y **fakes** para escenarios masivos o controlados.
  * Tests verdes.
* **mocking_objetos**:

  * Uso de **mock** / **patch** (aislar dependencias externas, simular respuestas, asserts de llamadas).
  * Tests verdes.
* **practica_tdd**:

  * Implementación mínima funcional que satisface los tests CRUD indicados en la carpeta.
  * Tests verdes.

#### Tareas (paso a paso sugerido)

1. **Estructura**: crea `Actividad9-CC3S2/` con la estructura indicada; copia las 7 sub-carpetas a `soluciones/`.
2. **Entorno**: crea venv y `pip install -r requirements.txt`.
3. **Ejecución base**: corre `make test_all` para ver el estado inicial.
4. **Iteración por sub-actividad**:

   * Lee `soluciones/<actividad>/Instrucciones.md`.
   * Completa/ajusta el código fuente y/o tests cuando así lo pida el enunciado.
   * Corre `pytest -q` dentro de esa subcarpeta hasta ver **verde**.
5. **Cobertura**: en `coverage_pruebas`, ejecuta `make cov`, revisa líneas faltantes y añade pruebas hasta alcanzar el umbral.
6. **Evidencia**: ejecuta una corrida completa y captura evidencia:

   ```bash
   script -c "make test_all" evidencias/sesion_pytest.txt
   (cd soluciones/coverage_pruebas && pytest --cov=models --cov-report term-missing) | tee evidencias/cobertura_resumen.txt
   ```

   *(En Windows, usa `powershell Start-Transcript` o redirecciones equivalentes.)*
7. **Limpieza**: `make clean` para dejar artefactos fuera (excepto evidencias).

#### Contenido del README.md (mínimo)

Incluye:

* **Cómo ejecutar**: versión de Python, pasos para crear venv, `make deps`, `make test_all`, `make cov`.
* **Explicación breve** de cómo usaste: aserciones, fixtures, coverage, factories/fakes, mocking, y el mini-ciclo TDD que seguiste.
* **Resultados**: número total de tests, porcentaje de cobertura (coverage_pruebas), hallazgos relevantes (por ejemplo, líneas difíciles de cubrir y cómo las cubriste).


#### Entrega

* PR/MR con la carpeta **`Actividad9-CC3S2/`** completa.
* Verifica que la **ruta** y los **nombres de carpetas** coinciden exactamente para la corrección automática.
