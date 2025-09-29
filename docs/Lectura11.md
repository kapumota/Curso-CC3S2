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

**Aserciones en DevSecOps**

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

**Stubs** devuelven respuestas prefabricadas sin verificar interacciones **mocks** permiten inspeccionar llamadas, argumentos y orden. En fronteras con red, reloj, disco o criptografía, los mocks ayudan a afirmar que el código **cumple contratos de uso** (URL, *params*, *headers*, `timeout`, *retries*). Un stub basta si solo importa el *payload* un mock es imprescindible si necesitas asegurar el **cómo** se invoca una dependencia. En un cliente HTTP estilo "IMDb", por ejemplo, `@patch("models.imdb.requests.get")` permite simular `200`, `404`, `500`, *timeout* y validar cabeceras o tiempo de espera.

En el contexto de **DevSecOps**, los mocks y stubs son esenciales para integrar la seguridad en el ciclo de desarrollo y pruebas. Los **stubs** proporcionan datos simulados para probar flujos de aplicación sin interactuar con sistemas reales, lo que reduce riesgos al evitar conexiones a entornos externos potencialmente inseguros durante las pruebas. Por ejemplo, un stub puede simular una respuesta de una API externa para probar el manejo de datos sensibles sin exponer credenciales reales.

Por otro lado, los **mocks** son cruciales para verificar que las interacciones con dependencias externas (como APIs, bases de datos o servicios criptográficos) respeten **controles de seguridad**. Por ejemplo, en una aplicación que interactúa con una API externa, un mock puede validar que se envían encabezados de autenticación correctos (como tokens OAuth), que los parámetros de la solicitud no contienen datos sensibles expuestos (como PII o contraseñas) y que se respetan configuraciones de seguridad como tiempos de espera (*timeout*) y límites de reintentos (*retries*) para evitar ataques de denegación de servicio.

**Inyección de dependencias e inversión de control**

La **inyección de dependencias** (IoD) y la **inversión de control** (IoC) son patrones clave en DevSecOps para facilitar pruebas seguras y mantenibles. La **inyección de dependencias** consiste en proporcionar a un componente sus dependencias externas (como un cliente HTTP o un servicio de base de datos) desde el exterior, en lugar de que el componente las cree internamente. Esto permite reemplazar dependencias reales por stubs o mocks durante las pruebas, reduciendo la superficie de ataque al evitar conexiones a sistemas reales que podrían ser vulnerables o no estar disponibles.

Por ejemplo, en un cliente HTTP que consulta una API de IMDb, puedes inyectar un cliente HTTP simulado en lugar de uno real. Esto se logra mediante un contenedor de IoC, que gestiona la creación y configuración de objetos, permitiendo al desarrollador especificar si se usará un cliente real o un mock/stub en función del entorno (desarrollo, pruebas, producción).

La **inversión de control** lleva este concepto más allá al delegar el control del flujo de la aplicación a un marco o contenedor. En DevSecOps, esto es crítico para garantizar que las pruebas unitarias y de integración sean seguras y consistentes. Por ejemplo, un contenedor IoC puede configurar un mock para simular un servicio criptográfico (como una librería para firmas digitales) y verificar que las claves utilizadas cumplen con estándares de seguridad (como longitud mínima o algoritmos aprobados por NIST).

**Aplicación en DevSecOps**

En un pipeline de DevSecOps, los mocks y stubs se integran en las pruebas automatizadas para validar no solo la funcionalidad, sino también la seguridad del código. Por ejemplo:

- **Pruebas de seguridad en APIs**: Usar mocks para simular respuestas de APIs externas y verificar que el código maneja correctamente casos de error (como `401 Unauthorized` o `429 Too Many Requests`) sin exponer datos sensibles en los logs o respuestas al usuario.
- **Validación de configuraciones seguras**: Con mocks, puedes asegurarte de que el código respeta configuraciones de seguridad, como tiempos de espera cortos para evitar bucles infinitos o reintentos excesivos que podrían ser explotados en un ataque DDoS.
- **Pruebas de cumplimiento**: Los mocks permiten simular interacciones con servicios que manejan datos regulados (como GDPR o HIPAA) para garantizar que el código no envía información sensible sin cifrar o que respeta los contratos de uso definidos.
- **Reducción de riesgos en entornos de prueba**: Al usar stubs y mocks, se evita la necesidad de conectarse a servicios reales durante las pruebas, lo que reduce la exposición a vulnerabilidades en entornos no productivos.

En el ejemplo del cliente HTTP para IMDb, podrías usar un mock con `@patch("models.imdb.requests.get")` para simular un ataque de inyección de datos en una respuesta `500` y verificar que el código no propaga información sensible en los errores. También podrías usar un stub para simular una respuesta válida con datos de películas, asegurando que el código parsea el *payload* sin introducir vulnerabilidades como inyecciones SQL o XSS.

En resumen, los mocks y stubs, combinados con IoD e IoC, permiten a los equipos de DevSecOps crear pruebas robustas que no solo validan la lógica de negocio, sino que también garantizan que el código cumple con principios de seguridad, minimiza riesgos y facilita la auditoría en pipelines de CI/CD.

### Factories & Fakes

En el contexto de DevSecOps, las factories y los fakes representan herramientas fundamentales para integrar la seguridad en el ciclo de vida del desarrollo de software, permitiendo una automatización eficiente de pruebas que abarcan no solo la funcionalidad, sino también aspectos críticos de seguridad como la gestión de secretos, el control de accesos y la simulación de entornos hostiles. 

Las **factories** son funciones o clases diseñadas para generar instancias de objetos con valores predeterminados que cumplen con las validaciones del modelo de datos. Por ejemplo, en un framework como *Factory Boy* en Python o **FactoryBot* en Ruby, una factory para un objeto `Usuario` podría definirse con atributos por defecto como nombre, email y contraseña hasheada, asegurando que el objeto sea válido según las reglas de negocio y seguridad, como longitudes mínimas de contraseña o formatos de email válidos. 

La **sobreescritura selectiva** permite modificar solo campos específicos, lo que es crucial en pipelines DevSecOps para probar escenarios de borde: un usuario con contraseña débil para simular un ataque de fuerza bruta, o un email inválido para verificar validaciones de entrada que prevengan inyecciones SQL o XSS.

Esta capacidad reduce la repetición en el código de pruebas, ya que en lugar de escribir manualmente objetos en cada test case, se invoca la factory una vez y se ajusta según sea necesario. En términos de DevSecOps, esto se alinea con prácticas como **shift-left security**, donde la seguridad se integra temprano en el desarrollo. 

Por ejemplo, en un pipeline CI/CD con herramientas como Jenkins o GitHub Actions, las factories pueden usarse en tests unitarios para generar datos que simulen incumplimiento normativos, como objetos con datos sensibles expuestos, permitiendo que herramientas de escaneo estático (SAST) como SonarQube detecten *issues* antes de llegar a staging. Además, hacen explícitas las variantes: una variante "válida" para tests de flujo normal, "inválida" para handling de errores seguros (evitando leaks de información en respuestas de error), y "límite" para probar overflows o condiciones de carrera que podrían explotarse en ataques DoS.

Pasando a los **fakes**, estos van más allá de simples **stubs** o **mocks**, implementando versiones minimalistas pero funcionales de dependencias externas. En DevSecOps, esto es esencial para aislar el sistema bajo prueba de servicios reales que podrían comprometer la seguridad o incurrir en costos. 

Tomemos el ejemplo de *FakeCache*: en un entorno real, podrías usar Redis o Memcached con encriptación TLS y políticas de acceso RBAC. Un fake implementaría esto en memoria, con soporte para TTL (Time To Live) para expiración de entradas, y quizás simulación de fallos como cache misses intencionales para probar resiliencia. 

Técnicamente, en código, un *FakeCache* podría ser una clase que hereda de una interfaz `ICache`, usando un diccionario interno para almacenamiento, un timer para TTL basado en threading. `Timer` en Python, y métodos como `get(key)`, `set(key, value, ttl)`, que internamente manejan locks para thread-safety, previniendo condiciones de carrera que en un entorno real podrían llevar a corrupciones de datos sensibles.

Otro ejemplo clave es *FakeClock*, que permite controlar el tiempo con un método `now()` inyectable. En DevSecOps, esto es vital para probar lógica dependiente del tiempo, como expiración de JWT (JSON Web Tokens). Imagina un servicio que renueva tokens cada 15 minutos: con *FakeClock*, puedes avanzar el tiempo virtualmente para simular expiraciones sin esperar en tiempo real, integrando esto en tests de integración que validen flujos de autenticación segura. 

Por ejemplo, en un test con Pytest, inyectas el `fake clock` vía inyección de dependencias (usando bibliotecas como `Injector` o el `built-in` de FastAPI), avanzas el tiempo y verificas que se lanza una excepción de token expirado, y que el token de actualización se usa correctamente sin exponer **alcances** innecesarios, alineado con los principios de menor privilegio.

El *FakeKMS* (Key Management Service) es particularmente relevante en DevSecOps, simulando cifrado y descifrado sin depender de servicios cloud como AWS KMS o Google Cloud KMS. Técnicamente, podría usar bibliotecas como `cryptography` en Python para implementar AES-GCM con keys generadas en memoria, soportando rotación de keys y auditoría de accesos. Esto permite probar flujos de encriptación de datos sensibles (como PII-Personally Identifiable Information) en pipelines, asegurando que el código maneje errores de cifrado graciosamente, sin leaks, y que integre con herramientas de DAST (Dynamic Application Security Testing) como OWASP ZAP para escanear vulnerabilidades en tiempo de ejecución.

Expandiendo al núcleo de DevSecOps, los fakes de proveedores de secretos, como un *FakeVault* simulando HashiCorp Vault, permiten validar flujos completos de gestión de secretos sin riesgos. En un pipeline, un fake podría exponer endpoints HTTP mockeados (usando `WireMock` o `Flask` para un server local) que responden a solicitudes de secrets con tokens JWT o API keys, simulando políticas de acceso basadas en roles. Por ejemplo, un flujo de renovación de tokens: el fake implementa un `endpoint /auth` que devuelve un `access_token` con expiración, un `refresh_token` y alcances limitados. En tests, se pueden forzar la revocación de tokens para comprobar el manejo de **401 Unauthorized** y y verificar que el sistema retrocede a mecanismos seguros como **MFA** sin exponer credenciales.

De modo análogo, un **FakeOIDCProvider** facilita probar la integración con **OAuth 2.0/OpenID Connect**. Técnicamente, basta con implementar **descubrimiento** (`.well-known/openid-configuration`), el **flujo de autorización por código** y la **introspección de tokens**. En DevSecOps, esto se encadena en CI para ejecutar **pruebas de seguridad automatizadas**: por ejemplo, confirmar que el cliente **valida la firma de los JWT** contra un **JWKS** simulado, mitigando **manipulación de tokens** y **ataques de repetición (replay)**. Además, mediante **pruebas de contrato** (con Pact) se verifica que el fake **se ajusta al contrato del proveedor real**, reduciendo el riesgo al pasar a producción.

Para hacer esto más técnico, consideremos un ejemplo de implementación en código. Supongamos un proyecto en Python con FastAPI para una API segura. Definimos una **factory** usando `factory_boy`:

```python
import factory
from myapp.models import User
from passlib.hash import bcrypt

class UserFactory(factory.Factory):
    class Meta:
        model = User
    
    username = factory.Faker('user_name')
    email = factory.Faker('email')
    password_hash = factory.LazyAttribute(lambda o: bcrypt.hash('securepassword123'))
```

Esto genera usuarios válidos por defecto. Para variantes inválidas:

```python
invalid_user = UserFactory(password_hash='weak')  # Sobreescritura para test de validación
```

Para fakes, un *FakeSecretsProvider*:

```python
import time
from typing import Dict
from threading import Lock

class FakeSecretsProvider:
    def __init__(self):
        self.secrets: Dict[str, str] = {}
        self.lock = Lock()
    
    def store_secret(self, key: str, value: str):
        with self.lock:
            self.secrets[key] = value
    
    def get_secret(self, key: str) -> str:
        with self.lock:
            if key in self.secrets:
                return self.secrets[key]
            raise KeyError("Secreto no encontrado")
    
    def simulate_rotation(self):
        with self.lock:
            for key in list(self.secrets.keys()):
                self.secrets[key] = self.secrets[key] + "_rotated"  # Simulación simple
```

En un pipeline DevSecOps con **Gi**, un stage de test podría ejecutar:

```yaml
test_security:
  stage: test
  script:
    - pytest --cov=myapp --cov-report=xml
    - sonar-scanner -Dsonar.projectKey=myproject -Dsonar.sources=. -Dsonar.tests=tests
```

Aquí, los tests usan factories para generar datos y fakes para dependencias, integrando escaneo de vulnerabilidades con `Trivy` o `Snyk` para detectar **issues** en bibliotecas.

En entornos avanzados como **Kubernetes** con **Istio**, que actúa como una malla de servicios, los fakes pueden inyectarse mediante contenedores acompañantes simulados. Con esto se imitan políticas de red y TLS mutuo para probar resiliencia frente a ataques tipo `man-in-the-middle`. En términos prácticos, un fake de Istio puede apoyarse en [proxies de Envoy](https://istio.io/latest/docs/ops/deployment/architecture/) configurados de forma local con scripts Lua para simular respuestas y verificar que el tráfico cifrado no se filtre.

En DevSecOps estos patrones se extienden a la **ingeniería del caos**. Los fakes permiten inyectar fallos de seguridad como retraso en la renovación de tokens para simular ataques por medición de tiempos o corrupción de cachés para comprobar la integridad de los datos. Herramientas de caos integradas con fakes automatizan estas pruebas dentro de los pipelines de integración y despliegue y contribuyen a una alta disponibilidad segura.

Para escalar con microservicios, las factories generan cargas de prueba para ejercicios de API con herramientas como **Postman** o **Karate** con foco en seguridad mediante cabeceras protectoras como X-XSS-Protection. Fakes de bases de datos como un **FakeMongo** con `mongomock` ayudan a validar consultas resistentes a inyecciones en motores NoSQL.

En cumplimiento normativo, por ejemplo con **GDPR** o **HIPAA**, las factories crean datos anonimizados usando Faker con configuraciones por región y los fakes registran accesos con trazas estructuradas. Estos registros pueden enviarse a la pila **ELK** para mantener auditorías completas y trazables.

Para medir la efectividad se recomiendan métricas concretas. Por ejemplo la **cobertura de código** con un objetivo mayor a 90 por ciento cuando se prueban rutas críticas con factories. La reducción del tiempo medio de detección de vulnerabilidades gracias a pruebas tempranas. O la disminución de falsos positivos mediante fakes que reproducen con fidelidad los contratos externos.

En síntesis, las factories y los fakes en DevSecOps no solo optimizan las pruebas. También incorporan la seguridad en el proceso de desarrollo desde el código hasta el despliegue y ayudan a prevenir incidentes costosos. En equipos ágiles conviene integrarlo con la planificación por sprints. Definir tareas para nuevas factories y agrega historias de seguridad como la verificación de factores múltiples con fakes de autenticación que no dependan de un proveedor único.

Existe un riesgo importante al usar fakes. Con el tiempo pueden separarse del comportamiento del proveedor real y producir falsos positivos o falsos negativos. Para mitigarlo se aplica pruebas de contrato que definan acuerdos entre el cliente y el proveedor y se ejecutan en integración continua. También puede usarse pruebas de conformidad contra esquemas reales. Por ejemplo validar puntos de publicación JWKS o el documento de descubrimiento de OIDC que se descargan de forma periódica en una tarea de integración continua. Así se detecta desviaciones y evitas que se oculten vulnerabilidades.

**Recomendaciones**

Algunas recomendaciones técnicas para factories en DevSecOps. Expone perfiles o rasgos predefinidos como `válida`, `inválida`, `límite` y datos personales para reutilizar sin repetir sobrescrituras. Un ejemplo con `Factory Boy`.

```python
class UserFactory(factory.Factory):
    class Meta:
        model = User

    @factory.trait
    def invalida(self):
        password_hash = 'weak'  # Contraseña no segura para pruebas de validación

    @factory.trait
    def pii(self):
        email = 'sensitive@pii.example'  # Para pruebas de enmascaramiento de datos
```

Esto permite llamar a `UserFactory.with_trait('pii')` y generar objetos orientados a pruebas de cumplimiento. Puedes integrarlo con [Datadog](https://www.datadoghq.com/) para vigilar que en pruebas no se filtren datos sensibles.

Generar datos realistas con Faker configurado por región como `es_PE` y usar formatos de referencia para correos y direcciones web. Así se reduce falsos negativos en validaciones de entrada que podrían abrir la puerta a recorridos de ruta. Cuando la aleatoriedad afecta la reproducibilidad se define una semilla global con `Faker.seed(42)` en un fixture de pytest o se usa generadores deterministas que acepten valores fijos para depuración en los pipelines.

Para fakes de tiempo y expiración se evita el uso directo de `datetime.now()` en código productivo. Se inyecta una interfaz de reloj con un método `now` y se crea un reloj real para producción y un reloj falso para pruebas. Se emplea `time.monotonic()` para calcular tiempos de vida ya que no se ve afectado por cambios del reloj del sistema y ayuda a prevenir ataques por medición de tiempos en criptografía.

En pytest ofrece dos caminos. Un reloj falso inyectable para pruebas unitarias finas. Un fixture que congele el tiempo con `freezegun` para escenarios de integración. Esto facilita simular saltos temporales en expiración de tokens o rotación de claves y combinarlo con análisis de seguridad que detecten dependencias frágiles.

### Fixtures: Scopes, anidación, reutilización y autouse

Las *fixtures* en pytest, decoradas con `@pytest.fixture`, encapsulan la preparación (*setup*) y limpieza (*teardown*) para pruebas, promoviendo modularidad y aislamiento. Son esenciales en DevSecOps para entornos consistentes, seguros y reproducibles.

#### **Scopes (Alcances)**

El parámetro `scope` define el ciclo de vida de una *fixture*:

- **`function`** (predeterminado): Ejecuta la *fixture* por cada función de prueba, garantizando máximo aislamiento. Ideal para pruebas unitarias donde el estado no debe compartirse.
  ```python
  @pytest.fixture(scope="function")
  def tmp_file(tmp_path):
      file = tmp_path / "test.txt"
      file.write_text("contenido")
      yield file
      # Limpieza automática
  ```

- **`class`**: Comparte una instancia entre los métodos de una clase de prueba. Útil para pruebas de integración que requieren un contexto común, como un cliente HTTP.
  ```python
  @pytest.fixture(scope="class")
  def http_client():
      client = HTTPClient(base_url="https://api.example.com")
      yield client
      client.close()
  ```

- **`module`**: Una instancia por archivo de prueba. Adecuado para configuraciones costosas, como bases de datos en memoria.
  ```python
  @pytest.fixture(scope="module")
  def db_connection():
      conn = Database.connect("sqlite:///:memory:")
      yield conn
      conn.close()
  ```

- **`session`**: Una instancia por sesión de pytest. Perfecto para recursos globales, como contenedores efímeros de Docker.
  ```python
  @pytest.fixture(scope="session")
  def docker_container():
      container = docker.run("my-service:latest")
      yield container
      container.stop()
  ```

**Buena práctica en DevSecOps**: Usa el *scope* más restrictivo posible para minimizar efectos secundarios. Para `session`, ten cuidado con estado mutable en pruebas paralelas (por ejemplo, con `pytest-xdist`). En contextos de seguridad, `session` es útil para configuraciones globales como certificados o bloqueos de red, pero debe gestionarse para evitar contaminación.

#### **Anidación y composición**

Las *fixtures* pueden depender de otras, permitiendo entornos complejos y realistas. Por ejemplo, combinar un directorio temporal, configuraciones falsas y modificaciones de entorno:

```python
@pytest.fixture
def tmp_config(tmp_path, monkeypatch):
    config_path = tmp_path / "config.yaml"
    config_path.write_text("api_key: fake-key")
    monkeypatch.setenv("CONFIG_PATH", str(config_path))
    yield config_path

def test_api_call(tmp_config, monkeypatch):
    monkeypatch.setenv("API_URL", "https://fake-api.com")
    response = make_api_call()
    assert response.status_code == 200
```

**Aplicaciones en DevSecOps**:
- Simula entornos de producción con variables de entorno endurecidas.
- Inyecta clientes HTTP mockeados para evitar conexiones reales.
- Prueba configuraciones de seguridad, como `SSL_STRICT=True` o tiempos de espera estrictos.

#### **Reutilización**

Define *fixtures* en `conftest.py` para compartirlas entre archivos de prueba, reduciendo duplicación:

```python
# conftest.py
@pytest.fixture
def secure_client(monkeypatch):
    client = HTTPClient()
    monkeypatch.setattr(client, "verify_ssl", True)
    yield client
```

Cualquier prueba puede usar `secure_client` sin redefinirla, promoviendo consistencia.

#### **Autouse**

Las *fixtures* con `autouse=True` se ejecutan automáticamente en su ámbito, ideales para reglas globales de seguridad. El ejemplo original de `block_network` usaba una sustitución invasiva de `socket.socket`. Una corrección más precisa y menos frágil es interceptar `socket.create_connection`:

```python
import socket
import pytest

@pytest.fixture(autouse=True, scope="session")
def block_network(monkeypatch):
    def _deny(*args, **kwargs):
        raise RuntimeError("Red bloqueda por politicas de pruebas")
    monkeypatch.setattr(socket, "create_connection", _deny)
    monkeypatch.setenv("REQUESTS_CA_BUNDLE", "/path/to/ca_bundle.pem")
    monkeypatch.setenv("PYTHONHASHSEED", "0")
    # Fijar semilla para reproducibilidad
    monkeypatch.setattr("random.seed", lambda x: None)  # Evita cambios aleatorios
    yield
```

**Alternativa con `pytest-socket`** (recomendada para simplicidad y robustez):

```python
# Requiere: pip install pytest-socket
@pytest.fixture(autouse=True, scope="session")
def block_network(socket_disabled):
    # Bloquea conexiones de red reales automáticamente
    pass
```

**Usos en DevSecOps**:
- **Bloqueo de red**: Evita conexiones accidentales a servicios reales, forzando mocks.
- **Configuraciones endurecidas**: Asegura certificados estrictos, niveles de *logging* elevados o semillas fijas (`PYTHONHASHSEED`, `random.seed`).
- **Auditoría**: Registra configuraciones globales para cumplimiento normativo.

**Precaución**: Usa `autouse` con moderación y documenta su propósito. En pruebas paralelas (`pytest-xdist`), evita estado mutable en *fixtures* de ámbito `session` para garantizar seguridad en hilos (*thread-safety*).

### Stubs de binarios/Comandos de sistema

Cuando el código invoca binarios como `curl`, `openssl` o `dig`, las pruebas deben evitar dependencias del sistema para garantizar portabilidad y seguridad.

#### **Patrón 1: Mock de `subprocess.run`**

Mockear `subprocess.run` simula la ejecución de comandos con salidas controladas:

```python
from unittest.mock import MagicMock
import subprocess

@pytest.fixture
def mock_subprocess(monkeypatch):
    mock = MagicMock()
    monkeypatch.setattr(subprocess, "run", mock)
    return mock

def test_curl_call(mock_subprocess):
    mock_subprocess.return_value = MagicMock(stdout="success", stderr="", returncode=0)
    result = run_curl_command("https://example.com")
    assert result == "success"
    mock_subprocess.assert_called_with(
        ["curl", "--tlsv1.3", "--cacert", "/path/to/ca.pem", "https://example.com"],
        capture_output=True, text=True
    )
```

**Ventajas**:
- Controla salidas, errores y códigos de retorno.
- Verifica *flags* de seguridad (por ejemplo, `--tlsv1.3`, `--cacert`).
- Simula *timeouts*, fallos o respuestas específicas.

#### **Patrón 2: Sombrear el PATH**

Crear stubs en un directorio temporal y modificar el `PATH` asegura que pytest use scripts controlados. El ejemplo original se mejora para ser multiplataforma y explícito:

```python
import os
import stat
import pytest

@pytest.fixture
def fake_curl(tmp_path, monkeypatch):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    curl_path = bin_dir / "curl"
    curl_path.write_text("#!/usr/bin/env bash\necho 'fake response'\n")
    curl_path.chmod(curl_path.stat().st_mode | stat.S_IXUSR)  # Permisos ejecutables
    old_path = os.environ.get("PATH", "")
    monkeypatch.setenv("PATH", f"{bin_dir}{os.pathsep}{old_path}")
    yield
```

**Ventajas**:
- Simula binarios reales en entornos cercanos al sistema operativo.
- Prueba integración con el sistema de archivos y manejo de errores.
- Verifica que el código no expone datos sensibles en la línea de comandos.

**Consideraciones de seguridad**:
- Asegúrate de que los stubs simulen *flags* como `--fail-with-body` para manejar errores HTTP.
- Audita que no se pasen datos sensibles (por ejemplo, claves API) en argumentos visibles en logs.

### Parametrización y `monkeypatch`

#### **Parametrización con `@pytest.mark.parametrize`**

La parametrización explora combinaciones de entradas y configuraciones, aumentando cobertura sin duplicación. El ejemplo original incluía un caso con `expected_status=None`, lo que puede causar problemas si `result` es `None`. Se corrige manejando excepciones explícitamente:

```python
import pytest

@pytest.mark.parametrize("url, expects_ok, headers", [
    ("https://api.example.com", True, {"Authorization": "Bearer token"}),
    ("https://invalid.example.com", False, {"timeout": "5"}),
])
def test_api_call(url, expects_ok, headers, monkeypatch):
    monkeypatch.setenv("API_URL", url)
    if expects_ok:
        response = make_api_call(headers=headers)
        assert response.status_code == 200
    else:
        with pytest.raises(Exception):
            make_api_call(headers=headers)
```

**Usos en DevSecOps**:
- Prueba combinaciones de *feature flags*, cabeceras obligatorias y *timeouts*.
- Verifica fallos seguros ante configuraciones inválidas (URLs malformadas, certificados no válidos).
- Cubre casos de borde, como respuestas HTTP 4xx/5xx o excepciones de red.

#### **`monkeypatch`**

`monkeypatch` modifica el entorno o comportamiento de módulos en tiempo de ejecución, ideal para pruebas de seguridad:

- **Modificar variables de entorno**:
  ```python
  def test_production_mode(monkeypatch):
      monkeypatch.setenv("ENV", "production")
      monkeypatch.setenv("STRICT_SSL", "1")
      config = load_config()
      assert config.ssl_verify is True
  ```

- **Sustituir funciones o atributos**:
  ```python
  def test_fixed_clock(monkeypatch):
      fake_time = lambda: 1697059200  # Fecha fija
      monkeypatch.setattr("time.time", fake_time)
      assert get_current_timestamp() == 1697059200
  ```

- **Fijar semilla para reproducibilidad**:
  ```python
  @pytest.fixture(autouse=True, scope="session")
  def fixed_seed(monkeypatch):
      monkeypatch.setattr("random.seed", lambda x: None)
      import random
      random.seed(0)
  ```

**Ventajas**:
- Simula entornos de producción o configuraciones endurecidas.
- Prueba manejo de fallos en dependencias externas.
- Garantiza reproducibilidad con semillas fijas.

### Patching: `patch.object`, `patch.dict`, `monkeypatch.setenv`

El *patching* aísla dependencias y simula condiciones específicas.

#### **`patch.object`**

Sustituye atributos o métodos en tiempo de ejecución. Se corrige el ejemplo original para incluir el *import* y soportar `pathlib`:

```python
import os
from pathlib import Path
from unittest.mock import patch

def test_file_not_exists():
    with patch.object(os.path, "exists", return_value=False):
        assert check_file(Path("/fake/path")) is False
```

**Usos**:
- Simula fallos en dependencias (por ejemplo, `os.path.exists` o `requests.get`).
- Prueba rutas alternativas en el código (éxito vs. error).

#### **`patch.dict`**

Modifica diccionarios como `os.environ`:

```python
import os
from unittest.mock import patch

def test_env_config():
    with patch.dict(os.environ, {"API_KEY": "fake-key", "TIMEOUT": "10"}):
        config = load_config()
        assert config.api_key == "fake-key"
        assert config.timeout == 10
```

#### **`monkeypatch.setenv`**

Modifica variables de entorno de forma idiomática:

```python
def test_strict_ssl(monkeypatch):
    monkeypatch.setenv("STRICT_SSL", "1")
    config = load_config()
    assert config.ssl_verify is True
```

**Patrones en DevSecOps**:
- Pruebas como `test_patch_object_on_os_path` verifican manejo de rutas inexistentes.
- `test_patch_dict_env` y `test_monkeypatch_setenv` aseguran cumplimiento de *12-Factor App*.
- Valida políticas de seguridad: *timeouts* estrictos, verificación de certificados, *retries*/*backoff*.

#### Autospec / `create_autospec`

`create_autospec` y `autospec=True` generan mocks que respetan la firma del objeto original. Para clases como `requests.Session`, el mock de clase está en `MockSession`, y la instancia en `MockSession.return_value`:

```python
from unittest.mock import patch
import pytest

def test_autospec_http_client():
    with patch("requests.Session", autospec=True) as MockSession:
        inst = MockSession.return_value
        inst.get.side_effect = [Exception("Network error"), type("R", (), {"status_code": 200})()]
        result = make_api_call()
        assert result.status_code == 200
```

**Ventajas**:
- Evita derivas de contrato en APIs críticas.
- Detecta invocaciones inválidas (métodos inexistentes o argumentos incorrectos).
- Mejora la robustez de pruebas en módulos de autenticación, cifrado o HTTP.

#### Inspección de Llamadas: `call_args_list`

`call_args_list` verifica cómo se llama a un método, asegurando cumplimiento de políticas de seguridad. Se mejora el ejemplo para manejar argumentos posicionales en `requests.get`:

```python
from unittest.mock import patch

def test_retry_policy():
    with patch("requests.Session.get") as mock_get:
        mock_get.side_effect = [
            Exception("401 Unauthorized"),
            type("R", (), {"status_code": 200, "json": lambda: {"data": "success"}})(),
        ]
        result = make_api_call_with_retries()
        assert result["data"] == "success"
        assert len(mock_get.call_args_list) == 2
        args, kwargs = mock_get.call_args_list[0]
        assert args[0] == "https://api.example.com"
        assert kwargs == {"headers": {"Authorization": "Bearer initial-token"}, "timeout": 5}
        args, kwargs = mock_get.call_args_list[1]
        assert kwargs["headers"] == {"Authorization": "Bearer new-token"}
```

**Usos**:
- Verifica reintentos tras 401, incluyendo refresco de tokens.
- Asegura cabeceras obligatorias (`User-Agent`, `Accept`) y *timeouts*.
- Comprueba *backoffs* crecientes y límites de intentos.

**Ejemplo de backoff verificado**:

```python
from unittest.mock import patch, call
import math

def _expected_delays(n, base=0.5, cap=5.0):
    # Exponencial con cap, sin jitter para simplicidad
    return [min(cap, base * (2**i)) for i in range(n)]

def test_retry_backoff_policy():
    with patch("requests.Session.get") as mock_get, patch("time.sleep") as mock_sleep:
        mock_get.side_effect = [TimeoutError, TimeoutError, type("R", (), {"status_code": 200})()]
        result = make_api_call_with_retries()
        assert result.status_code == 200
        expected_delays = _expected_delays(2)
        actual_delays = [c.args[0] for c in mock_sleep.call_args_list]
        assert actual_delays == expected_delays
        assert all(
            kwargs["timeout"] == 5
            for _, kwargs in mock_get.call_args_list
        )
```

**Política de backoff**:
- Usa *backoff* exponencial con *jitter* (por ejemplo, `random.uniform(0, 0.1)` añadido al intervalo).
- Limita intentos (por ejemplo, 3) y define `max_delay` (por ejemplo, 5 segundos).
- Valida que cada llamada incluye *timeouts* y cabeceras obligatorias.

### Marcas de pytest: `xfail` y `skip`

Las marcas controlan la ejecución de pruebas y documentan comportamientos esperados.

#### **`xfail`**

Marca pruebas que se espera fallen, sin romper el CI:

```python
@pytest.mark.xfail(reason="Bug #123: API no soporta IPv6")
def test_ipv6_support():
    result = make_api_call("https://[::1]/endpoint")
    assert result.status_code == 200
```

#### **`skip`**

Omite pruebas en entornos no aplicables:

```python
import sys

@pytest.mark.skipif(sys.platform != "linux", reason="Requiere Linux")
def test_linux_specific():
    assert check_system_call() == "Linux"
```

**Gobernanza en DevSecOps**:
- **Auditoría**: Usa `pytest --markers` para rastrear marcas.
- **Restricciones en CI**: Configura pipelines para fallar si el conteo de `xfail` supera un *baseline*.
- **Documentación**: Vincula cada marca a un *issue* con fecha objetivo.
- **Ejemplo**:
  ```python
  @pytest.mark.skipif(os.getenv("CI") == "true", reason="Recursos limitados en CI")
  def test_resource_heavy():
      assert run_heavy_computation() == "done"
  ```

#### **Profundizaciones DevSecOps**

1. **Cobertura como *gate***:
   - Usa `pytest --cov --cov-fail-under=90` para exigir cobertura mínima en módulos críticos (autenticación, cifrado, *middlewares*).
   - Integra con CI para bloquear *merges* si la cobertura cae.

2. **Semillas y relojes**:
   - Fija `random.seed(0)` y `time.time` en *fixtures* globales para reproducibilidad.
   - Ejemplo:
     ```python
     @pytest.fixture(autouse=True, scope="session")
     def fixed_seed_and_clock(monkeypatch):
         monkeypatch.setattr("time.time", lambda: 1697059200)
         import random
         random.seed(0)
     ```

3. **Retries/backoff**:
   - Implementa *backoff* exponencial con *jitter* y `max_delay`.
   - Valida con `call_args_list` que los *timeouts* y cabeceras sean consistentes.
   - Ejemplo: Verifica *jitter* en el intervalo de espera:
     ```python
     def _expected_delays_with_jitter(n, base=0.5, cap=5.0, jitter=0.1):
         import random
         return [min(cap, base * (2**i) + random.uniform(0, jitter)) for i in range(n)]
     ```

4. **Paralelismo seguro**:
   - Con `pytest-xdist`, evita *fixtures* de `session` con estado mutable para prevenir conflictos entre hilos.
   - Usa *locks* o *fixtures* de ámbito `function` para recursos compartidos.

5. **Marcas gobernadas**:
   - Falla el pipeline si el conteo de `xfail` aumenta.
   - Genera reportes en CI con `pytest --junitxml` para auditar marcas.

### Matrices de casos recomendadas

Esta sección describe conjuntos de pruebas (matrices) que cubren casos específicos para validar el comportamiento de sistemas en diferentes escenarios, especialmente enfocados en seguridad y robustez.

1. **JWT (JSON Web Tokens)**:
   - **Casos de prueba**:
     - **Firma inválida**: Verificar que el sistema rechaza tokens con firmas no válidas (por ejemplo, manipuladas o generadas con una clave incorrecta).
     - **Expirado**: Comprobar que el sistema rechaza tokens cuyo tiempo de expiración (`exp`) ha pasado.
     - **`nbf` futuro**: Validar que el sistema rechaza tokens con un campo "not before" (`nbf`) establecido en una fecha futura.
     - **`aud` incorrecta**: Asegurar que el sistema verifica la audiencia (`aud`) y rechaza tokens dirigidos a una audiencia incorrecta.
     - ***Scope* faltante**: Probar que el sistema valida los permisos (scopes) en el token y rechaza aquellos sin los scopes necesarios.
   - **Propósito**: Garantizar que el manejo de autenticación y autorización basado en JWT es seguro frente a manipulaciones o configuraciones incorrectas.

2. **HTTP**:
   - **Casos de prueba**:
     - Códigos de estado HTTP: {200 (OK), 401 (Unauthorized), 403 (Forbidden), 404 (Not Found), 429 (Too Many Requests), 500 (Internal Server Error)}.
     - Combinaciones con **retries** (0 a 2 intentos) y **timeouts** (de 0.5s a 2s).
   - **Propósito**: Validar que el sistema maneja correctamente diferentes respuestas HTTP, incluyendo errores, reintentos en caso de fallos transitorios (como 429 o 500) y tiempos de espera razonables para evitar bloqueos o comportamientos impredecibles.

3. **Headers**:
   - **Casos de prueba**:
     - Presencia/ausencia de cabeceras de seguridad como:
       - **HSTS** (HTTP Strict Transport Security): Asegura que los navegadores solo usen HTTPS.
       - **CSP** (Content Security Policy): Controla qué recursos pueden cargarse para prevenir ataques como XSS.
       - **X-Content-Type-Options**: Evita que los navegadores interpreten incorrectamente el tipo de contenido.
       - **Referrer-Policy**: Controla cómo se envía la información del referente en las solicitudes.
   - **Propósito**: Garantizar que las respuestas HTTP incluyen cabeceras de seguridad esenciales para proteger contra ataques comunes.

4. **Colas**:
   - **Casos de prueba**:
     - Combinaciones de **ack** (acknowledgment, confirmar recepción), **retry×3** (reintentos hasta 3 veces) y **DLQ** (Dead Letter Queue, cola para mensajes fallidos).
     - Pruebas con payloads que contienen o no **PII** (Información de Identificación Personal), verificando que los datos sensibles se redacten en los logs.
   - **Propósito**: Asegurar que los sistemas de mensajería (como colas) manejan correctamente los mensajes, reintentos, fallos y protegen datos sensibles en los logs.

5. **Binarios**:
   - **Casos de prueba**:
     - Uso de herramientas como `curl` con/sin la opción `--cacert` (para validar certificados TLS).
     - Uso de `openssl s_client` con/sin `-verify_return_error` (para verificar errores en la validación de certificados TLS).
   - **Propósito**: Probar la configuración segura de conexiones TLS, asegurando que el sistema valida correctamente certificados y maneja errores de conexión.


### Indicadores útiles en CI/CD

Esta sección describe métricas y prácticas para monitorear la calidad y seguridad en pipelines de CI/CD.

1. **Cobertura de seguridad por módulo sensible**:
   - En lugar de medir solo la cobertura total de pruebas, se debe medir la cobertura específica para módulos críticos desde el punto de vista de seguridad (por ejemplo, autenticación, autorización, manejo de datos sensibles).
   - **Propósito**: Identificar lagunas en las pruebas de componentes críticos.

2. **Tendencia de marcas `xfail`/`skip`**:
   - Monitorear el uso de marcas `xfail` (pruebas que se espera fallen) y `skip` (pruebas omitidas) en un tablero histórico.
   - **Propósito**: Detectar pruebas problemáticas o deshabilitadas que podrían indicar deuda técnica o problemas de calidad.

3. **Tiempo hasta verde (Time to Green)**:
   - Medir cuánto tiempo tarda en pasar a "verde" (éxito) una historia de seguridad en el pipeline.
   - **Propósito**: Vigilar el ciclo RGR (Red-Green-Refactor) para identificar cuellos de botella en la resolución de problemas de seguridad.

4. **Flakiness (pruebas inestables)**:
   - Monitorear pruebas asíncronas usando un "reloj falso" (mocking de tiempo) y tiempos de espera amplios en CI.
   - Generar alertas si los resultados varían frecuentemente.
   - **Propósito**: Identificar y mitigar pruebas inestables que generan falsos positivos o negativos.

5. **Verificación de contrato**:
   - Medir el porcentaje de endpoints validados contra especificaciones como OpenAPI (para REST) o *protos* de gRPC.
   - **Propósito**: Asegurar que las APIs cumplen con sus contratos definidos, evitando errores en producción.

6. **Auditoría de secretos**:
   - Escanear logs y artefactos generados en el pipeline para detectar exposición accidental de secretos (claves, contraseñas, tokens).
   - **Propósito**: Garantizar que los datos sensibles estén correctamente redactados o no se registren.


### Consejos operativos y *tips*

Esta sección ofrece prácticas específicas para mejorar las pruebas y la seguridad en el desarrollo.

1. **Autouse fixture para cabeceras de seguridad**:
   - Implementar un *fixture* en pytest que se ejecute automáticamente para verificar la presencia de cabeceras de seguridad (HSTS, CSP, etc.) en cada respuesta HTTP.
   - **Propósito**: Garantizar que todas las respuestas incluyen configuraciones de seguridad sin necesidad de pruebas explícitas repetitivas.

2. **Stubs de binarios**:
   - Al simular herramientas como `curl` o `openssl`, no solo simular la salida, sino también verificar que se usen los *flags* mínimos requeridos (por ejemplo, TLS habilitado, compresión adecuada, manejo de errores).
   - **Propósito**: Asegurar que las pruebas reflejan configuraciones seguras y reales.

3. **Uso de `create_autospec` en mocks**:
   - Preferir `create_autospec` (en Python, parte de `unittest.mock`) en lugar de mocks genéricos para pruebas donde el contrato de una API o servicio es crítico.
   - **Propósito**: Detectar errores en las llamadas a métodos o funciones durante las pruebas, respetando la interfaz esperada.

4. **Validación de OpenAPI en el pipeline**:
   - Integrar un validador de OpenAPI en el pipeline de CI/CD para verificar que las respuestas (reales o simuladas) cumplen con la especificación de la API.
   - **Propósito**: Garantizar consistencia entre las implementaciones y las especificaciones de la API.

5. **Uso de `call_args_list`**:
   - En pruebas de HTTP (síncrono o asíncrono) y colas, usar `call_args_list` (de `unittest.mock`) para verificar el orden, número y metadatos de las llamadas (como `correlation-id` o `idempotency-key`).
   - **Propósito**: Asegurar que las interacciones con APIs o colas respetan los requisitos de trazabilidad e idempotencia.

6. **Comando `make verify-tests`**:
   - Definir un comando en el sistema de construcción (como `make verify-tests`) que ejecute:
     - Pruebas con `pytest` y cobertura.
     - Auditoría de marcas (`xfail`, `skip`).
     - Detección de secretos en logs.
     - Generación de reportes HTML como artefactos del pipeline.
   - **Propósito**: Centralizar y automatizar la validación de calidad y seguridad en un solo paso reproducible.






