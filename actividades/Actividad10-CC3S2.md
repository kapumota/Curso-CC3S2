## Actividad: : DI, fixtures y cobertura con gates

>Para esta actividad en clase, toma de referencia el [laboratorio 4](https://github.com/kapumota/Curso-CC3S2/tree/main/labs/Laboratorio4) del curso.

## Parte 1

### De `requests`  a DI + pruebas sin red, con políticas DevSecOps

#### Punto de partida (estado actual)

Tu clase `IMDb` vive en `models/imdb.py` y expone tres métodos que llaman directamente a `requests.get`: `search_titles`, `movie_reviews` y `movie_ratings`. Cada uno construye una URL HTTPS a `imdb-api.com` y retorna `json()` si el `status_code` es 200; en otro caso, `{}`. 

Tus pruebas (`tests/test_imdb.py`) ya **parchean** la llamada de red usando `@patch("models.imdb.requests.get")`, cargan **fixtures** desde `tests/fixtures/imdb_responses.json`, y verifican tanto casos "felices" como de error (API key inválida). También hacen asserts de **URL exacta** con `assert_called_once_with("<URL>")`.  

> Detalle importante del contrato de pruebas actual:
>
> * Para "títulos": se espera `https://imdb-api.com/API/SearchTitle/<apikey>/<title>`
> * Para "reviews": `.../Reviews/<apikey>/<imdb_id>`
> * Para "ratings": `.../Ratings/<apikey>/<imdb_id>`
> * Fixtures incluyen, por ejemplo, `movie_ratings` con campos como `rottenTomatoes` y `filmAffinity`.  

#### Paso 1 - Refactor mínimo a **Inyección de dependencias (DI)** sin romper pruebas

Desacopla la capa HTTP para poder:

1. inyectar un cliente simulado (mock) en pruebas sin tocar red, y
2. seguir siendo compatible con el patch existente sobre `requests.get`.

**Cambios sugeridos**

* Añade a `__init__` un parámetro opcional `http_client`.
* Guarda `self.http = http_client or requests`.
* Reemplaza cada `requests.get(...)` por `self.http.get(...)`.

> Por qué **no** rompe tus pruebas actuales: tus tests parchean **`models.imdb.requests.get`**; como el "default" para `self.http` sigue siendo `requests`, el patch intercepta igual. Los asserts de URL se mantienen idénticos (por ahora). 

**Ejemplo (fragmento):**

```python
# models/imdb.py
import logging
from typing import Any, Dict
import requests  # ¡Se mantiene para compatibilidad con @patch!
import urllib.parse  # lo usaremos en el paso 2 (opcional)
logger = logging.getLogger(__name__)

class IMDb:
    def __init__(self, apikey: str, http_client=None):
        self.apikey = apikey
        self.http = http_client or requests  # DI con default

    def search_titles(self, title: str) -> Dict[str, Any]:
        logger.info("Buscando en IMDb el título: %s", title)
        url = f"https://imdb-api.com/API/SearchTitle/{self.apikey}/{title}"
        r = self.http.get(url)
        return r.json() if r.status_code == 200 else {}
```

> Con esto, tu suite actual debería seguir pasando tal cual, porque la ruta del patch no cambia. (Tu base hace exactamente esas construcciones de URL y compara contra ellas.)  

#### Paso 2 - Giro **DevSecOps**: allowlist de host + timeout por **ENV** (12-Factor III)


Añade "gates" de seguridad operables por configuración:

* **Allowlist**: solo permitir el host `imdb-api.com`.
* **Timeout** configurable por variable de entorno `HTTP_TIMEOUT` (default, por ejemplo, 2.0 s).

**Diseño**

* Define constantes de módulo:

  * `ALLOWED_HOSTS = {"imdb-api.com"}`
  * `TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "2.0"))`
* Extrae un helper `_enforce_policies(url: str)` que:

  * verifica que el **hostname** está en la allowlist, y
  * pide `https://` (sin TLS no hay salida).
* En cada método: **construye URL -> valida -> `self.http.get(url, timeout=TIMEOUT)`**.

> Nota: al **añadir `timeout`** a las llamadas, tus pruebas que hacen `assert_called_once_with("<URL>")` deberán ajustarse para incluir el keyword argument `timeout=TIMEOUT`. Ese es el **único** cambio en asserts (la URL exacta no se toca). 

**Fragmento:**

```python
# models/imdb.py (añadidos)
import os, urllib.parse
ALLOWED_HOSTS = {"imdb-api.com"}
TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "2.0"))

def _enforce_policies(url: str):
    host = urllib.parse.urlparse(url).hostname
    if host not in ALLOWED_HOSTS:
        raise ValueError(f"Host no permitido: {host}")
    if not url.startswith("https://"):
        raise ValueError("Se requiere HTTPS")

class IMDb:
    ...
    def movie_ratings(self, imdb_id: str) -> Dict[str, Any]:
        url = f"https://imdb-api.com/API/Ratings/{self.apikey}/{imdb_id}"
        _enforce_policies(url)
        r = self.http.get(url, timeout=TIMEOUT)
        return r.json() if r.status_code == 200 else {}
```

**Ajuste en pruebas (ejemplo):**

```python
from models.imdb import TIMEOUT

mock_get.assert_called_once_with(
    "https://imdb-api.com/API/SearchTitle/fake_api_key/Bambi",
    timeout=TIMEOUT,
)
```

> Repite el mismo patrón en los demás asserts (`Reviews`, `Ratings`, casos de error). Tus fixtures siguen igual (mismos campos).  

**Test nuevo para la allowlist** (unidad de `_enforce_policies` o integración):

```python
import pytest
from models.imdb import _enforce_policies

def test_politica_rechaza_host_no_permitido():
    with pytest.raises(ValueError):
        _enforce_policies("https://malicioso.evil/xx")
```

> Si prefieres no exponer `_enforce_policies`, puedes probar integración inyectando un "cliente" que no llegue a tocar red y fabricando una URL alternativa mediante un método auxiliar; pero para demo didáctica, la unidad del helper es clara y estable.

**Opcional: robustez de inputs**
Si el título puede incluir espacios o caracteres especiales, puedes normalizar con `urllib.parse.quote(title, safe="")` **antes** de formarlo en la URL (ojo: tus pruebas comparan **URL literal**; si cambias el encoding tendrás que actualizar los asserts para coincidir con la nueva URL codificada). 

#### Paso 3 - Pruebas 100% **sin red** usando DI (además del patch)

Aunque tus pruebas ya mockean `requests.get`, con DI puedes **inyectar** un cliente HTTP falso (Mock) y asercionar **interacciones** sin depender de la ruta del patch:

```python
from unittest.mock import Mock
from models.imdb import IMDb, TIMEOUT

def test_search_titles_con_cliente_inyectado(imdb_data):
    http = Mock()
    mock_resp = Mock(status_code=200)
    mock_resp.json.return_value = imdb_data["search_title"]
    http.get.return_value = mock_resp

    imdb = IMDb(apikey="fake_api_key", http_client=http)
    out = imdb.search_titles("Bambi")

    http.get.assert_called_once_with(
        "https://imdb-api.com/API/SearchTitle/fake_api_key/Bambi",
        timeout=TIMEOUT,  # si ya implementaste políticas
    )
    assert out == imdb_data["search_title"]
```

> Esto hace que tu suite sea **más explícita**: las pruebas no dependen de `requests` en absoluto y validan contrato de URL + kwargs. El contenido de `search_title` sale de tu JSON de fixtures, que ya incluye `results`, `expression`, etc. 


#### Paso 4 - **Cobertura** con **gate** (DevSecOps)

Para que la pipeline falle cuando la cobertura caiga por debajo del umbral, añade `--cov-fail-under=85` en tu configuración `pytest` o en el target de Make:

```
pytest --cov=models --cov=tests --cov-report=term-missing --cov-fail-under=85
```

Y encadénalo como "gate" previo a `run/pack` en tu `Makefile`:

```makefile
gates: lint coverage
	@echo "Gates OK"

run: gates
	python -m app.main
```

> Así integras calidad (medición) y control automatizado a nivel de CI/CD (en línea con 12-Factor V: separar compilar -> lanzar -> ejecutar, y con cultura de **gates** operativos). Tus pruebas ya cubren rutas felices y fallidas (por ejemplo, `INVALID_API`), lo que ayuda a subir cobertura.  

#### Paso 5 - Checklist de migración (rápida)

1. Implementa DI (sin tocar tests): constructor con `http_client`; `self.http.get`. 
2. Añade `ALLOWED_HOSTS`, `TIMEOUT` y `_enforce_policies` y llama con `timeout=TIMEOUT`.
3. Actualiza **tus asserts** `assert_called_once_with` para incluir `timeout=TIMEOUT` en **todas** las pruebas que validan URL exacta. 
4. Agrega un test unitario de rechazo de host (allowlist) y, si quieres, otro de "rechazo por no-HTTPS".
5. Activa cobertura con gate ≥ 85% y encadénalo a tus targets de `Make`.
6. (Opcional) Crea variantes de pruebas con **cliente inyectado** para independencia total de `requests`.

#### Paso 6 - Pitfalls habituales (y soluciones)

* **Asserts rotos** tras introducir `timeout`:
  Actualiza a `assert_called_once_with(<URL>, timeout=TIMEOUT)`. (Es el cambio más común.) 

* **Quitar `import requests` por error**:
  **No lo quites**; tus pruebas siguen parcheando `models.imdb.requests.get`. Mantenerlo preserva compatibilidad.

* **Cambiar el formato de URL (por ejemplo, aplicar `quote`)**:
  Si codificas el título, recuerda alinear los asserts con la nueva representación.

* **Cobertura insuficiente** al activar el gate:
  Añade pruebas negativas (allowlist, no-HTTPS, 404/400) y de borde (payload vacío) para subir cobertura. Tus fixtures ya traen casos útiles (`INVALID_API`, campos de `movie_ratings`). 

#### Paso 7 - Relación explícita con tus archivos

* **Implementación actual** de `IMDb` (tres métodos, `requests.get`, retorno `{}` si no es 200) -> base para DI. 
* **Pruebas existentes** (patch sobre `models.imdb.requests.get`, asserts de URL exacta, carga de fixtures, verificación de `INVALID_API`) -> te indican qué contratos no debes romper y qué asserts debes extender con `timeout`. 
* **Fixtures** (`imdb_responses.json`) -> describen la forma esperada de respuestas (clave para asserts de igualdad de diccionarios y para cubrir rutas de negocio). 

#### Comandos guía

```bash
# Suite base (antes y después del Paso 1)
make test ACTIVITY=mocking_objetos

# Con timeout por ENV (Paso 2)
export HTTP_TIMEOUT=2.0
make test ACTIVITY=mocking_objetos

# Cobertura y gate (Paso 4)
pytest --cov=models --cov=tests --cov-report=term-missing --cov-fail-under=85
```

Con esto, conviertes un cliente acoplado a red en un **componente inyectable y testeable**, añades **controles de seguridad/operación** gobernados por entorno (12-Factor III) y elevas la **calidad** con un **gate de cobertura** que refuerza la disciplina DevSecOps - todo **sin romper** el contrato que ya exigen tus pruebas actuales y tus fixtures.   

## Parte 2

### Stubs y fixtures

Genera datos mínimos (stubs) y fixtures reutilizables, con validación de entrada y logs redaccionados.

1. **Rutas de trabajo**

* `labs/Laboratorio4/Actividades/pruebas_fixtures/`
* `labs/Laboratorio4/Actividades/factories_fakes/`

2. **Archivo**: `Actividades/pruebas_fixtures/conftest.py`

```python
import json
import os
import re
import logging
import pytest

class SecretRedactor(logging.Filter):
    """Redacta tokens, claves de API y encabezados de autorización en los registros."""
    SECRET_PAT = re.compile(r"(Authorization:\s*Bearer\s+)[A-Za-z0-9\-\._~\+\/]+=*", re.I)
    KEY_PAT = re.compile(r"(api[_-]?key|token|secret)\s*=\s*[^&\s]+", re.I)

    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        msg = self.SECRET_PAT.sub(r"\1<REDACTED>", msg)
        msg = self.KEY_PAT.sub(lambda m: m.group(1) + "=<REDACTED>", msg)
        record.msg = msg
        return True

@pytest.fixture(autouse=True)
def _redacted_logging(caplog):
    logger = logging.getLogger()
    logger.addFilter(SecretRedactor())
    caplog.set_level(logging.INFO)
    yield
    logger.filters.clear()

@pytest.fixture
def stub_valid_account():
    # Stub mínimo de camino feliz
    return {"id": "u_001", "email": "user@example.com", "role": "reader", "active": True}

@pytest.fixture
def stub_corrupt_account():
    # negativo: tipos incorrectos/campos faltantes
    return {"id": None, "email": "bad@@", "role": 123, "active": "yes"}

@pytest.fixture
def imdb_fixtures():
    # Carga respuestas plausibles de IMDb desde el archivo de partidos.
    base = os.path.dirname(__file__)
    with open(os.path.join(base, "fixtures", "imdb_responses.json"), "r", encoding="utf-8") as f:
        return json.load(f)
```

3. **Archivo**: `Actividades/pruebas_fixtures/fixtures/imdb_responses.json`

```json
{
  "search_titles_ok": {
    "results": [
      {"id": "tt0111161", "title": "The Shawshank Redemption"},
      {"id": "tt0068646", "title": "The Godfather"}
    ],
    "errorMessage": ""
  },
  "ratings_ok": {
    "imDbId": "tt0111161",
    "imDb": "9.3",
    "metacritic": "82",
    "theMovieDb": "8.7"
  },
  "malformed_payload": {
    "oops": "no es el esquema esperado"
  }
}
```

4. **Validación de entrada (ejemplo mínimo)**
   `Actividades/factories_fakes/validators.py`

```python
def validate_account(d):
    # controles mínimos estrictos
    if not isinstance(d, dict): raise TypeError("la cuenta debe ser un dict")
    for k in ("id", "email", "role", "active"):
        if k not in d: raise ValueError(f"falta {k}")
    if not isinstance(d["id"], str) or not d["id"]:
        raise ValueError("id debe ser una cadena no vacía")
    if "@" not in d["email"]:
        raise ValueError("correo inválido")
    if not isinstance(d["role"], str):
        raise ValueError("role debe ser una cadena")
    if not isinstance(d["active"], bool):
        raise ValueError("active debe ser booleano")
    return True

```

5. **Test rápido**
   `Actividades/pruebas_fixtures/test_accounts.py`

```python
import pytest
from factories_fakes.validators import validate_account

def test_valid_account(stub_valid_account):
    assert validate_account(stub_valid_account) is True

@pytest.mark.parametrize("field", ["id","email","role","active"])
def test_missing_fields(stub_valid_account, field):
    d = dict(stub_valid_account)
    d.pop(field)
    with pytest.raises(ValueError):
        validate_account(d)

def test_corrupt_types(stub_corrupt_account):
    with pytest.raises((ValueError, TypeError)):
        validate_account(stub_corrupt_account)
```


### Mock de fallos y resiliencia

Simula `timeout`, `HTTP 500`, y payload malformado; opcional backoff con jitter; verificar logs redaccionados.

1. **Cliente Fake (sin red)**
   `Actividades/mocking_objetos/fake_http.py`

```python
import time
from typing import Dict, Any

class FakeHttpClient:
    """Sin red. Sirve datos pre-cargados, puede simular errores/tiempos de espera."""
    def __init__(self, fixtures: Dict[str, Any], delay_ms: int = 0, fail_mode: str | None = None):
        self._fx = fixtures
        self._delay = delay_ms / 1000.0
        self._fail_mode = fail_mode

    def get_json(self, url: str, headers=None, timeout=2.0):
        if self._delay:
            time.sleep(min(self._delay, timeout + 0.05))
        if self._fail_mode == "timeout":
            # Simula tiempo de espera excedido
            time.sleep(timeout + 0.1)
            raise TimeoutError("la solicitud excedió el tiempo de espera")
        if self._fail_mode == "500":
            raise RuntimeError("HTTP 500 simulado")
        if "malformed" in url:
            return self._fx["malformed_payload"]
        if "Ratings" in url:
            return self._fx["ratings_ok"]
        return self._fx["search_titles_ok"]

```

2. **Backoff con jitter (opcional)**
   `Actividades/mocking_objetos/backoff.py`

```python
import random
import time
from functools import wraps

def bounded_jitter_backoff(tries=3, base=0.05, cap=0.5):
    """Retardo exponencial limitado con variación aleatoria"""
    def deco(fn):
        @wraps(fn)
        def _wrap(*a, **kw):
            attempt = 0
            while True:
                try:
                    return fn(*a, **kw)
                except Exception as e:
                    attempt += 1
                    if attempt >= tries:
                        raise
                    sleep = min(cap, base * (2 ** (attempt - 1))) + random.uniform(0, base)
                    time.sleep(sleep)
        return _wrap
    return deco

```

3. **Tests de resiliencia**
   `Actividades/mocking_objetos/test_resilience.py`

```python
import logging
import pytest
from .fake_http import FakeHttpClient
from ..pruebas_fixtures.conftest import SecretRedactor  # reutiliza redactor

LOGGER = logging.getLogger("imdb")

def test_timeout_logged_redacted(imdb_fixtures, caplog):
    caplog.set_level(logging.INFO)
    LOGGER.addFilter(SecretRedactor())
    client = FakeHttpClient(imdb_fixtures, delay_ms=0, fail_mode="timeout")
    with pytest.raises(TimeoutError):
        client.get_json("https://imdb-api.com/API/Ratings/KEY/tt0111161", headers={"Authorization":"Bearer AAA.BBB"})
    # valida redacción
    msgs = " ".join(m for _,_,m in caplog.record_tuples)
    assert "Bearer <REDACTED>" in msgs

def test_http_500_branch(imdb_fixtures):
    client = FakeHttpClient(imdb_fixtures, fail_mode="500")
    with pytest.raises(RuntimeError):
        client.get_json("https://imdb-api.com/API/Ratings/KEY/tt0111161")

def test_malformed_payload_branch(imdb_fixtures):
    client = FakeHttpClient(imdb_fixtures)
    data = client.get_json("https://imdb-api.com/API/Ratings/KEY/malformed")
    assert "oops" in data 

```

> **Gate de cobertura**: estos tests abren ramas de error (timeout/500/malformed).


### Coverage y reportes

1. **Comandos**

```bash
make test ACTIVITY=coverage_pruebas
make coverage_individual
```

2. **Política de  repositorio**: `pytest.ini` en la raíz del laboratorio (o dentro de `Actividades/coverage_pruebas/`)

```ini
[pytest]
addopts = -q --cov=Actividades --cov-report=term-missing --cov-report=html:htmlcov_coverage_pruebas --cov-fail-under=85
```

3. **Evidencias**

* Exporta `htmlcov_coverage_pruebas/` a `evidencias/coverage/`.
* Guarda `logs/` con redacción activa (ver filtro).
* README corto en `evidencias/` indicando **qué** cubrió cada test y **dónde** están los reportes.


### SOLID + DI/DIP para "cliente seguro"

1. **Abstracción** (ISP + DIP)
   `Actividades/mocking_objetos/http_abstraction.py`

```python
from typing import Protocol, Any, Mapping

class HttpClient(Protocol):
    def get_json(self, url: str, headers: Mapping[str,str] | None = None, timeout: float = 2.0) -> Any:
        ...
```

2. **Implementación real con políticas (timeouts, allowlist, HTTPS-only)**
   `Actividades/mocking_objetos/real_http.py`

```python
import logging
import re
import urllib.parse as up
import os
import requests
from .http_abstraction import HttpClient

LOGGER = logging.getLogger("imdb")
ALLOWLIST = {"imdb-api.com", "api.themoviedb.org"}

def _https_and_allowed(url: str) -> None:
    u = up.urlparse(url)
    if u.scheme.lower() != "https":
        raise ValueError("Politica OCP : HTTPS requerido")
    host = u.hostname or ""
    if host not in ALLOWLIST:
        raise ValueError(f"Host no permitido: {host}")

class RealHttpClient(HttpClient):
    def __init__(self, timeout: float | None = None):
        self.timeout = timeout or float(os.getenv("HTTP_TIMEOUT", "3.0"))

    def get_json(self, url, headers=None, timeout=None):
        _https_and_allowed(url)
        t = timeout or self.timeout
        resp = requests.get(url, headers=headers or {}, timeout=t)
        if resp.status_code >= 500:
            raise RuntimeError(f"Error server {resp.status_code}")
        resp.raise_for_status()
        return resp.json()
```

3. **IMDb usando DIP (LSP: Fake sustituye sin romper)**
   `Actividades/mocking_objetos/models/imdb.py`

```python
from typing import Mapping, Any
from ..mocking_objetos.http_abstraction import HttpClient

class ImdbService:
    BASE = "https://imdb-api.com/API"

    def __init__(self, client: HttpClient, apikey: str):
        self.client = client
        self.apikey = apikey

    def search_titles(self, title: str) -> Any:
        url = f"{self.BASE}/SearchTitle/{self.apikey}/{title}"
        return self.client.get_json(url)

    def movie_ratings(self, imdb_id: str) -> Any:
        url = f"{self.BASE}/Ratings/{self.apikey}/{imdb_id}"
        return self.client.get_json(url)
```

4. **Tests con Fake (sin red)**
   `Actividades/mocking_objetos/test_imdb_di.py`

```python
from .fake_http import FakeHttpClient
from .models.imdb import ImdbService

def test_imdb_with_fake(imdb_fixtures):
    svc = ImdbService(FakeHttpClient(imdb_fixtures), apikey="KEY")
    data = svc.search_titles("shawshank")
    assert data["results"][0]["id"].startswith("tt")
```


### Cómo conectar al laboratorio (paso a paso)

1. **Calentar**

```bash
make test ACTIVITY=pruebas_pytest
```

2. **Mocking**

* Trabaja en `Actividades/mocking_objetos/` y añade `fake_http.py`, `real_http.py`, `http_abstraction.py`, `backoff.py`, `models/imdb.py` (si no existe, ajusta import paths a tu layout).

3. **Fixtures**

* Coloca `imdb_responses.json` en `Actividades/pruebas_fixtures/fixtures/`.
* Usa `conftest.py` mostrado (mismo directorio) para exponer fixtures y redacción.

4. **DI Refactor + Tests**

* Asegura que **tests** usan `ImdbService(FakeHttpClient(...))`.
* Mantén compatibilidad si ya tenías `@patch("models.imdb.requests.get")` (depreca gradualmente).

5. **Gates**

```bash
make coverage_individual
make lint
```

* `pytest.ini` con `--cov-fail-under=85`.
* Exporta `htmlcov_*` por actividad -> `evidencias/coverage/`.
* README en `evidencias/` con contrato + rutas de reportes + muestras de logs **redaccionados**.

### **Ejercicios**

#### 1) Unificación de nombres y rutas

**Contexto:** La base mezcla `IMDb` e `ImdbService` en `models/imdb.py` y subcarpetas de `Actividades/mocking_objetos`.

**Ejercicio:** Refactoriza a una sola clase pública (`ImdbService`) y ajusta los imports relativos para que `tests/test_imdb.py` y `Actividades/mocking_objetos/test_imdb_di.py` encuentren la misma implementación. Evita `..mocking_objetos` en rutas si mueves archivos.

#### 2) Asserts tras añadir `timeout`

**Contexto:** Tras aplicar `timeout=TIMEOUT` en `self.http.get(...)`, los tests con `assert_called_once_with("<URL>")` fallan por kwargs faltantes.

**Ejercicio:** Actualiza **todos** los asserts que verifican URLs para incluir `timeout=TIMEOUT`. Repite en rutas felices y negativas. Asegura que `TIMEOUT` viene del mismo módulo importado.

#### 3) Encoding del título vs contrato de pruebas

**Contexto:** Si aplicas `urllib.parse.quote(title, safe="")`, el contrato de la URL cambia.

**Ejercicio:** Crea una variante de test con título que contenga espacios y símbolos (`"Star Wars: Episode IV"`). Decide si congelas comportamiento sin encoding o actualizas los asserts a la URL codificada. Documenta la decisión en `tests/README.md`.


#### 4) Backoff con jitter reproducible

**Contexto:** El decorador de backoff introduce aleatoriedad y puede volver frágil el CI.

**Ejercicio:** En `test_backoff.py`, fija la semilla (`random.seed(1337)`) y comprueba con `monkeypatch` que el backoff **no** excede el cap. Mide el número de reintentos invocando una función que falla las dos primeras veces.

#### 5) Contrato de errores HTTP

**Contexto:** `RealHttpClient` hoy puede elevar 5xx de dos formas (manual + `raise_for_status`).

**Ejercicio:** Elige un único mecanismo. Si te quedas con `raise_for_status()`, mapea `requests.HTTPError` a una excepción de dominio (`RuntimeError` o custom) y añade tests que prueben 404 y 500 con mensajes claros.

#### 6) Redacción de secretos sin falsos positivos

**Contexto:** El filtro de logs podría redaccionar cadenas inocuas.

**Ejercicio:** Añade un test que loguee una línea con `Authorization: Bearer` **sin** token y otra con un querystring `?apikey=demo`. Verifica que solo se redacciona el caso con token real y que no se rompe la legibilidad del log. Incluye una muestra de log en `evidencias/logs/`.

#### 7) Cobertura de bordes de payload

**Contexto:** Para sostener el gate de cobertura, necesitas cubrir casos raros.

**Ejercicio:** Agrega tests para:

* `status_code=204` sin body,
* JSON vacío `{}`,
* respuesta 200 con `errorMessage` no vacío (por ejemplo, `INVALID_API`).
  Verifica que el servicio retorna `{}` o lanza excepción según tu contrato.

#### 8) Política HTTPS-only y subdominios

**Contexto:** Allowlist restringe `imdb-api.com`, pero ¿y `api.imdb-api.com`?

**Ejercicio:** Define si permites subdominios. Si **sí**, ajusta `_https_and_allowed` para aceptar `*.imdb-api.com`. Si **no**, agrega un test que garantice el rechazo. Añade también un test que rechaza `http://` con mensaje explicativo.


#### 9) Hook de trazado ligero en HttpClient

**Contexto:** Quieres métricas sin acoplar a red.

**Ejercicio:** Extiende el `Protocol` para aceptar un `tracer: Callable[[str, float, float, int|None], None] | None`. Implementa en `FakeHttpClient` y `RealHttpClient`. En tests, inyecta un tracer que acumule llamadas y verifica que captura `url`, duración y `status`.

#### 10) Validación de esquema mínima

**Contexto:** `malformed_payload` existe en fixtures.

**Ejercicio:** Implementa un validador ligero para `ratings` (campos: `imDbId: str`, `imDb: str`, etc.). Si el esquema no coincide, retorna `{}` o lanza `ValueError`. Prueba ambas rutas y mide cobertura de ramas.

#### 11) Make y evidencias con hash de commit

**Contexto:** Evidencias deben ser trazables a un commit.

**Ejercicio:** Modifica `make coverage_individual` para exportar a `evidencias/coverage/htmlcov_coverage_pruebas_<gitshort>/`. 
Usa `git rev-parse --short HEAD`. 

#### 12) Simulación de PRs cortos

**Contexto:** Mejor integrar en incrementos.

**Ejercicio:** Simula tres PRs locales (ramas `feature/di`, `feature/policies`, `feature/resilience`), ejecuta `make gates` en cada merge a `develop` y  conserva bitácoras por PR en `evidencias/bitacoras/PRx.md` (incluye logs redaccionados y salida de cobertura).

#### 13) Latencia y presupuesto de tiempo

**Contexto:** `FakeHttpClient` puede introducir `delay_ms`.

**Ejercicio:** Crea un test que establezca `HTTP_TIMEOUT=0.05` y `delay_ms=80`. Verifica que se lanza `TimeoutError` y que el tracer registra una duración ≥ timeout. Restablece ENV al final del test.

#### 14) Idempotencia de `make run`

**Contexto:** `run` no idempotente puede contaminar diagnósticos.

**Ejercicio:** Implementa un lockfile `.run.lock` con `trap` de limpieza. Prueba que dos `make run` concurrentes no sobrescriben `out/` y que el segundo termina con código de salida distinto de 0 con mensaje claro.


#### 15) Variación de `TIMEOUT` por entorno

**Contexto:** Política operable por ENV (12-Factor III).

**Ejercicio:** Escribe un test parametrizado que setee `HTTP_TIMEOUT` a `0.1`, `1.0`, `3.5` y verifique que `self.http.get(..., timeout=TIMEOUT)` refleja el valor en cada ejecución (usa `capsys` o un tracer para inspección).

#### 16) Allowlist dinámica

**Contexto:** A veces necesitas permitir un host temporal en laboratorio.

**Ejercicio:** Añade `HTTP_ALLOWLIST=imdb-api.com,api.themoviedb.org` y ajusta la política para leerla. Tests: lista vacía (usa default), lista con host inválido y con espacios. Verifica normalización.


#### 17) "Pruebas sin red" como contrato

**Contexto:** El propósito es que **nada** toque la red.

**Ejercicio:** Crea un test de integración que falla si `requests.get` es llamado (parchea y asegura `assert_not_called()`), usando únicamente `FakeHttpClient`. Incluye este test en la ruta de `gates`.



#### 18) Evidencias de trazas y cobertura

**Contexto:** Auditoría académica y reproducibilidad.

**Ejercicio:** Publica en `evidencias/`:

* Captura de `pytest -q -ra` con resumen de xfails/skips,
* Carpeta de cobertura con hash de commit,
* Muestra de logs redaccionados y **no** redaccionados (para comparar),
* Mini bitácora con tiempos de cada fase (`dns/tls/http` si aplicaste el tracer por etapas).



#### 19) Revisión de mensajes de error

**Contexto:** Mensajes confusos dificultan depuración.

**Ejercicio:** Asegura que las excepciones levantadas por políticas incluyan la **URL** y la **causa** (por ejemplo, "HTTPS requerido"). Agrega tests que validen substrings clave del mensaje.


#### 20) Política de subprocesos (opcional)

**Contexto:** Algunos alumnos usarán llamadas concurrentes.

**Ejercicio:** Ejecuta dos consultas IMDb en paralelo con `ThreadPoolExecutor` y `FakeHttpClient(delay_ms=20)`. Verifica que el tracer registra dos entradas y que la política de timeout se aplica por llamada, no global.



#### 21) Modo "solo validación" (dry-run)

**Contexto:** Queremos validar políticas sin ejecutar la llamada real.

**Ejercicio:** Añade un flag de entorno `HTTP_DRY_RUN=1` que hace que `RealHttpClient.get_json` valide políticas y retorne un stub mínimo (`{"dryRun": true}`) sin tocar red. Testea que `requests.get` **no** se invoca y que las políticas siguen aplicando.



#### 22) Contrato estable para `errorMessage`

**Contexto:** La API puede retornar `200` con `errorMessage`.

**Ejercicio:** Define que **cualquier** `errorMessage` no vacío resulte en `{}` (o excepción). Agrega tests con fixture que contiene `errorMessage: "Invalid API Key"` y verifica la rama.


#### 23) Métrica por endpoint

**Contexto:** Observabilidad mínima.

**Ejercicio:** Con el tracer, construye un CSV en `out/metrics.csv` con columnas `endpoint,status,duration_ms`. Prueba que al menos tres llamadas (search, ratings, malformed) producen filas con status adecuado y duración > 0.


#### 24) Documentación mínima de contrato

**Contexto:** Evaluador necesita saber qué esperar.

**Ejercicio:** En `docs/contratos.md` (texto corto), enumera: formatos de URL, política de allowlist/HTTPS/timeout, comportamiento ante `errorMessage`, dry-run y trazador. Añade un test que verifique que el archivo existe y no está vacío (sanity check de entrega).

### Entregable

En tu repositorio personal, sube la carpeta **`Actividad10-CC3S2/`** con **los 24 ejercicios implementados y probados**. Incluye código, pruebas y evidencias reproducibles.

```
Actividad10-CC3S2/
  src/
    models/imdb.py                                # E01, E02, E03, E07, E10, E19, E21, E22
    servicios/
      http_abstraction.py                         # E09, E11
      real_http.py                                # E05, E08, E09, E19, E21
      fake_http.py                                # E03, E06, E07, E09, E13, E17, E20
      backoff.py                                  # E04
  tests/
    test_e01_unificacion_clase_imdbservice.py     # E01
    test_e02_asserts_timeout_kwarg.py             # E02
    test_e03_di_con_fakeclient_sin_red.py         # E03
    test_e04_backoff_jitter_seeded.py             # E04
    test_e05_http_error_mapping.py                # E05
    test_e06_log_redaction_precision.py           # E06
    test_e07_payload_edges_branches.py            # E07
    test_e08_https_only_y_subdominios.py          # E08
    test_e09_tracer_hook_metrica_basica.py        # E09
    test_e10_schema_validation_ratings.py         # E10
    test_e11_legacy_patch_compat.py               # E11
    test_e12_coverage_gate_en_gates.py            # E12
    test_e13_time_budget_timeout_latencia.py      # E13
    test_e14_idempotencia_make_run_lock.py        # E14
    test_e15_timeout_variaciones_parametrizado.py # E15
    test_e16_allowlist_dinamica_env.py            # E16
    test_e17_no_network_contract_global.py        # E17
    test_e18_evidencias_reportes_existencia.py    # E18
    test_e19_mensajes_error_con_contexto.py       # E19
    test_e20_threadpool_timeout_por_llamada.py    # E20
    test_e21_dry_run_valida_politicas_sin_red.py  # E21
    test_e22_error_message_contrato_estable.py    # E22
    test_e23_metrics_csv_generacion.py            # E23
    test_e24_docs_contratos_sanity.py             # E24
  Actividades/
    pruebas_fixtures/
      conftest.py                                 # E06 (redacción), fixtures, logging
      fixtures/imdb_responses.json                # E03, E07, E10, E22, E23
    mocking_objetos/
      models/imdb.py                              # E01 (si reexportas/mantienes ruta única)
  docs/
    contratos.md                                  # E24 (contrato: URLs, políticas, errorMessage, tracer, dry-run)
    bitacoras/
      PR1.md                                      # E12 (gates por "PR" simulado)
      PR2.md
      PR3.md
  evidencias/
    coverage/
      htmlcov_coverage_pruebas_<gitshort>/        # E12, E18
    logs/
      app_redacted.log                            # E06, E18
      app_raw_sample.log                          # E06, E18
  out/
    metrics.csv                                    # E23
  pytest.ini                                       # E12 (cov-fail-under=85)
  Makefile                                         # E12, E14 (gates y run con lockfile)
  README.md                                        # Instrucciones mínimas de ejecución
```

**Requisitos operativos del envío**

* Suite **sin red** con DI/Fakes; compatibilidad con `@patch` donde aplique.
* **Políticas** por entorno: `HTTP_TIMEOUT`, `HTTP_ALLOWLIST`, `HTTP_DRY_RUN=1`; **HTTPS-only** y allowlist activas; errores con **URL + causa**.
* **Cobertura ≥ 85%** como **gate** en `pytest.ini` y encadenada en `make gates`.
* **Observabilidad**: tracer y **`out/metrics.csv`**; logs con **redacción de secretos**.
* **Trazabilidad**: carpeta de cobertura con **`<gitshort>`**, bitácoras `PR*.md`, y `docs/contratos.md` no vacío.

**Ejecución esperada**

* `make test` (suite completa)
* `make gates` (lint + cobertura con umbral)
* `HTTP_TIMEOUT=0.5 make test` (variaciones)

Entrega únicamente la carpeta **`Actividad10-CC3S2/`** con lo anterior y **los 24 tests `test_eXX_*.py` pasando**.
