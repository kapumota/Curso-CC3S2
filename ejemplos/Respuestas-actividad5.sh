#!/usr/bin/env bash
# Automatiza, en un solo script, los ejercicios solicitados para Laboratorio2 y la actividad 5 (parte 2) con manejo robusto
# cuando 'make clean' o similares borran el directorio de evidencias.
# Requisitos: make, bash, awk, grep, sha256sum, GNU tar, shellcheck, shfmt, (opcional) ruff, python3
set -euo pipefail
IFS=$'\n\t'
umask 027

ROOT_DIR="$(pwd)"
EVID_DIR="out"

ensure_out() {
  mkdir -p "$EVID_DIR"
}

ensure_out

note() {
  ensure_out
  printf "\n\n %s \n" "$*" | tee -a "$EVID_DIR/5---master-log.txt" ;
}

run()  {
  ensure_out
  echo "+ $*" | tee -a "$EVID_DIR/5---master-log.txt" ;
  eval "$@" ;
}

# Guardar stdout+stderr de un comando en un archivo, a prueba de 'make clean' intermedio.
save() {
  local outfile="$1"; shift
  ensure_out
  echo "+ $*" | tee -a "$EVID_DIR/5---master-log.txt"
  local tmp
  tmp="$(mktemp)"
  # No fallar el script maestro por fallos esperados de subcomandos de demostración
  set +e
  bash -lc "$*" >"$tmp" 2>&1
  local rc=$?
  set -e
  ensure_out
  mv "$tmp" "$outfile"
  echo "(salida guardada en $outfile, rc=$rc)"
  return 0
}

# Helper: extraer hashes del verify-repro
extract_hashes() {
  local infile="$1"
  [ -f "$infile" ] || { echo "WARN: no existe $infile para extraer hashes" >&2; return 1; }
  awk -F'=' '/^SHA256_/{print $2}' "$infile" | tr -d '\r'
}

# Paso 0: sanidad básica
note "0) Verificación rápida de presencia de Makefile y estructura"
test -f Makefile || { echo "No se encontró Makefile en $ROOT_DIR"; exit 1; }
test -d src && test -d scripts && test -d tests || { echo "Faltan directorios src/ scripts/ tests/"; exit 1; }


# 1) make -n all (dry-run). Identificar expansiones $@, $<, orden y encadenamiento

note "1) Dry-run de 'make -n all' y explicaciones sobre \$@, \$<, encadenamiento"
save "$EVID_DIR/5---01-dry-run.txt" "make -n all"

# Intento de leer OUT_DIR y SRC_DIR desde Makefile (si no, usa defaults)
OUT_DIR="$(awk -F= '/^[[:space:]]*OUT_DIR[[:space:]]*=/ { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); print val }' Makefile)"
SRC_DIR="$(awk -F= '/^[[:space:]]*SRC_DIR[[:space:]]*=/ { val=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", val); print val }' Makefile)"
[ -n "${OUT_DIR:-}" ] || OUT_DIR="out"
[ -n "${SRC_DIR:-}" ] || SRC_DIR="src"

TARGET="$OUT_DIR/hello.txt"
FIRST_PREREQ="$SRC_DIR/hello.py"
TARGET_DIR="$OUT_DIR"

ensure_out
{
  echo "Explicación de expansiones esperadas en la regla de build:"
  echo "  \$@    -> $TARGET"
  echo "  \$(@D) -> $TARGET_DIR"
  echo "  \$<    -> $FIRST_PREREQ"
  echo "Encadenamiento de 'all': tools -> lint -> build -> test -> package (según Makefile)."
} | tee "$EVID_DIR/5---01-explicacion-expansiones.txt" >/dev/null


# 2) make -d build, localizar líneas clave y explicar recompilación por timestamps

note "2) Debug (-d) de 'make build' y análisis de timestamps"
save "$EVID_DIR/5---02-make-d-build.txt" "make -d build"

grep -E "Considering target file|Must remake target" "$EVID_DIR/5---02-make-d-build.txt" \
  > "$EVID_DIR/5---02-claves.txt" || true

explain_ts="$EVID_DIR/5---02-explicacion-timestamps.txt"
ensure_out
{
  echo "Timestamps:"
  if [ -f "$TARGET" ]; then
    echo "  Existe $TARGET (objetivo)"
    if [ "$FIRST_PREREQ" -nt "$TARGET" ]; then
      echo "  $FIRST_PREREQ es más nuevo que $TARGET → debe reconstruir."
    else
      echo "  $TARGET es más nuevo o igual → no necesita reconstruir."
    fi
  else
    echo "  No existe $TARGET → debe construir por primera vez."
  fi
  echo "mkdir -p \$(@D) asegura que el directorio destino ($TARGET_DIR) exista antes de escribir el archivo."
} > "$explain_ts"


# 3) Simular BSD tar en PATH y correr 'make tools' para observar el fallo

note "3) Simulación de 'BSD tar' y verificación de error en 'make tools'"
FAKE_BIN="$(mktemp -d)"
cat > "$FAKE_BIN/tar" <<'FAKE'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then
  echo "bsdtar 3.6.3 - libarchive"
  exit 0
fi
echo "bsdtar (fake) invocado con: $*" >&2
exit 1
FAKE
chmod +x "$FAKE_BIN/tar"

OLD_PATH="$PATH"
export PATH="$FAKE_BIN:$PATH"
save "$EVID_DIR/5---03-tools-bsd-tar.txt" "make tools"
export PATH="$OLD_PATH"


# 4) 'make verify-repro' y comparación de SHA256_1 vs SHA256_2

note "4) Verificación de reproducibilidad con 'make verify-repro'"
# Guardar salida en archivo temporal por si 'verify-repro' borra out/
tmp_vr="$(mktemp)"
set +e
bash -lc "make verify-repro" >"$tmp_vr" 2>&1
rc_vr=$?
set -e
ensure_out
cp "$tmp_vr" "$EVID_DIR/5---04-verify-repro.txt"

mapfile -t SHAS < <(extract_hashes "$EVID_DIR/5---04-verify-repro.txt" || true)
SHA1="${SHAS[0]:-}"
SHA2="${SHAS[1]:-}"

{
  echo "RC verify-repro: $rc_vr"
  echo "SHA1=$SHA1"
  echo "SHA2=$SHA2"
  if [[ -n "$SHA1" && "$SHA1" == "$SHA2" ]]; then
    echo "OK: artefactos idénticos (build determinista)"
  else
    echo "ADVERTENCIA: hashes distintos o no detectados."
    echo "Hipótesis: zona horaria, versión/implementación de tar, contenido no determinista, variables de entorno no fijadas."
  fi
} | tee "$EVID_DIR/5---04-shas.txt" >/dev/null


# 5) Cronometrar 'make clean && make all' y luego 'make all' sin cambios

note "5) Tiempos comparativos: primera vs segunda ejecución"
if command -v /usr/bin/time >/dev/null 2>&1; then
  tmp1="$(mktemp)"; set +e; bash -lc "/usr/bin/time -f 'Tiempo: %E user %U sys %S' bash -lc 'make clean && make all'" >"$tmp1" 2>&1; set -e
  ensure_out; cp "$tmp1" "$EVID_DIR/5---05-run1.txt"
  tmp2="$(mktemp)"; set +e; bash -lc "/usr/bin/time -f 'Tiempo: %E user %U sys %S' bash -lc 'make all'" >"$tmp2" 2>&1; set -e
  ensure_out; cp "$tmp2" "$EVID_DIR/5---05-run2.txt"
else
  save "$EVID_DIR/5---05-run1.txt" "bash -lc 'time -p make clean && make all'"
  save "$EVID_DIR/5---05-run2.txt" "bash -lc 'time -p make all'"
fi

ensure_out
{
  echo "Resumen tiempos:"
  if [ -f "$EVID_DIR/5---05-run1.txt" ]; then
    echo -n "  Primera: "
    grep -m1 '^Tiempo:' "$EVID_DIR/5---05-run1.txt" | sed 's/^Tiempo: //' || echo "(ver archivo)"
  else
    echo "  Primera: (sin archivo, ver logs anteriores)"
  fi
  echo -n "  Segunda: "
  (grep -m1 '^Tiempo:' "$EVID_DIR/5---05-run2.txt" | sed 's/^Tiempo: //' || echo "(ver archivo)")
} | tee "$EVID_DIR/5---05-resumen.txt" >/dev/null


# 6) PYTHON=python3.12 make test (si existe) y comprobar override; comparar artefactos

note "6) Override de intérprete: PYTHON=python3.12 (si está disponible)"
if command -v python3.12 >/dev/null 2>&1; then
  save "$EVID_DIR/5---06-py312-version.txt" "python3.12 --version"
  save "$EVID_DIR/5---06-test-py312.txt" "PYTHON=python3.12 make test"
  save "$EVID_DIR/5---06-default-package.txt" "make clean && make package"
  DEF_SHA="$(sha256sum dist/app.tar.gz | awk '{print $1}')"
  save "$EVID_DIR/5---06-py312-package.txt" "make clean && PYTHON=python3.12 make package"
  PY312_SHA="$(sha256sum dist/app.tar.gz | awk '{print $1}')"
  ensure_out
  {
    echo "SHA por defecto: $DEF_SHA"
    echo "SHA con python3.12: $PY312_SHA"
    if [[ "$DEF_SHA" == "$PY312_SHA" ]]; then
      echo "OK: artefacto idéntico; el intérprete no afecta el resultado final."
    else
      echo "DIFERENCIA: el intérprete cambió el artefacto (revisar entorno)."
    fi
  } | tee "$EVID_DIR/5---06-package-compare.txt" >/dev/null
else
  ensure_out
  echo "python3.12 no está instalado; se omite la prueba de override." | tee "$EVID_DIR/5---06-py312-skip.txt" >/dev/null
fi


# 7) make test normal y demostración de fallo propagado

note "7) make test normal y demostración de fallo del script de pruebas"
save "$EVID_DIR/5---07-test-normal.txt" "make test"

# Demostración de propagación de error: inyectar fallo temporal en scripts/run_tests.sh
ORIG="scripts/run_tests.sh"
BAK="${ORIG}.bak_autotest"
cp -f "$ORIG" "$BAK"
awk 'NR==1{print; print "exit 2 # simulación de fallo"; next}1' "$BAK" > "$ORIG"
save "$EVID_DIR/5---07-test-fail-demo.txt" "make -k test || true"
mv -f "$BAK" "$ORIG"


# 8) touch src/hello.py y analizar qué objetivos se rehacen

note "8) Cambios en src/hello.py y targets que se rehacen"
save "$EVID_DIR/5---08-touch.txt" "touch src/hello.py && make all"


# 9) make -j4 all (concurrencia) y comparación de artefacto con ejecución secuencial

note "9) Ejecución concurrente (-j4) e identidad de resultados"
run "make clean"
run "make -s all"
SEQ_SHA="$(sha256sum dist/app.tar.gz | awk '{print $1}')"
run "make clean"
# Guardar salida paralela sin perderla si clean borra out/
tmp_par="$(mktemp)"; set +e; bash -lc "make -j4 all" >"$tmp_par" 2>&1; set -e
ensure_out; cp "$tmp_par" "$EVID_DIR/5---09-parallel.txt"
PAR_SHA="$(sha256sum dist/app.tar.gz | awk '{print $1}')"
ensure_out
{
  echo "SHA secuencial: $SEQ_SHA"
  echo "SHA paralelo:   $PAR_SHA"
  if [[ "$SEQ_SHA" == "$PAR_SHA" ]]; then
    echo "OK: resultados idénticos; no hay condiciones de carrera."
  else
    echo "ADVERTENCIA: diferencias detectadas; revisar dependencias/mkdir -p."
  fi
} | tee "$EVID_DIR/5---09-sha-compare.txt" >/dev/null


# 10) make lint y make format: interpretar diagnósticos

note "10) Lint y formato"
save "$EVID_DIR/5---10-lint.txt" "make lint || true"
save "$EVID_DIR/5---10-format.txt" "make format || true"

note "Fin: revisa los archivos 5---*.txt dentro de out/ y dist/"
