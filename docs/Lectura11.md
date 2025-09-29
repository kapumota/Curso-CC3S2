### Ejecución de pruebas con pytest

La ejecución con `pytest` parte de convenciones simples: archivos `test_*.py`, clases `Test*` y funciones `test_*`. Para integrarlo en DevSecOps, se estandarizan comandos (típicamente encapsulados en un Makefile o *workflow* CI):

* `pytest -q` para salidas compactas y reproducibles.
* `pytest -vv` para máxima verbosidad y explicación de parametrizaciones.
* `pytest -k "expresión"` para ejecutar subconjuntos (por nombre, etiqueta o patrón).
* `-x` y `--maxfail=1` favorecen el ciclo RGR (Red-Green-Refactor) al cortar en el primer fallo.
* `-ra` resume *skips*, *xfail* y causas, útil para vigilancia de deuda técnica.

En pipelines DevSecOps, el *job* de pruebas puede incluir **gates** (umbral de cobertura, conteo de `xfail` tolerados, ausencia de *print* con secretos) y **matrices** (sistemas operativos, versiones de Python, *feature flags*). Aislar red real, reloj y disco es esencial: idealmente, una suite unitaria no realiza IO salvo en pruebas de integración controladas.

### Aserciones

Las aserciones de `pytest` son legibles: `assert expr`. El *assertion rewriting* muestra *diffs* ricos en estructuras. En seguridad y confiabilidad conviene afirmar:

* Códigos de estado y *timeouts*: `assert 200 <= resp.status_code < 300` y `assert kwargs["timeout"] <= 2`.
* Cabeceras seguras: `Strict-Transport-Security`, `Content-Security-Policy`, `X-Content-Type-Options`.
* Invariantes de formatos sensibles: API keys, IDs, UUIDs, *slugs*.
* Comportamientos ante errores: que no se filtren secretos en *tracebacks* ni en *logs*.

Las aserciones deben ser específicas y separadas por intención (autenticación, autorización, validación de entradas, manejo de errores, observabilidad), para que un fallo indique con precisión la clase de riesgo.

### Datos de prueba

Los datos de prueba deben ser **deterministas y representativos**. Además de *happy path*, incluir **casos hostiles**: entradas Unicode complejas, *payloads* con inyección, rutas con `../`, JSON profundamente anidados, límites de tamaño y valores fuera de rango. Es común modelarlos como *fixtures* que devuelven diccionarios, rutas (`tmp_path`), estructuras de directorio o *payloads* JSON. Para redes y criptografía se prefieren **dobles de prueba** (mocks/stubs/fakes) y **relojes falsos** para reproducibilidad.

###  Código de cobertura

La cobertura (con `coverage.py` y `pytest-cov`) sirve como indicador de **alcance**. Sugerencias:

* `pytest --cov=mi_paquete --cov-report=term-missing:skip-covered --cov-fail-under=85`.
* Prestar atención a **ramas de error y de seguridad** (validaciones, *fallbacks*, *circuit breakers*).
* Reporte HTML publicado como artefacto de CI.
* Métrica separada de **cobertura de módulos sensibles** (`auth`, `security`, `crypto`, *middleware*).

###  Mocks vs Stubs

**Stubs** devuelven respuestas prefabricadas sin verificar interacciones; **mocks** permiten inspeccionar llamadas, argumentos y orden. En fronteras con red, reloj, disco o criptografía, los mocks ayudan a afirmar que el código **cumple contratos de uso** (URL, *params*, *headers*, `timeout`, *retries*). Un stub basta si solo importa el *payload*; un mock es imprescindible si necesitas asegurar el **cómo** se invoca una dependencia. En un cliente HTTP estilo "IMDb", por ejemplo, `@patch("models.imdb.requests.get")` permite simular `200`, `404`, `500`, *timeout* y validar cabeceras o tiempo de espera.

###  Factory & fakes mocking

Las **factories** crean objetos válidos por defecto, con sobreescritura selectiva de campos; reducen repetición y hacen explícitas variantes (válida/ inválida/ límite). Los **fakes** implementan una versión minimalista pero útil (p. ej., *FakeCache* en memoria con TTL, *FakeClock* con `now()` controlable, *FakeKMS* que simula cifrado). En DevSecOps, fakes de **proveedores de secretos** o **servicios de identidad** permiten validar *flows* (renovación de tokens, *scopes*, *refresh*) sin tocar sistemas reales.

###  Fixtures: scopes, anidación, reutilización y autouse

`@pytest.fixture` encapsula preparación y limpieza. **Scopes**:

* `function` (por defecto): máximo aislamiento.
* `class`: comparte estado entre métodos de una clase.
* `module`: una instancia por archivo; útil para *setup* mediano.
* `session`: una por sesión; perfecto para levantar *containers* efímeros.

La **composición** de *fixtures* habilita entornos realistas: *tmp dirs* + *fake configs* + `monkeypatch` de variables sensibles. **Autouse fixtures** imponen reglas globales: bloquear red real, fijar `PYTHONHASHSEED`, subir nivel de *logging*, forzar *CA bundles* estrictos. En DevSecOps, un *autouse* puede **impedir egress** accidental y forzar que todas las salidas a red pasen por un cliente inyectable.

###  Stubs de binarios/comandos de sistema

Si el código invoca `curl`, `openssl`, `dig` u otros binarios, las pruebas **no deben depender** del sistema. Dos patrones:

1. **Mock de `subprocess.run`** devolviendo un objeto con `stdout`, `stderr`, `returncode`.
2. **Sombrear el PATH**: crear *scripts* stub (p. ej., `tmp_path/"bin"/"curl"`) que impriman salidas controladas; luego `monkeypatch.setenv("PATH", str(bin_dir), prepend=True)`.

Con esto se simulan éxitos, fallos, *timeouts*, y se verifica que el programa pase **flags de seguridad** (por ejemplo, `--tlsv1.3`, `--cacert`, `--fail-with-body`).

###  Parametrización y `monkeypatch`

`@pytest.mark.parametrize` explora combinaciones de entradas y políticas (cabeceras obligatorias, *feature flags*, variantes de *timeouts*). `monkeypatch` cambia entorno o atributos en tiempo de prueba:

* `monkeypatch.setenv("ENV", "production")` y `monkeypatch.setenv("STRICT_SSL", "1")` para ramas endurecidas.
* `monkeypatch.setattr(modulo, "func", sustituto)` para fijar reloj, generadores de IDs o proveedores de datos.

Ambos reducen duplicación y cubren matices sin comprometer aislamiento.

### Patching: `patch.object`, `patch.dict`, `monkeypatch.setenv`

**`patch.object`** sustituye atributos de objetos o módulos vivos, ideal para forzar fallos o desviar rutas (por ejemplo, `os.path.exists`, o `Session.get` de un cliente HTTP). **`patch.dict`** cambia *dicts* como `os.environ`, y **`monkeypatch.setenv`** ofrece una interfaz idiomática en pytest. Pruebas tipo `test_patch_object_on_os_path`, `test_patch_dict_env` y `test_monkeypatch_setenv` confirman que el código **lee configuración 12-Factor** y reacciona con seguridad (timeouts estrictos, verificación de certificados, políticas de *retries* y *backoff*).

###  Autospec / `create_autospec`

`create_autospec` genera mocks que **respetan la firma** del objeto real; invocaciones con parámetros incorrectos fallan. Esto evita **derivas de contrato** en módulos críticos (auth, crypto, HTTP). `autospec=True` en `patch` ofrece lo mismo. Un test como `test_autospec_restricts_attributes` detecta uso de métodos inexistentes o falta de argumentos obligatorios como `timeout`.

### Inspección de llamadas: `call_args_list`

Al validar seguridad, importa **cómo** se llama: orden, reintentos, cabeceras, *budget* de latencia. `call_args_list` permite asegurar que:

* Tras 401, se refresca token y se reintenta con `Authorization` correcto.
* Cada intento incluye `User-Agent`, `Accept` y `timeout` esperados.
* Se aplican *backoffs* crecientes y se respeta un máximo de intentos.

Un patrón típico: iterar `for call in mock.get.call_args_list:` y asertar invariantes por intento.

### Marcas de pytest: `xfail` y `skip`

`xfail` documenta fallos esperados (bugs/pendientes) sin romper CI; `skip` evita ejecutar en entornos no aplicables (SO, capacidades, flags). Es clave **gobernarlas**: medir recuentos en CI, rechazar *merge* si suben respecto a un *baseline*, y enlazar cada marca a un *issue* con fecha objetivo. `@pytest.mark.skipif(condición, reason="...")` y `@pytest.mark.xfail(condición, reason="...")` hacen explícita la intención.

###  Patching en el ciclo TDD orientado a DevSecOps

TDD (Red-Green-Refactor) se potencia con *patching* para **aislar dependencias** y obtener señales rápidas:

* **Red**: primero la prueba expresa una política de seguridad o contrato observable (por ejemplo, "las búsquedas usan `requests.get` con `timeout ≤ 2`, validación de certificado, y *user-agent* explícito; ante 5xx, reintentos con *backoff* y auditoría sin filtrar
*  secretos").
* **Green**: implementar lo mínimo para pasar, inyectando dependencias (sesiones HTTP, reloj, fuente de aleatoriedad) para facilitar *patch*.
* **Refactor**: limpiar nombres, extraer funciones puras, consolidar *fixtures* y *factories*, fortalecer validaciones y mejorar observabilidad.

En un patrón realista tipo "cliente IMDb", una prueba `@patch("models.imdb.requests.get")` valida ruta, *params*, `timeout`, cabeceras seguras, y mapeos de JSON. Los casos negativos fuerzan `Timeout`, `HTTPError`, `JSONDecodeError` y comprueban errores controlados y *logs* redactados.


### Patching en *middlewares* de seguridad (WSGI/ASGI) y fallos criptográficos

Validar que *middlewares* agregan cabeceras seguras y manejan errores sin filtrar secretos.

* **WSGI (Flask/Gunicorn)**: *patch* del *middleware* `SecurityHeaders.__call__` para devolver cabeceras `CSP` y `HSTS`, y un caso negativo donde falten para exigir *fallback* seguro.
* **ASGI (Starlette/FastAPI)**: *patch* al método `dispatch` de un *AuthzMiddleware* con `autospec=True` para forzar excepción y verificar que el manejador responde `500` sin mensajes crudos ni secretos en el cuerpo.
* **Criptografía**: *patch* de `ssl.create_default_context`, `jwt.decode` (forzar `InvalidSignatureError`/`ExpiredSignatureError`), y validación de que el servicio responde `401`/`403` y registra auditoría sin filtrar *tokens*.

### Evitar efectos secundarios en *patching* holístico

Cuando se *patchean* varias capas (red, reloj, fs, entorno), conviene centralizarlo en *fixtures* con `yield` y *scopes* adecuados, usar `monkeypatch` para limpieza automática, y un *autouse fixture* "de humo" que compruebe que la red real permanece bloqueada. Regla de oro: *patch* **donde se usa**, no donde se define, para evitar inconsistencias de importación.

### Autospec en APIs REST/gRPC y validación con OpenAPI

* **REST**: `create_autospec(requests.Session, instance=True)` para obligar a incluir `timeout`, `headers`, `json`. Validar respuestas mock contra el **esquema OpenAPI** (por ejemplo, con un validador) como *oracle* de contrato.
* **gRPC**: `create_autospec(MyServiceStub, instance=True)` para verificar métodos, *metadata* y *deadlines*. El contrato proviene de los *protos*; en TDD, una prueba roja primero compara una respuesta inválida contra el esquema.

### Inspección de flujos asíncronos (aiohttp/HTTPX) y colas de mensajes

* **Async HTTP**: *patch* de `AsyncClient.get` para simular `Timeout` y luego `200`, verificar *retries*, `call_args_list` y `timeout`.
* **Colas (RabbitMQ/Kafka/SQS)**: *autospec* de productores/consumidores para aserciones de `ack/nack`, *dead-letter*, orden y **idempotency key** en *headers*. Inspeccionar secuencias con `call_args_list` y validar políticas de reintentos.

### Automatizar la revisión de marcas (xfail/skip)

Un pequeño *script* en CI puede ejecutar `pytest -q -ra`, **parsear el resumen** y comparar los recuentos con un *baseline*. Si aumentan `xfail` o `skip` sin justificación, fallar el *job* y generar enlaces a *issues*. Uso de `skipif` **dinámico**: capacidades del entorno (SO, disponibilidad de emuladores como Localstack), flags de características, o presencia de binarios.

### Ejemplo completo de TDD para microservicio con OAuth2 (Red -> Green -> Refactor)

**Objetivo:** endpoint `/profile` con *Bearer Token* RS256, *scope* `profile:read`, `timeout` ≤ 2s, *retries* ante 5xx, *logs* redactados.

* **Red**:

  * Pruebas que *patchean* `jwt.decode` (válido -> 200; firma inválida/expirado -> 401).
  * Prueba de *scope* insuficiente -> 403.
  * `@patch("miapp.http.Session.get")` con `500 -> 200` para cubrir *retries*, y aserciones sobre `timeout` y cabeceras seguras.
  * *patch* del logger para verificar **redacción** de `Authorization` en *logs* (ausencia de secretos).

* **Green**: mínima implementación con dependencias inyectables (cliente HTTP, verificador JWT, reloj). Se añaden *middlewares* de seguridad (HSTS, CSP), validadores de entrada y *métricas* (latencia, reintentos).

* **Refactor**: extracción de funciones puras (validación de *scopes*, construcción de cabeceras), consolidación de *factories* de tokens (válido, caducado, firma incorrecta), y endurecimiento de políticas por entorno (`STRICT_SSL`, `ENV=production`).

**Priorización TDD de seguridad**: empezar por autenticación/autorización, límites/tiempos, integridad/confidencialidad (cabeceras, TLS), idempotencia y reintentos, y finalmente observabilidad/auditoría. Parametrizar matrices de riesgo desde el inicio.

### Matrices de casos recomendadas

* **JWT**: {firma inválida, expirado, `nbf` futuro, `aud` incorrecta, *scope* faltante}.
* **HTTP**: {200, 401, 403, 404, 429, 500} × {retries 0–2} × {timeout 0.5s–2s}.
* **Headers**: presencia/ausencia de HSTS, CSP, X-Content-Type-Options, Referrer-Policy.
* **Colas**: {ack, retry×3, DLQ} × {payload con/sin PII} (verificar redacción en *logs*).
* **Binarios**: `curl` con/sin `--cacert`, `openssl s_client` con/sin `-verify_return_error`.

### Indicadores útiles en CI/CD

* **Cobertura de seguridad** por módulo sensible, no solo cobertura total.
* **Tendencia de marcas** `xfail`/`skip` (tablero histórico).
* **Tiempo hasta verde** por historia de seguridad (para vigilar ciclo RGR).
* **Flakiness**: pruebas asíncronas con reloj falso y *timeouts* amplios en CI; alertas cuando varían.
* **Verificación de contrato**: porcentaje de endpoints validados contra OpenAPI o *protos* gRPC.
* **Auditoría de secretos**: grep en artefactos de *logs* para asegurar redacción.

### Consejos operativos y *tips*

* Usa un **autouse fixture** para comprobar en cada respuesta que cabeceras de seguridad están presentes.
* Para *stubs* de binarios, además de simular salida, **aserta flags** mínimos obligatorios (TLS, compresión, manejo de errores).
* Prefiere `create_autospec` al *mock* "libre" cuando el contrato importa; ayuda a detectar llamadas inválidas en tiempo de prueba.
* Integra la validación de **OpenAPI** al *pipeline*: cada respuesta *mock* o real de prueba debe pasar por el validador.
* Aprovecha `call_args_list` tanto en HTTP síncrono como asíncrono y en **colas** para asegurar orden, conteo y metadatos críticos (correlation-id, idempotency-key).
* Define un `make verify-tests` que ejecute pytest con cobertura, auditor de marcas, detección de secretos en *logs* y genere reportes HTML como artefactos.

