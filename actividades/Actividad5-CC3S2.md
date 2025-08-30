## Actividad 5: Construyendo un pipeline DevOps con Make y Bash

El laboratorio se apoya en un enfoque híbrido **Construir -> Leer -> Extender** porque así se fija el aprendizaje y se conecta con prácticas reales de DevOps. 
En **Construir**, se crea desde cero un Makefile y un script Bash que ejecuta y prueba un pequeño programa en Python.
Aquí se interiorizan conceptos críticos: cómo Make decide si rehacer un target a partir de sus dependencias, el uso de variables y automáticas (`$@`, `$<`), y el "modo estricto" en Bash (`set -euo pipefail`, `IFS` seguro) junto con `trap` para limpieza y preservación del código de salida. 

En **Leer**, se inspecciona un repositorio más completo con `make -n` y `make -d` para entender la caché incremental, la diferencia entre `:=` y `?=`, y convenciones de industria como un `help` autodocumentado. 

Por último, en **Extender**, se añaden linters, un fallo controlado con rollback y mediciones de tiempo, reforzando la reproducibilidad y la automatización.

El pipeline resultante **compila, prueba y empaqueta** scripts de Python y demuestra prácticas robustas de shell (funciones, arrays, here-docs, subshells, `trap`). Además, el Makefile está **endurecido**: usa reglas claras, evita reglas implícitas, y produce artefactos con empaquetado **100% reproducible** (metadatos normalizados, orden estable, zona horaria fija). Esto facilita CI/CD, auditoría, y builds deterministas, tal como se espera en entornos profesionales.


#### Preparación

- **Entorno:** Linux (o WSL, trabajando en `~/proyecto` para evitar I/O lento en `/mnt/c`).
- **Dependencias:** `make`, `bash`, `python3`, `shellcheck`, `shfmt`, `ruff` (opcional), `git` (opcional para benchmark), `grep`, `awk`, `tar` (GNU tar), `sha256sum` (GNU coreutils).

**Estructura inicial:**

```
Laboratorio2/
├── Makefile
├── src/
│   ├── __init__.py
│   └── hello.py
├── scripts/
│   └── run_tests.sh
├── tests/
│   └── test_hello.py
├── out/
└── dist/
```

Crea `src/__init__.py` (vacío) para compatibilidad con imports en entornos Python antiguos.

### Parte 1: Construir - Makefile y Bash desde cero

**Objetivo:** Crear un Makefile y un script Bash robusto para ejecutar un script Python, internalizando conceptos clave y errores comunes.

#### 1.1 Crear un script Python simple

Crea `src/hello.py`:

```python
def greet(name):
    return f"Hello, {name}!"

if __name__ == "__main__":
    print(greet("World"))
```

#### 1.2 Crear un Makefile básico

Crea **Makefile** con un encabezado robusto y un target simple:

```makefile
# Makefile
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
MAKEFLAGS += --warn-undefined-variables --no-builtin-rules
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help
export LC_ALL := C
export LANG   := C
export TZ     := UTC

.PHONY: all build test package clean help lint tools check benchmark format dist-clean verify-repro

PYTHON ?= python3
SHELLCHECK := shellcheck
SHFMT := shfmt
SRC_DIR := src
TEST_DIR := tests
OUT_DIR := out
DIST_DIR := dist

all: tools lint build test package ## Construir, testear y empaquetar todo

build: $(OUT_DIR)/hello.txt ## Generar out/hello.txt

$(OUT_DIR)/hello.txt: $(SRC_DIR)/hello.py
	mkdir -p $(@D)
	$(PYTHON) $< > $@

clean: ## Limpiar archivos generados
	rm -rf $(OUT_DIR) $(DIST_DIR)

help: ## Mostrar ayuda
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':|##' '{printf "  %-12s %s\n", $$1, $$3}'
```

Este **Makefile** establece un entorno de construcción **estricto y determinista** y define un flujo mínimo para generar un artefacto desde un script de Python. 
Primero fija el intérprete de recetas a **Bash** (`SHELL := bash`) y activa **modo estricto** con `.SHELLFLAGS := -eu -o pipefail -c` para que cualquier error o variable no definida detenga la ejecución. 
Refuerza la detección de problemas con `MAKEFLAGS += --warn-undefined-variables` y desactiva **reglas implícitas** con `--no-builtin-rules`, evitando comportamientos sorpresivos.
Exporta `LC_ALL`, `LANG` y `TZ` a `C/UTC` para obtener salidas reproducibles (mensajes, ordenamientos y fechas estables). 
Declara como **.PHONY** un conjunto de objetivos lógicos (por ejemplo, `all`, `clean`, `help`) para que no entren en conflicto con archivos reales del mismo nombre.

Define variables de conveniencia: `PYTHON ?= python3` (sobrescribible desde el entorno/CI) y rutas (`SRC_DIR`, `OUT_DIR`, etc.). El objetivo **`all`** actúa como agregador y, cuando el Makefile completo las tenga definidas, ejecutará `tools`, `lint`, `build`, `test` y `package` en cadena. En este fragmento, el objetivo **`build`** produce `out/hello.txt` a partir de `src/hello.py`: crea el directorio de destino con `mkdir -p $(@D)` y ejecuta `$(PYTHON) $< > $@` (donde `$<` es el primer prerequisito y `$@` el target). La directiva **`.DELETE_ON_ERROR`** asegura que si una receta falla, no quede un artefacto parcialmente generado. Finalmente, **`help`** autodocumenta los objetivos escaneando el propio Makefile con `grep` y `awk`, y se fija como objetivo por defecto con `.DEFAULT_GOAL := help`, de modo que invocar `make` sin argumentos muestra la ayuda.

#### Ejercicios

1. Ejecuta `make help` y guarda la salida para análisis. Luego inspecciona `.DEFAULT_GOAL` y `.PHONY` dentro del Makefile.
   Comandos:

   ```bash
   mkdir -p logs evidencia
   make help | tee logs/make-help.txt
   grep -E '^\.(DEFAULT_GOAL|PHONY):' -n Makefile | tee -a logs/make-help.txt
   ```

   Entrega: redacta 5-8 líneas explicando qué imprime `help`, por qué `.DEFAULT_GOAL := help` muestra ayuda al correr `make` sin argumentos, y la utilidad de declarar PHONY.

2. Comprueba la generación e idempotencia de `build`. Limpia salidas previas, ejecuta `build`, verifica el contenido y repite `build` para constatar que no rehace nada si no cambió la fuente.
   Comandos:

   ```bash
   rm -rf out dist
   make build | tee logs/build-run1.txt
   cat out/hello.txt | tee evidencia/out-hello-run1.txt
   make build | tee logs/build-run2.txt
   stat -c '%y %n' out/hello.txt | tee -a logs/build-run2.txt
   ```

   Entrega: explica en 4-6 líneas la diferencia entre la primera y la segunda corrida, relacionándolo con el grafo de dependencias y marcas de tiempo.

3. Fuerza un fallo controlado para observar el modo estricto del shell y `.DELETE_ON_ERROR`. Sobrescribe `PYTHON` con un intérprete inexistente y verifica que no quede artefacto corrupto.
   Comandos:

   ```bash
   rm -f out/hello.txt
   PYTHON=python4 make build ; echo "exit=$?" | tee logs/fallo-python4.txt || echo "falló (esperado)"
   ls -l out/hello.txt | tee -a logs/fallo-python4.txt || echo "no existe (correcto)"
   ```

   Entrega: en 5-7 líneas, comenta cómo `-e -u -o pipefail` y `.DELETE_ON_ERROR` evitan estados inconsistentes.

4. Realiza un "ensayo" (dry-run) y una depuración detallada para observar el razonamiento de Make al decidir si rehacer o no.
   Comandos:

   ```bash
   make -n build | tee logs/dry-run-build.txt
   make -d build |& tee logs/make-d.txt
   grep -n "Considerando el archivo objetivo 'out/hello.txt'" logs/make-d.txt
   ```

   Entrega: resume en 6-8 líneas qué significan fragmentos resultantes.

5. Demuestra la incrementalidad con marcas de tiempo. Primero toca la **fuente** y luego el **target** para comparar comportamientos.
   Comandos:

   ```bash
   touch src/hello.py
   make build | tee logs/rebuild-after-touch-src.txt

   touch out/hello.txt
   make build | tee logs/no-rebuild-after-touch-out.txt
   ```

   Entrega: explica en 5-7 líneas por qué cambiar la fuente obliga a rehacer, mientras que tocar el target no forja trabajo extra.

6. Ejecuta verificación de estilo/formato **manual** (sin objetivos `lint/tools`). Si las herramientas están instaladas, muestra sus diagnósticos; si no, deja evidencia de su ausencia.
   Comandos:

   ```bash
   command -v shellcheck >/dev/null && shellcheck scripts/run_tests.sh | tee logs/lint-shellcheck.txt || echo "shellcheck no instalado" | tee logs/lint-shellcheck.txt
   command -v shfmt >/dev/null && shfmt -d scripts/run_tests.sh | tee logs/format-shfmt.txt || echo "shfmt no instalado" | tee logs/format-shfmt.txt
   ```

   Entrega: en 4-6 líneas, interpreta advertencias/sugerencias (o comenta la ausencia de herramientas y cómo instalarlas en tu entorno).

7. Construye un paquete **reproducible** de forma manual, fijando metadatos para que el hash no cambie entre corridas idénticas. Repite el empaquetado y compara hashes.
   Comandos:

   ```bash
   mkdir -p dist
   tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner -cf dist/app.tar src/hello.py
   gzip -n -9 -c dist/app.tar > dist/app.tar.gz
   sha256sum dist/app.tar.gz | tee logs/sha256-1.txt

   rm -f dist/app.tar.gz
   tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner -cf dist/app.tar src/hello.py
   gzip -n -9 -c dist/app.tar > dist/app.tar.gz
   sha256sum dist/app.tar.gz | tee logs/sha256-2.txt

   diff -u logs/sha256-1.txt logs/sha256-2.txt | tee logs/sha256-diff.txt || true
   ```

   Entrega: pega el hash y explica en 5-7 líneas cómo `--sort=name`, `--mtime=@0`, `--numeric-owner` y `gzip -n` eliminan variabilidad.

8. Reproduce el error clásico "missing separator" **sin tocar el Makefile original**. Crea una copia, cambia el TAB inicial de una receta por espacios, y confirma el error.
   Comandos:

   ```bash
   cp Makefile Makefile_bad
   # (Edita Makefile_bad: en la línea de la receta de out/hello.txt, reemplaza el TAB inicial por espacios)
   make -f Makefile_bad build |& tee evidencia/missing-separator.txt || echo "error reproducido (correcto)"
   ```

   Entrega: explica en 4-6 líneas por qué Make exige TAB al inicio de líneas de receta y cómo diagnosticarlo rápido.

#### 1.3 Crear un script Bash 

Haz ejecutable y pega el contenido:

```bash
chmod +x scripts/run_tests.sh
```

```bash
#!/usr/bin/env bash
# scripts/run_tests.sh

set -euo pipefail
IFS=$'\n\t'
umask 027
set -o noclobber

# Usa PYTHON del entorno si existe; si no, python3
PY="${PYTHON:-python3}"

# Directorio de código fuente
SRC_DIR="src"

# Archivo temporal
tmp="$(mktemp)"

# Limpieza segura + posible rollback de hello.py si existiera un .bak
cleanup() {
	rc="$1"
	rm -f "$tmp"
	if [ -f "${SRC_DIR}/hello.py.bak" ]; then
		mv -- "${SRC_DIR}/hello.py.bak" "${SRC_DIR}/hello.py"
	fi
	exit "$rc"
}
trap 'cleanup $?' EXIT INT TERM

# Verificación de dependencias
check_deps() {
	local -a deps=("$PY" grep)
	for dep in "${deps[@]}"; do
		if ! command -v "$dep" >/dev/null 2>&1; then
			echo "Error: $dep no está instalado" >&2
			exit 1
		fi
	done
}

# Ejecuta un "test" simple sobre src/hello.py
run_tests() {
	local script="$1"
	local output
	output="$("$PY" "$script")"
	if ! echo "$output" | grep -Fq "Hello, World!"; then
		echo "Test falló: salida inesperada" >&2
		mv -- "$script" "${script}.bak" || true
		exit 2
	fi
	echo "Test pasó: $output"
}

# Demostración de pipefail
echo "Demostrando pipefail:"
set +o pipefail
if false | true; then
	echo "Sin pipefail: el pipe se considera exitoso (status 0)."
fi
set -o pipefail
if false | true; then
	:
else
	echo "Con pipefail: se detecta el fallo (status != 0)."
fi

# Escribir en $tmp (ya existe); '>|' evita el bloqueo de 'noclobber'
cat <<'EOF' >|"$tmp"
Testeando script Python
EOF

# Ejecutar
check_deps
run_tests "${SRC_DIR}/hello.py"
```

**Ejercicios:**

* Ejecuta ./scripts/run\_tests.sh en un repositorio limpio. Observa las líneas "Demostrando pipefail": primero sin y luego con pipefail.
  Verifica que imprime "Test pasó" y termina exitosamente con código 0 (`echo $?`).
* Edita src/hello.py para que no imprima "Hello, World!". Ejecuta el script: verás "Test falló", moverá hello.py a hello.py.bak, y el **trap** lo restaurará. Confirma código 2 y ausencia de .bak.
* Ejecuta `bash -x scripts/run_tests.sh`. Revisa el trace: expansión de `tmp` y `PY`, llamadas a funciones, here-doc y tuberías. Observa el trap armado al inicio y ejecutándose al final; estado 0.
* Sustituye `output=$("$PY" "$script")` por `("$PY" "$script")`. Ejecuta script. `output` queda indefinida; con `set -u`, al referenciarla en `echo` aborta antes de `grep`. El trap limpia y devuelve código distinto no-cero.

 > En Bash, *trap* registra acciones a ejecutar cuando ocurren señales o eventos (EXIT, INT, ERR).
> Permite limpiar recursos, restaurar archivos, cerrar procesos, registrar errores y preservar códigos de salida correctamente.
