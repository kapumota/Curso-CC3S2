### Prueba de entrada

**Objetivo:** comprobar habilidades mínimas en CLI Linux/WSL, Bash, Git, Python y nociones básicas de HTTP/DNS/TLS.  
**Duración estimada:** 4 h (entrega en 3 días). Lunes 8 setiembre 13:00 horas.
**Entrega:** subir **este directorio** `Prueba_entrada_CC3S2/` como repositorio público en GitHub (o dentro de un repo como subcarpeta).  
**Permitido:** documentación oficial. **Prohibido:** IA generativa y colaboración.  

#### Estructura obligatoria

```
Prueba_entrada_CC3S2/
├─ README.md
├─ seccion1_cli_automatizacion/
│  ├─ Makefile
│  ├─ scripts/syscheck.sh
│  └─ reports/{http.txt,dns.txt,tls.txt,sockets.txt}
├─ seccion2_python_git/
│  ├─ app/app.py
│  ├─ tests/test_app.py
│  ├─ coverage.txt    (se genera al correr pytest con cobertura)
│  └─ git_log.txt     (se genera con git log)
└─ seccion3_redes_api/
   ├─ example.html
   ├─ dig_output.txt
   ├─ api_response.json
   ├─ api_title.txt
   ├─ network_answers.txt
   └─ deploy_scenario.txt
```

Desde `Prueba_entrada_CC3S2/seccion1_cli_automatizacion/` debe funcionar `make all` sin intervención.

#### Sección 1-CLI y Automatización (6 pts)

**1.1 `syscheck.sh` (4 pts)**  
Bash con `set -euo pipefail` + `trap`. Genera:
- `http.txt`: `curl -Is https://example.com` + 2-3 líneas explicando el código HTTP. (1.5)  
- `dns.txt`: `dig A/AAAA/MX example.com +noall +answer` + comenta el **TTL**. (1.5)  
- `tls.txt`: versión TLS observada (`curl -Iv` u `openssl s_client`). (0.5)  
- `sockets.txt`: `ss -tuln` + 1-2 riesgos de puertos abiertos. (0.5)

**1.2 Makefile (2 pts)**  
Targets: `help`, `tools` (verifica git/bash/make/python3/pytest/curl/dig/ss/jq), `report`, `all`. Idempotente.

#### Sección 2-Python + Tests y Git (8 pts)

**2.1 Función + CLI (3 pts)**  
`app/app.py`: `summarize(nums)` -> `{"count","sum","avg"}` con validación; CLI `python -m app "1,2,3"`.

**2.2 Pytest + cobertura (3 pts)**  
`tests/test_app.py`: 3 tests (normal, borde, error) con fixture; guardar cobertura en `coverage.txt` (meta ~ 70%).

**2.3 Flujo Git (2 pts)**  
Ramas (`feature/msg`), **merge FF**, **cherry-pick** de fix y **rebase** corto. Guarda `git_log.txt` y explica en README (4-6 líneas) FF vs rebase vs cherry-pick.


#### Sección 3-Redes, HTTP/TLS y API (6 pts)

**3.1 GET y DNS (2 pts)**  
`curl https://example.com -o example.html` (1) y `dig google.com ANY +noall +answer > dig_output.txt` con breve explicación en `network_answers.txt` (TTL/qué muestra `dig`) (1).

**3.2 API + `jq` (2 pts)**  
`curl https://jsonplaceholder.typicode.com/posts/1 -s -o api_response.json`; extraer `title` con `jq -r '.title' > api_title.txt`. En README, indicar el header de tipo de contenido (**Content-Type**).

**3.3 Conceptos y pipeline (2 pts)**  
En `network_answers.txt` (~150 palabras): ¿qué es HTTP?, 80 vs 443, por qué TLS.  
En `deploy_scenario.txt` (~200 palabras): flujo mínimo "código -> pruebas -> despliegue" y una herramienta por paso.

#### Rúbrica resumida (20 pts)

- **S1 (6):** `syscheck.sh` correcto y evidencias (4). Makefile e idempotencia (2).  
- **S2 (8):** Función+CLI (3). Tests+coverage (3). Git flujo+explicación (2).  
- **S3 (6):** GET+DNS (2). API+`jq` (2). Conceptos+pipeline (2).

**Rechazo automático:** falta de archivos clave, `make all` falla, evidencias vacías, uso de IA/copia, un único mega-commit final.

#### Reproducción (ejemplos)

```bash
# Ubuntu/WSL
sudo apt update && sudo apt install -y git make python3 python3-pip curl dnsutils iproute2 jq
pip install -U pytest pytest-cov

# Sección 1
cd Prueba_entrada_CC3S2/seccion1_cli_automatizacion
make all
cd ../..

# Sección 2
cd Prueba_entrada_CC3S2/seccion2_python_git
pytest -q --maxfail=1 --disable-warnings --cov=app --cov-report=term-missing | tee coverage.txt
cd ../..

# Sección 3
curl -s https://example.com -o Prueba_entrada_CC3S2/seccion3_redes_api/example.html
dig google.com ANY +noall +answer > Prueba_entrada_CC3S2/seccion3_redes_api/dig_output.txt
curl -s https://jsonplaceholder.typicode.com/posts/1 -o Prueba_entrada_CC3S2/seccion3_redes_api/api_response.json
jq -r '.title' Prueba_entrada_CC3S2/seccion3_redes_api/api_response.json > Prueba_entrada_CC3S2/seccion3_redes_api/api_title.txt
```
