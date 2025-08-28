## Make para devops y devsecops

Este documento busca explicar de forma integrada qué es **Make** y cómo un **Makefile** puede sostener un flujo de DevOps/DevSecOps. 
El punto de partida es el [Laboratorio 1](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio1): una app Flask, Nginx como reverse proxy con TLS, y un servicio systemd. 

A partir de ahí, se conectan las piezas: build/test/pack, variables, targets, `.PHONY`, caché incremental y extensiones de seguridad. 

#### 1) Qué es Make y cómo se lee un Makefile, con ejemplos

Make orquesta **objetivos**, **dependencias** y **recetas** para construir proyectos reproducibles. Modela un grafo dirigido acíclico: cada objetivo declara archivos requeridos y comandos. 
Con marcas de tiempo, Make decide qué está desactualizado,  si un prerequisito cambió, reconstruye ese nodo y sus sucesores; si no, evita trabajo innecesario. 
Las **reglas de patrón** y **variables** generalizan tareas; los objetivos **.PHONY** representan acciones sin archivos. 
Al separar **build**, **release** y **run**, favorece artefactos inmutables, caché y paralelización con `-j`. 
Los **includes** y condiciones permiten reutilización y entornos. Resultado: compilaciones incrementales, deterministas y auditable, con fallos visibles y repetibles desde un simple `Makefile`, bien documentado.

En el archivo, el Makefile se **autodocumenta** y fija un shell coherente:

```make
SHELL := /bin/bash
.DEFAULT_GOAL := help
```

El objetivo por defecto (`help`) no es un adorno, transforma el Makefile en una **interfaz de usuario técnica**. Al listar tareas, parámetros y ejemplos de ejecución, reduce fricción, estandariza comandos y acelera el "onboarding". 
Proporciona descubribilidad, evita memorizar flags y actúa como contrato de uso entre desarrollo y operaciones. Si se organiza por categorías y muestra prerequisitos, promueve flujos seguros y repetibles. 
Integrado con colores y descripciones breves, facilita auditorías y sesiones de soporte.  Además, sirve como documentación viva que se actualiza con el propio código. 

En suma, `make help` guía, educa y previene errores operativos cotidianos en equipos grandes.


El propio código de ayuda lo muestra:

```make
.PHONY: help
help: ## Mostrar los targets disponibles
	@echo "Make targets:"
	@grep -E '^[a-zA-Z0-9_\-]+:.*?##' $(MAKEFILE_LIST) | \
	awk 'BEGIN{FS=":.*?##"}{printf " \033[36m%-22s\033[0m %s\n", $$1, $$2}'
```

Los comentarios `##` son metadatos: `grep` extrae las líneas `objetivo: ... ## descripción` de \$(MAKEFILE\_LIST) y `awk` imprime una tabla coloreada con el nombre del target y su intención. 
Como `help` es el primer objetivo (o se define `.DEFAULT_GOAL := help`), ejecutar `make` sin argumentos invoca esa ayuda. 

Así, el Makefile se auto-documenta: muestra qué comandos existen, para qué sirven y cómo usarlos, sin abrir archivos. Mantener la descripción junto al target evita desactualización y reduce errores operativos y dudas.


#### 2) Make en DevOps

En DevOps, automatizar es reducir ambigüedad y fricción. El Makefile de ejemplo encarna tres momentos: **preparar**, **verificar**, **empaquetar/operar**.

#### Preparar (equivalente a "build" del pipeline)

El entorno debe ser reproducible. Aquí, una **venv** llamada `bdd`, con rutas portables entre Unix y Windows:

```make
VENV := bdd
UNAME_S := $(shell uname -s 2>/dev/null)
ifeq ($(OS),Windows_NT)
  VENV_BIN := $(VENV)/Scripts
else ifneq (,$(findstring MINGW,$(UNAME_S)))
  VENV_BIN := $(VENV)/Scripts
else ifneq (,$(findstring MSYS,$(UNAME_S)))
  VENV_BIN := $(VENV)/Scripts
else ifneq (,$(findstring CYGWIN,$(UNAME_S)))
  VENV_BIN := $(VENV)/Scripts
else
  VENV_BIN := $(VENV)/bin
endif

PY_BOOT := $(shell if command -v py >/dev/null 2>&1; then echo "py -3"; \
	elif command -v python3 >/dev/null 2>&1; then echo "python3"; \
	else echo "python"; fi)
PY  := $(VENV_BIN)/python
PIP := $(PY) -m pip
```

El target que **construye** ese entorno y deja Flask listo es:

```make
prepare: $(VENV) ## Crear venv 'bdd' e instalar dependencias de la app
	@echo "Actualizando pip e instalando Flask..."
	@$(PIP) --version
	@$(PIP) install --upgrade pip
	@$(PIP) install flask

$(VENV):
	@echo "Creando venv con: $(PY_BOOT) -m venv --prompt $(VENV_PROMPT) $(VENV)"
	@$(PY_BOOT) -m venv --prompt "$(VENV_PROMPT)" $(VENV)
```
El caché incremental funciona porque \$(VENV) es un objetivo con el mismo nombre que el directorio `bdd/`. Make compara marcas de tiempo: si ese directorio ya existe, asume el target actualizado y omite su receta,  por eso no vuelve a crear el entorno. 
Al invocar `make prepare`, solo se ejecutan los pasos de instalación, que son idempotentes (pip no reinstala paquetes ya satisfechos). 
Si cambias la versión de Python o deseas regenerar el venv, puedes forzar la reconstrucción borrándolo (`rm -rf bdd/`) o ejecutando `make -B $(VENV)`/`touch -t 0001010000 bdd`. 
Así controlas reconstrucciones sin perder reproducibilidad y coherencia de versiones.


#### Verificar (smoke tests pragmáticos)

Probar rápido que algo *responde* antes de seguir. El `check-http` muestra la intención:

```make
check-http: ## Verificar HTTP, puertos y sockets (curl/ss/lsof o netstat)
	@echo "curl HEAD"
	@[ -n "$(CURL)" ] && $(CURL) -sS -I http://127.0.0.1:$(PORT) || echo "curl no disponible"
	@echo "curl GET"
	@[ -n "$(CURL)" ] && $(CURL) -sS http://127.0.0.1:$(PORT) || echo "curl no disponible"
	@echo "Sockets escuchando (ss/netstat)"
	@{ [ -n "$(SS)" ] && $(SS) -ltnp | grep :$(PORT) || \
	   { [ -n "$(NETSTAT)" ] && $(NETSTAT) -ano | grep ":$(PORT) " || echo "ni ss ni netstat disponibles"; }; }
	@echo "Puertos abiertos (lsof)"
	@[ -n "$(LSOF)" ] && $(LSOF) -i :$(PORT) -sTCP:LISTEN || echo "lsof no disponible"
```

Un vistazo al **código de la app** ayuda a entender lo que esperamos:

```python
# app.py (extracto)
from flask import Flask, jsonify
import os

PORT    = int(os.environ.get("PORT", "8080"))
MESSAGE = os.environ.get("MESSAGE", "Hola")
RELEASE = os.environ.get("RELEASE", "v0")

app = Flask(__name__)

@app.route("/")
def root():
    return jsonify(status="ok", message=MESSAGE, release=RELEASE, port=PORT)

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=PORT)
```

Este fragmento define un microservicio Flask parametrizable por entorno. `PORT`, `MESSAGE` y `RELEASE` se leen de variables; si no existen, usan valores por defecto. 
La ruta `/` expone un **contrato observable** estable: un JSON con `status`, `message`, `release` y `port`. Así, operaciones puede validar disponibilidad y configuración sin acceder al código. 

Prueba: `curl -i http://127.0.0.1:$PORT/` debe devolver `HTTP/1.1 200 OK` y ese JSON. 
En paralelo, `ss -ltnp | grep :$PORT` confirmará `LISTEN` en `127.0.0.1:$PORT` perteneciente a `python`. Cambiar `MESSAGE` o `RELEASE` en el entorno modifica la respuesta sin redeployar binarios, habilitando pruebas idempotentes y trazabilidad de versiones en producción segura.


#### Empaquetar/Operar ( proxy reverso + servicio del sistema)

El "pack" no crea un binario: **empaqueta como servicio** público y gestionado.

**TLS + Nginx**: primero certificados, luego vhost.

```make
tls-cert: ## Generar certificado TLS autofirmado para $(DOMAIN) (365 días)
	@[ -n "$(OPENSSL)" ] || { echo "openssl no disponible"; exit 1; }
	@mkdir -p $(CERT_DIR)
	@if [ ! -f "$(KEY_FILE)" ]; then \
	  $(OPENSSL) req -x509 -nodes -newkey rsa:2048 \
	    -keyout $(KEY_FILE) -out $(CRT_FILE) -days 365 \
	    -subj "/CN=$(DOMAIN)"; \
	  echo "Certificado creado en $(CERT_DIR)/"; \
	else echo "Certificado ya existe en $(CERT_DIR)/"; fi
```

**Qué hace y por qué importa**

* Genera un X.509 autofirmado RSA-2048 por 365 días; `-nodes` evita passphrase (útil para arranques automáticos).
* Idempotente: si existen clave y cert, no los regenera.
* Buenas prácticas: protege la clave (`chmod 600`), valida con `openssl x509 -in $(CRT_FILE) -noout -subject -issuer -dates`.
* Producción: sustituir por ACME/Let’s Encrypt y rotación automatizada.

El vhost de Nginx actúa como frontera pública: **termina TLS** en el puerto 443, redirige las peticiones de 80 a 443 y, tras descifrar, **encamina** el tráfico hacia el backend Flask en `127.0.0.1:8080` mediante `proxy_pass`. 
Conserva identidad y contexto con `Host`, `X-Forwarded-For` y `X-Forwarded-Proto`, permitiendo enlaces correctos, auditoría y políticas de forma segura. 
Esta capa descarga criptografía del aplicativo, habilita HSTS, rate limiting, WAF, compresión y caché estática, y simplifica la **rotación de certificados** sin tocar el código. 

Al mantener el backend en loopback, reduce superficie expuesta y separa responsabilidades: Nginx gestiona el borde y Flask entrega lógica de negocio.


```nginx
# nginx/miapp.conf (extracto)
server {
  listen 443 ssl;
  server_name miapp.local;

  ssl_certificate     /etc/ssl/miapp/miapp.local.crt;
  ssl_certificate_key /etc/ssl/miapp/miapp.local.key;

  location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto https;
  }
}

server {
  listen 80;
  server_name miapp.local;
  return 301 https://$host$request_uri;
}
```

**Qué resuelve este vhost**

* Termina TLS en 443 y fuerza **80 -> 443** (canónico, base para HSTS).
* `proxy_pass` a Flask en `127.0.0.1:8080`; los headers preservan `Host`, cliente real y esquema (`https`) para logs, enlaces absolutos y seguridad aguas abajo.
* Beneficios: renovación de certificados sin tocar la app, límites de tasa/WAF, compresión y métricas homogéneas en el edge.

El objetivo que instala y activa esto en el sistema:

```make
nginx: ## Instalar vhost de Nginx y recargar (Linux)
	@if [ -z "$(NGINX)" ]; then echo "nginx no encontrado (omitiendo)"; exit 1; fi
	@sudo mkdir -p $(NGINX_CERT_DIR)
	@if [ -f "$(CRT_FILE)" ] && [ -f "$(KEY_FILE)" ]; then \
	  sudo cp $(CRT_FILE) $(NGINX_CERT_DIR)/$(DOMAIN).crt; \
	  sudo cp $(KEY_FILE) $(NGINX_CERT_DIR)/$(DOMAIN).key; \
	else echo "Faltan certificados. Ejecuta 'make tls-cert' primero."; exit 1; fi
	@sudo cp nginx/miapp.conf $(NGINX_SITE_AVAIL)
	@sudo ln -sf $(NGINX_SITE_AVAIL) $(NGINX_SITE_ENABLED)
	@sudo nginx -t
	@sudo systemctl reload nginx
	@echo "Nginx recargado. Prueba: https://$(DOMAIN)"
```

**Instalación y verificación**

* Copia `crt/key` a `/etc/ssl/miapp/`, habilita el sitio (symlink `sites-available` -> `sites-enabled`), valida con `nginx -t` y recarga sin downtime.
* Requisitos: `nginx` y `sudo` disponibles; estructura tipo Debian.
* Pruebas:

  1. Añade `/etc/hosts`: `127.0.0.1 $(DOMAIN)`
  2. Arranca Flask en `:8080` y Nginx.
  3. `curl -I http://$(DOMAIN)` -> `301` a `https://…`
  4. `curl -kI https://$(DOMAIN)` -> `200 OK` (usar `-k` por ser autofirmado).
  5. `ss -ltnp | grep -E ':443|:8080'` confirma `nginx` y `python`.

Con esto, el **artefacto** desplegado es el servicio accesible por TLS, listo para endurecer (cifras, HSTS, OCSP) y observar (logs, métricas).


Con **systemd**, la aplicación deja de depender de una terminal y se ejecuta como servicio del sistema: inicia al boot, se supervisa, reinicia ante fallos y expone logs coherentes. 
El objetivo `systemd-install` **renderiza** la unidad sustituyendo variables (`{{APP_DIR}}`, `{{USER}}`) con `sed`, la copia a `/etc/systemd/system`, ordena `daemon-reload`, la habilita y arranca, mostrando su estado. 

Así fijamos usuario efectivo, directorio de trabajo y el intérprete del entorno virtual en `bdd`, más configuración vía `Environment`. 

Este enfoque estandariza despliegue y operación, facilita auditoría con `journalctl` y permite cambios controlados mediante reinicios. 

Todo sin alterar el código de la aplicación, solo infraestructura declarativa.

```make
systemd-install: ## Instalar/habilitar/iniciar el unit de systemd para la app
	@if [ -z "$(SYSTEMCTL)" ]; then echo "systemctl no encontrado (omitiendo)"; exit 1; fi
	@if [ -z "$(SED)" ]; then echo "sed no encontrado"; exit 1; fi
	@echo "Renderizando unit con APP_DIR=$(APP_DIR) y USER=$$USER ..."
	@$(SED) -e "s#{{APP_DIR}}#$(APP_DIR)#g" -e "s#{{USER}}#$$USER#g" systemd/miapp.service > /tmp/$(APP_NAME).service
	@sudo cp /tmp/$(APP_NAME).service /etc/systemd/system/$(APP_NAME).service
	@sudo systemctl daemon-reload
	@sudo systemctl enable $(APP_NAME).service
	@sudo systemctl restart $(APP_NAME).service
	@sudo systemctl --no-pager status $(APP_NAME).service || true
```

Esta plantilla fija el **ciclo de vida** del servicio. `[Unit]` declara dependencia de red (`After=network-online.target`). 
En `[Service]`, `User={{USER}}` aplica principio de menor privilegio; `WorkingDirectory={{APP_DIR}}` define contexto; `ExecStart` usa el intérprete del venv (`bdd/bin/python`) 
para aislar dependencias,  `Restart=on-failure` aporta resiliencia ante errores transitorios.

Las líneas `Environment=` parametrizan **puerto**, **mensaje** y **release** sin tocar código, habilitando paridad dev-prod y despliegues reproducibles.
En `[Install]`, `WantedBy=multi-user.target` asegura inicio al arranque del sistema. Con esto, los logs quedan en `journalctl`, se simplifican diagnósticos y se habilitan **overrides** limpios (p. ej., variables adicionales) sin modificar la unidad base ni la aplicación. Facilita auditorías y control operacional.


```ini
[Unit]
Description=Mi App 12-Factor (Flask)
After=network-online.target

[Service]
User={{USER}}
WorkingDirectory={{APP_DIR}}
ExecStart={{APP_DIR}}/bdd/bin/python {{APP_DIR}}/app.py
Restart=on-failure
Environment=PORT=8080
Environment=MESSAGE=Hola
Environment=RELEASE=v0

[Install]
WantedBy=multi-user.target
```

> **Pitfall útil**: si por error `ExecStart` apuntara a `.venv/bin/python` en lugar de `bdd/bin/python`, systemd fallaría con `status=203/EXEC`. Esta plantilla hace explícito el camino correcto.


#### 3) DevSecOps: seguridad desde el diseño

En DevOps/DevSecOps no basta con que un servicio responda,  interesa cómo responde: seguro (TLS, mínimos privilegios), observable (logs/metrics/traces), resiliente (reinicios, healthchecks), performante (latencia/throughput), escalable, reproducible (infra como código), mantenible y con costos controlados. 
Eso garantiza confiabilidad, diagnósticos rápidos y despliegues predecibles, no simples "demos que funcionan", bajo presión y cambios. 

Dos objetivos le ponen lupa a TLS:

```make
check-tls: ## Validar handshake TLS y cabeceras con openssl/curl
	@echo "openssl s_client"
	@[ -n "$(OPENSSL)" ] && $(OPENSSL) s_client -connect $(DOMAIN):443 -servername $(DOMAIN) -brief -showcerts </dev/null || echo "openssl no disponible"
	@echo "curl sobre TLS (-k por cert autofirmado)"
	@[ -n "$(CURL)" ] && $(CURL) -sk https://$(DOMAIN) || echo "curl no disponible"
	@echo "Encabezados HTTP"
	@[ -n "$(CURL)" ] && $(CURL) -skI https://$(DOMAIN) || echo "curl no disponible"
```

`openssl s_client` muestra **TLS 1.3**, suite como `TLS_AES_256_GCM_SHA384`, y que el cert es **autofirmado** (esperado en laboratorio). `curl -k` confirma que el **mismo JSON** llega ahora cifrado vía Nginx. Eso es DevSecOps: medir seguridad como parte del *happy path*.

Abrir puertos en firewall, cuando aplica también está contemplado:

```make
ufw-open: ## Abrir 80/443 en UFW (Linux)
	@if [ -n "$(UFW)" ]; then \
	  sudo ufw allow 80/tcp || true; \
	  sudo ufw allow 443/tcp || true; \
	else echo "UFW no está instalado (omitiendo)"; fi
```

Y como **extensión** (no incluida por defecto), encajar linters/auditoría en el mismo flujo es trivial:

```make
lint:
	$(PY) -m flake8 app.py

deps-audit:
	$(PY) -m pip_audit
```

#### 4) Variables, flexibilidad y multiplataforma

Las variables llevan el espíritu **12-Factor** al Makefile:

```make
APP_NAME ?= miapp
DOMAIN   ?= miapp.local
PORT     ?= 8080
MESSAGE  ?= Hola
RELEASE  ?= v0
```

Cambiar comportamiento sin tocar código es tan natural como:

```bash
make run PORT=9000 MESSAGE="Hola DevOps" RELEASE=v1
```

La app responderá con esos valores, porque `app.py` los lee del entorno. Y la detección del SO que viste en `VENV_BIN` evita condicionar a un único sistema.

Para evitar ifs frágiles y que cada target degrade con mensajes claros cuando falta una herramienta, declara los binarios una sola vez:

```make
# Descubrimiento (command -v) para uso condicional en targets
CURL      := $(shell command -v curl 2>/dev/null)
SS        := $(shell command -v ss 2>/dev/null)
NETSTAT   := $(shell command -v netstat 2>/dev/null)
LSOF      := $(shell command -v lsof 2>/dev/null)
OPENSSL   := $(shell command -v openssl 2>/dev/null)
SYSTEMCTL := $(shell command -v systemctl 2>/dev/null)
UFW       := $(shell command -v ufw 2>/dev/null)
SED       := $(shell command -v sed 2>/dev/null)
NGINX     := $(shell command -v nginx 2>/dev/null)
```

De esta forma, cada receta puede anteponer `[ -n "$(CMD)" ] && ... || echo "no disponible"` y seguir siendo idempotente y autoexplicativa.

#### 5) Targets abstractos, `.PHONY` 

Marcar acciones como `.PHONY` evita colisiones con archivos homónimos y asegura ejecución cuando se invocan:

```make
.PHONY: help prepare run check-http tls-cert nginx systemd-install check-tls cleanup
```

Gracias al objetivo `help`, que recorre el Makefile y extrae las descripciones marcadas con `##` usando grep/awk, el archivo deja de ser un simple conjunto de recetas y se vuelve una guía viva. 
Cada target se autoexplica, se descubre con un solo comando (`make`), y su intención queda visible junto a la acción. 
Es, en la práctica, documentación ejecutable: actualiza y prueba lo que enseña, reduce fricción al incorporarse al proyecto y evita wikis desalineadas con la realidad del código.


#### 6) Caché incremental y control del ciclo de vida

Cada vez que Make **no** hace algo, está respetando tiempos y estados.

Ejemplos visibles:

* **`$(VENV)`**: si `bdd/` existe, **no** recrea la venv.
* **`tls-cert`**: si ya hay `.key`/`.crt`, **no** regenera.

Cuando necesitas volver a cero, hay **targets deliberados**:

```make
venv-recreate: ## Recrear la venv 'bdd' desde cero
	@rm -rf $(VENV)
	@$(MAKE) prepare
```

Y para "desmontar" lo desplegado, la **fase de limpieza** deja el sistema consistente y listo para repetir:

```make
cleanup: ## Remover vhost, detener unit y conservar certs/logs
	@echo "Deteniendo servicio systemd (si existe)..."
	@[ -n "$(SYSTEMCTL)" ] && sudo systemctl stop $(APP_NAME).service 2>/dev/null || true
	@[ -n "$(SYSTEMCTL)" ] && sudo systemctl disable $(APP_NAME).service 2>/dev/null || true
	@[ -n "$(SYSTEMCTL)" ] && sudo rm -f /etc/systemd/system/$(APP_NAME).service 2>/dev/null || true
	@[ -n "$(SYSTEMCTL)" ] && sudo systemctl daemon-reload 2>/dev/null || true
	@echo "Eliminando sitio Nginx (si existe)..."
	@sudo rm -f $(NGINX_SITE_ENABLED) 2>/dev/null || true
	@sudo rm -f $(NGINX_SITE_AVAIL) 2>/dev/null || true
	@{ [ -n "$(NGINX)" ] && sudo nginx -t >/dev/null 2>&1 && sudo systemctl reload nginx || true; }
	@echo "Limpieza completada. Certificados conservados en $(CERT_DIR)/."
```

**Detiene y deshabilita** el servicio, **borra** la unidad y el vhost, **recarga** Nginx y **conserva certificados**: es un **rollback limpio**. 
En este contexto, *rollback* significa devolver el sistema a un estado seguro anterior sin dejar residuos operativos. 
El target de limpieza lo implementa así: detiene y deshabilita el servicio de systemd, borra la unidad y el vhost de Nginx, recarga la configuración para aplicar los cambios y conserva los certificados. 
Al preservar artefactos críticos (clave y certificado), permite reinstalar rápido sin rehacer todo, logrando una reversión controlada, reproducible y auditable que minimiza riesgos y tiempo de inactividad.

#### 7) DNS y nombres locales: contexto útil con un ejemplo extra

Este target automatiza el mapeo local del nombre al loopback. En Linux/macOS verifica idempotencia con `grep -qE` y solo añade la línea si no existe, usando `sudo tee -a /etc/hosts`, así evita duplicados y requiere privilegios mínimos. Si `/etc/hosts` no está, informa. 

En Windows, no modifica archivos: detecta el SO y muestra el comando sugerido para ejecutarlo en PowerShell con privilegios de Administrador. Con ello, `miapp.local` resuelve a `127.0.0.1` sin DNS externo, encajando con el vhost de Nginx para probar `https://miapp.local/`. 

Reversión: eliminar la línea del hosts. Nota: puede requerir cerrar/reabrir navegador o reiniciar el servicio mDNSResponder.


```make
hosts-setup: ## Añadir '127.0.0.1 $(DOMAIN)' a hosts (Linux/macOS) o mostrar comando para Windows
ifeq ($(IS_WIN),)
	@if [ -f /etc/hosts ]; then \
		if ! grep -qE "127\.0\.0\.1\s+$(DOMAIN)" /etc/hosts; then \
			echo "Agregando $(DOMAIN) a /etc/hosts"; \
			echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts; \
		else echo "$(DOMAIN) ya está presente en /etc/hosts"; fi; \
	else echo "/etc/hosts no encontrado."; fi
else
	@echo "Windows detectado. Abre PowerShell como Admin y ejecuta:"
	@echo powershell -NoProfile -ExecutionPolicy Bypass -Command "<comando…>"
endif
```

Esto complementa perfecto el vhost de Nginx: el navegador resuelve `https://miapp.local/` **sin** montar un DNS real.

#### 8) `.PHONY` y ayuda como contrato de uso

```make
.PHONY: help prepare run check-http tls-cert nginx systemd-install check-tls cleanup cleanup-check hosts-setup
```

Gracias al objetivo `help`, que recorre el Makefile y extrae las descripciones marcadas con `##` usando grep/awk, el archivo  se vuelve **documentación ejecutable**: muestra qué comandos existen, para qué sirven y cómo usarlos, sin abrir archivos.
