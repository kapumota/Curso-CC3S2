## Pruebas avanzadas con pytest, DI y DevSecOps 

> El reporte se basa en el ejemplo dado en clases: [Ejemplo de mocks-SOLID](https://github.com/kapumota/Curso-CC3S2/tree/main/ejemplos/Ejemplo_mocks_SOLID)

### Introducción y contexto operativo

El proyecto que analizamos define un servicio de negocio minimalista que consulta un endpoint externo y lo hace cumpliendo políticas de DevSecOps como allowlist de hosts y timeouts configurables por variables de entorno.
La estructura modular incluye un puerto de abstracción `HttpPort`, un servicio `MovieService` que depende de ese puerto, dos adaptadores HTTP que lo implementan y una ruta de entrada que levanta el servicio con un cliente falso para ejecución determinista. 

El contrato del puerto queda establecido en `ports.py` con un protocolo typing que exige un método `get_json` que devuelve datos serializadosa partir de una URL, lo que elimina el acoplamiento directo del dominio con una librería de red particular .

El servicio delega la obtención de datos a su dependencia inyectada y expone un método `status` que interroga un endpoint fijo. Esto se ve en `service.py` donde el constructor recibe una instancia que cumple el puerto y la guarda como campo, mientras que `status` delega a `http.get_json` con la URL de estado del sistema . La ejecución por línea de comandos muestra un composition root educado en `main.py`: crea un `FakeHttpClient` con fixtures predecibles, compone un `MovieService` y imprime el resultado para inspección en pruebas o en uso interactivo, lo que permite correr sin red y con salidas deterministas en stdout .

Del lado de infraestructura de pruebas y gates DevSecOps, el Makefile recibido orquesta tareas de `lint`, `coverage`, `security`, `semgrep` y `pre-commit`, y concentra los gates en el target `gates`, que corre lint y coverage con umbral mínimo definido en `COV_MIN` igual a 85. 

Esto genera una presión sana por mantener calidad estática y dinámica, y es coherente con prácticas que impiden avanzar un build si la cobertura cae por debajo del mínimo o si el estilo presenta errores. También observamos un `env-check` que verifica que las herramientas estén disponibles en el PATH del entorno virtual activo, y un target `pack` reproducible con tar ordenado, metadatos normalizados y suma SHA-256.

### 1. Mocks vs Stubs

En el proyecto aparecen claramente ambos conceptos:

* **Stub**. Un stub es un doble de prueba de respuesta fija. En `test_clients.py`, el test `test_stub_respuesta_fija` crea un objeto `Mock` y solo le configura qué devolverán `status_code` y `json` para simular una respuesta HTTP. No le exige comportamiento dinámico, ni validaciones sobre cómo fue llamado. El foco es la *salida* de `get_json`. El stub permite afirmar que `get_json` traduce correctamente el resultado a un diccionario con `{"ok": True}` sin tocar la red .

* **Mock**. Un mock, además de simular respuestas, verifica *interacciones*. El test `test_mock_verifica_interaccion` comprueba que `get_json` invoca a `http.get` exactamente una vez, con la URL esperada y el timeout de 2.0. Esto valida contrato de interacción y política de timeout en una sola pasada. La aserción `assert_called_once_with` capta regresiones en parámetros o en el orden de llamadas .

En la capa de adaptadores con `requests`, aparece otro estilo de stub ad hoc. `test_adapters_secure_client.py` usa `monkeypatch` para interceptar `requests.get` y sustituirlo por una función `fake_get` que devuelve un `DummyResp` con `raise_for_status` y `json`. 

Aquí se simula el cliente real a un nivel más bajo, y además se afirma sobre el timeout y la URL exacta, reforzando la política del adapter "seguro" frente a la API. 
El doble `DummyResp` se comporta como una mínima implementación del contrato de `requests.Response` para lo que necesitamos en la prueba  .

Un tercer ejemplo es `FakeHttpClient`, que no verifica interacciones y devuelve desde un diccionario de fixtures indexado por URL. Es un stub clásico que hace trivial probar `MovieService` sin red y sin `requests` .

### 2. Factory y fakes en mocking

El patrón **Fake** aparece codificado en `FakeHttpClient`. Este fake cumple la interfaz `HttpPort` y permite preparar fácilmente escenarios desde pares URL -> payload, algo ideal para tests funcionales a nivel de servicio. 
La prueba `test_service_usa_fake_con_fixtures` inyecta el fake al servicio y afirma el diccionario devolviendo exactamente lo preparado, haciendo evidente el aislamiento de red, la repetibilidad y la velocidad de ejecución .

Una **factory** explícita no se implementa, aunque el propio comentario en `service.py` deja abierta la idea de introducir una `httpFactory`  con protocolo, que produciría un `HttpPort` según entorno y política. 
Esa ampliación encaja cuando el composition root necesita "fabricar" adaptadores distintos por configuración, sin cambiar la firma del servicio. El comentario ilustra el diseño deseado y muestra intención de evolución hacia una DI más flexible .

En `clients.py`, la función `get_json` recibe por defecto el módulo `requests`, pero permite inyectar otro objeto compatible vía parámetro `http`. 
Esto es una forma ligera de factoría a través del parámetro, que permite inyectar un mock o un stub de cliente HTTP sin reescribir el cuerpo de `get_json`. 

La política de seguridad se expresa con `_check_allowlist` y el timeout tomado de la variable de entorno `HTTP_TIMEOUT`, lo que permite que los dobles respeten la misma superficie de contrato y que las pruebas puedan mutar el entorno con `monkeypatch.setenv` si hiciera falta  .

### 3. Fixtures de pytest

#### `@pytest.fixture` y scopes

Aunque el código de prueba no define fixtures explícitas con `@pytest.fixture`, la estructura sugiere puntos claros para crearlas. 
Por ejemplo, un fixture `fixtures_status_ok` podría devolver el diccionario `{"https://api.ejemplo.com/status": {"ok": True}}` que usan varias pruebas. 
Su **scope** sería `function` si queremos aislamiento absoluto, o `module` si su creación es cara y queremos reutilizarlo entre tests del mismo archivo.

El fixture para un `FakeHttpClient` listo para usar también es natural. Un `@pytest.fixture(scope="function")` que instancie `FakeHttpClient` con las fixtures y lo devuelva reduciría duplicación y haría más expresivos los tests de `MovieService` y del `main`.

Para pruebas que verdaderamente simulen recursos costosos o configuraciones comunes, `scope="session"` permite inicializar una sola vezpor corrida y compartirlo con todos los módulos.

### Fixtures anidadas y reutilización

La composición de fixtures hace evidente la separación de responsabilidades. Uno entrega datos de ejemplo, otro arma el cliente fake y  otro arma el servicio. 

Con esto, un test puede recibir el servicio ya listo, mientras otro se queda en el nivel del cliente si lo necesita.
En el proyecto, la composición real se ve en `main.py`, donde se "anidan" responsabilidades en tres pasosequilibrados: construir fixtures, crear el `FakeHttpClient` y construir el `MovieService` para luego imprimir el resultado. 

Ese patrón es equivalente a una cadena de fixtures explícitas en pytest, solo que aquí vive en el **composition root** de ejecución .

### Autouse fixtures

Los checks de entorno que hace el Makefile podrían migrarse a fixtures `autouse` para validar precondiciones al inicio de cada módulo de tests. Por ejemplo, un autouse que verifique `HTTP_TIMEOUT` o que limpie variables de entorno antes de cada prueba encaja con la idea de "gates" previos a la ejecución.

### 4. Stubs de binarios y comandos de sistema

El patrón de stubear binarios del sistema es fundamental en pipelines DevSecOps donde corremos `curl`, `dig` o `nc`. 
Aquí el proyecto no invoca binarios externos, pero el mismo enfoque usado con `requests.get` se aplica a `subprocess.run` o a un wrapper propio.

Los pasos son:

* Extraer llamadas a binarios a una función o puerto que podamos interceptar.
* Inyectar esa dependencia en el servicio o función.
* En pruebas, sustituirla por un stub que devuelva stdout y códigos de salida prefabricados.

El test de `SecureRequestsClient` muestra el método con `monkeypatch` directo sobre la función de librería que ejecuta la acción externa. Para binarios, haríamos `monkeypatch.setattr(subprocess, "run", fake_run)` y devolveríamos un objeto con campos `returncode`, `stdout` y `stderr`, análogo a `DummyResp` en el adapter de red .

### 5. Parametrización y `monkeypatch`

#### `@pytest.mark.parametrize` con `monkeypatch`

La parametrización permite cubrir múltiples endpoints y variaciones de entorno sin multiplicar código. Podríamos parametrizar con una tabla de casos sobre URLs permitidas y bloqueadas y con distintos valores
de `HTTP_TIMEOUT`. `monkeypatch.setenv("HTTP_TIMEOUT", "5.0")` haría efectivo el cambio en `TIMEOUT` para el módulo que toma la variable al cargarlo. 
En el adapter "seguro" y en la función `get_json` el timeout proviene de esa variable y se usa al invocar la librería HTTP  .

El ejemplo del test en `test_adapters_secure_client.py` ya usa `monkeypatch.setattr` para interceptar la llamada de red y afirma que el `timeout` pasado es 2.0. 
Este mismo patrón, combinado con parametrización, comprobaría tolerancias y valores degradados por tipo de entorno .

### 6. Patching

### `patch.object` y `test_patch_object_on_os_path`

El patrón se observa, aunque no de manera explícita con `patch.object`, en la prueba que sustituye `requests.get`. 
Se puede extrapolar al sistema de archivos para pruebas puras de lógica, por ejemplo para simular que `os.path.exists` devuelve falso o verdadero según el caso. 
La analogía con el proyecto sería parchear `urllib.parse.urlparse` para validar rutas host inválidas o casos límites . 

El [allowlist](https://jfrog.com/blog/three-approaches-to-strengthening-security-with-allowlists/) se calcula parseando la URL y 
comparando `hostname`, así que parchear ese punto también probaría el tratamiento de entradas malformadas en `_check_allowlist` y en el adapter  .

### `patch.dict` y `monkeypatch.setenv`

Ambos son adecuados para simular configuraciones. La variable `HTTP_TIMEOUT` controla el tiempo de espera. 
Con `patch.dict("os.environ", {"HTTP_TIMEOUT": "0.1"}, clear=False)` o con `monkeypatch.setenv("HTTP_TIMEOUT", "0.1")` podemos observar que el adapter utilice ese valor.
En `SecureRequestsClient` el timeout se resuelve al módulo import time, lo que sugiere recargar el módulo si queremos que el cambio tenga efecto, o bien leer la variable más tarde. 

A nivel de función `get_json`, el timeout se consulta del módulo y se pasa al cliente inyectado. Ambas rutas se benefician de las técnicas de parcheo según el punto donde se evalúa la variable  .

### 7. Autospec y `create_autospec`

En `test_clients.py` se usa `Mock` genérico, pero en escenarios con APIs más ricas conviene restringir atributos para evitar falsos positivos. 
Con `create_autospec` podríamos construir un doble que solo permita atributos existentes de `requests`, por ejemplo `get`, y que falle si accedemos a uno inexistente. 
Esto endurece la prueba y previene errores sutiles. El patrón sería `http = create_autospec(requests)`, configurar `http.get.return_value` y luego afirmar interacciones como se hace en la prueba actual que exige `timeout=2.0` .

### 8. Inspección de llamadas con `call_args_list`

Además de `assert_called_once_with`, a veces necesitamos ver *todas* las invocaciones, especialmente en flujos que reintentan con **backoff**. 
La lista `call_args_list` del mock revela la secuencia de parámetros. Tras ejecutar una función que realiza varias llamadas, podríamos inspeccionar cada tupla para asegurar que primero se llamó al endpoint de *status*, luego al de *ratings*, o que los tiempos entre reintentos crecieron según política. 

El diseño actual consulta un solo endpoint, pero si `MovieService` creciera para encadenar `status`, `movie_reviews` y `movie_ratings`, `call_args_list` sería clave para validar orden y parámetros sin tocar la red. 
Hoy se valida una única llamada con los parámetros exactos, lo que ya establece la base de inspección de interacción .

### 9. Marcas de pytest: `xfail` y `skip`

En pipelines orientados a gates, `xfail` documenta deudas técnicas conocidas o comportamientos no soportados en determinados entornos, mientras que `skip` evita ruido cuando una precondición externa no se cumple. 

En este proyecto podrían emplearse para:

* `xfail` temporal cuando se habilite un host en lista de permitidos y la regla aún no se despliega en producción.
* `skip` si `requests` no está disponible en entornos de ejecución minimalistas, aunque lo ideal es stubear siempre, como ya se hace con `FakeHttpClient` y `monkeypatch`.

Integrar estas marcas con el Makefile garantiza que los gates no fallen por causas controladas y explícitas, manteniendo la **trazabilidad del riesgo**.


### 10. Patching dentro del ciclo TDD

El ciclo TDD Red Verde Refactor se ve en miniatura en la prueba `test_main_prints_status`. Primero escribimos un test que espera que `main` imprima claves y valores que señalan el servicio arriba. Luego implementamos el composition root para que pase usando el fake y fixtures. Finalmente refactorizamos hacia DI clara y política de seguridad en los adaptadores. El test asegura que la salida en stdout contiene indicadores `ok` y `service up`, lo que sirve como contrato observable del CLI de demostración  .

El parcheo con `monkeypatch.setattr` en la capa de red apoya la etapa Roja al simular rápidamente respuestas y errores de `requests`, para después codificar el adapter seguro que además verifica allowlist y timeout. La prueba de allowlist que espera `ValueError` tanto en `clients.get_json` como en `SecureRequestsClient` fija una expectativa de política de seguridad que guía la implementación y evita regresiones futuras  .

### DevSecOps, SOLID, DI y el composition root

#### DIP e inversión de dependencias

El principio **DIP** se aplica de forma directa. `MovieService` depende de la abstracción `HttpPort`, no del detalle `requests`. 
El puerto está definido como `Protocol` con un `get_json` tipado, de modo que cualquier implementación que lo cumpla se puede inyectar sin modificar el dominio. 

Esta capa de dominio no conoce ni decide la librería HTTP, lo que minimiza el acoplamiento y maximiza la testabilidad  .

#### Adaptadores y políticas DevSecOps

El adapter `SecureRequestsClient` codifica dos controles:

* **Allowlist de hosts**. Solo permite `api.ejemplo.com`. Cualquier otro host produce `ValueError`. Esto protege contra SSRF y errores de configuración que apunten a destinos no aprobados, y queda probado en `test_secure_requests_client_allowlist` y también en pruebas de `clients.get_json`   .

* **Timeout configurable**. El tiempo se alimenta por `HTTP_TIMEOUT`, con valor por defecto 2.0, y se pasa a `requests.get`. La prueba del cliente seguro afirma el valor 2.0 en el stub de `fake_get`. Esta práctica evita bloqueos y normaliza latencias bajo estrés, una política típica de seguridad operacional  .

El adapter falso compone el otro extremo del DIP. Provee datos deterministas y permite pruebas puras del dominio sin red, reforzando TDD yendo de rojo a verde con latencia mínima y sin flakiness .

#### Composition root

El **composition root** es el lugar único donde el sistema decide qué implementaciones concretas conectar con las abstracciones del dominio. 
En este proyecto, `main.py` cumple ese rol cuando:

1. Define las **fixtures** de datos de status para la URL conocida.
2. Instancia el **adapter falso** `FakeHttpClient` con esas fixtures.
3. Construye el **servicio** `MovieService` inyectando ese adapter.
4. Ejecuta el caso de uso `status` e imprime la salida para inspección.

En términos de responsabilidades, el *composition root*:

* Orquesta la **selección de implementaciones** de puertos, que puede variar por entorno. En dev o test se usa `FakeHttpClient`. En producción sería natural seleccionar `SecureRequestsClient`. Esta decisión no se entierra en el servicio, se mantiene en el borde de la aplicación para respetar DIP.
* Centraliza la **configuración**. Ahí se resolverían variables de entorno, políticas de timeouts y listas de hosts, incluso creando factorías si la complejidad aumenta.
* Define el **modo de ejecución**. Aquí imprime a stdout, pero podría integrar un CLI o un servidor web que use el servicio. El servicio no se entera del modo de ejecución.

El `main` de ejemplo encapsula un mini composition root que es didáctico y coherente con la arquitectura de puertos y adaptadores. 
El test asociado captura su contrato observable leyendo `stdout` con `capsys`, lo que es una técnica limpia para verificar integración ligera sin mocks de bajo nivel  .

#### Variantes habituales de DI con fixtures

Con pytest, las variantes de DI se expresan en cómo preparamos y suministramos dependencias a las unidades bajo prueba.

* **Constructor-like**. Inyectar por constructor es el patrón que usa `MovieService`, que recibe un `HttpPort` en `__init__`. En tests, construimos `MovieService(FakeHttpClient(fixtures))` para un control completo y explícito  .

* **Setter-like**. El comentario en `service.py` muestra la idea de cambiar la dependencia asignando `svc.http = SecureRequestClient()` en escenarios donde la inyección por constructor no aplica o queremos cambiarla durante el ciclo de vida. No es la forma preferida, pero puede ser útil en integración o demos. La intención aparece registrada en los comentarios del archivo de servicio .

* **Interface-driven**. Con `Protocol` tipado como puerto, cualquier doble de prueba o adapter real que implemente `get_json` es válido. Esta es la forma más alineada con DIP, ya que el dominio nunca ve clases concretas sino capacidades. El contrato está en `ports.py` y el adapter seguro y el fake lo implementan en `adapters.py`   .

* **Proxy-like**. `clients.get_json` actúa como un proxy o wrapper del `requests.get`, añadiendo allowlist y controlando `raise_for_status`. Este estilo permite parchearlo a nivel de función y pasarle un doble por parámetro `http`. Se presta para monkeypatch y autospec en pruebas más estrictas .

* **Factory-like**. Aunque no existe una clase factory formal, el comentario sugiere introducir una `httpFactory` protocolar. En pytest la factory suele expresarse como un fixture que devuelve instancias listas para usar, quizás parametrizado por política de entorno. El patrón reduce duplicación y facilita componer estrategias de red o de fake a gusto .

#### Pruebas de contrato y seguridad en la capa de red

La prueba `test_secure_requests_client_happy_path` define un *fake_get* que asegura que la URL y el timeout son correctos y devuelve un `DummyResp` exitoso. 
Luego ejercita `SecureRequestsClient.get_json` y comprueba que el payload tenga `ok` y que la marca `from` sea `secure-client`. Demuestra cómo validar contrato de interacción y contrato de datos al mismo tiempo sin red ni dependencias externas. 

Este patrón es una base sólida para expandir a otros endpoints, siempre apoyados en la allowlist y en timeouts controlados .

Complementariamente, `test_secure_requests_client_allowlist` asegura que URLs fuera de la allowlist disparan `ValueError`. 
Con ello blindamos la superficie del adapter y forzamos que cualquier función de mayor nivel se atenga a políticas de seguridad de destino. 
Si más adelante el conjunto `ALLOWED_HOSTS` se configurara por entorno, bastará parametrizar la prueba o el fixture que compone el adapter  .

En la ruta alternativa de cliente funcional `clients.get_json`, se impone la misma política a través de `_check_allowlist` que extrae `hostname` con `urllib.parse.urlparse` y compara contra el conjunto de permitidos. 
La prueba `test_allowlist_bloquea_dominios_no_permitidos` lo verifica y evita llamadas a red para hosts maliciosos. 
Este diseño ofrece dos lugares coherentes donde validar la política, uno orientado a clase **adapter** y otro a función **proxy**, ambos alineados con DevSecOps  .

#### Contratos observables y pruebas de entrada por CLI

`test_main_prints_status` ilustra una prueba de contrato observable a través de stdout. Al capturar la salida con `capsys` y buscar claves y valores, garantizamos que la UX mínima del ejecutable presenta señales inequívocas desalud. 
La dependencia real de red no interviene porque `main` arma el sistema con fixtures y `FakeHttpClient`. 

Esta técnica es útil en pipelines donde el contrato de salida de un CLI es insumo de otras etapas automatizadas  .

#### Gates de calidad y reproducibilidad

El Makefile que acompaña el proyecto muestra una integración coherente de pruebas y análisis estático como **gates**:

* `lint` ejecuta `ruff check app tests` y normaliza estilo y hallazgos de calidad en Python.
* `coverage` corre `pytest` con cobertura de `app` y exige un mínimo con `--cov-fail-under` implícito en el umbral `COV_MIN=85`. Esto fuerza a cubrir los caminos críticos como allowlist, timeouts y rutas felices.
* `security` intenta `bandit` recursivo en `app`. Sirve como gate liviano para patrones de inseguridad codificada.
* `semgrep` permite políticas de seguridad y estilo adicionales por reglas locales configuradas en `.semgrep`.
* `gates` agrupa `lint` y `coverage`, lo que evita greenwashing de builds al impedir merges con estilos rotos o con cobertura insuficiente. En equipos que toman en serio la **calidad como contrato**, es común ampliar `gates` para exigir `bandit` y `semgrep` en nivel bloqueante.

El target `pack` produce artefactos reproducibles con tar ordenado por nombre, metadatos congelados, propietario y grupo numéricos, y suma SHA-256 almacenada y mostrada. Esta práctica alinea con trazabilidad y reproducibilidad, y facilita auditorías.

#### Ideas de extensión de pruebas con el código actual

1. **Parametrización de políticas**. Añadir una batería parametrizada sobre `ALLOWED_HOSTS` y tiempos. Con `monkeypatch` se puede forzar temporales y medir que se usan correctamente tanto en el adapter como en la función proxy.

2. **Pruebas negativas de `raise_for_status`**. El `DummyResp` ya implementa `raise_for_status`. Añadir casos con `status_code` 400 o 500 para asegurar que la excepción de `requests.HTTPError` se propaga y que el dominio la maneja si fuera el caso .

3. **Autospec para `requests`**. Sustituir `Mock` por `create_autospec(requests)` para estrechar la superficie de fallo y evitar atributos inexistentes en dobles, endureciendo las pruebas de interacción en `clients.get_json`.

4. **call_args_list para reintentos**. Si se incorporan reintentos con jitter y backoff acotado, inspeccionar `http.get.call_args_list` permitiría verificar secuencia de intentos y parámetros constantes como URL y timeout.

5. **Fixtures autouse para entorno limpio**. Un autouse que limpie o fije `HTTP_TIMEOUT` y cualquier otra variable usada por el adapter evitaría test interdependientes.

6. **Stubs de comandos del sistema**. Si más adelante el proyecto incorpora diagnósticos con `curl` o `dig`, envolver esas llamadas en un puerto y stubear en pruebas con objetos tipo `CompletedProcess` falsos devolvería salidas prefabricadas sin depender del host, alineado con el enfoque ya mostrado para HTTP.

#### Lectura del dominio y diseño evolutivo

El servicio `MovieService` tiene una única operación `status` que usa una URL fija. Esto es suficiente para demostrar DI y separar política de seguridad a la periferia. 

El siguiente paso natural sería mover la URL a configuración, mantener la allowlist, y crecer a múltiples métodos como `movie_reviews` o `movie_ratings`, que aparecen mencionados en comentarios. 

Cada método del servicio seguiría dependiendo del puerto `HttpPort`, y los tests a nivel dominio usarían `FakeHttpClient` con fixtures por  URL, mientras que los tests del adapter seguirían en bajo nivel con `monkeypatch` a `requests.get` y verificaciones de interacción y política. 

Esta metodología mantiene el dominio libre de detalles, sostiene la testabilidad extrema y permite que el composition root decida cómo se conectan las dependencias según el entorno, que es el corazón del DIP y de una arquitectura limpia para DevSecOps.

#### Integración con el Makefile y pipeline

El Makefile define un modo de trabajo donde las herramientas se resuelven desde el entorno virtual activo y ofrece tareas estándar que deberían ejecutarse en CI. 

La combinación de `lint` más `coverage` en `gates` pone barreras de calidad que encajan con un enfoque DevSecOps, donde la seguridad y la robustez se prueban temprano y a cada commit. `security` y `semgrep` aportan análisis estático de patrones peligrosos, por ejemplo invocaciones a red sin timeout o interpolación insegura de rutas, que es exactamente lo que el adapter seguro ya evita a nivel de código. 
El target `pack` crea artefactos deterministas con normalización de metadata y suma de verificación, lo que cierra el círculo de reproducibilidad y auditoría.

Desde pytest, cada tema descrito arriba contribuye a que esos gates sean significativos. Los stubs evitan **flakiness**, los mocks verifican contratos de interacción, los fixtures reducen duplicación y preparan contextos 
claros, `monkeypatch` facilita controlar entorno y dependencias, el parcheo dirigido en TDD acelera el Red-Verde-Refactor, **autospec** evita falsos positivos y la inspección de llamadas documenta y asegura la orquestación correcta del comportamiento.  
Sumado al **composition root**, todos estos elementos forman una línea de montaje de calidad y seguridad que no depende de servicios externos y que produce evidencia confiable en cada ejecución.

### Implementación del composition root

El *composition root*  es el borde donde decides **qué implementación real** vas a inyectar en tus servicios que dependen de **interfaces** o **protocolos**.

Gracias a esto, el dominio se mantiene limpio y desacoplado y puedes cambiar adaptadores sin tocar la lógica del negocio.

En el ejemplo, ese rol lo cumple `app/main.py`.

#### Las piezas que habilitan el composition root

1. **El puerto** que define el contrato de la dependencia:

```python
# app/ports.py
from typing import Protocol, Any

class HttpPort(Protocol):
    def get_json(self, url: str) -> Any: ...
```

2. **El servicio de dominio** que depende de la abstracción, no del detalle:

```python
# app/service.py
from .ports import HttpPort

class MovieService:
    def __init__(self, http: HttpPort):
        self.http = http
    def status(self):
        return self.http.get_json("https://api.ejemplo.com/status")
```

3. **Los adaptadores concretos** que implementan el puerto:

```python
# app/adapters.py
import os, urllib.parse, requests
from .ports import HttpPort

ALLOWED_HOSTS = {"api.ejemplo.com"}
TIMEOUT = float(os.getenv("HTTP_TIMEOUT", "2.0"))

class SecureRequestsClient(HttpPort):
    def get_json(self, url: str):
        host = urllib.parse.urlparse(url).hostname
        if host not in ALLOWED_HOSTS:
            raise ValueError(f"Host no permitido: {host}")
        r = requests.get(url, timeout=TIMEOUT)
        r.raise_for_status()
        return r.json()

class FakeHttpClient(HttpPort):
    def __init__(self, fixtures):
        self.fixtures = fixtures
    def get_json(self, url: str):
        return self.fixtures[url]
```

#### Dónde está el composition root y qué hace

Tu composition root está en `app/main.py`.Ahí se deciden las conexiones entre dependencias y abstracciones y se configura el entorno de ejecución.

```python
# app/main.py
from .adapters import FakeHttpClient

def main():
    fixtures = {"https://api.ejemplo.com/status": {"ok": True, "service": "up"}}
    http = FakeHttpClient(fixtures)           # 1) eliges el adapter concreto
    from .service import MovieService         #    sin tocar el dominio
    svc = MovieService(http)                  # 2) inyectas la abstracción
    print(svc.status())                       # 3) ejecutas el caso de uso

if __name__ == "__main__":
    main()
```

### Paso a paso del flujo de ejecución

1. **Preparación de datos de entorno de ejecución**
   `fixtures = {...}` define la respuesta que queremos observar en este modo. Esto da **determinismo** y evita red durante la demo o las pruebas de contrato.

2. **Elección del adaptador**
   `http = FakeHttpClient(fixtures)` selecciona la implementación concreta de `HttpPort`. Podrías elegir el cliente seguro en producción y el fake en dev o test.

3. **Composición del servicio**
   `svc = MovieService(http)` inyecta la abstracción. El servicio solo conoce el **puerto** `HttpPort`, no sabe que por debajo hay un `FakeHttpClient` o un `SecureRequestsClient`.

4. **Ejecución del caso de uso**
   `print(svc.status())` dispara el flujo: `MovieService.status()` delega en `http.get_json(...)`.

   * Con `FakeHttpClient` retorna desde `fixtures`
   * Con `SecureRequestsClient` llamaría a `requests.get` con `timeout` y **allowlist**, y fallaría si el host no es permitido

5. **Contrato observable**
   El `print` expone una salida legible. Tu test de entrada (`test_main_entrypoint.py`) asegura que la ejecución imprime algo que contiene `"ok"`, `"service"` y `"up"`. Ese es el **contrato observable** del CLI:

```python
# tests/test_main_entrypoint.py
from app.main import main

def test_main_prints_status(capsys):
    main()
    out = capsys.readouterr().out.strip()
    assert "ok" in out and "service" in out and "up" in out
```

#### Por qué esto es DIP y SOLID

* **DIP**: `MovieService` depende de `HttpPort` y no de `requests` ni de ninguna clase concreta. Cambiar la implementación de `HttpPort` no requiere tocar el servicio.
* **SRP**: `main.py` decide cableado y modo de ejecución. `MovieService` hace negocio. `adapters.py` hace IO y política de seguridad. Cada uno con su responsabilidad.

#### Cómo cambiar la política sin tocar el dominio

El valor del composition root es que puedes **conmutar implementaciones** sin modificar `MovieService`.

#### Opción 1: usar el cliente seguro desde el composition root

```python
# app/main_secure.py
from .adapters import SecureRequestsClient
from .service import MovieService

def main():
    http = SecureRequestsClient()
    svc = MovieService(http)
    print(svc.status())
```

Con esto, tu servicio aplicará **allowlist** y **timeout** tomados de `HTTP_TIMEOUT`. Si el host no está en `ALLOWED_HOSTS`, levanta `ValueError`.

#### Opción 2: un composition root que decide por variable de entorno

```python
# app/main_alt.py
import os
from .adapters import FakeHttpClient, SecureRequestsClient
from .service import MovieService

def build_http():
    mode = os.getenv("HTTP_MODE", "fake")
    if mode == "fake":
        fixtures = {"https://api.ejemplo.com/status": {"ok": True, "service": "up"}}
        return FakeHttpClient(fixtures)
    if mode == "secure":
        return SecureRequestsClient()
    raise ValueError("HTTP_MODE inválido")

def main():
    http = build_http()
    svc = MovieService(http)
    print(svc.status())
```

Prueba de ese composition root alternativo:

```python
# tests/test_main_alt.py
from app.main_alt import main
def test_main_alt_fake(capsys, monkeypatch):
    monkeypatch.setenv("HTTP_MODE", "fake")
    main()
    out = capsys.readouterr().out
    assert "ok" in out and "service" in out and "up" in out
```

#### Cómo se valida todo esto con tus tests actuales

* **Dominio con fake**
  `test_service_and_dip.py::test_service_usa_fake_con_fixtures` crea `FakeHttpClient` con fixtures, lo inyecta en `MovieService` y afirma la respuesta. Demuestra DI y que el dominio está limpio.

* **Política de seguridad**
  `test_service_and_dip.py::test_secure_requests_client_allowlist` garantiza que el adapter seguro rechaza hosts fuera de la allowlist con `ValueError`.

* **Contrato observable del CLI**
  `test_main_entrypoint.py` captura `stdout` y verifica que el CLI imprime "ok", "service", "up".

* **Interacción a bajo nivel**
  `test_adapters_secure_client.py::test_secure_requests_client_happy_path` usa `monkeypatch` para interceptar `requests.get`, afirma que se invoca con `timeout` esperado y devuelve un `DummyResp` que simula la respuesta.
  `test_clients.py` muestra la otra vía proxy `get_json` con mocks y stubs verificando `assert_called_once_with`.

Todo esto se integra con tu Makefile mediante `make gates` que corre `lint` y `coverage` con umbral mínimo.

#### Señales claras de "composition root bien hecho" 

1. **No hay new() de adaptadores dentro del dominio**
   `MovieService` solo recibe `HttpPort` en el constructor. No crea `SecureRequestsClient` adentro.

2. **El dominio no lee variables de entorno**
   `HTTP_TIMEOUT` y `allowlist` se resuelven en el adaptador o en el composition root. El servicio desconoce esos detalles.

3. **Puedes cambiar de Fake a Secure sin tocar el servicio**
   `main.py` decide `FakeHttpClient`. Otro `main_secure.py` decidiría `SecureRequestsClient`.

4. **El contrato observable se prueba arriba**
   `test_main_prints_status` no hace mocks de red. Verifica salida final. Eso es típico cuando hay un composition root correcto.

#### Cómo evolucionar tu composition root sin romper DIP

* **Modo por entorno**
  Usa `HTTP_MODE` como en `main_alt.py` para alternar `fake` y `secure`.

* **Factory mínima para HTTP**
  Encapsula la decisión en una función o clase factory que devuelva `HttpPort`. El servicio sigue limpio y tus tests pueden usar una fixture que devuelva la factory deseada.

* **Múltiples puertos**
  Si el dominio necesita más dependencias (por ejemplo, caché o logging estructurado), defínelas como `Protocols` y decide sus implementaciones en el composition root.

* **Configuración compuesta**
  El composition root puede leer un archivo `.env` o variables de entorno y construir adaptadores con esa configuración. El dominio no se entera.

Ejemplo de factory simple invocada desde el composition root:

```python
# app/http_factory.py
import os
from .adapters import FakeHttpClient, SecureRequestsClient

def make_http():
    mode = os.getenv("HTTP_MODE", "fake")
    if mode == "fake":
        fixtures = {"https://api.ejemplo.com/status": {"ok": True, "service": "up"}}
        return FakeHttpClient(fixtures)
    return SecureRequestsClient()
```

```python
# app/main_factory.py
from .http_factory import make_http
from .service import MovieService

def main():
    http = make_http()
    svc = MovieService(http)
    print(svc.status())
```

#### Resumen operativo, paso a paso

1. `ports.py` define **la abstracción** `HttpPort`.
2. `service.py` **depende del puerto** y expone `status()` que delega en `get_json`.
3. `adapters.py` ofrece **dos implementaciones** del puerto.

   * `FakeHttpClient` para entornos sin red y pruebas deterministas
   * `SecureRequestsClient` con políticas DevSecOps: **allowlist** y **timeout**
4. `main.py` es el **composition root**:

   * prepara fixtures
   * elige el **adapter** a usar
   * **inyecta** en `MovieService`
   * **ejecuta** y **expone** el resultado en stdout
5. `tests/` validan cada capa y el contrato observable del CLI sin romper el acoplamiento.
6. El Makefile asegura **gates** de calidad y reproducibilidad.

