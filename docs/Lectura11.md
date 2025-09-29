### Ejecución de pruebas con pytest

La ejecución con `pytest` parte de convenciones simples: archivos `test_*.py`, clases `Test*` y funciones `test_*`. Para integrarlo en DevSecOps, se estandarizan comandos (típicamente encapsulados en un Makefile o *workflow* CI)

* `pytest -q` para salidas compactas y reproducibles.
* `pytest -vv` para máxima verbosidad y explicación de parametrizaciones.
* `pytest -k "expresión"` para ejecutar subconjuntos (por nombre, etiqueta o patrón).
* `-x` y `--maxfail=1` favorecen el ciclo RGR (Red-Green-Refactor) al cortar en el primer fallo.
* `-ra` resume *skips*, *xfail* y causas, útil para vigilancia de deuda técnica.

En un entorno DevSecOps, estas opciones se combinan con herramientas como GitHub Actions, GitLab CI/CD o Jenkins para automatizar la ejecución de pruebas en cada *commit*, *pull request* o despliegue. Por ejemplo, un *workflow* puede usar `pytest -q` para pruebas rápidas en entornos de desarrollo y `pytest -vv` para generar reportes detallados en auditorías de seguridad. 

La integración con herramientas de análisis estático (como Bandit para Python) y escaneos de vulnerabilidades (como Snyk o Dependabot) complementa las pruebas funcionales, asegurando que el código no solo sea correcto, sino también seguro y robusto.

### Aserciones

Las aserciones de `pytest` son legibles: `assert expr`. El *assertion rewriting* muestra *diffs* ricos en estructuras. En seguridad y confiabilidad conviene afirmar

* Códigos de estado y *timeouts*: `assert 200 <= resp.status_code < 300` y `assert kwargs["timeout"] <= 2`
* Cabeceras seguras: `Strict-Transport-Security`, `Content-Security-Policy`, `X-Content-Type-Options`
* Invariantes de formatos sensibles: API keys, IDs, UUIDs, *slugs*
* Comportamientos ante errores: que no se filtren secretos en *tracebacks* ni en *logs*

Las aserciones deben ser específicas y separadas por intención (autenticación, autorización, validación de entradas, manejo de errores, observabilidad), para que un fallo indique con precisión la clase de riesgo.

**Assertion rewriting**

El *assertion rewriting* es una característica clave de `pytest` que mejora la legibilidad y la depuración de las aserciones. Cuando se ejecuta una aserción como `assert a == b`, `pytest` reescribe el código en tiempo de ejecución para capturar los valores de las expresiones y generar mensajes de error detallados. 

Por ejemplo, si `assert response.json() == expected_dict` falla, `pytest` no solo indica que la aserción falló, sino que muestra una comparación detallada (*diff*) entre los valores reales y esperados, destacando diferencias en estructuras complejas como diccionarios o listas. En DevSecOps, esto es especialmente útil para validar respuestas de APIs, donde un pequeño cambio en un campo puede indicar una vulnerabilidad (por ejemplo, una cabecera de seguridad ausente o un campo expuesto incorrectamente). Para aprovechar al máximo el *assertion rewriting*, se recomienda evitar aserciones genéricas como `assert True` y usar comparaciones explícitas que permitan a `pytest` generar *diffs* útiles.

#### Aserciones en DevSecOps

En el contexto de DevSecOps, las aserciones no solo verifican la funcionalidad, sino que también garantizan la seguridad y la robustez del sistema. Por ejemplo, al probar una API, se pueden incluir aserciones para verificar que las respuestas no exponen información sensible (como tokens en encabezados o datos de usuarios en errores). También se pueden usar aserciones para validar que el sistema respeta políticas de seguridad, como tiempos de espera estrictos (`timeout`) o configuraciones de CORS correctas. 

La granularidad en las aserciones es crucial: en lugar de una sola aserción que valide una respuesta completa, se deben usar múltiples aserciones para verificar aspectos específicos (por ejemplo, `assert "Content-Security-Policy" in response.headers` y `assert response.headers["Content-Security-Policy"] == "default-src 'self'"`). Esto facilita la trazabilidad de fallos y reduce el riesgo de pasar por alto vulnerabilidades.

### Datos de prueba

Los datos de prueba deben ser **deterministas y representativos**. Además de *happy path*, incluir **casos hostiles**: entradas Unicode complejas, *payloads* con inyección, rutas con `../`, JSON profundamente anidados, límites de tamaño y valores fuera de rango. Es común modelarlos como *fixtures* que devuelven diccionarios, rutas (`tmp_path`), estructuras de directorio o *payloads* JSON. Para redes y criptografía se prefieren **dobles de prueba** (mocks/stubs/fakes) y **relojes falsos** para reproducibilidad.

**Happy path**

El *happy path* (camino feliz) se refiere a los casos de prueba que verifican el comportamiento esperado del sistema bajo condiciones ideales, es decir, cuando todas las entradas son válidas y el sistema funciona correctamente. Por ejemplo, en una API de autenticación, el *happy path* incluiría un caso donde un usuario proporciona credenciales correctas y recibe un token de acceso válido con un código de estado 200. En DevSecOps, los casos de *happy path* son esenciales para garantizar que el sistema cumple con los requisitos funcionales, pero no son suficientes. 
Deben complementarse con casos de borde y pruebas de seguridad que simulen ataques o condiciones anómalas. Por ejemplo, un caso de *happy path* podría ser `assert login("user", "valid_password") == {"token": "abc123"}`, mientras que un caso hostil probaría `assert login("user", "'; DROP TABLE users;") raises InvalidCredentials`.

**Datos de prueba en DevSecOps**

Los datos de prueba en un entorno DevSecOps deben ser cuidadosamente diseñados para cubrir tanto el *happy path* como escenarios de ataque. Esto incluye

* **Entradas maliciosas**: Probar inyecciones SQL, XSS, o comandos en entradas de usuario (por ejemplo, `<script>alert('xss')</script>` o `; rm -rf /`).
* **Casos de borde**: Valores nulos, cadenas vacías, números extremadamente grandes o negativos, y estructuras JSON malformadas.
* **Datos representativos**: Simular datos reales que el sistema manejará en producción, como nombres con caracteres internacionales (Unicode), direcciones complejas o payloads de gran tamaño.
* **Datos sensibles**: Verificar que el sistema no expone información como claves API, contraseñas o datos personales en respuestas o logs.

Las *fixtures* de `pytest` son ideales para gestionar datos de prueba. Por ejemplo, una *fixture* puede generar un diccionario con datos válidos para el *happy path* y otro con datos maliciosos para pruebas de seguridad. Ejemplo

```python
import pytest

@pytest.fixture
def valid_user():
    return {"username": "testuser", "password": "secure123"}

@pytest.fixture
def malicious_user():
    return {"username": "testuser; DROP TABLE users;", "password": "<script>alert('xss')</script>"}
```

Estas *fixtures* permiten reutilizar datos de prueba consistentes y deterministas en múltiples pruebas, mejorando la mantenibilidad y la reproducibilidad.

**Dobles de prueba y relojes falsos**

Los **dobles de prueba** (mocks, stubs, fakes) son objetos simulados que reemplazan dependencias externas, como bases de datos, APIs o servicios de red, para aislar el código bajo prueba. En DevSecOps, los dobles son cruciales para probar escenarios de red o criptografía sin depender de sistemas externos, lo que garantiza pruebas rápidas y deterministas. Por ejemplo, un *mock* puede simular una respuesta de una API externa con un código de estado 503 para probar el manejo de errores.

Los **relojes falsos** (*fake clocks*) se utilizan para controlar el tiempo en las pruebas, especialmente en sistemas que dependen de timestamps, como tokens JWT o verificaciones de expiración. Por ejemplo, la librería `freezegun` permite simular fechas específicas

```python
from freezegun import freeze_time
import datetime

def test_token_expiration():
    with freeze_time("2025-01-01"):
        token = generate_token()
        assert token.expires_at == datetime.datetime(2025, 1, 1, 0, 30)
```

En DevSecOps, los relojes falsos son esenciales para probar escenarios de seguridad relacionados con el tiempo, como la expiración de sesiones, la rotación de claves o la validación de certificados. Por ejemplo, se puede simular un tiempo futuro para verificar que un token ha expirado y que el sistema lo rechaza correctamente, evitando vulnerabilidades como el uso de tokens caducados.

**Relojes falsos en DevSecOps**

En un contexto de seguridad, los relojes falsos también ayudan a probar la robustez de sistemas ante manipulaciones temporales. Por ejemplo, un atacante podría intentar manipular el tiempo del sistema para explotar tokens no expirados. Las pruebas con relojes falsos permiten simular estos escenarios y verificar que el sistema responde correctamente. 

Además, los relojes falsos aseguran que las pruebas sean reproducibles, ya que el comportamiento no depende del tiempo real del sistema.

### Código de cobertura

La cobertura de código es una métrica clave en el desarrollo de software, ya que permite identificar qué partes del código han sido ejecutadas durante las pruebas automatizadas. Sin embargo, una alta cobertura no garantiza la calidad del software; es crucial complementarla con pruebas bien diseñadas que cubran casos límite, condiciones excepcionales y flujos críticos.

- **Uso de `coverage.py` y `pytest-cov`:** Estas herramientas son ampliamente utilizadas en Python para medir la cobertura de pruebas unitarias, de integración y funcionales. La opción `--cov-report=term-missing:skip-covered` genera un reporte en consola que omite los módulos completamente cubiertos, destacando solo las áreas con líneas no probadas. La bandera `--cov-fail-under=85` establece un umbral mínimo de cobertura del 85%, fallando el proceso si no se alcanza.

- **Ramas de error y seguridad:** Es fundamental incluir pruebas que validen el manejo de errores (excepciones, entradas inválidas) y aspectos de seguridad, como la gestión de sesiones en módulos de autenticación (`auth`), el uso seguro de algoritmos en `crypto` o la protección contra ataques en *middleware*. Los *fallbacks* (mecanismos de recuperación ante fallos) y *circuit breakers* (para evitar fallos en cascada en sistemas distribuidos) deben estar cubiertos por pruebas específicas para garantizar la robustez del sistema.

- **Reporte HTML en CI:** Publicar el reporte HTML generado por `coverage.py` como un artefacto en pipelines de integración continua (CI), como GitHub Actions o Jenkins, permite a los equipos visualizar fácilmente las áreas de código no probadas. Esto fomenta la colaboración y mejora la trazabilidad durante las revisiones de código.

- **Módulos sensibles y DevSecOps:** Los módulos relacionados con seguridad (`auth`, `security`, `crypto`, *middleware*) requieren un enfoque especial en un entorno DevSecOps. Esto implica no solo medir la cobertura, sino también realizar análisis estáticos de código, pruebas de penetración y auditorías de seguridad. Una métrica separada para estos módulos ayuda a priorizar su calidad, ya que un fallo en ellos puede tener consecuencias críticas, como brechas de seguridad o pérdida de datos.

La cobertura (con `coverage.py` y `pytest-cov`) sirve como indicador de **alcance**. 


**Información adicional:**
- **Recomendaciones adicionales:**
  - **Integración con herramientas de análisis estático:** Combinar la cobertura con herramientas como `bandit` para detectar vulnerabilidades de seguridad en el código Python.
  - **Pruebas de mutación:** Utilizar herramientas como `mutmut` o `cosmic-ray` para evaluar la efectividad de las pruebas, identificando si detectan cambios (mutaciones) en el código.
  - **Automatización en CI/CD:** Configurar pipelines para que fallen automáticamente si la cobertura cae por debajo del umbral establecido o si los módulos sensibles no alcanzan una cobertura del 100%.
  - **Monitoreo continuo:** Usar dashboards (por ejemplo, en SonarQube) para rastrear la evolución de la cobertura y correlacionarla con métricas de calidad como la densidad de defectos.

Este enfoque integral no solo mejora la cobertura de código, sino que también fortalece la seguridad y la calidad del software en un contexto DevSecOps, alineándose con las mejores prácticas de desarrollo moderno.

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

