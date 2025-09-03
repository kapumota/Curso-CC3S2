#!/usr/bin/env bash
#
# CARACTERÍSTICAS:
#   - Salida por ETAPAS (CLI, Administración, Redes, Bash Robusto, Unix Text Toolkit)
#   - Modo --dry-run para no ejecutar acciones potencialmente intrusivas
#   - Idempotente: usa un directorio temporal LAB_DIR (por defecto ./lab_tmp)
#   - Explicaciones ricas con ejemplos reales y simulados
#   - Uso de: navegación, globbing, pipes, redirecciones, xargs
#             usuarios/grupos/permisos, procesos/señales, systemd/journalctl (si existen)
#             ip, ss, curl, nc, comprobaciones HTTP, ssh/scp/rsync (seguros/dry-run)
#             set -euo pipefail, IFS, funciones, arrays, here-docs, subshell vs sustitución
#             trap, códigos de salida
#             grep, sed, awk, cut, sort, uniq, tr, tee, find
#
# USO:
#   ./devops_unix_lab.sh [opciones]
#
# OPCIONES:
#   --stage {all|1|2|3|4|5}   Ejecuta una etapa específica (por defecto: all)
#   --dry-run                 Imprime/omite acciones cambiantes (modo seguro)
#   --cleanup                 Elimina LAB_DIR y sale
#   --fast                    Reduce dataset de ejemplo para ejecución más breve
#   --verbose                 Muestra comandos antes de ejecutarlos
#   --no-color                Desactiva colores ANSI
#
# ETAPAS:
#   1) CLI Sólida (navegación, globbing, pipes, redirecciones, xargs)
#   2) Administración Básica (usuarios/grupos/permisos, procesos/señales, systemd, journalctl)
#   3) Redes Esenciales (ip, ss, curl, nc, HTTP checks, ssh/scp/rsync)
#   4) Bash Robusto (set -euo, IFS, funciones, arrays, here-doc, subshell vs $( ), trap, exit codes)
#   5) Unix Text Toolkit (grep, sed, awk, cut, sort, uniq, tr, tee, find)
#
# NOTAS DE SEGURIDAD:
#   - NUNCA crea usuarios/grupos del sistema ni toca servicios de producción.
#   - Para systemd/journalctl/ssh/scp/rsync: opera en modo lectura o simulado/dry-run.
#   - Para redes: usa timeouts cortos, HEAD requests y destinos públicos (example.com) o locales.
#
# Requisitos mínimos: bash 4+, coreutils, procps/psmisc, iproute2, curl, netcat (o ncat), rsync.
# En ausencia de algún binario, el script degradará con mensajes "no disponible".


set -euo pipefail
IFS=$'\n\t'

#Config global 
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
LAB_DIR_DEFAULT="$SCRIPT_DIR/lab_tmp"
LAB_DIR="${LAB_DIR:-$LAB_DIR_DEFAULT}"

DRY_RUN=0
FAST=0
VERBOSE=0
NO_COLOR=0
STAGE="all"

# Colores 
function _init_colors() {
  if [[ -t 1 && $NO_COLOR -eq 0 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
    C_GRAY=$'\033[90m'
  else
    C_RESET=""; C_BOLD=""; C_DIM=""
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
    C_MAGENTA=""; C_CYAN=""; C_GRAY=""
  fi
}
_init_colors

# Mensajería/Logs
function say()   { printf "%s\n" "$*"; }
function info()  { printf "%b[i]%b %s\n" "$C_CYAN" "$C_RESET" "$*"; }
function ok()    { printf "%b[✔]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
function warn()  { printf "%b[!]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
function err()   { printf "%b[x]%b %s\n" "$C_RED" "$C_RESET" "$*"; }
function sec()   { printf "\n%b==>%b %b%s%b\n" "$C_MAGENTA" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }
function sub()   { printf "%b  ->%b %s\n" "$C_BLUE" "$C_RESET" "$*"; }
function mute()  { printf "%b     %s%b\n" "$C_GRAY" "$*" "$C_RESET"; }

# Trampas/limpieza
LAB_LOCK="$LAB_DIR/.lock"
declare -a CLEANUP_PATHS=()

function on_exit() {
  local code=$?
  if [[ $code -eq 0 ]]; then
    ok "Ejecución completada (exit=$code)."
  else
    err "Ejecución terminó con error (exit=$code). Revise los mensajes anteriores."
  fi
  # No borramos LAB_DIR por defecto para permitir re-ejecuciones.
}
function on_error() {
  local code=$?
  err "Error capturado (exit=$code) en línea ${BASH_LINENO[0]} (comando: ${BASH_COMMAND})"
}
trap on_exit EXIT
trap on_error ERR

# Utilidades
function usage() {
  cat <<'EOF'
Uso: ./devops_unix_lab.sh [opciones]

Opciones:
  --stage {all|1|2|3|4|5}   Ejecuta una etapa específica (por defecto: all).
  --dry-run                 Imprime/omite acciones que cambian el sistema.
  --cleanup                 Elimina LAB_DIR y sale.
  --fast                    Usa datasets pequeños para una ejecución rápida.
  --verbose                 Muestra comandos antes de ejecutarlos.
  --no-color                Desactiva colores ANSI.

Ejemplos:
  ./devops_unix_lab.sh
  ./devops_unix_lab.sh --stage 3
  DRY_RUN=1 ./devops_unix_lab.sh --stage all --fast
EOF
}

function parse_args() {
  while (( $# )); do
    case "$1" in
      --stage) STAGE="${2:-all}"; shift;;
      --dry-run) DRY_RUN=1;;
      --cleanup) rm -rf -- "$LAB_DIR"; ok "LAB_DIR eliminado: $LAB_DIR"; exit 0;;
      --fast) FAST=1;;
      --verbose) VERBOSE=1;;
      --no-color) NO_COLOR=1; _init_colors;;
      -h|--help) usage; exit 0;;
      *) err "Opción desconocida: $1"; usage; exit 1;;
    esac
    shift
  done
}

function ensure_dir() {
  local d="$1"; [[ -d "$d" ]] || mkdir -p "$d"
}

function exists() {
  command -v "$1" >/dev/null 2>&1
}

function run() {
  # Ejecuta un comando respetando --dry-run y --verbose
  if [[ $VERBOSE -eq 1 ]]; then
    mute "+ $*"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    mute "(dry-run) no se ejecuta"
    return 0
  fi
  "$@"
}

function run_timeout() {
  local t="$1"; shift
  if exists timeout; then
    run timeout "$t" "$@"
  else
    run "$@"
  fi
}

# Ejecuta y captura exit code sin abortar por set -e
function try_run() {
  set +e
  "$@"
  local code=$?
  set -e
  return $code
}

# Mostrar comando + salida acotada
function show_capture() {
  local title="$1"; shift
  sub "$title"
  if [[ $VERBOSE -eq 1 ]]; then
    mute "+ $*"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    mute "(dry-run) comando omitido"
    return 0
  fi
  # Captura con límite de líneas
  local out; out="$("$@" 2>&1 | sed -e 's/\x1b\[[0-9;]*m//g')"
  if [[ -z "$out" ]]; then mute "(sin salida)"; else
    # Limitar a 40 líneas para legibilidad
    local max=40
    if (( $(wc -l <<<"$out") > max )); then
      echo "$out" | head -n $max
      mute "... (truncado)"
    else
      echo "$out"
    fi
  fi
}

# Dataset
function init_lab_space() {
  ensure_dir "$LAB_DIR"
  ensure_dir "$LAB_DIR/cli"
  ensure_dir "$LAB_DIR/admin"
  ensure_dir "$LAB_DIR/net"
  ensure_dir "$LAB_DIR/text"
  ensure_dir "$LAB_DIR/systemd"
  : > "$LAB_LOCK"
  ok "LAB_DIR: $LAB_DIR"
}

# ETAPA 1
# CLI Sólida: navegación, globbing, pipes, redirecciones, xargs
function stage_01_cli() {
  sec "Etapa 1: CLI sólida — navegación, globbing, pipes, redirecciones, xargs"

  local D="$LAB_DIR/cli"
  ensure_dir "$D"/{in,out,tmp,docs}
  sub "Creando dataset de ejemplo para globbing y texto…"
  if [[ $FAST -eq 1 ]]; then
    run bash -c 'for i in {1..20}; do echo "linea $i" > "'"$D"'/in/file_${i}.txt"; done'
  else
    run bash -c 'for i in {1..200}; do echo "linea $i" > "'"$D"'/in/file_${i}.txt"; done'
  fi
  run bash -c 'printf "%s\n" \
    "ERROR Disk full at 2025-08-26" \
    "WARN CPU throttling at 2025-08-26" \
    "INFO Service started ok" \
    "ERROR Network unreachable" \
    > "'"$D"'/in/app.log"'

  sub "Navegación avanzada: pushd/popd, cd - y directorios relativos"
  run bash -c "pushd '$D/in' >/dev/null && pwd && popd >/dev/null"
  run bash -c "cd '$D/out' && pwd && cd - >/dev/null"

  sub "Globbing: patrones *.txt, ? y rangos { }"
  show_capture "Listar primeros .txt" bash -c "ls -1 '$D/in'/*.txt | head -n 5"
  run bash -c "touch '$D/in/note_A.txt' '$D/in/note_B.txt' '$D/in/note_C.txt'"
  show_capture "Patrón ?:" bash -c "ls -1 '$D/in'/note_?.txt"

  sub "Brace expansion: generar series de archivos/logs"
  run bash -c "touch '$D/in'/report_{2025..2026}_{01..03}.log"
  show_capture "Ejemplo report_{2025..2026}_{01..03}.log" bash -c "ls -1 '$D/in'/report_*.log | head -n 6"

  sub "Redirecciones: >, >>, 2>, &> y here-doc"
  run bash -c "echo 'Primera línea' > '$D/out/salida.txt'"
  run bash -c "echo 'Segunda línea (append)' >> '$D/out/salida.txt'"
  run bash -c "cat '$D/out/salida.txt' 1> '$D/out/stdout.txt' 2> '$D/out/stderr.txt'"
  run bash -c "cat > '$D/docs/config.ini' <<'EOF'
# Config de ejemplo
[server]
port=8080
mode=dev
EOF"

  sub "Pipelines: grep | cut | sort | uniq -c | tee"
  run bash -c "cat '$D/in/app.log' \
    | grep -E 'ERROR|WARN|INFO' \
    | cut -d' ' -f1 \
    | sort \
    | uniq -c \
    | tee '$D/out/levels.count'"

  sub "xargs seguro con NUL: find -print0 | xargs -0"
  run bash -c "find '$D/in' -maxdepth 1 -type f -name '*.txt' -print0 \
    | xargs -0 wc -l > '$D/out/wc_l.txt'"

  sub "xargs paralelo (-P) (simulado): cat archivos y contar bytes"
  if exists xargs; then
    run bash -c "find '$D/in' -type f -name '*.txt' -print0 \
      | xargs -0 -P 4 -n 50 bash -c 'cat \"\$@\" > /dev/null' _"
    ok "xargs paralelo ejecutado (P=4, lote=50)."
  else
    warn "xargs no disponible."
  fi

  sub "Sustitución de procesos <() para streaming sin archivos intermedios"
  run bash -c "comm -12 <(ls -1 '$D/in' | sort) <(ls -1 '$D/in' | sort) | head -n 3 || true"

  ok "Etapa 1 completada."
}

# ETAPA 2
# Administración básica: usuarios/grupos/permisos, procesos/señales, systemd, journalctl
function stage_02_admin() {
  sec "Etapa 2: Administración básica — usuarios/grupos/permisos, procesos/señales, systemd, journalctl"

  local D="$LAB_DIR/admin"
  ensure_dir "$D"

  sub "Usuarios/Grupos/Permisos (sin tocar el sistema)"
  show_capture "Identidad actual (id, groups)" bash -c "id && echo 'groups: ' && groups || true"
  show_capture "Umask actual" bash -c "umask"
  run bash -c "echo 'contenido' > '$D/perm_demo.txt'"
  run bash -c "chmod 640 '$D/perm_demo.txt'"
  show_capture "stat perm_demo.txt" bash -c "stat '$D/perm_demo.txt' || ls -l '$D/perm_demo.txt'"

  sub "Permisos simbólicos y octales"
  run bash -c "chmod u+x '$D/perm_demo.txt'"
  show_capture "ls -l perm_demo.txt" ls -l "$D/perm_demo.txt"

  sub "Procesos: ps, señales, jobs; spawn controlado + kill"
  run bash -c "sleep 10 & echo \$! > '$D/sleeper.pid'"
  local SPID
  SPID="$(cat "$D/sleeper.pid")"
  show_capture "ps (sleeper activo?)" ps -o pid,ppid,stat,cmd --pid "$SPID" || true
  sub "Enviar SIGTERM al sleeper ($SPID)"
  try_run kill -TERM "$SPID" || true
  sleep 0.2
  show_capture "Verificar terminación" ps -o pid,stat,cmd --pid "$SPID" || true

  sub "systemd: listar algunos servicios (si existe)"
  if exists systemctl; then
    show_capture "systemctl --version" systemctl --version
    show_capture "5 servicios (cortado)" bash -c "systemctl list-units --type=service --no-pager | head -n 5"
  else
    warn "systemctl no disponible en este entorno."
  fi

  sub "journalctl: últimas 10 líneas (si existe)"
  if exists journalctl; then
    show_capture "journalctl -n 10" journalctl -n 10 --no-pager
  else
    warn "journalctl no disponible en este entorno."
  fi

  sub "Ejemplo seguro de unit file (NO instalamos; mostramos comandos)"
  cat > "$LAB_DIR/systemd/miapp.service" <<'EOF'
[Unit]
Description=Mi App 12-Factor (Demo)
After=network.target

[Service]
Type=simple
WorkingDirectory=%h/miapp
ExecStart=/usr/bin/python3 app.py
Restart=on-failure
Environment=APP_ENV=dev APP_PORT=8080

[Install]
WantedBy=default.target
EOF
  ok "Unit file de ejemplo en: $LAB_DIR/systemd/miapp.service"
  mute "Para instalar (simulado):
  mkdir -p ~/.config/systemd/user
  cp $LAB_DIR/systemd/miapp.service ~/.config/systemd/user/
  systemctl --user daemon-reload
  systemctl --user enable --now miapp.service
  journalctl --user -u miapp.service -f"

  ok "Etapa 2 completada."
}

# ETAPA 3
# Redes esenciales: ip, ss, curl, nc, comprobaciones HTTP, ssh/scp/rsync
function stage_03_network() {
  sec "Etapa 3: Redes esenciales — ip, ss, curl, nc, HTTP checks, ssh/scp/rsync"

  local D="$LAB_DIR/net"
  ensure_dir "$D"

  sub "Direcciones y rutas (ip)"
  if exists ip; then
    show_capture "ip -brief address" ip -brief address
    show_capture "ip route" ip route
  else
    warn "'ip' no disponible."
  fi

  sub "Sockets abiertos (ss -tuln)"
  if exists ss; then
    show_capture "ss -tuln (primeras 10)" bash -c "ss -tuln | head -n 10"
  else
    warn "'ss' no disponible."
  fi

  sub "Comprobación HTTP con curl (HEAD, tiempos y códigos)"
  if exists curl; then
    show_capture "curl -I https://example.com" curl -I -sS https://example.com
    show_capture "curl -w (tiempos)" bash -c "curl -sS -o /dev/null -w 'code=%{http_code} time_namelookup=%{time_namelookup} time_connect=%{time_connect} time_total=%{time_total}\n' https://example.com"
  else
    warn "curl no disponible."
  fi

  sub "Port-check con nc (timeout corto)"
  if exists nc; then
    try_run bash -c "echo | nc -vz -w 2 example.com 80" || true
    try_run bash -c "echo | nc -vz -w 2 example.com 443" || true
  elif exists ncat; then
    try_run bash -c "ncat -vz --recv-only example.com 80 -w 2" || true
    try_run bash -c "ncat -vz --recv-only example.com 443 -w 2" || true
  else
    warn "nc/ncat no disponible."
  fi

  sub "SSH: mostrar configuración efectiva sin conectar"
  if exists ssh; then
    show_capture "ssh -G localhost (parámetros efectivos)" ssh -G localhost
  else
    warn "ssh no disponible."
  fi

  sub "rsync (dry-run) para sincronización determinista local"
  if exists rsync; then
    run bash -c "mkdir -p '$D/src' '$D/dst'"
    run bash -c "echo 'rsync demo' > '$D/src/a.txt'"
    show_capture "rsync --dry-run -av" rsync --dry-run -av "$D/src/" "$D/dst/"
    run rsync -av "$D/src/" "$D/dst/"
    show_capture "ls dst" ls -l "$D/dst"
  else
    warn "rsync no disponible."
  fi

  sub "scp (solo demostración de flags; no copiamos remotamente)"
  if exists scp; then
    mute "Ejemplo: scp -P 22 archivo.txt usuario@host:/ruta (omitido)"
  else
    warn "scp no disponible."
  fi

  ok "Etapa 3 completada."
}

# ETAPA 4
# Bash robusto: set -euo pipefail, IFS, funciones, arrays, here-docs, subshell vs $( ), trap, exit codes
function stage_04_bash_robust() {
  sec "Etapa 4: Bash robusto — set -euo pipefail, IFS, funciones, arrays, here-docs, subshell vs sustitución, trap, exit codes"

  local D="$LAB_DIR/bash"
  ensure_dir "$D"

  sub "IFS seguro y lectura por líneas (mapfile/read)"
  run bash -c "printf '%s\n' 'alpha beta' 'gamma delta' > '$D/words.txt'"
  run bash -c "mapfile -t L < '$D/words.txt'; printf 'L[0]=%s / L[1]=%s\n' \"\${L[0]}\" \"\${L[1]}\" > '$D/mapfile.out'"
  show_capture "mapfile.out" cat "$D/mapfile.out"

  sub "Funciones con return/exit code y parámetros"
  cat > "$D/fn_demo.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
sum() { local a="$1" b="$2"; echo $((a+b)); }
fail_if_odd() { local n="$1"; (( n % 2 == 1 )) && return 17 || return 0; }
echo "sum(2,3)=$(sum 2 3)"
fail_if_odd 3 || echo "fail_if_odd(3) exit=$?"
EOF
  run bash "$D/fn_demo.sh" | tee "$D/fn_demo.out" >/dev/null
  show_capture "fn_demo.out" cat "$D/fn_demo.out"

  sub "Arrays (indexados y asociativos)"
  cat > "$D/arrays.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
declare -a A=(dev ops sec)
declare -A M=([env]=prod [region]=us-east [replicas]=3)
printf "A: %s | %s | %s\n" "${A[@]}"
for k in "${!M[@]}"; do printf "M[%s]=%s\n" "$k" "${M[$k]}"; done | sort
EOF
  run bash "$D/arrays.sh" | tee "$D/arrays.out" >/dev/null
  show_capture "arrays.out" cat "$D/arrays.out"

  sub "Here-doc con y sin expansión (<<EOF vs <<'EOF')"
  cat > "$D/here.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
NAME="MiServicio"
cat <<EXPAND
Servicio: $NAME
Ruta: $HOME
EXPAND
cat <<'NOEXPAND'
LITERAL $NAME no se expande.
Ruta literal: $HOME
NOEXPAND
EOF
  run bash "$D/here.sh" | tee "$D/here.out" >/dev/null
  show_capture "here.out" cat "$D/here.out"

  sub "Subshell (paréntesis) vs sustitución de comandos $( )"
  cat > "$D/subshell.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
D="$(pwd)"
( cd / >/dev/null; echo "(subshell) ahora estoy en: $(pwd)"; )
echo "(padre) sigo en: $D"
LIST="$(ls -1 2>/dev/null | wc -l)"
echo "Número de entradas en directorio actual: $LIST"
EOF
  run bash "$D/subshell.sh" | tee "$D/subshell.out" >/dev/null
  show_capture "subshell.out" cat "$D/subshell.out"

  sub "trap de limpieza y reporte de errores"
  cat > "$D/trap_demo.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
cleanup(){ rm -rf "$TMP"; echo "[cleanup] borrado $TMP"; }
onerr(){ echo "[error] status=$? en línea ${BASH_LINENO[0]} (cmd=${BASH_COMMAND})"; }
trap cleanup EXIT
trap onerr ERR
echo "Trabajando en $TMP"
echo "hola" > "$TMP/archivo"
false  # fuerza error para demostrar ERR
EOF
  try_run bash "$D/trap_demo.sh" | tee "$D/trap_demo.out" >/dev/null || true
  show_capture "trap_demo.out" cat "$D/trap_demo.out"

  sub "PIPESTATUS: códigos de salida en pipelines"
  cat > "$D/pipestatus.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
( false | true | true ) || true
echo "PIPESTATUS: ${PIPESTATUS[*]}"
EOF
  run bash "$D/pipestatus.sh" | tee "$D/pipestatus.out" >/dev/null
  show_capture "pipestatus.out" cat "$D/pipestatus.out"

  ok "Etapa 4 completada."
}

# ETAPA 5 
# Unix text toolkit: grep, sed, awk, cut, sort, uniq, tr, tee, find
function stage_05_text_toolkit() {
  sec "Etapa 5: Unix Text Toolkit-grep, sed, awk, cut, sort, uniq, tr, tee, find"

  local D="$LAB_DIR/text"
  ensure_dir "$D"
  sub "Generando logs sintéticos reproducibles…"
  local N=2000
  [[ $FAST -eq 1 ]] && N=400
  run bash -c "rm -f '$D/app.log' '$D/access.log'"
  run bash -c '
    set -e
    for i in $(seq 1 '"$N"'); do
      lvl=$(shuf -e INFO WARN ERROR -n1)
      svc=$(shuf -e web api worker -n1)
      printf "%s %s %s %s\n" "$(date +%Y-%m-%dT%H:%M:%S)" "$lvl" "$svc" "msg=$i"
    done > "'"$D"'/app.log"
  '
  run bash -c '
    set -e
    for i in $(seq 1 '"$N"'); do
      code=$(shuf -e 200 201 204 301 302 400 401 403 404 429 500 502 503 -n1)
      method=$(shuf -e GET POST PUT PATCH DELETE -n1)
      path=$(shuf -e / /api /login /logout /items /items/42 -n1)
      rt=$(awk -v min=0.01 -v max=1.50 "BEGIN{srand(); printf \"%.3f\", min+rand()*(max-min)}")
      printf "%s %s %s %s %.3f\n" "$(date +%H:%M:%S)" "$method" "$path" "$code" "$rt"
    done > "'"$D"'/access.log"
  '

  sub "grep: filtrar líneas ERROR y contar"
  show_capture "grep ' ERROR ' | wc -l" bash -c "grep ' ERROR ' '$D/app.log' | wc -l"

  sub "grep -E con regex: niveles y servicios combinados"
  show_capture "grep -E '(ERROR|WARN) (api|worker)'" bash -c "grep -E '(ERROR|WARN) (api|worker)' '$D/app.log' | head -n 5"

  sub "sed: sustitución in-place (copia segura) y extracción"
  run bash -c "cp '$D/app.log' '$D/app.sed.log'"
  run bash -c "sed -i 's/worker/queue/g' '$D/app.sed.log'"
  show_capture "sed cambio worker->queue" bash -c "grep 'queue' '$D/app.sed.log' | head -n 3"

  sub "awk: agregación por nivel (cuenta) y por servicio (cuenta)"
  show_capture "awk niveles" awk '{c[$2]++} END{for(k in c) printf "%s %d\n", k, c[k]}' "$D/app.log" | sort
  show_capture "awk servicios" awk '{c[$3]++} END{for(k in c) printf "%s %d\n", k, c[k]}' "$D/app.log" | sort

  sub "cut/sort/uniq: histogramas de códigos HTTP"
  show_capture "Histogramas códigos" bash -c "cut -d' ' -f4 '$D/access.log' | sort | uniq -c | sort -nr | head"

  sub "tr: normalización (mayúsculas->minúsculas) antes de conteo"
  show_capture "tr + uniq" bash -c "cut -d' ' -f2 '$D/access.log' | tr '[:upper:]' '[:lower:]' | sort | uniq -c"

  sub "tee: guardar mientras mostramos"
  run bash -c "grep ' 5..$' '$D/access.log' | tee '$D/server_errors.log' >/dev/null"
  show_capture "server_errors.log (5xx)" head -n 5 "$D/server_errors.log"

  sub "find: búsqueda por nombre/tiempo/tamaño"
  run bash -c "dd if=/dev/zero of='$D/big.bin' bs=1K count=1024 status=none"
  show_capture "find . -name '*.log' -size -100k" bash -c "cd '$D' && find . -name '*.log' -size -100k -printf '%p %kKB\n' | head"

  sub "find -print0 | xargs -0 para procesar logs en lote"
  run bash -c "cd '$D' && find . -name '*.log' -print0 | xargs -0 wc -l > summary_wc.txt"
  show_capture "summary_wc.txt" head -n 5 "$D/summary_wc.txt"

  sub "awk avanzado: percentiles aproximados del response time (p50, p95, p99)"
  cat > "$D/pctl.awk" <<'EOF'
# calcula percentiles aproximando por ordenamiento en memoria (dataset acotado)
{ vals[++n]=$5 }
END{
  if(n==0){print "no data"; exit}
  # bubble sort simple (dataset pequeño para demo)
  for(i=1;i<=n;i++) for(j=1;j<=n-1;j++) if(vals[j]>vals[j+1]){t=vals[j];vals[j]=vals[j+1];vals[j+1]=t}
  p=function(p){ idx=int(p*(n+1)); if(idx<1)idx=1; if(idx>n)idx=n; return vals[idx] }
  printf "n=%d p50=%.3f p95=%.3f p99=%.3f\n", n, p(0.50), p(0.95), p(0.99)
}
EOF
  show_capture "percentiles" awk -f "$D/pctl.awk" "$D/access.log"

  ok "Etapa 5 completada."
}

# Orquestación
declare -A STAGE_MAP=(
  [1]=stage_01_cli
  [2]=stage_02_admin
  [3]=stage_03_network
  [4]=stage_04_bash_robust
  [5]=stage_05_text_toolkit
)

function run_stage() {
  local s="$1"
  if [[ "$s" == "all" ]]; then
    for i in 1 2 3 4 5; do
      "${STAGE_MAP[$i]}"
    done
  else
    if [[ -n "${STAGE_MAP[$s]:-}" ]]; then
      "${STAGE_MAP[$s]}"
    else
      err "Etapa desconocida: $s"; usage; exit 1
    fi
  fi
}

# Resumen
function summary() {
  sec "Resumen de laboratorio (estructura de $LAB_DIR)"
  show_capture "árbol (nivel 2)" bash -c "cd '$LAB_DIR' && (command -v tree >/dev/null && tree -L 2 || find . -maxdepth 2 -type d -print)"
  sub "Re-ejecutar etapas:"
  mute "  ./devops_unix_lab.sh --stage 1     # Solo CLI"
  mute "  ./devops_unix_lab.sh --stage 2     # Administración"
  mute "  ./devops_unix_lab.sh --stage 3     # Redes"
  mute "  ./devops_unix_lab.sh --stage 4     # Bash robusto"
  mute "  ./devops_unix_lab.sh --stage 5     # Text toolkit"
  mute "  DRY_RUN=1 ./devops_unix_lab.sh --stage all --fast  # Demo rápida y segura"
}

#Main 
parse_args "$@"
init_lab_space
run_stage "$STAGE"
summary
exit 0

