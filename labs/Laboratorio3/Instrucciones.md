### Laboratorio: Patrón AAA, RGR y Makefiles

En este laboratorio se aplica los principios de **Patrón AAA (Arrange‑Act‑Assert)**, el ciclo **RGR (Red‑Green‑Refactor)** y el uso disciplinado de **Makefiles** para garantizar reproducibilidad y trazabilidad.


#### Prerrequisitos
Asegura el siguiente entorno (Linux/WSL2 recomendado):

- **Herramientas**: make, pytest, python.
- **Clonar / extraer** el laboratorio en una ruta sin espacios.
- **Permisos de ejecución** para scripts: `chmod +x scripts/*.sh` (si aplica).

> Sugerencia: fija versiones con `required_version`/lockfiles si el repositorio las provee. Ejecuta `make help` para ver objetivos disponibles.


#### Makefile: flujo estándar
El flujo base sigue **12‑Factor (I, III, V)** y gates de calidad. Ejecuta en orden:

- `make help` - lista objetivos y uso.
- `make test` - ejecuta pruebas (Bats/pytest/etc.).


#### 4) Patrón AAA (Arrange‑Act‑Assert)

Usa AAA en cada prueba/ejecución:

1. **Arrange (Preparar):** configura entradas, variables de entorno y precondiciones.  
   Ejemplo: exporta `PORT`, define rutas en `out/` y `dist/`.
2. **Act (Actuar):** ejecuta el comando bajo prueba (script/función/servicio).  
   Ejemplo: `./scripts/run_demo.sh` o `make run`.
3. **Assert (Afirmar):** verifica resultados con salidas, logs o asserts.  
   Ejemplo.: `bats tests/` o compara archivos esperados en `out/` usando `diff`.

> Mantén **fixtures** minimales y salidas deterministas (hash, timestamps normalizados) para reproducibilidad.

#### Ciclo RGR (Red‑Green‑Refactor)
Aplica TDD/BDD liviano:

- **Red:** escribe/ajusta una prueba que **falle** (demuestra el gap).
- **Green:** implementa el mínimo código para **pasar** la prueba.
- **Refactor:** mejora el diseño sin romper verde; extrae funciones, limpia shell.
- Registra el ciclo en commits atómicos y en español (evita "update/fix").

> Consejo: guarda evidencias en `out/` (logs, métricas, trazas) y, si existe, en `docs/bitacora.md`.

#### Variables y contratos
- Declara variables de entorno requeridas (por ejemplo `PORT`, `TARGETS`, `RELEASE`).  
- Documenta un **contrato de entradas/salidas** (archivos en `out/` y empaques en `dist/`).  
- Si el proyecto incluye **Bats**, añade asserts sobre: códigos de salida, contenido de logs, y presencia de artefactos.

#### Ejecución mínima de punta a punta
```bash
  make test      # Ejecuta todas las pruebas (AAA + RGR) con pytest"
  make cov       # Ejecuta las pruebas con resumen de cobertura"
  make lint      # Analiza src/ y tests/ con pylint (sin globs)"
  make rgr       # Alias rápido para el ciclo Red/Green"
  make red       # Asegura que al menos una prueba falle (estado RED)"
  make green     # Ejecuta pruebas hasta que pasen (estado GREEN)"
  make refactor  # Ejecuta pruebas tras refactor (deben seguir en verde)"
```

#### Gates de calidad recomendados
Integra como parte de `make test` u objetivos separados:
- **Linting**: `shellcheck`, `shfmt -d` (o `-w` en commit aparte).
- **Pruebas**: `bats tests/` (si existe), asserts sobre códigos/outputs.
- **Plan/Drift (si aplica Terraform)**: `terraform fmt/validate`, `tflint`, `checkov/OPA`.
- **Packaging**: crear `dist/release-*.tar.gz` + `SHA256SUMS` reproducibles.

Falla el pipeline si **cualquier gate** falla (código ≠ 0).
