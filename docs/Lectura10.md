### Expresiones regulares en Git Hooks

Los Git hooks son scripts que Git ejecuta en momentos clave del flujo de trabajo (por ejemplo, antes de un commit o después de un merge). 
Incorporar validaciones con regex asegura calidad, consistencia y seguridad. 
Hooks se versionan en `.githooks/` y un Makefile simplifica la instalación y la verificación de la herramienta. 

Aquí se explica cómo usar expresiones regulares dentro de Git hooks para imponer calidad, consistencia y seguridad en el repositorio, con instalación simple vía `core.hooksPath` y un Makefile. Primero se normalizan finales de línea con `.gitattributes` para evitar problemas de CRLF/LF entre sistemas.

### Configuración inicial de hooks

Hooks en .git/hooks no se versionan, así que usamos .githooks/:

```bash
# Configurar ruta de hooks
git config core.hooksPath .githooks/
```

Usa `make install-hooks` para copiar y dar permisos (ver Makefile). Para normalizar finales de línea, preferimos `.gitattributes` sobre `core.autocrlf`:

```text
# En .gitattributes
* text=auto eol=lf
*.sh text eol=lf
*.py text eol=lf
*.bat text eol=crlf
```
Alternativa: `git config core.autocrlf input` en Linux/macOS.

### Pre‑commit: Filtrado de archivos, formatos y seguridad

El **pre-commit** filtra solo los archivos en *staging* y aplica validaciones rápidas y portables (uso de `-z`/`-0`). Exige extensiones permitidas, detecta posibles secretos con un patrón que cubre claves comunes (Bearer, AWS, GitHub) y excluye rutas ruidosas y binarios. Complementa el guardia regex con **gitleaks** sobre el contenido *staged* para detección robusta. En calidad de código, prioriza **ruff** (con *fallback* a flake8) para Python y **eslint** opcional para JS/TS, de modo que el costo se limite a lo cambiado.

Valida extensiones, detecta secretos y ejecuta linters solo en archivos modificados o añadidos:

```bash
# En .githooks/pre-commit
#!/usr/bin/env bash
set -euo pipefail

# Filtrar archivos añadidos/modificados
STAGED_Z=$(git diff --cached --diff-filter=ACM --name-only -z)
[ -z "$STAGED_Z" ] && { echo "No hay archivos modificados para validar."; exit 0; }

# Validar extensiones
echo "$STAGED_Z" | tr '\0' '\n' | while IFS= read -r file; do
  [[ $file =~ \.(py|js|ts|java)$ ]] || { echo "Extensión no permitida: $file"; exit 1; }
done

# Detección de secretos (excluye rutas ruidosas)
SECRETS_PATTERN='(AWS_ACCESS_KEY_ID|api_key|password|secret)=[A-Za-z0-9+/=]{20,}\b|Bearer [A-Za-z0-9\-_\.=]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}'
echo "$STAGED_Z" | tr '\0' '\n' | grep -Ev '(^tests/fixtures/|\.png$|\.pdf$|\.csv$)' | tr '\n' '\0' | \
  xargs -0 -r grep -E -- "$SECRETS_PATTERN" 2>/dev/null && { echo "¡Error: Posible secreto detectado!"; exit 1; }

# Escanear secretos solo en staged con gitleaks
if command -v gitleaks >/dev/null; then
  echo "$STAGED_Z" | xargs -0 -I{} git show :{} | gitleaks detect --no-git --stdin --report-path secrets-staged.json --report-format json || true
  if jq -e '.[]' secrets-staged.json >/dev/null 2>&1; then
    echo "Secretos detectados en staged files. Revisar secrets-staged.json"
    exit 1
  fi
else
  echo "Advertencia: gitleaks no instalado. Regex local usado como guardia rápida."
fi

# Linter solo en .py staged
if command -v ruff >/dev/null; then
  echo "$STAGED_Z" | grep -zE '\.py$' | xargs -0 -r ruff check
elif command -v flake8 >/dev/null; then
  echo "$STAGED_Z" | grep -zE '\.py$' | xargs -0 -r flake8 --max-line-length=88
else
  echo "Advertencia: ni ruff ni flake8 están instalados. Instala con 'pip install ruff' o 'pip install flake8'."
fi

# Para JS/TS (si aplica)
if command -v eslint >/dev/null; then
  echo "$STAGED_Z" | grep -zE '\.(js|ts)$' | xargs -0 -r eslint --max-warnings 0 || true
fi
```

Usa `-z` y `-0` para portabilidad en macOS/BSD.

- `SECRETS_PATTERN` incluye tokens comunes (Bearer, AWS, GitHub).
- Excluye `tests/fixtures`, `.png`, `.pdf`, `.csv`.
- `gitleaks` escanea staged files; regex como guardia rápida.
- `ruff` preferido, con fallback a `flake8`.
- `grep -E --` protege contra filenames que empiezan con `-`.


### Commit‑msg: Convenciones de mensajes y tickets de seguridad

El **commit-msg** aplica **Conventional Commits** en la primera línea y restringe su longitud a 72 caracteres (medición *Unicode-safe*). Si el tipo es `fix` o `security`, exige un ticket `SEC-XXXX` en esa misma línea, reforzando trazabilidad y gobernanza de parches. 

Valida solo la primera línea según **Conventional Commits**:

```bash
# En .githooks/commit-msg
#!/usr/bin/env bash
set -euo pipefail

MSG_FILE=$1
PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|security|build|ci|revert)(\([a-z0-9\-]+\))?:\s'
SECURITY_PATTERN='^SEC\-[0-9]+:'

# Validar formato y longitud de la primera línea
first="$(head -n1 "$MSG_FILE")"
printf '%s' "$first" | grep -E "$PATTERN" >/dev/null || {
  echo "Formato inválido: tipo(scope?): descripción"
  echo "Ejemplo: feat: añadir validación de entrada"
  exit 1
}
[ "$(printf %s "$first" | wc -m)" -le 72 ] || {
  echo "Primera línea excede 72 caracteres"
  exit 1
}

# Validar tickets de seguridad solo en primera línea
if printf '%s\n' "$first" | grep -E '^(fix|security)\b' >/dev/null; then
  printf '%s\n' "$first" | grep -E "$SECURITY_PATTERN" >/dev/null || {
    echo "Commits de tipo 'fix' o 'security' requieren SEC-XXXX en la primera línea"
    exit 1
  }
fi
```

- `wc -m` valida longitud en caracteres (Unicode-safe).
- Restringe validaciones de `fix|security` a la primera línea.
- Incluye tipos `build|ci|revert`.
- Usa `grep -E` para portabilidad.

### Post‑merge: Limpieza, notificaciones y auto-corrección

El **post-merge** no bloquea: corrige espacios finales (preferentemente con ruff), detecta marcadores de conflictos, y audita dependencias Python (pip-audit/safety) o Node (npm audit), dejando reportes para revisión. 

Notifica y corrige sin bloquear:

```bash
# En .githooks/post-merge
#!/usr/bin/env bash
set -euo pipefail

# Corregir espacios finales con ruff
if command -v ruff >/dev/null; then
  ruff check . --select W291 --fix
elif git diff --check | grep -E '^[^:]+:[0-9]+: trailing whitespace'; then
  echo "Espacios finales detectados. Corrigiendo con perl..."
  git diff --check | grep -E '^[^:]+:[0-9]+:' | cut -d: -f1 | sort -u | \
    xargs -r perl -pi -e 's/[ \t]+$//'
fi

# Detectar marcadores de conflicto
if git grep -nE '^<{7} |^={7}$|^>{7} ' -- .; then
  echo "Marcadores de conflicto presentes. Resuelve manualmente."
fi

# Verificar dependencias
if [[ -f requirements.txt ]]; then
  if command -v pip-audit >/dev/null; then
    pip-audit -r requirements.txt > deps_report.txt || true
    if grep -E 'Vulnerability found' deps_report.txt; then
      echo "Dependencias vulnerables detectadas. Revisar deps_report.txt"
    fi
  elif command -v safety >/dev/null; then
    safety check -r requirements.txt --full-report > deps_report.txt || true
    if grep -E 'Vulnerabilities found' deps_report.txt; then
      echo "Dependencias vulnerables detectadas. Revisar deps_report.txt"
    fi
  else
    echo "Advertencia: ni pip-audit ni safety están instalados."
  fi
fi

# Para JS/TS (opcional)
if [[ -f package.json ]] && command -v npm >/dev/null; then
  npm audit --audit-level=moderate > npm_audit.txt || true
fi
```

- Usa `ruff` para espacios finales, con fallback a `perl`.
- Patrones precisos (`^<{7} |^={7}$|^>{7}`) para marcadores de conflicto.
- Notifica sin `exit 1`.

### Automatización de ejecución y reportes

Un script de **reportes** genera una ejecución autocontenida con *timestamp*: corre pruebas (pytest), SAST (bandit), auditoría de dependencias y secretos (gitleaks), recoge errores/advertencias, calcula hashes SHA-256 de artefactos y mantiene un índice histórico. 

Otro script de **CI local** valida el nombre de rama, ejecuta pruebas, SAST, auditorías y secretos, y puede replicarse con `act` en un workflow de GitHub Actions.

```bash
# En scripts/generate-report.sh
#!/usr/bin/env bash
set -euo pipefail

TIMESTAMP=$(date -u +%Y-%m-%d_%H%M%S)
OUT_DIR="out/$TIMESTAMP"
LOGFILE="$OUT_DIR/build.log"
SAST_LOG="$OUT_DIR/sast.log"
DEPS_LOG="$OUT_DIR/deps.log"
SECRETS_LOG="$OUT_DIR/secrets.log"
REPORT="$OUT_DIR/report.md"

mkdir -p out "$OUT_DIR"
touch out/index.md

# Verificar dependencias
command -v jq >/dev/null || echo "Advertencia: jq no instalado. Reporte puede ser incompleto." | tee -a "$SECRETS_LOG"

# 1. Ejecutar pruebas
echo "Ejecutando tests..." | tee "$LOGFILE"
if command -v pytest >/dev/null; then
  pytest --maxfail=1 --durations=0 -q 2>&1 | tee -a "$LOGFILE"
else
  echo "Advertencia: pytest no está instalado." | tee -a "$LOGFILE"
fi

# 2. Ejecutar análisis SAST
echo "Ejecutando SAST..." | tee -a "$SAST_LOG"
STAGED_PY=$(git diff --cached --diff-filter=ACM --name-only -z | grep -zE '\.py$' || true)
if command -v bandit >/dev/null && [ -n "$STAGED_PY" ]; then
  echo "$STAGED_PY" | xargs -0 -r bandit -f txt -o "$SAST_LOG" || true
elif command -v bandit >/dev/null; then
  echo "Sin .py staged; ejecutando SAST sobre src/ (fallback)"
  bandit -r src --exclude tests,fixtures -f txt -o "$SAST_LOG" || true
else
  echo "Advertencia: bandit no instalado." | tee -a "$SAST_LOG"
fi

# 3. Escanear dependencias
echo "Escaneando dependencias..." | tee -a "$DEPS_LOG"
if [[ -f requirements.txt ]]; then
  if command -v pip-audit >/dev/null; then
    pip-audit -r requirements.txt >> "$DEPS_LOG" || true
  elif command -v safety >/dev/null; then
    safety check -r requirements.txt --full-report >> "$DEPS_LOG" || true
  else
    echo "Advertencia: ni pip-audit ni safety están instalados." >> "$DEPS_LOG"
  fi
fi

# 4. Escanear secretos
echo "Escaneando secretos..." | tee -a "$SECRETS_LOG"
if command -v gitleaks >/dev/null; then
  if [ -n "$(git diff --cached --name-only -z)" ]; then
    git diff --cached --name-only -z | xargs -0 -I{} git show :{} | \
      gitleaks detect --no-git --stdin --report-path "$SECRETS_LOG" --report-format json || true
  else
    echo "Sin archivos staged; escaneando src/ (fallback)"
    gitleaks detect --source src --no-git --report-path "$SECRETS_LOG" --report-format json || true
  fi
else
  echo "Advertencia: gitleaks no instalado." | tee -a "$SECRETS_LOG"
fi

# 5. Extraer resultados
ERRORS=$(grep -E '^(E|ERROR):' "$LOGFILE" || true)
WARNINGS=$(grep -E '^(W|WARNING):' "$LOGFILE" || true)
VULNERABILITIES=$(grep -E '^.*(high|critical) severity' "$SAST_LOG" || true)
DEPS_VULNS=$(grep -E 'Vulnerability found' "$DEPS_LOG" || true)
SECRETS=$(command -v jq >/dev/null && jq -r '.[]?.description // "Ninguno"' "$SECRETS_LOG" || echo "Ninguno")
MON_SEV="_No disponible_"
[[ -f out/monitor_severity.txt ]] && MON_SEV="$(cat out/monitor_severity.txt)"

# 6. Extraer tiempo total
TOTAL_TIME=$(grep -Eo 'TOTAL.*[0-9]+\.[0-9]+s' "$LOGFILE" | grep -Eo '[0-9]+\.[0-9]+s' || echo "N/A")

# 7. Generar reporte
cat > "$REPORT" <<EOF
# Reporte de Ejecución Local ($TIMESTAMP)

## Errores detectados
$(if [[ -z "$ERRORS" ]]; then echo "_Ninguno_"; else echo "\`\`\`"; echo "$ERRORS"; echo "\`\`\`"; fi)

## Advertencias
$(if [[ -z "$WARNINGS" ]]; then echo "_Ninguna_"; else echo "\`\`\`"; echo "$WARNINGS"; echo "\`\`\`"; fi)

## Vulnerabilidades de seguridad (SAST)
$(if [[ -z "$VULNERABILITIES" ]]; then echo "_Ninguna_"; else echo "\`\`\`"; echo "$VULNERABILITIES"; echo "\`\`\`"; fi)

## Vulnerabilidades en dependencias
$(if [[ -z "$DEPS_VULNS" ]]; then echo "_Ninguna_"; else echo "\`\`\`"; echo "$DEPS_VULNS"; echo "\`\`\`"; fi)

## Secretos detectados
$(if [[ "$SECRETS" == "Ninguno" ]]; then echo "_Ninguno_"; else echo "\`\`\`"; echo "$SECRETS"; echo "\`\`\`"; fi)

## Severidad de monitoreo de logs
- $MON_SEV

## Tiempo total
- $TOTAL_TIME
EOF

# 8. Generar SHA256SUMS
if command -v sha256sum >/dev/null; then
  sha256sum "$LOGFILE" "$SAST_LOG" "$DEPS_LOG" "$SECRETS_LOG" "$REPORT" > "$OUT_DIR/SHA256SUMS" 2>/dev/null
elif command -v shasum >/dev/null; then
  shasum -a 256 "$LOGFILE" "$SAST_LOG" "$DEPS_LOG" "$SECRETS_LOG" "$REPORT" > "$OUT_DIR/SHA256SUMS" 2>/dev/null
else
  echo "Advertencia: ni sha256sum ni shasum están instalados."
fi

# Actualizar índice
echo "- [$TIMESTAMP]($TIMESTAMP/report.md)" >> out/index.md

echo "Reporte generado en $REPORT"
```

- Inicializa `out/index.md`.
- Incluye severidad de monitoreo.
- Usa `-z` y `-0` para portabilidad.
- Fallback a `src/` para SAST y secretos si no hay archivos preparados (staged).

### Configuración CI local

Pipeline CI local con script Bash o `act`:

```bash
# En scripts/ci-local.sh
#!/usr/bin/env bash
set -euo pipefail

echo "Simulando pipeline CI local..."

# 1. Validar formato de rama
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ ! $BRANCH =~ ^(main|feature/.*|fix/.*|hotfix/.*|chore/.*|security/.*)$ ]]; then
  echo "Error: La rama debe ser 'main', 'feature/*', 'fix/*', 'hotfix/*', 'chore/*' o 'security/*'"
  echo "Rationale: Nombres estandarizados mejoran trazabilidad."
  exit 1
fi

# 2. Ejecutar pruebas
if command -v pytest >/dev/null; then
  pytest --maxfail=1 --durations=0 -q
else
  echo "Advertencia: pytest no está instalado."
fi

# 3. Análisis SAST
STAGED_PY=$(git diff --cached --diff-filter=ACM --name-only -z | grep -zE '\.py$' || true)
if command -v bandit >/dev/null && [ -n "$STAGED_PY" ]; then
  echo "$STAGED_PY" | xargs -0 -r bandit -f txt -o sast-report.txt || true
elif command -v bandit >/dev/null; then
  echo "Sin .py staged; ejecutando SAST sobre src/ (fallback)"
  bandit -r src --exclude tests,fixtures -f txt -o sast-report.txt || true
else
  echo "Advertencia: bandit no instalado."
fi
if grep -E '^.*(high|critical) severity' sast-report.txt 2>/dev/null; then
  echo "Vulnerabilidades críticas detectadas. Revisar sast-report.txt"
  exit 1
fi

# 4. Escaneo de dependencias
if [[ -f requirements.txt ]]; then
  if command -v pip-audit >/dev/null; then
    pip-audit -r requirements.txt || true
  elif command -v safety >/dev/null; then
    safety check -r requirements.txt --full-report || true
  else
    echo "Advertencia: ni pip-audit ni safety están instalados."
  fi
fi

# 5. Escaneo de secretos
if command -v gitleaks >/dev/null; then
  if [ -n "$(git diff --cached --name-only -z)" ]; then
    git diff --cached --name-only -z | xargs -0 -I{} git show :{} | \
      gitleaks detect --no-git --stdin --report-path gitleaks-report.json --report-format json || true
  else
    echo "Sin archivos staged; escaneando src/ (fallback)"
    gitleaks detect --source src --no-git --report-path gitleaks-report.json --report-format json || true
  fi
else
  echo "Advertencia: gitleaks no instalado."
fi

echo "Pipeline local completado."
```

- Fallback a `src/` para SAST y secretos.
- Usa `-z` y `-0` para portabilidad.

### Alternativa con act:

```bash
act -j build
```
Con `.github/workflows/ci.yml`:

```yaml
name: Local CI Simulation
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install pytest bandit pip-audit ruff
      - name: Run tests
        run: pytest --maxfail=1 --durations=0 -q
      - name: Run SAST
        run: |
          FILES=$(git diff --cached --diff-filter=ACM --name-only -z | grep -zE '\.py$' || true)
          [ -n "$FILES" ] && echo "$FILES" | xargs -0 -r bandit -f txt -o sast-report.txt || \
          bandit -r src --exclude tests,fixtures -f txt -o sast-report.txt || true
      - name: Scan dependencies
        run: pip-audit -r requirements.txt
      - name: Scan secrets
        run: |
          if [ -n "$(git diff --cached --name-only -z)" ]; then
            git diff --cached --name-only -z | xargs -0 -I{} git show :{} | \
              gitleaks detect --no-git --stdin --report-path gitleaks-report.json --report-format json
          else
            gitleaks detect --source src --no-git --report-path gitleaks-report.json --report-format json
          fi
```
### Aplicación en el patrón Arrange‑Act‑Assert

Las **pruebas de seguridad con regex** siguen AAA y el principio **FIRST**: patrones anclados y acotados para evitar *ReDoS*, casos aislados y aserciones claras. Se ilustra un ciclo **Red-Green-Refactor** para reducir falsos positivos en detección de secretos, pasando de una coincidencia laxa a una expresión anclada y documentada.

Pruebas de seguridad con regex seguras:

```python
import re
import pytest

SAFE = re.compile(r'\A[A-Za-z0-9_]{1,50}\Z')
BAD = re.compile(r'\A(?:SELECT|INSERT|UPDATE|DELETE|<\s*script\b)', re.IGNORECASE)

@pytest.mark.parametrize("s,ok", [
    ("SELECT * FROM users", False),
    ("<script>alert('xss')</script>", False),
    ("safe_input_123", True),
])
def test_secure_input(s, ok):
    is_safe = bool(SAFE.match(s)) and not BAD.search(s)
    assert is_safe == ok, f"Input '{s}' no cumple con la validación esperada"
```

- `SAFE` permite `_` para coherencia.
>Nota: En producción, usa parametrización SQL, escape HTML o listas de caracteres permitidos.

### Principio FIRST en pruebas de regex

Ajustamos FIRST para pruebas de seguridad:

- **Fast:** Patrones acotados (`{1,50}`) y anclas (`\A...\Z`).
- **Isolated:** Pruebas separadas para formato y seguridad.
- **Repeatable:** Datos estáticos locales.
- **Self-validating:** Aserciones claras.
- **Timely:** Pruebas de seguridad primero.

**Ejemplo:**

```python
def test_prevent_redos():
    patron = re.compile(r'\A[A-Za-z0-9_]{1,32}\Z')  # Evita ReDoS, permite _
    assert patron.match("safe_input_123")
    assert not patron.match("a" * 1000)  # Prueba de rendimiento
```

### Flujo RGR (Red‑Green‑Refactor)

Caso de falso positivo en detección de secretos:

**Ciclo: Prevenir falsos positivos en secretos**

**Red:**

```python
def test_secret_detection():
    patron = re.compile(r'(password|secret)=[A-Za-z0-9+/=]{20,}')
    assert not patron.match("password=test123")  # Falla por falso positivo
 ```
**Green:**

```python
patron = re.compile(r'\A(password|secret)=[A-Za-z0-9+/=]{20,}\b\Z')
```
**Refactor:**
```python
SECRETS_PATTERN = r'''
    \A                          # Inicio
    (?:password|secret)=        # Clave
    [A-Za-z0-9+/=]{20,}\b      # Valor largo
    \Z                          # Fin
'''
patron = re.compile(SECRETS_PATTERN, re.VERBOSE)
# Nota: Gitleaks es preferido para detección robusta (firmas + entropía)
```

### Herramientas DevSecOps Locales

- Bandit: Análisis estático para Python (`pip install bandit`).
- Pip-audit: Escaneo de dependencias (`pip install pip-audit`).
- Gitleaks: Detección de secretos (`brew install gitleaks`).
- Ruff: Linter/formatter rápido (`pip install ruff`).
- Flake8: Linter alternativo (`pip install flake8`).
- ESLint: Linter para JS/TS (`npm install eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin`).

**Ejemplo:**

```bash
gitleaks detect --source src --no-git --report-path gitleaks-report.json --report-format json
```
### Monitoreo de seguridad local

El **monitoreo local** de logs aplica listas negras y blancas, clasifica severidad (OK/ALERTA/CRÍTICO) y rota archivos, persistiendo el estado para incluirlo en reportes. La configuración se centraliza en `pyproject.toml` (ruff/pytest/bandit) y `.editorconfig` (EOL, espacios finales). El **Makefile** expone una UX coherente (`install-hooks`, `lint`, `test`, `sast`, `deps-audit`, `scan-secrets`, `ci-local`, `report`, `doctor`). 

Finalmente, se sugiere integrar todo con el framework **pre-commit** para caching y ejecución consistente de `ruff`, `bandit` y `gitleaks`.


```bash
# En scripts/monitor-logs.sh
#!/usr/bin/env bash
set -euo pipefail

LOGFILE="app.log"
PATTERN='(\bSELECT\b|\bINSERT\b|\b<script\b)'
WHITELIST='(\bSELECT\s*option\b)'
SEVERITY="OK"
EXIT_CODE=0

if [[ -f "$LOGFILE" ]]; then
  if grep -E "$PATTERN" "$LOGFILE" | grep -E -v "$WHITELIST" >/dev/null; then
    echo "Posible ataque detectado en $LOGFILE"
    SEVERITY="CRÍTICO"
    EXIT_CODE=2
  else
    echo "No se detectaron patrones maliciosos en $LOGFILE"
    SEVERITY="OK"
    EXIT_CODE=0
  fi
else
  echo "Advertencia: $LOGFILE no existe"
  SEVERITY="ALERTA"
  EXIT_CODE=1
fi

# Rotación antes de salir
if [[ -f "$LOGFILE" && $(stat -f %z "$LOGFILE" 2>/dev/null || stat -c %s "$LOGFILE") -gt 1048576 ]]; then
  mv "$LOGFILE" "${LOGFILE}.$(date -u +%Y%m%d_%H%M%S)"
fi

# Persistir severidad
mkdir -p out && echo "$SEVERITY" > out/monitor_severity.txt
exit "$EXIT_CODE"
```

- Códigos de salida: 0 (OK), 1 (ALERTA), 2 (CRÍTICO).
- Persiste severidad antes de salir.

### Configuración centralizada

Reglas en `pyproject.toml`:

```toml
[tool.ruff]
line-length = 88
exclude = ["tests/fixtures"]
select = ["E", "F", "W", "I", "S"]  # Incluye S para seguridad

[tool.pytest.ini_options]
addopts = "--maxfail=1 --durations=0"
markers = ["security: pruebas de seguridad"]

[tool.bandit]
exclude_dirs = ["tests", "fixtures"]
```

Normalización en `.editorconfig`:

```ini
root = true
[*]
end_of_line = lf
trim_trailing_whitespace = true
insert_final_newline = true
```
Este material define una columna vertebral DevSecOps "local first" para un proyecto Python, donde la calidad, la seguridad y la experiencia de desarrollo se integran desde el repositorio. 

La configuración centralizada en `pyproject.toml` unifica estilo, pruebas y análisis estático: Ruff fija un largo de línea de 88, excluye "fixtures" y activa selectores `E/F/W/I` más **S** para reglas de seguridad. Pytest estandariza la ejecución con `--maxfail=1` y expone el marcador `security` para aislar pruebas de seguridad. Bandit excluye directorios no productivos. 

En paralelo, `.editorconfig` impone normalización transversal (LF, recorte de espacios y salto final), evitando "diffs" ruidosos y asegurando consistencia entre IDEs y sistemas operativos.

### Makefile para UX

Sobre esa base, el **Makefile** ofrece una UX de un solo comando por tarea frecuente, con shell robusto (`set -euo pipefail`) y *targets* autoexplicativos: `install-hooks` establece `.githooks/` como ruta de hooks y los deja ejecutables. `lint` ejecuta Ruff; `test` dispara Pytest con parámetros coherentes con el `pyproject`. `sast` prioriza archivos *staged* y, si no hay cambios, recurre a un escaneo recursivo de `src`, generando `sast-report.txt`.  `deps-audit` elige inteligentemente entre `pip-audit` y `safety`; `scan-secrets` integra Gitleaks tanto sobre cambios *staged* como sobre `src`. `doctor` audita prerequisitos; `ci-local` y `report` empaquetan la tubería local y la generación de artefactos. 

Con `help` se documenta a sí mismo, favoreciendo descubribilidad.


```make
# En Makefile
SHELL := /usr/bin/env bash
.ONESHELL:

.PHONY: install-hooks lint test sast deps-audit scan-secrets ci-local report doctor help

install-hooks: ## Configura hooks en .githooks/
	set -euo pipefail
	@echo "Configurando hooks..."
	git config core.hooksPath .githooks/
	mkdir -p .githooks
	if [ -d hooks ]; then cp hooks/* .githooks/; fi
	chmod +x .githooks/* 2>/dev/null || true
	@echo "Hooks instalados en .githooks/"

lint: ## Ejecuta linter (ruff o flake8)
	set -euo pipefail
	@echo "Ejecutando linter..."
	ruff check . || true

test: ## Ejecuta pruebas con pytest
	set -euo pipefail
	@echo "Ejecutando pruebas..."
	pytest --maxfail=1 --durations=0 -q || true

sast: ## Ejecuta análisis SAST con bandit
	set -euo pipefail
	@echo "Ejecutando análisis SAST..."
	FILES=$$(git diff --cached --diff-filter=ACM --name-only -z | grep -zE '\.py$' || true)
	[ -n "$$FILES" ] && echo "$$FILES" | xargs -0 -r bandit -f txt -o sast-report.txt || \
	bandit -r src --exclude tests,fixtures -f txt -o sast-report.txt || true

deps-audit: ## Escanea dependencias (pip-audit o safety)
	set -euo pipefail
	@echo "Escaneando dependencias..."
	if command -v pip-audit >/dev/null; then \
		pip-audit -r requirements.txt || true; \
	else \
		safety check -r requirements.txt --full-report || true; \
	fi

scan-secrets: ## Escanea secretos con gitleaks
	set -euo pipefail
	@echo "Escaneando secretos..."
	if [ -n "$$(git diff --cached --name-only -z)" ]; then \
		git diff --cached --name-only -z | xargs -0 -I{} git show :{} | \
		gitleaks detect --no-git --stdin --report-path gitleaks-report.json --report-format json || true; \
	else \
		gitleaks detect --source src --no-git --report-path gitleaks-report.json --report-format json || true; \
	fi

ci-local: ## Ejecuta pipeline CI local
	set -euo pipefail
	@echo "Ejecutando pipeline local..."
	./scripts/ci-local.sh

report: ## Genera reporte en out/
	set -euo pipefail
	@echo "Generando reporte..."
	./scripts/generate-report.sh

doctor: ## Verifica herramientas instaladas
	set -euo pipefail
	@echo "Verificando herramientas..."
	command -v git >/dev/null || { echo "Git no instalado"; exit 1; }
	command -v pytest >/dev/null || echo "Advertencia: pytest no instalado"
	command -v ruff >/dev/null || echo "Advertencia: ruff no instalado"
	command -v bandit >/dev/null || echo "Advertencia: bandit no instalado"
	command -v pip-audit >/dev/null || echo "Advertencia: pip-audit no instalado"
	command -v gitleaks >/dev/null || echo "Advertencia: gitleaks no instalado"
	command -v eslint >/dev/null || echo "Advertencia: eslint no instalado"
	command -v jq >/dev/null || echo "Advertencia: jq no instalado"
	@echo "Verificación completada"

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## ' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'
```

### Hilo rojo DevSecOps local

El "hilo rojo" arranca con una historia de usuario de autenticación y criterios de aceptación que conectan negocio con controles técnicos: acceso con credenciales válidas, error explícito con contraseña incorrecta y rechazo de entradas maliciosas (XSS y SQL injection). Ese contrato guía los *gates* previos al commit y las pruebas. El **hook pre-commit** inspecciona los archivos *staged* y falla si detecta patrones de secretos (tokens, credenciales, claves), ejecuta Bandit selectivamente y corta el commit ante severidades altas o críticas. Así, los defectos de seguridad se detienen en la frontera más barata: antes de que lleguen a la rama.

Las **pruebas AAA** para seguridad modelan entradas con expresiones regulares: una "whitelist" de identificadores seguros y una "blacklist" de patrones peligrosos (SQL, `<script>`). El *Arrange* define los insumos, el *Act* evalúa la condición de seguridad y el *Assert* contrasta con el resultado esperado. Este enfoque convierte amenazas típicas en casos reproducibles, alineando pruebas y *acceptance criteria*.

La **pipeline local** orquesta `test`, `sast`, `deps-audit` y `scan-secrets` en un script idempotente que finaliza con estado claro ("Pipeline completado"). Esta secuencia refleja *shift-left security*: primero correcciones funcionales, después análisis de código, luego vulnerabilidades de dependencias y, finalmente, secretos. Para operación, un **monitor de logs** simple examina `app.log` y alerta ante trazas que indiquen SQL o XSS (con excepciones explícitas como `SELECT option`), facilitando detección temprana de abuso o validaciones insuficientes sin depender aún de un SIEM.

Finalmente, se propone consolidar todo con el framework **pre-commit**: Ruff y Bandit via repos oficiales, más un hook local de Gitleaks. Esta capa añade *caching* y ejecución homogénea en cada estación de trabajo con `pip install pre-commit` y `pre-commit install`, reduciendo tiempos y variabilidad. En conjunto, la lectura muestra cómo traducir requisitos de negocio en controles automáticos y repetibles, con configuraciones declarativas, *targets* amigables y *gates* de seguridad que bloquean riesgos en origen.

#### 1. Historia de usuario:

> Como usuario registrado, quiero iniciar sesión en el sistema para acceder a mi cuenta personal.


#### 2. Criterios de aceptación:

- Credenciales válidas permiten acceso al dashboard.
- Contraseña incorrecta muestra un mensaje de error.
- Entradas maliciosas (<script>, SELECT *) son rechazadas.


#### 3. Hook pre-commit:

```bash
#!/usr/bin/env bash
set -euo pipefail
STAGED_Z=$(git diff --cached --diff-filter=ACM --name-only -z)
[ -z "$STAGED_Z" ] && { echo "No hay archivos modificados."; exit 0; }
echo "$STAGED_Z" | tr '\0' '\n' | grep -Ev '(^tests/fixtures/|\.png$|\.pdf$|\.csv$)' | tr '\n' '\0' | \
  xargs -0 -r grep -E -- '(password|secret)=[A-Za-z0-9+/=]{20,}\b|Bearer [A-Za-z0-9\-_\.=]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}' && { echo "¡Error: Secreto detectado!"; exit 1; }
if command -v bandit >/dev/null; then
  FILES=$$(echo "$STAGED_Z" | grep -zE '\.py$' || true)
  [ -n "$$FILES" ] && echo "$$FILES" | xargs -0 -r bandit -f txt -o sast-report.txt || true
  if grep -E '^.*(high|critical) severity' sast-report.txt 2>/dev/null; then
    echo "Vulnerabilidades críticas detectadas"
    exit 1
  fi
fi
```

#### 4. Pruebas AAA para seguridad:

```python
import re
import pytest

SAFE = re.compile(r'\A[A-Za-z0-9_]{1,50}\Z')
BAD = re.compile(r'\A(?:SELECT|INSERT|UPDATE|DELETE|<\s*script\b)', re.IGNORECASE)

@pytest.mark.parametrize("s,ok", [
    ("SELECT * FROM users", False),
    ("<script>alert('xss')</script>", False),
    ("safe_input_123", True),
])
def test_secure_input(s, ok):
    is_safe = bool(SAFE.match(s)) and not BAD.search(s)
    assert is_safe == ok
```

#### 5. Pipeline local:

```bash
#!/usr/bin/env bash
set -euo pipefail
make test
make sast
make deps-audit
make scan-secrets
echo "Pipeline completado."
```

#### 6. Monitoreo de logs:

```bash
#!/usr/bin/env bash
set -euo pipefail
LOGFILE="app.log"
if grep -E '(\bSELECT\b|\b<script\b)' "$LOGFILE" | grep -E -v '(\bSELECT\s*option\b)' >/dev/null; then
  echo "Alerta: Posible ataque detectado"
  exit 2
fi
```

### Nota adicional: Framework pre-commit

Considera el framework `pre-commit` para encapsular `ruff`, `bandit`, `pip-audit`, y `gitleaks` con caching local:

```yaml
# En .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.6.9
    hooks:
      - id: ruff
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.10
    hooks:
      - id: bandit
        args: [--exclude, tests,fixtures]
  - repo: local
    hooks:
      - id: gitleaks
        name: gitleaks
        entry: gitleaks detect --source . --report-format json --report-path gitleaks-report.json --no-git
        language: system
```

Instala con `pip install pre-commit` y ejecuta `pre-commit install`.
