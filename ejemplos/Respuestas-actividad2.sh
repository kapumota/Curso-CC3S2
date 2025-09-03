#!/usr/bin/env bash
# 1) Convierte CRLF -> LF
#sed -i 's/\r$//' Respuestas-actividad2.sh

# 2) Correge un typo si lo tienes en tu copia: >/div/null -> >/dev/null
#sed -i 's|>/div/null|>/dev/null|g' Respuestas-actividad2.sh

# Archivo: Respuestas-actividad2.sh
# Uso:
#   chmod +x Respuestas-actividad2.sh
#   ./Respuestas-actividad2.sh all               # ejecutar todo el flujo end-to-end
#   ./Respuestas-actividad2.sh prepare           # crear venv y app.py
#   ./Respuestas-actividad2.sh run               # iniciar Flask en $PORT
#   ./Respuestas-actividad2.sh http-checks       # evidencias con curl y ss
#   ./Respuestas-actividad2.sh hosts-setup       # añadir 127.0.0.1 miapp.local
#   ./Respuestas-actividad2.sh dns-demo          # dig/getent/TTL
#   ./Respuestas-actividad2.sh tls-cert          # cert autofirmado con SAN
#   ./Respuestas-actividad2.sh nginx             # reverse proxy TLS -> Flask
#   ./Respuestas-actividad2.sh tls-checks        # openssl s_client y curl -k
#   ./Respuestas-actividad2.sh logs-pipeline     # demostrar logs por stdout
#   ./Respuestas-actividad2.sh table             # tabla Comando->Resultado
#   ./Respuestas-actividad2.sh systemd           # unidad opcional si hay systemd
#   ./Respuestas-actividad2.sh stop              # detener la app
#   ./Respuestas-actividad2.sh clean             # limpiar artefactos
set -euo pipefail

# Configuración (puedes sobrescribir con variables de entorno)
DOMAIN="${DOMAIN:-miapp.local}"
PORT="${PORT:-8080}"
MESSAGE="${MESSAGE:-Hola CC3S2}"
RELEASE="${RELEASE:-v1}"

ROOT_DIR="$(pwd)"
APP_DIR="${APP_DIR:-$ROOT_DIR/miapp}"
VENV="$APP_DIR/.venv"
EVID="$ROOT_DIR/evidencias"
CERT_DIR="$ROOT_DIR/certs"
NGINX_SITE="/etc/nginx/sites-available/miapp.conf"
NGINX_LINK="/etc/nginx/sites-enabled/miapp.conf"
SYS_ENV="/etc/default/miapp"
SYS_UNIT="/etc/systemd/system/miapp.service"

mkdir -p "$APP_DIR" "$EVID" "$CERT_DIR"

# Funciones de registro simples
log(){ printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[ADVERTENCIA]\033[0m %s\n" "$*"; }
err(){ printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2; }

# Verifica que exista un comando requerido
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { err "Falta el comando: $1"; exit 1; }; }

# Asegura paquete (vía apt) si falta
ensure_pkg(){
  if ! dpkg -s "$1" >/dev/null 2>&1; then
    log "Instalando paquete: $1 (requiere sudo)"
    sudo apt-get update -y && sudo apt-get install -y "$1"
  fi
}

# Detecta si systemd está disponible
is_systemd(){ [[ -d /run/systemd/system ]]; }

# Obtiene el PID que escucha en un puerto (si existe)
pid_on_port(){
  ss -ltnp | awk -v p=":$1" '$4 ~ p {print $0}' | sed -E 's/.*pid=([0-9]+).*/\1/' | head -n1 || true
}

# Genera la aplicación Flask de ejemplo
write_app(){
  cat > "$APP_DIR/app.py" <<'PY'
import os, sys, time, json, logging
from flask import Flask, jsonify, request

# Configuración por entorno (12-Factor): se lee al iniciar el proceso
APP_MESSAGE = os.environ.get("MESSAGE", "Hola CC3S2")
APP_RELEASE = os.environ.get("RELEASE", "v1")
APP_PORT    = int(os.environ.get("PORT", "8080"))

app = Flask(__name__)

# Logs estructurados (JSON por línea) a stdout
logging.basicConfig(level=logging.INFO, stream=sys.stdout, format="%(message)s")
logger = logging.getLogger("miapp")

def jlog(level, **kv):
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "level": level, **kv}
    logger.info(json.dumps(rec, ensure_ascii=False))

@app.before_request
def log_request():
    jlog("INFO", event="request",
         method=request.method,
         path=request.path,
         remote=request.headers.get("X-Forwarded-For") or request.remote_addr,
         proto=request.headers.get("X-Forwarded-Proto") or request.environ.get("wsgi.url_scheme"))

@app.route("/", methods=["GET"])
def index():
    # Respuesta JSON incluyendo cabeceras de proxy para observabilidad
    payload = {
        "message": APP_MESSAGE,
        "release": APP_RELEASE,
        "headers": {
            "X-Forwarded-For": request.headers.get("X-Forwarded-For"),
            "X-Forwarded-Proto": request.headers.get("X-Forwarded-Proto"),
            "X-Forwarded-Host": request.headers.get("X-Forwarded-Host"),
        }
    }
    return jsonify(payload), 200

if __name__ == "__main__":
    jlog("INFO", event="startup", port=APP_PORT)
    # Port binding: expone en todas las interfaces
    app.run(host="0.0.0.0", port=APP_PORT)
PY
}

# Prepara entorno virtual e instala dependencias
prepare(){
  need_cmd python3
  ensure_pkg python3-venv
  log "Creando entorno virtual en $VENV"
  python3 -m venv "$VENV"
  # shellcheck disable=SC1091 (fuente de venv en tiempo de ejecución)
  source "$VENV/bin/activate"
  pip install --upgrade pip >/dev/null
  pip install flask >/dev/null
  write_app
  log "Aplicación creada en $APP_DIR/app.py"
}

# Detiene la app si está corriendo
stop(){
  if [[ -f "$APP_DIR/app.pid" ]] && kill -0 "$(cat "$APP_DIR/app.pid")" 2>/dev/null; then
    log "Deteniendo app Flask (PID $(cat "$APP_DIR/app.pid"))"
    kill "$(cat "$APP_DIR/app.pid")" || true
    sleep 1
  fi
  if p=$(pid_on_port "$PORT"); then
    if [[ -n "$p" ]]; then
      warn "El puerto $PORT sigue en uso por PID $p; intentando kill"
      sudo kill "$p" || true
    fi
  fi
}

# Inicia la app con variables de entorno
run_app(){
  stop || true
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  log "Iniciando Flask en PORT=$PORT MESSAGE='$MESSAGE' RELEASE='$RELEASE'"
  ( cd "$APP_DIR"
    PORT="$PORT" MESSAGE="$MESSAGE" RELEASE="$RELEASE" \
      nohup "$VENV/bin/python" app.py > "$EVID/4--01-app-stdout.log" 2>&1 &
    echo $! > "$APP_DIR/app.pid"
  )
  sleep 1
  log "App PID: $(cat "$APP_DIR/app.pid") — stdout -> $EVID/4--01-app-stdout.log"
}

# Comprobaciones HTTP (cabeceras, códigos, socket)
http_checks(){
  need_cmd curl
  need_cmd ss
  log "curl -v http://127.0.0.1:$PORT/"
  curl -sS -v "http://127.0.0.1:$PORT/" -o /dev/null \
    2> "$EVID/4--02-curl-v.txt" || true
  log "curl -i -X POST http://127.0.0.1:$PORT/"
  curl -sS -i -X POST "http://127.0.0.1:$PORT/" \
    > "$EVID/4--03-curl-i-post.txt" || true
  log "ss -ltnp | grep :$PORT"
  ss -ltnp | grep ":$PORT" > "$EVID/4--04-ss-port-$PORT.txt" || true

  cat > "$EVID/4--05-env-change-explanation.txt" <<EOF
Pregunta guía: ¿Qué cambia si modificas MESSAGE/RELEASE sin reiniciar?
Respuesta: Nada en la app en ejecución. Las variables de entorno se leen
al iniciar el proceso (12-Factor: Build/Release/Run). Cambiarlas en tu shell
no altera el entorno del proceso ya lanzado; debes reiniciar para que apliquen.
EOF
}

# Añade entrada a /etc/hosts para el dominio de laboratorio
hosts_setup(){
  if grep -qE "127\.0\.0\.1[[:space:]]+$DOMAIN" /etc/hosts; then
    log "/etc/hosts ya contiene $DOMAIN"
  else
    log "Agregando 127.0.0.1 $DOMAIN a /etc/hosts (requiere sudo)"
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts >/dev/null
  fi
  printf "Resolución local activa para %s (127.0.0.1)\n" "$DOMAIN" \
    > "$EVID/4--06-hosts-setup.txt"
}

# Demostración DNS y TTL
dns_demo(){
  need_cmd dig
  need_cmd getent
  log "dig +short $DOMAIN"
  dig +short "$DOMAIN" > "$EVID/4--07-dig-miapp.txt" || true
  log "getent hosts $DOMAIN"
  getent hosts "$DOMAIN" > "$EVID/4--08-getent-miapp.txt" || true
  log "TTL demo: dig example.com A +ttlunits"
  dig example.com A +ttlunits > "$EVID/4--09-ttl-demo.txt" || true

  cat > "$EVID/4--10-hosts-vs-authoritative.txt" <<'EOF'
Diferencia /etc/hosts vs zona DNS autoritativa:
- /etc/hosts es un archivo local estático que el resolutor consulta primero; no hay TTL ni delegación.
- Una zona autoritativa vive en servidores DNS y responde para su dominio con TTLs y delegación.
- Para laboratorio, /etc/hosts basta porque fuerza la resolución local sin depender de DNS público.
EOF
}

# Genera certificado autofirmado con SAN (dominio e IP)
tls_cert(){
  ensure_pkg openssl
  local crt="$CERT_DIR/$DOMAIN.crt"
  local key="$CERT_DIR/$DOMAIN.key"
  if [[ -f "$crt" && -f "$key" ]]; then
    log "Certificado existente en $crt"
  else
    log "Generando certificado autofirmado (SAN: DNS:$DOMAIN, IP:127.0.0.1)"
    openssl req -x509 -newkey rsa:2048 -days 365 -nodes \
      -keyout "$key" -out "$crt" \
      -subj "/CN=$DOMAIN" \
      -addext "subjectAltName=DNS:$DOMAIN,IP:127.0.0.1" >/dev/null 2>&1
  fi
  printf "crt=%s\nkey=%s\n" "$crt" "$key" > "$EVID/4--11-cert-paths.txt"
}

# Configura Nginx como reverse proxy TLS -> Flask
nginx_setup(){
  ensure_pkg nginx
  tls_cert

  local crt="$CERT_DIR/$DOMAIN.crt"
  local key="$CERT_DIR/$DOMAIN.key"

  log "Escribiendo server block de Nginx en $NGINX_SITE (requiere sudo)"
  sudo tee "$NGINX_SITE" >/dev/null <<NGX
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate     $crt;
    ssl_certificate_key $key;

    add_header Strict-Transport-Security "max-age=31536000" always;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Host \$host;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}
NGX

  if [[ ! -e "$NGINX_LINK" ]]; then
    sudo ln -s "$NGINX_SITE" "$NGINX_LINK" || true
  fi

  log "Validando configuración: nginx -t"
  sudo nginx -t 2> "$EVID/4--12-nginx-test.txt" || { err "nginx -t falló"; exit 1; }

  log "Recargando Nginx"
  if is_systemd; then
    sudo systemctl reload nginx
  else
    sudo service nginx reload
  fi
}

# Comprobaciones TLS y sockets 443/8080
tls_checks(){
  need_cmd openssl
  need_cmd curl
  need_cmd ss

  log "openssl s_client -connect $DOMAIN:443 -servername $DOMAIN -brief"
  openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" -brief </dev/null \
    > "$EVID/4--13-s_client-brief.txt" 2>&1 || true

  log "curl -k https://$DOMAIN/"
  curl -sS -k "https://$DOMAIN/" -D "$EVID/4--14-curl-k-headers.txt" \
    > "$EVID/4--15-curl-k-body.json" || true

  log "ss -ltnp | grep -E ':(443|$PORT)'"
  ss -ltnp | grep -E ":(443|$PORT)" > "$EVID/4--16-ss-ports-443-8080.txt" || true

  if is_systemd; then
    log "journalctl -u nginx -n 50 --no-pager"
    sudo journalctl -u nginx -n 50 --no-pager > "$EVID/4--17-nginx-journalctl.txt" || true
  else
    if [[ -f /var/log/nginx/error.log ]]; then
      sudo tail -n 50 /var/log/nginx/error.log > "$EVID/4--17-nginx-errorlog.txt" || true
    fi
  fi
}

# Demuestra logs por stdout redirigidos por pipeline
logs_pipeline(){
  log "Generando solicitudes para producir logs"
  curl -s "http://127.0.0.1:$PORT/" >/dev/null || true
  ( sleep 0.5; curl -s "http://127.0.0.1:$PORT/" >/dev/null ) &

  log "Capturando 5 líneas con pipeline: tail -f ... | head -n 5"
  timeout 3s tail -f "$EVID/4--01-app-stdout.log" | head -n 5 \
    > "$EVID/4--18-logs-pipeline-sample.txt" || true

  cat > "$EVID/4--19-why-stdout-12factor.txt" <<'EOF'
12-Factor: Logs como flujo en stdout/stderr.
La app no escribe a archivos; el entorno (CLI, systemd, Docker, etc.) redirige/recoge.
Esto simplifica agregación, rotación y envío a herramientas (ELK, Loki).
EOF
}

# Emite un Makefile con atajos para re-ejecutar el flujo
makefile_emit(){
  cat > "$ROOT_DIR/Makefile" <<'MK'
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
all: prepare run hosts-setup dns-demo http-checks tls-cert nginx tls-checks logs-pipeline table

prepare: ; ./Respuestas-actividad2.sh prepare
run:     ; ./Respuestas-actividad2.sh run
hosts-setup: ; ./Respuestas-actividad2.sh hosts-setup
dns-demo: ; ./Respuestas-actividad2.sh dns-demo
http-checks: ; ./Respuestas-actividad2.sh http-checks
tls-cert: ; ./Respuestas-actividad2.sh tls-cert
nginx: ; ./Respuestas-actividad2.sh nginx
tls-checks: ; ./Respuestas-actividad2.sh tls-checks
logs-pipeline: ; ./Respuestas-actividad2.sh logs-pipeline
systemd: ; ./Respuestas-actividad2.sh systemd
stop: ; ./Respuestas-actividad2.sh stop
clean: ; ./Respuestas-actividad2.sh clean
table: ; ./Respuestas-actividad2.sh table

.PHONY: all prepare run hosts-setup dns-demo http-checks tls-cert nginx tls-checks logs-pipeline systemd stop clean table
MK
  log "Makefile generado. Puedes ejecutar: make all"
}

# Genera la tabla Comando -> Resultado esperado (Markdown)
table_md(){
  cat > "$EVID/4--20-tabla_comandos.md" <<EOF
# Comando -> Resultado esperado

| Comando | Resultado esperado |
|---|---|
| \`PORT=$PORT MESSAGE="$MESSAGE" RELEASE="$RELEASE" python3 app.py\` | La app escucha en :$PORT, hace logs JSON a stdout y responde JSON con \`message\` y \`release\`. |
| \`curl -v http://127.0.0.1:$PORT/\` | Muestra solicitud/respuesta con cabeceras, código 200 y cuerpo JSON. |
| \`curl -i -X POST http://127.0.0.1:$PORT/\` | Devuelve 405 Method Not Allowed (la ruta '/' solo acepta GET). |
| \`ss -ltnp | grep :$PORT\` | Socket TCP en LISTEN con el PID del proceso Python. |
| \`dig +short $DOMAIN\` | Devuelve 127.0.0.1 (por entrada en /etc/hosts). |
| \`getent hosts $DOMAIN\` | Resolución vía NSS; muestra 127.0.0.1. |
| \`openssl s_client -connect $DOMAIN:443 -servername $DOMAIN -brief\` | Handshake TLSv1.2/1.3 con certificado autofirmado; SNI correcto. |
| \`curl -k https://$DOMAIN/\` | Respuesta 200 con JSON; \`-k\` omite validación de CA por ser autofirmado. |
| \`journalctl -u nginx -n 50\` | Últimas líneas del servicio Nginx (si systemd). |
| \`tail -f evidencias/4--01-app-stdout.log | head -n 5\` | Demuestra logs como flujo redirigible por pipeline. |
EOF
}

# Crea una unidad systemd opcional para la app (si hay systemd)
systemd_unit(){
  if ! is_systemd; then
    warn "No se detectó systemd; se omite la creación de la unidad."
    return 0
  fi
  log "Creando /etc/default/miapp con variables de entorno (requiere sudo)"
  sudo tee "$SYS_ENV" >/dev/null <<EOF
PORT=$PORT
MESSAGE=$MESSAGE
RELEASE=$RELEASE
APP_DIR=$APP_DIR
VENV=$VENV
EOF

  log "Escribiendo unidad systemd en $SYS_UNIT (requiere sudo)"
  sudo tee "$SYS_UNIT" >/dev/null <<'UNIT'
[Unit]
Description=CC3S2 Flask App (miapp)
After=network.target

[Service]
Type=simple
EnvironmentFile=/etc/default/miapp
WorkingDirectory=${APP_DIR}
ExecStart=${VENV}/bin/python app.py
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT
  log "Recargando daemon y habilitando servicio"
  sudo systemctl daemon-reload
  sudo systemctl enable --now miapp
  sudo systemctl status miapp --no-pager > "$EVID/4--21-systemd-status.txt" || true
  sudo journalctl -u miapp -n 50 --no-pager > "$EVID/4--22-systemd-journal.txt" || true
}

# Limpia artefactos generados
clean(){
  stop || true
  warn "Limpiando archivos generados (se conservan certs y evidencias)"
  rm -rf "$APP_DIR/.venv" || true
  rm -f "$APP_DIR/app.py" "$APP_DIR/app.pid" || true
  if [[ -L "$NGINX_LINK" ]]; then sudo rm -f "$NGINX_LINK"; fi
  if [[ -f "$NGINX_SITE" ]]; then sudo rm -f "$NGINX_SITE"; fi
  if is_systemd && [[ -f "$SYS_UNIT" ]]; then
    sudo systemctl disable --now miapp || true
    sudo rm -f "$SYS_UNIT"
    sudo systemctl daemon-reload
  fi
}

# Orquestación completa end-to-end
all(){
  prepare
  run_app
  http_checks
  hosts_setup
  dns_demo
  nginx_setup
  tls_checks
  logs_pipeline
  makefile_emit
  table_md
  log "Listo. Revisa evidencias en: $EVID"
}

# Selector de subcomando
case "${1:-all}" in
  prepare) prepare ;;
  run) run_app ;;
  http-checks) http_checks ;;
  hosts-setup) hosts_setup ;;
  dns-demo) dns_demo ;;
  tls-cert) tls_cert ;;
  nginx) nginx_setup ;;
  tls-checks) tls_checks ;;
  logs-pipeline) logs_pipeline ;;
  table) table_md ;;
  systemd) systemd_unit ;;
  stop) stop ;;
  clean) clean ;;
  all) all ;;
  *) err "Subcomando no reconocido: $1"; exit 2 ;;
esac
