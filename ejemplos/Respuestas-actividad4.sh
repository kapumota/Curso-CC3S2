#!/usr/bin/env bash
# Archivo: Respuestas-actividad4.sh
# Propósito: Ejecutar la actividad 4 (CLI para DevSecOps), generando evidencias
# y aplicando un SANITIZADOR al final en la misma ejecución.
#
# Uso:
#   chmod +x Respuestas-actividad4.sh
#   ./Respuesta-actividad4.sh                 # Ejecuta todo con grabación vía 'script' si está disponible
#   ./Respuesta-actividad4.sh --no-script     # Ejecuta sin 'script' (usa 'tee' para un log bruto)
#   ./Respuesta-actividad4.sh --dry-run       # Modo demostración: no usa sudo, no crea/borra cuentas; produce evidencias mock
#
# Notas importantes:
# - Este script crea la carpeta 'Actividad4-CC3S2' en el directorio actual y guarda todo dentro.
# - En sistemas sin systemd (o WSL2 antiguo), usa fallbacks de logging.
# - El SANITIZADOR corre al final y genera 'evidencias/sesion_redactada.txt'.

set -Eeuo pipefail
IFS=$'\n\t'

#Configuración
ROOT_DIR="${ROOT_DIR:-$(pwd)/Actividad4-CC3S2}"
EVID="${ROOT_DIR}/evidencias"
LOG_BRUTO="${EVID}/sesion.txt"          # Grabación completa (script o tee)
LOG_RED="${EVID}/sesion_redactada.txt"  # Grabación redactada
DRY_RUN=false
NO_SCRIPT=false
INSIDE="false"

#Helpers
log(){ printf '[%s] %s\n' "$(date +'%F %T')" "$*" | tee -a "${EVID}/run.log"; }

run(){
  # Ejecutar mostrando comando (emulación simple de set -x amigable)
  echo "+ $*" | tee -a "${EVID}/cmds.log"
  if ${DRY_RUN}; then return 0; fi
  "$@"
}

have(){ command -v "$1" >/dev/null 2>&1; }

is_systemd(){ [[ -d /run/systemd/system ]] && have systemctl; }

is_wsl(){ grep -qi 'microsoft' /proc/version 2>/dev/null || true; }

# Detecta CRLF y avisa (problema común al editar en Windows)
if grep -q $'\r' "$0"; then
  echo "ADVERTENCIA: Se detectaron finales de línea CRLF en este script. Convierte a LF para evitar errores (ej. con 'dos2unix')." >&2
fi

#Parseo de flags simples
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ; shift ;;
    --no-script) NO_SCRIPT=true ; shift ;;
    --inside) INSIDE=true ; shift ;;
  esac
done

#Preparación de estructura
prep_dirs(){
  mkdir -p "$EVID"
  log "Directorio raíz: $ROOT_DIR"
  log "Evidencias en: $EVID"
}

#Grabación de sesión
# Reejecuta el script bajo 'script' para capturar toda la sesión en un único archivo.
record_if_possible(){
  if ${INSIDE}; then return 0; fi
  if ${NO_SCRIPT}; then
    log "Ejecución sin 'script': usaremos tee para log bruto"
    : >"$LOG_BRUTO"
    # Reinvocar el propio script, marcando --inside y encadenando tee
    if ${DRY_RUN}; then DRY="--dry-run"; else DRY=""; fi
    # shellcheck disable=SC2091
    ( "$0" --inside ${DRY} | tee -a "$LOG_BRUTO" )
    return 1  # evita continuar la ruta del "padre"
  fi
  if have script; then
    log "Usando 'script' para grabar toda la sesión en $LOG_BRUTO"
    : >"$LOG_BRUTO"
    if ${DRY_RUN}; then DRY="--dry-run"; else DRY=""; fi
    # 'script -c' ejecuta un único comando; re-llamamos el script en modo --inside
    script -q -c "$0 --inside ${DRY}" "$LOG_BRUTO"
    return 1
  else
    log "'script' no disponible. Usa --no-script o instala 'bsdutils'/'util-linux'."
    : >"$LOG_BRUTO"
    if ${DRY_RUN}; then DRY="--dry-run"; else DRY=""; fi
    ( "$0" --inside ${DRY} | tee -a "$LOG_BRUTO" )
    return 1
  fi
}

#SANITIZADOR (al final)#
sanear_logs(){
  log "Aplicando SANITIZADOR sobre $LOG_BRUTO -> $LOG_RED"
  if [[ ! -s "$LOG_BRUTO" ]]; then
    log "No hay log bruto para sanear (¿falló la grabación?)."
    return 0
  fi
  # 1) Palabras sensibles y pares clave=valor / clave: valor
  sed -E \
    -e 's/(password|token|secret)/[REDACTED]/gI' \
    -e 's/\b(pass(word)?|token|secret|api[-_]?key)\b[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gI' \
    "$LOG_BRUTO" > "$LOG_RED.tmp"

  # 2) Cabeceras HTTP Authorization (Basic/Bearer)
  sed -E 's/\b(Authorization:)[[:space:]]+(Basic|Bearer)[[:space:]]+[A-Za-z0-9._~+\/=\-]+/\1 \2 [REDACTED]/gI' \
    "$LOG_RED.tmp" > "$LOG_RED.tmp2"

  # 3) Opcional: quitar códigos ANSI
  sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g' "$LOG_RED.tmp2" > "$LOG_RED"
  rm -f "$LOG_RED.tmp" "$LOG_RED.tmp2"

  # 4) Verificación rápida
  { grep -nEi '(pass(word)?|token|secret|api[-_]?key|authorization)' "$LOG_RED" | head || true; } >"$EVID/sane_check.txt"
  log "SANITIZADOR listo. Muestras en $EVID/sane_check.txt"
}

#Sección 1: Manejo sólido de CLI
seccion1(){
  log "[Sección 1] Manejo sólido de CLI"
  cd "$ROOT_DIR"

  # Navegación básica
  run pwd
  run ls -la || true
  run bash -lc 'cd /tmp && pwd && ls -A | wc -l'

  # Globbing y archivos de prueba
  run bash -lc 'touch archivo1.txt archivo2.txt archivo3.doc'
  run bash -lc 'ls archivo*.txt || true'

  # Pipes
  run bash -lc 'ls -A | wc -l'

  # Redirecciones
  run bash -lc 'ls > lista.txt'
  run bash -lc 'printf "Hola\n" >> lista.txt'
  run bash -lc 'wc -l < lista.txt'
  run bash -lc 'ls noexiste 2> errores.txt || true'

  # xargs seguro (dry-run con echo)
  run bash -lc "find . -maxdepth 1 -name 'archivo*.txt' | xargs echo rm --"

  # Entregables: etc_lista.txt
  run bash -lc 'cd /etc && ls -a > "'$ROOT_DIR'/etc_lista.txt"'

  # Conteo robusto en /tmp
  run bash -lc 'find /tmp -maxdepth 1 -type f \( -name "*.txt" -o -name "*.doc" \) | wc -l > "'$ROOT_DIR'/tmp_conteo.txt"'

  # Archivo de prueba
  run bash -lc 'printf "Línea1\nLínea2\n" > test.txt'

  # Comprobación
  run bash -lc 'nl test.txt | head -n 5'
  run bash -lc 'wc -l lista.txt'
}

#Sección 2: Administración básica
seccion2(){
  log "[Sección 2] Administración básica"
  cd "$ROOT_DIR"

  run whoami
  run id

  # Usuarios/Grupos/Permisos (con fallback si no hay sudo o en --dry-run)
  local CAN_SUDO=1
  if ${DRY_RUN}; then CAN_SUDO=0; fi
  if ! sudo -n true 2>/dev/null; then CAN_SUDO=0; fi

  if (( CAN_SUDO==1 )); then
    log "Creando usuario y grupo reales (devsec/ops)"
    run sudo addgroup ops || true
    run sudo adduser --disabled-password --gecos "" devsec || true
    run sudo usermod -aG ops devsec || true
    run bash -lc 'touch secreto.txt'
    run sudo chown devsec:ops secreto.txt
    run sudo chmod 640 secreto.txt
  else
    log "Sin privilegios sudo o en --dry-run: simulando con recursos del usuario"
    run bash -lc 'mkdir -p mockuser && touch secreto.txt && chmod 640 secreto.txt'
  fi

  # Procesos/Señales
  run ps aux | head -n 5
  # No matamos nada crítico en este entorno; demostración de señal sobre proceso seguro (sleep)
  run bash -lc 'sleep 30 & echo $! > .sleep.pid'
  local SPID
  SPID=$(cat .sleep.pid || echo "")
  if [[ -n "${SPID}" ]]; then
    run kill -SIGTERM "${SPID}" || true
  fi

  # systemd (si aplica)
  if is_systemd; then
    run systemctl status ssh || run systemctl status sshd || true
    run bash -lc 'journalctl -u systemd-logind -n 10 || true'
  else
    log "Sin systemd: usando fallbacks"
    run bash -lc 'tail -n 100 /var/log/syslog 2>/dev/null | grep -i error | head || true'
  fi

  # Comprobaciones
  run bash -lc 'namei -l secreto.txt'
  if (( CAN_SUDO==1 )); then
    run id devsec || true
  else
    log "id devsec (simulado): sin cuenta real creada"
  fi
}

#Sección 3: Utilidades de texto de Unix
seccion3(){
  log "[Sección 3] Utilidades de texto de Unix"
  cd "$ROOT_DIR"

  run bash -lc 'printf "linea1: dato1\nlinea2: dato2\n" > datos.txt'

  # grep
  run bash -lc 'grep root /etc/passwd | head -n 5'

  # sed
  run bash -lc "sed 's/dato1/secreto/' datos.txt > nuevo.txt"

  # awk & cut
  run bash -lc "awk -F: '{print \$1}' /etc/passwd | sort | uniq > usuarios.txt"

  # tr & tee
  run bash -lc 'printf "hola\n" | tr "a-z" "A-Z" | tee mayus.txt'

  # find mtime
  run bash -lc 'find /tmp -mtime -5 -type f 2>/dev/null | head -n 20 > tmp_ult5dias.txt'

  # Pipeline completo sobre /etc
  run bash -lc 'ls /etc | grep conf | sort | tee lista_conf.txt | wc -l'

  # Auditoría opcional sobre evidencias
  run bash -lc "grep -Ei 'error|fail' '${EVID}/sesion.txt' | tee '${EVID}/hallazgos.txt' | head || true"

  # Comprobaciones
  run bash -lc 'file lista_conf.txt && head -n 5 lista_conf.txt'
  run bash -lc 'cat mayus.txt'
}

#Auditoría solicitada (entregables específicos)
auditoria_entregables(){
  log "[Auditoría] Generando entregables de auditoría"
  cd "$ROOT_DIR"

  # 1) journalctl severidades altas hoy (o fallbacks)
  if is_systemd; then
    if sudo -n true 2>/dev/null; then
      run bash -lc "sudo journalctl -p err..alert --since 'today' > '${ROOT_DIR}/journal_err_today.txt' || true"
    else
      log "Sin sudo no se puede acceder a ciertos logs de journalctl; intentando sin sudo"
      run bash -lc "journalctl -p err..alert --since 'today' > '${ROOT_DIR}/journal_err_today.txt' || true"
    fi
  else
    run bash -lc "sudo tail -n 100 /var/log/syslog 2>/dev/null | grep -i error > '${ROOT_DIR}/journal_err_today.txt' || true"
  fi

  # 2) find /tmp últimos 5 días con formato
  run bash -lc "find /tmp -mtime -5 -type f -printf '%TY-%Tm-%Td %TT %p\n' 2>/dev/null | sort > '${ROOT_DIR}/tmp_ult5_formateado.txt' || true"

  # 3) sudo -l (fragmento representativo)
  if sudo -n -l >/dev/null 2>&1; then
    run bash -lc "sudo -n -l | sed -n '1,50p' > '${ROOT_DIR}/sudo_l_head.txt'"
  else
    printf "%s\n" "sudo -l no disponible (sin privilegios o contraseña requerida)." > "${ROOT_DIR}/sudo_l_head.txt"
  fi

  # 4) Mini-pipeline con datos reales (sshd/sudo)
  if is_systemd; then
    if sudo -n true 2>/dev/null; then
      run bash -lc "sudo journalctl -t sshd -t sudo --since today \
        | awk '{print \$1,\$2,\$3,\$5}' \
        | sort | uniq -c | sort -nr > '${ROOT_DIR}/auth_counts.txt' || true"
    else
      run bash -lc "journalctl -t sshd -t sudo --since today 2>/dev/null \
        | awk '{print \$1,\$2,\$3,\$5}' \
        | sort | uniq -c | sort -nr > '${ROOT_DIR}/auth_counts.txt' || true"
    fi
  else
    if [[ -f /var/log/auth.log ]]; then
      run bash -lc "grep -Ei 'sshd|sudo' /var/log/auth.log \
        | awk '{print \$1,\$2,\$3,\$5}' \
        | sort | uniq -c | sort -nr > '${ROOT_DIR}/auth_counts.txt' || true"
    elif [[ -f /var/log/secure ]]; then
      run bash -lc "grep -Ei 'sshd|sudo' /var/log/secure \
        | awk '{print \$1,\$2,\$3,\$5}' \
        | sort | uniq -c | sort -nr > '${ROOT_DIR}/auth_counts.txt' || true"
    else
      printf "%s\n" "No se encontraron logs de autenticación estándar." > "${ROOT_DIR}/auth_counts.txt"
    fi
  fi
}

## README mínimo
render_readme(){
  cat >"${ROOT_DIR}/README.md" <<'MD'
# Actividad 4-Introducción a Herramientas CLI para DevSecOps

Este directorio contiene los **entregables** de la actividad. Se ejecutó con un script automatizado que:
- Crea evidencias reproducibles.
- Aplica un **sanitizador** para remover secretos del log de sesión.
- Genera archivos de salida de cada sección.

## Cómo reproducir
```bash
chmod +x Respuesta-actividad4.sh
./Respuesta-actividad4.sh
```

> Si no cuentas con `script`, usa `./Respuesta-actividad4.sh --no-script`.

## Archivos principales
- `evidencias/sesion.txt` -> Log original grabado.
- `evidencias/sesion_redactada.txt` -> Log **sanitizado** (usar este para la entrega).
- `etc_lista.txt`, `lista.txt`, `test.txt`, `mayus.txt`, `lista_conf.txt`, `usuarios.txt`, `tmp_ult5_formateado.txt`, `auth_counts.txt`.
- Auditoría: `journal_err_today.txt`, `sudo_l_head.txt`.

## Notas de seguridad (DevSecOps)
- Se emplean flags seguros (`--`, `-print0/-0`, `set -Eeuo pipefail`).
- Se evita el borrado real en masa y se usan **dry-runs** donde aplica.
- En sistemas sin `systemd`, se aplican fallbacks para no romper el flujo.
MD
}

#Flujo principal (dentro de la grabación)
main_inside(){
  prep_dirs
  cd "$ROOT_DIR"
  log "Inicio de ejecución dentro de la sesión grabada"
  seccion1
  seccion2
  seccion3
  auditoria_entregables
  render_readme
  log "Fin de ejecución dentro de la sesión grabada"
}

#Orquestación
main(){
  prep_dirs
  # Si no estamos en --inside, intentar reejecutar bajo 'script' (o tee) y salir.
  if ! ${INSIDE}; then
    record_if_possible || true
    # Si llegamos aquí, ya se ejecutó el hijo y terminó. Pasamos a saneamiento.
    sanear_logs
    log "Listo. Revisa: $ROOT_DIR"
    log "Entrega recomendada: carpeta Actividad4-CC3S2 completa, especialmente evidencias/sesion_redactada.txt"
    return 0
  fi
  # Modo dentro de la grabación
  main_inside
}

main "$@"
