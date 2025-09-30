### SOLID y pruebas

En los entornos de desarrollo actuales, donde los ciclos de entrega se miden en minutos y las arquitecturas se despliegan en contenedores efímeros, el *testing* automatizado debe integrarse de manera orgánica con la filosofía **DevOps**. 
Lejos de ser meros conjuntos de comandos que se ejecutan tras cada *commit*, las suites de pruebas se convierten en un componente vivo que evoluciona junto al código de producción. Para que esa evolución sea sostenible, resulta esencial aplicar los principios de diseño **SOLID**, no únicamente al código que se despliega, sino también al propio diseño de las pruebas.

Al adoptar la visión de que cada caso de prueba es, en sí mismo, un pequeño fragmento de software con sus propias responsabilidades, dependencias y efectos secundarios, podemos elevar la calidad de la suite al mismo nivel de rigor que exigimos al *core* de negocio. A continuación exploramos cómo cada principio SOLID encuentra su correspondencia natural en el *testing*, acompañándolo de ejemplos de código autocontenidos y comentados para evidenciar los desafíos que resuelven y los beneficios que aportan.

### 1 Principio de Responsabilidad Única (SRP)

El **Principio de Responsabilidad Única (SRP, Single Responsibility Principle)**, aplicado a pruebas unitarias, establece que cada test debe tener un único propósito o razón de existir, es decir, debe validar una sola pregunta o comportamiento específico del sistema. Esto asegura que los tests sean claros, enfocados y fáciles de entender, además de facilitar la identificación de fallos. Cuando un test viola SRP, se vuelve confuso, difícil de mantener y menos útil para diagnosticar problemas.

**¿Qué significa SRP en pruebas?**

Un test debe probar **una sola cosa**. Esto implica:
- Validar un único comportamiento o regla del sistema.
- Usar un solo `assert` (o un grupo pequeño de `asserts` relacionados con el mismo comportamiento).
- Evitar mezclar múltiples casos de prueba o lógicas complejas (como bucles o ramas condicionales) dentro de un mismo test.

Por ejemplo, en el caso del siguiente código proporcionado:

```python
@pytest.mark.unit
def test_descuento_cliente_frecuente():
    subtotal = 100.0
    es_cliente_frecuente = True
    esperado = 90.0
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
    assert resultado == pytest.approx(esperado)
```

Este test cumple con SRP porque:
- Solo valida la regla de descuento para un cliente frecuente.
- Tiene un único `assert` que verifica el resultado esperado.
- No incluye lógica adicional (como simular un carrito o validar otras reglas).

Si el test falla, el motivo es claro: la lógica de descuento para clientes frecuentes no está funcionando como se espera.

**2. Beneficios de aplicar SRP en pruebas**

1. **Claridad**: Un test con una sola responsabilidad es fácil de leer y entender. Su nombre y código indican claramente qué se está probando.
2. **Diagnóstico rápido**: Si un test falla, sabes exactamente qué comportamiento o regla está rota, sin necesidad de investigar múltiples condiciones.
3. **Mantenibilidad**: Los tests enfocados son más fáciles de actualizar cuando el código cambia, ya que no están acoplados a múltiples responsabilidades.
4. **Reusabilidad**: Al ser específicos, los tests pueden integrarse en suites de pruebas más grandes sin generar ruido o dependencias innecesarias.
5. **Confianza**: Tests claros y enfocados inspiran mayor confianza en que el sistema funciona correctamente.


**Violaciones comunes de SRP en pruebas**

Cuando un test no respeta SRP, suele incluir múltiples responsabilidades, lo que lo hace confuso y frágil. Ejemplo de un test que viola SRP:

```python
@pytest.mark.unit
def test_calcular_precio_final():
    # Caso 1: Cliente frecuente
    subtotal = 100.0
    es_cliente_frecuente = True
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
    assert resultado == pytest.approx(90.0)  # 10% de descuento

    # Caso 2: Cliente no frecuente
    es_cliente_frecuente = False
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
    assert resultado == pytest.approx(100.0)  # Sin descuento

    # Caso 3: Subtotal con impuestos
    subtotal = 100.0
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente, incluir_impuestos=True)
    assert resultado == pytest.approx(110.0)  # 10% de impuestos
```

**Problemas con este test:**
- Valida tres comportamientos distintos: descuento para cliente frecuente, precio sin descuento y cálculo de impuestos.
- Si falla, no está claro cuál de los tres casos es el problema sin depurar.
- El test es más largo y difícil de leer.
- Cambios en una regla (por ejemplo, el porcentaje de impuestos) pueden romper el test, aunque las otras reglas estén correctas.

**Corrección**: Dividir el test en tres tests separados, cada uno con una sola responsabilidad:

```python
@pytest.mark.unit
def test_descuento_cliente_frecuente():
    subtotal = 100.0
    es_cliente_frecuente = True
    esperado = 90.0
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
    assert resultado == pytest.approx(esperado)

@pytest.mark.unit
def test_precio_sin_descuento():
    subtotal = 100.0
    es_cliente_frecuente = False
    esperado = 100.0
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
    assert resultado == pytest.approx(esperado)

@pytest.mark.unit
def test_precio_con_impuestos():
    subtotal = 100.0
    es_cliente_frecuente = False
    esperado = 110.0
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente, incluir_impuestos=True)
    assert resultado == pytest.approx(esperado)
```

Ahora, cada test valida una sola regla, y un fallo señala exactamente qué comportamiento está roto.

**Cómo mantener SRP en pruebas**

Para garantizar que los tests cumplan con SRP, considera las siguientes prácticas:

1. **Nombrar los tests de forma descriptiva**:
   - Usa nombres que indiquen claramente qué se está probando, por ejemplo, `test_descuento_cliente_frecuente` en lugar de `test_calcular_precio_final`.
   - Un buen nombre de test actúa como documentación y refuerza la idea de una sola responsabilidad.

2. **Un solo `assert` por test (o asserts relacionados)**:
   - Idealmente, un test debe tener un solo `assert`. Si necesitas varios, asegúrate de que todos validen aspectos del mismo comportamiento.
   - Ejemplo: Si pruebas un objeto con múltiples propiedades, pero todas forman parte de la misma regla de negocio, varios `asserts` pueden ser aceptables.

3. **Evitar lógica compleja**:
   - No uses bucles, condicionales ni estructuras complejas dentro de un test, ya que suelen indicar que estás probando múltiples casos.
   - Si necesitas probar varios casos, crea tests separados o usa pruebas parametrizadas (por ejemplo, con `@pytest.mark.parametrize`).

   Ejemplo con parametrización:

   ```python
   @pytest.mark.parametrize(
       "subtotal, es_cliente_frecuente, esperado",
       [(100.0, True, 90.0), (100.0, False, 100.0)]
   )
   def test_calcular_precio_final(subtotal, es_cliente_frecuente, esperado):
       resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
       assert resultado == pytest.approx(esperado)
   ```

   Esto permite probar múltiples casos manteniendo un test claro y enfocado.

4. **Usar *fixtures* minimalistas**:
   - Como se menciona en el ejemplo original, los *fixtures* deben incluir solo los datos necesarios para el test. Evita crear estructuras complejas (como un carrito completo) si no son relevantes para la prueba.
   - Ejemplo: Si pruebas un descuento, no necesitas simular un inventario o un proceso de pago.

5. **Separar pruebas unitarias de pruebas de integración**:
   - Las pruebas unitarias deben centrarse en un componente aislado. Si necesitas probar interacciones entre componentes, usa pruebas de integración, pero no mezcles ambos enfoques en un solo test.

**Ejemplo práctico: Ampliando el caso de uso**

Supongamos que el sistema de precios tiene reglas adicionales, como descuentos por cantidad o promociones especiales. Cada regla debe tener su propio test para respetar SRP:

```python
@pytest.mark.unit
def test_descuento_por_cantidad():
    subtotal = 1000.0  # Precio alto para activar descuento por cantidad
    es_cliente_frecuente = False
    esperado = 900.0   # 10% de descuento por cantidad
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente, cantidad=10)
    assert resultado == pytest.approx(esperado)

@pytest.mark.unit
def test_promocion_especial():
    subtotal = 100.0
    es_cliente_frecuente = False
    promocion_activa = True
    esperado = 80.0    # 20% de descuento por promoción
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente, promocion=promocion_activa)
    assert resultado == pytest.approx(esperado)
```

Cada test valida una regla específica, lo que facilita identificar problemas si alguno falla.

**Cuándo relajar SRP (con cuidado)**

En algunos casos, puede ser aceptable incluir más de un `assert` o validar aspectos relacionados, siempre que estén estrechamente vinculados a la misma responsabilidad. Por ejemplo:

```python
@pytest.mark.unit
def test_descuento_y_redondeo():
    subtotal = 99.999
    es_cliente_frecuente = True
    resultado = calcular_precio_final(subtotal, es_cliente_frecuente)
    assert resultado == pytest.approx(89.9991)  # Descuento del 10%
    assert round(resultado, 2) == 90.00        # Verifica redondeo para presentación
```

Aquí, los dos `asserts` están relacionados con el mismo comportamiento (descuento y su presentación), por lo que el test sigue siendo claro. Sin embargo, esto debe hacerse con moderación para no introducir confusión.

### 2  El principio Abierto/Cerrado (OCP)

El **Principio Abierto/Cerrado (Open/Closed Principle, OCP)** establece que un sistema debe estar **abierto para su extensión** pero **cerrado para su modificación**. 
En el contexto de pruebas unitarias, esto implica que deberíamos poder agregar nuevos casos de prueba sin necesidad de alterar el código existente de las pruebas. El ejemplo proporcionado con **pytest** y su funcionalidad de parametrización ilustra perfectamente cómo aplicar OCP en pruebas. 

### **1. Explicación detallada de un ejemplo**

El siguiente código de prueba utiliza la parametrización de **pytest** para cumplir con OCP. Vamos a desglosarlo:

```python
# tests/test_redondeo.py
import pytest
from tienda.redondeo import redondear

CASOS = [
    # cantidad, esperado
    (2.499, 2.50),
    (2.444, 2.44),
    (5.995, 6.00),  # nuevo caso agregado sin modificar el test
]

@pytest.mark.parametrize("cantidad,esperado", CASOS)
def test_redondeo_05_centimos(cantidad, esperado):
    """
    OCP: el test no cambia cuando agregamos tuplas a CASOS.
    """
    assert redondear(cantidad) == pytest.approx(esperado)
```

- **Estructura del test**: La lista `CASOS` contiene tuplas con los valores de entrada (`cantidad`) y los resultados esperados (`esperado`). El decorador `@pytest.mark.parametrize` itera sobre estas tuplas, ejecutando la función `test_redondeo_05_centimos` para cada par de valores.
- **Cumplimiento de OCP**:
  - **Abierto para extensión**: Puedes añadir nuevos casos de prueba simplemente agregando más tuplas a la lista `CASOS`. Por ejemplo, si quieres probar `redondear(3.141, 3.14)`, basta con añadir `(3.141, 3.14)` a `CASOS`.
  - **Cerrado para modificación**: No necesitas tocar la lógica de la función de prueba `test_redondeo_05_centimos`. El test sigue funcionando sin cambios en su estructura.

- **Uso de `pytest.approx`**: Esto es particularmente útil para manejar posibles imprecisiones en cálculos de punto flotante, asegurando que las comparaciones sean robustas.

**Beneficios de aplicar OCP en pruebas**
Aplicar OCP en pruebas, como en el ejemplo, tiene varias ventajas:

1. **Escalabilidad**: Puedes aumentar la cobertura de pruebas añadiendo más casos a `CASOS` sin esfuerzo adicional. Esto es ideal cuando el sistema evoluciona y necesitas probar nuevos escenarios.
2. **Mantenibilidad**: Al no modificar la lógica de la prueba, reduces el riesgo de introducir errores al actualizar los tests.
3. **Legibilidad**: La lista `CASOS` actúa como una documentación clara de los casos de prueba, haciendo que sea fácil entender qué escenarios se están cubriendo.
4. **Reusabilidad**: Puedes reutilizar la misma estructura de parametrización en otros tests, cambiando solo los datos de entrada y salida.
5. **Automatización**: Facilita la integración con herramientas de CI/CD, ya que añadir casos no requiere reescribir código.

**Extensiones del enfoque**

Para llevar este enfoque más allá y hacerlo aún más robusto, se pueden considerar las siguientes ideas:

**a. Externalizar los casos de prueba**
En lugar de mantener la lista `CASOS` en el archivo de prueba, podrías externalizar los datos a un archivo (por ejemplo, JSON, YAML o CSV) para facilitar su gestión, especialmente si hay muchos casos. Ejemplo con JSON:

```python
# tests/casos_redondeo.json
[
    {"cantidad": 2.499, "esperado": 2.50},
    {"cantidad": 2.444, "esperado": 2.44},
    {"cantidad": 5.995, "esperado": 6.00}
]
```

```python
# tests/test_redondeo.py
import pytest
import json
from tienda.redondeo import redondear

with open("casos_redondeo.json") as f:
    CASOS = [(caso["cantidad"], caso["esperado"]) for caso en json.load(f)]

@pytest.mark.parametrize("cantidad,esperado", CASOS)
def test_redondeo_05_centimos(cantidad, esperado):
    assert redondear(cantidad) == pytest.approx(esperado)
```

**Ventaja**: Los equipos no técnicos (como QA) pueden actualizar los casos de prueba sin tocar el código.

**b. Generación dinámica de casos**
Si los casos de prueba siguen un patrón, puedes generarlos dinámicamente. Por ejemplo, para probar redondeos en un rango de valores:

```python
import pytest
from tienda.redondeo import redondear

# Generar casos dinámicamente
CASOS = [(x/1000, round(x/1000, 2)) for x in range(1000, 6000, 500)]

@pytest.mark.parametrize("cantidad,esperado", CASOS)
def test_redondeo_05_centimos(cantidad, esperado):
    assert redondear(cantidad) == pytest.approx(esperado)
```

**Ventaja**: Cubre un rango amplio de valores automáticamente, ideal para pruebas exhaustivas.

**c. Clasificación de casos con etiquetas**
Puedes usar marcadores de **pytest** para clasificar casos de prueba según su propósito (por ejemplo, casos límite, casos comunes, casos de error):

```python
import pytest
from tienda.redondeo import redondear

CASOS = [
    pytest.param(2.499, 2.50, marks=pytest.mark.casos_comunes),
    pytest.param(2.444, 2.44, marks=pytest.mark.casos_comunes),
    pytest.param(5.995, 6.00, marks=pytest.mark.casos_limite),
    pytest.param(-1.0, -1.0, marks=pytest.mark.casos_error),
]

@pytest.mark.parametrize("cantidad,esperado", CASOS)
def test_redondeo_05_centimos(cantidad, esperado):
    assert redondear(cantidad) == pytest.approx(esperado)
```

**Ventaja**: Permite filtrar y ejecutar subconjuntos de pruebas con `pytest -m casos_limite`, por ejemplo.

**d. Manejo de excepciones**
Si la función `redondear` puede lanzar excepciones (por ejemplo, para entradas inválidas), puedes extender el enfoque para probar esos casos:

```python
import pytest
from tienda.redondeo import redondear

CASOS = [
    (2.499, 2.50),
    (2.444, 2.44),
    ("invalido", pytest.raises(ValueError)),  # Caso de excepción
]

@pytest.mark.parametrize("cantidad,esperado", CASOS)
def test_redondeo_05_centimos(cantidad, esperado):
    if isinstance(esperado, type) and issubclass(esperado, Exception):
        with esperado:
            redondear(cantidad)
    else:
        assert redondear(cantidad) == pytest.approx(esperado)
```

**Ventaja**: Amplía la cobertura para incluir casos de error sin modificar la lógica del test.


**Consideraciones adicionales**
- **Límites de OCP en pruebas**: Aunque la parametrización es poderosa, si la lógica de la función `redondear` cambia significativamente (por ejemplo, para manejar diferentes reglas de redondeo), podrías necesitar ajustar la función de prueba. En estos casos, OCP no elimina por completo la necesidad de modificar el código, pero minimiza el impacto.
- **Cobertura de pruebas**: Asegúrate de que `CASOS` cubra casos límite, casos comunes y casos de error. Herramientas como **pytest-cov** pueden ayudarte a verificar la cobertura.
- **Mantenimiento de datos**: Si `CASOS` crece demasiado, considera organizarlo en módulos separados o usar una base de datos para casos complejos.


### 3  Principio de Sustitución de Liskov (LSP)

El Principio de Sustitución de Liskov (LSP, por sus siglas en inglés) establece que los objetos de una clase derivada deben poder sustituir a los objetos de su clase base sin alterar el comportamiento correcto del programa. En el contexto de pruebas unitarias, esto implica que los *doubles* de prueba (como mocks, stubs, o fakes) deben comportarse de manera consistente con la interfaz de la clase real que están reemplazando. Esto asegura que las pruebas sean confiables y reflejen el comportamiento real del sistema.

**Ejemplo**

```python
# app/repositorio.py
class RepositorioDB:
    def obtener(self, id_: int) -> dict: ...
    def guardar(self, registro: dict) -> int: ...

# tests/test_servicio.py
import pytest
from unittest.mock import create_autospec
from app.servicio import ServicioNegocio
from app.repositorio import RepositorioDB

@pytest.fixture
def repo_mock():
    # LSP: el mock hereda la firma exacta de RepositorioDB
    return create_autospec(RepositorioDB, instance=True)

def test_obtener_invoca_repo(repo_mock):
    svc = ServicioNegocio(repo=repo_mock)

    repo_mock.obtener.return_value = {"id": 1, "valor": 42}
    resultado = svc.obtener_transformado(1)

    repo_mock.obtener.assert_called_once_with(1)
    assert resultado == 84  # lógica de negocio duplica el valor
```

En el ejemplo proporcionado, se utiliza `create_autospec` de la biblioteca `unittest.mock` en Python para garantizar que el mock respete la interfaz de la clase `RepositorioDB`. Si la firma real cambia (p. ej. `id` --> `identificador`), el mock detectará de inmediato el error, garantizando que **LSP** se respeta.

**Contexto del ejemplo y aplicación del LSP**

En el código, la clase `RepositorioDB` define una interfaz con dos métodos:
- `obtener(id_: int) -> dict`: Recibe un identificador entero y devuelve un diccionario.
- `guardar(registro: dict) -> int`: Recibe un diccionario y devuelve un entero.

El mock generado con `create_autospec(RepositorioDB, instance=True)` crea un objeto que imita exactamente la firma de los métodos de `RepositorioDB`. Esto significa que:
- El mock solo permitirá llamadas a métodos que existen en `RepositorioDB`.
- Las firmas de los métodos (nombres, parámetros, tipos de retorno implícitos) serán respetadas.
- Si se intenta llamar a un método inexistente o con argumentos incorrectos, el mock lanzará un error en tiempo de prueba.

Por ejemplo, en el test `test_obtener_invoca_repo`:
- Se configura el mock para que `repo_mock.obtener(1)` devuelva `{"id": 1, "valor": 42}`.
- Se verifica que el método `obtener` del mock fue llamado con el argumento correcto (`1`).
- La lógica de negocio en `ServicioNegocio` duplica el valor (42 → 84), y el test valida este comportamiento.

El uso de `autospec=True` asegura que cualquier cambio en la interfaz de `RepositorioDB` (por ejemplo, renombrar `obtener` a `buscar` o cambiar el tipo de `id_` a `str`) romperá el test de inmediato, alertando al desarrollador sobre una violación potencial del LSP.


**¿Por qué es importante respetar el LSP en pruebas?**

El LSP en pruebas garantiza que los *doubles* de prueba sean representaciones fieles de los objetos reales. Esto es crucial por las siguientes razones:

- **Consistencia con el comportamiento real**: Si el mock no respeta la interfaz real, las pruebas podrían pasar incluso si el código no funcionaría en un entorno real. Por ejemplo, si el mock permite llamar a `obtener` con un string (`"1"`) cuando la implementación real solo acepta enteros, el test podría dar un falso positivo.
  
- **Detección temprana de errores**: Al usar `autospec`, cualquier cambio en la interfaz de la clase real (como un cambio en la firma de un método) se detecta inmediatamente en las pruebas, evitando que se introduzcan errores sutiles en el código de producción.

- **Mantenimiento del contrato**: El LSP asegura que el contrato definido por la clase base (o interfaz) se mantenga. En el ejemplo, `ServicioNegocio` espera que cualquier implementación de `RepositorioDB` cumpla con la interfaz definida. Si el mock no respeta este contrato, las pruebas no serían confiables.

**Ejemplo de violación del LSP y consecuencias**

Supongamos que modificamos la interfaz de `RepositorioDB` sin actualizar el mock o el código del test:

```python
# Nueva versión de RepositorioDB
class RepositorioDB:
    def obtener(self, identificador: str) -> dict: ...  # Cambio de id_ (int) a identificador (str)
    def guardar(self, registro: dict) -> int: ...
```

Si no usáramos `create_autospec`, un mock manual como el siguiente podría no detectar el cambio:

```python
from unittest.mock import Mock

@pytest.fixture
def repo_mock():
    repo = Mock()
    repo.obtener = Mock(return_value={"id": 1, "valor": 42})
    return repo
```

En este caso, el test seguiría pasando incluso si `ServicioNegocio` llama a `obtener(1)` (con un entero) en lugar de `obtener("1")` (con un string), lo que violaría el LSP porque el mock no respeta la nueva interfaz.

Con `create_autospec`, el test fallaría inmediatamente porque el mock detectaría que `obtener` espera un string y no un entero, forzando al desarrollador a actualizar el código de `ServicioNegocio` para cumplir con la nueva interfaz.

**Ventajas de usar `create_autospec`**

- **Validación estricta de la interfaz**: `create_autospec` asegura que el mock solo exponga los métodos definidos en la clase original y que las firmas de esos métodos sean respetadas.
- **Reducción de errores manuales**: Sin `autospec`, los mocks manuales pueden ser propensos a errores, como olvidar un método o configurar una firma incorrecta.
- **Mantenimiento simplificado**: Cuando la interfaz cambia, los tests fallan automáticamente, lo que facilita la refactorización y asegura que el código se mantenga alineado con el contrato.

**Casos prácticos adicionales**

**Caso 1: Agregar un nuevo método a la interfaz**
Imagina que se agrega un nuevo método a `RepositorioDB`:

```python
class RepositorioDB:
    def obtener(self, id_: int) -> dict: ...
    def guardar(self, registro: dict) -> int: ...
    def eliminar(self, id_: int) -> None: ...  # Nuevo método
```

Si el test intenta llamar a `repo_mock.eliminar` sin que este método esté configurado, o si el mock no está creado con `create_autospec`, podría no reflejar la nueva interfaz. Con `create_autospec`, el mock incluirá automáticamente el método `eliminar`, y cualquier llamada incorrecta (por ejemplo, pasar un string en lugar de un entero) fallará.

**Caso 2: Cambiar el tipo de retorno**
Supongamos que `obtener` ahora devuelve una lista en lugar de un diccionario:

```python
class RepositorioDB:
    def obtener(self, id_: int) -> list: ...
    def guardar(self, registro: dict) -> int: ...
```

Si `ServicioNegocio` asume que `obtener` devuelve un diccionario y usa algo como `resultado["valor"]`, el test fallará si el mock está configurado para devolver una lista, reflejando el comportamiento real y alertando sobre la necesidad de actualizar la lógica de negocio.

**Mejores prácticas para aplicar LSP en pruebas**

1. **Siempre usa `create_autospec` para mocks de clases o interfaces**: Esto garantiza que el mock sea un sustituto válido según el LSP.
2. **Configura retornos realistas**: Asegúrate de que los valores de retorno del mock sean representativos de lo que la implementación real devolvería. Por ejemplo, si `obtener` devuelve `{"id": 1, "valor": 42}`, el mock debe devolver un diccionario con la misma estructura.
3. **Valida las interacciones con `assert_called_once_with`**: Esto asegura que el mock fue usado correctamente, respetando la interfaz esperada.
4. **Documenta cambios en la interfaz**: Si cambias la interfaz de una clase como `RepositorioDB`, actualiza los tests y verifica que todos los mocks reflejen los cambios.
5. **Considera el uso de interfaces explícitas**: En Python, puedes usar `abc.ABC` para definir interfaces abstractas, lo que refuerza el cumplimiento del LSP al obligar a las implementaciones a seguir un contrato claro.

**Código de ejemplo ampliado**

Aquí hay una versión ampliada del test que incluye más validaciones y un caso adicional para ilustrar el LSP:

```python
# app/repositorio.py
from abc import ABC, abstractmethod

class Repositorio(ABC):
    @abstractmethod
    def obtener(self, id_: int) -> dict:
        pass

    @abstractmethod
    def guardar(self, registro: dict) -> int:
        pass

class RepositorioDB(Repositorio):
    def obtener(self, id_: int) -> dict:
        # Implementación real
        pass

    def guardar(self, registro: dict) -> int:
        # Implementación real
        pass

# app/servicio.py
class ServicioNegocio:
    def __init__(self, repo: Repositorio):
        self.repo = repo

    def obtener_transformado(self, id_: int) -> int:
        data = self.repo.obtener(id_)
        return data["valor"] * 2

# tests/test_servicio.py
import pytest
from unittest.mock import create_autospec
from app.servicio import ServicioNegocio
from app.repositorio import RepositorioDB

@pytest.fixture
def repo_mock():
    return create_autospec(RepositorioDB, instance=True)

def test_obtener_invoca_repo(repo_mock):
    svc = ServicioNegocio(repo=repo_mock)
    repo_mock.obtener.return_value = {"id": 1, "valor": 42}
    
    resultado = svc.obtener_transformado(1)
    
    repo_mock.obtener.assert_called_once_with(1)
    assert resultado == 84

def test_falla_si_interfaz_cambia(repo_mock):
    # Simulando un cambio en la interfaz (obtener espera un string)
    with pytest.raises(TypeError):
        repo_mock.obtener("1")  # Error: obtener espera un int
```

En este ejemplo:
- Se usa una interfaz abstracta (`Repositorio`) para reforzar el contrato.
- El segundo test verifica que el mock respeta el tipo de parámetro (`int`), fallando si se pasa un tipo incorrecto (`str`), lo que demuestra cómo `create_autospec` ayuda a cumplir con el LSP.

### 4  Principio de Segregación de Interfaces (ISP)

El ISP en pruebas implica que cada fixture debe tener una **responsabilidad única** y proporcionar solo lo que un test específico necesita. Esto contrasta con la creación de una "mega-fixture" que incluye todo (base de datos, usuarios, clientes HTTP, configuraciones de entorno, etc.), lo que forzaría a los tests a depender de configuraciones irrelevantes, aumentando la complejidad y el acoplamiento.

En lugar de una mega-*fixture*, se crean piezas pequeñas y composables:

```python
# tests/conftest.py
import pytest
from tienda.models import Usuario
from tienda.db import SessionLocal

@pytest.fixture
def conexion_bd():
    """Solo abre una sesión de BD; nada más."""
    db = SessionLocal()
    yield db
    db.close()

@pytest.fixture
def usuario_autenticado(conexion_bd):
    """Crea un usuario y lo devuelve logueado."""
    user = Usuario(nombre="Ana")
    conexion_bd.add(user)
    conexion_bd.commit()
    return user

@pytest.fixture
def cliente_http(app):    # fixture que monta FastAPI TestClient
    from fastapi.testclient import TestClient
    return TestClient(app)
```

En el ejemplo proporcionado, las fixtures están diseñadas de manera modular:

1. **`conexion_bd`**: Proporciona únicamente una sesión de base de datos. Es una interfaz mínima, ideal para tests que solo necesitan interactuar con la base de datos.
2. **`usuario_autenticado`**: Depende de `conexion_bd` y añade la creación de un usuario autenticado. Es útil para tests que requieren un usuario en la base de datos.
3. **`cliente_http`**: Proporciona un cliente HTTP para interactuar con la aplicación FastAPI, sin necesidad de involucrar la base de datos o usuarios.

Este diseño permite **componer** fixtures según las necesidades específicas de cada test, cumpliendo con el ISP al evitar que los tests dependan de funcionalidades que no usan.

**Beneficios de aplicar ISP en fixtures**

1. **Modularidad**: Cada fixture tiene una responsabilidad clara y limitada, lo que facilita su reutilización y combinación.
2. **Reducción de acoplamiento**: Los tests solo consumen las fixtures que necesitan, evitando dependencias innecesarias.
3. **Mantenibilidad**: Si necesitas modificar la lógica de conexión a la base de datos, solo cambias `conexion_bd`, sin afectar otras fixtures.
4. **Eficiencia**: Al evitar configuraciones innecesarias (como crear usuarios o clientes HTTP cuando no son necesarios), los tests se ejecutan más rápido.
5. **Claridad**: Los nombres específicos de las fixtures (`conexion_bd`, `usuario_autenticado`, `cliente_http`) indican claramente su propósito, haciendo que los tests sean más legibles.

**Ejemplo práctico de uso**

Imagina que tienes dos tipos de tests: uno que verifica la lectura de datos desde la base de datos y otro que prueba endpoints de la API que requieren autenticación. Veamos cómo se combinan las fixtures según las necesidades:

```python
# tests/test_lectura_datos.py
def test_leer_datos(conexion_bd):
    """Test que solo necesita leer datos de la base de datos."""
    resultado = conexion_bd.query(Usuario).all()
    assert len(resultado) == 0  # Verifica que no hay usuarios inicialmente

# tests/test_api.py
def test_endpoint_con_autenticacion(cliente_http, usuario_autenticado):
    """Test que necesita un usuario autenticado y un cliente HTTP."""
    headers = {"Authorization": f"Bearer {usuario_autenticado.id}"}
    respuesta = cliente_http.get("/recurso_protegido", headers=headers)
    assert respuesta.status_code == 200
```

En el primer test, solo se usa `conexion_bd`, ya que no se necesita un usuario ni un cliente HTTP. En el segundo, se combinan `cliente_http` y `usuario_autenticado` para probar un endpoint protegido. Esto demuestra cómo las fixtures segregadas permiten a los tests depender solo de lo que necesitan, cumpliendo con el ISP.

**Ampliando el ejemplo: más fixtures específicas**

Podemos extender el diseño para cubrir otros casos comunes en pruebas, manteniendo el principio de segregación de interfaces. Por ejemplo:

```python
# tests/conftest.py

@pytest.fixture
def usuario_admin(conexion_bd):
    """Crea un usuario con rol de administrador."""
    admin = Usuario(nombre="Admin", rol="admin")
    conexion_bd.add(admin)
    conexion_bd.commit()
    return admin

@pytest.fixture
def datos_prueba(conexion_bd):
    """Crea un conjunto de datos de prueba en la base de datos."""
    usuarios = [Usuario(nombre=f"User{i}") for i in range(3)]
    conexion_bd.add_all(usuarios)
    conexion_bd.commit()
    return usuarios

@pytest.fixture
def cliente_autenticado(cliente_http, usuario_autenticado):
    """Devuelve un cliente HTTP con autenticación configurada."""
    cliente_http.headers.update({"Authorization": f"Bearer {usuario_autenticado.id}"})
    return cliente_http
```

- **`usuario_admin`**: Proporciona un usuario con permisos de administrador, útil para probar funcionalidades restringidas.
- **`datos_prueba`**: Crea datos genéricos para pruebas que necesitan un entorno poblado.
- **`cliente_autenticado`**: Combina el cliente HTTP con un usuario autenticado, útil para pruebas de endpoints protegidos.

Estos ejemplos refuerzan el ISP al mantener cada fixture enfocada en una tarea específica. Un test que necesita un cliente autenticado no tiene que preocuparse por cómo se configura la autenticación; simplemente usa `cliente_autenticado`.

**Antipatrones a evitar**

1. **Mega-fixture**: Crear una sola fixture que configure todo (base de datos, usuarios, clientes HTTP, etc.) viola el ISP porque fuerza a los tests a depender de configuraciones que no siempre necesitan.
   ```python
   # Antipatrón: una fixture que hace demasiado
   @pytest.fixture
   def entorno_completo():
       db = SessionLocal()
       user = Usuario(nombre="Ana")
       db.add(user)
       db.commit()
       client = TestClient(app)
       client.headers.update({"Authorization": f"Bearer {user.id}"})
       yield db, user, client
       db.close()
   ```
   Esto obliga a los tests a desempaquetar un tuple (`db, user, client`) incluso si solo necesitan uno de los elementos, lo que aumenta el acoplamiento.

2. **Dependencias implícitas**: Si una fixture asume que otra siempre estará presente sin declararla explícitamente, puede generar errores difíciles de depurar.

3. **Nombres genéricos**: Usar nombres como `setup` o `test_env` en lugar de `conexion_bd` o `usuario_autenticado` reduce la claridad sobre el propósito de la fixture.


**Consejos para aplicar ISP en pruebas**

1. **Identifica las necesidades mínimas de cada test**: Antes de escribir una fixture, pregunta qué necesita específicamente el test. Por ejemplo, ¿requiere una base de datos vacía, datos predefinidos, un usuario autenticado, o un cliente HTTP?
2. **Usa nombres descriptivos**: Los nombres de las fixtures deben reflejar claramente su propósito (`conexion_bd` en lugar de `db`).
3. **Aprovecha la composición**: Diseña fixtures que puedan combinarse fácilmente. Por ejemplo, `cliente_autenticado` combina `cliente_http` y `usuario_autenticado`.
4. **Limpieza adecuada**: Asegúrate de que las fixtures manejen la limpieza (como cerrar conexiones a la base de datos) para evitar efectos secundarios entre tests.
5. **Revisa periódicamente**: A medida que el proyecto crece, revisa si las fixtures siguen siendo específicas o si se han convertido en "mega-fixtures" accidentalmente.

### 5  Principio de Inversion de Dependencias (DIP)

El **Principio de Inversión de Dependencia (DIP)** es uno de los cinco principios SOLID en el diseño de software orientado a objetos. En resumen, establece que:

- Las clases de alto nivel (como servicios o lógica de negocio) no deben depender de clases de bajo nivel (como implementaciones concretas de repositorios o bases de datos). Ambas deben depender de **abstracciones** (interfaces o protocolos).
- Las abstracciones no deben depender de los detalles; los detalles deben depender de las abstracciones.

Esto invierte la dependencia tradicional, donde el código de alto nivel "conoce" los detalles de implementación, lo que hace el sistema más rígido y difícil de probar o mantener.

**Ejemplo**

El código de producción depende de abstracciones y los tests inyectan implementaciones concretas o *fakes*.

```python
# dominio/puertos.py
from abc import ABC, abstractmethod
from typing import Protocol

class IRepositorioMensajes(Protocol):
    @abstractmethod
    def guardar(self, mensaje: str) -> None: ...
    @abstractmethod
    def obtener_todos(self) -> list[str]: ...

# infraestructura/repos_sqlite.py
import sqlite3
from dominio.puertos import IRepositorioMensajes

class RepoSQLite(IRepositorioMensajes):
    ...

# servicio.py
from dominio.puertos import IRepositorioMensajes

class ServicioMensajeria:
    def __init__(self, repo: IRepositorioMensajes):
        self._repo = repo

    def publicar(self, msg: str) -> None:
        self._repo.guardar(msg.upper())

# tests/test_servicio_mensajeria.py
from dominio.puertos import IRepositorioMensajes
from servicio import ServicioMensajeria

class RepoEnMemoria(IRepositorioMensajes):
    def __init__(self):
        self._datos: list[str] = []
    def guardar(self, mensaje: str) -> None:
        self._datos.append(mensaje)
    def obtener_todos(self):
        return self._datos

def test_publicar_mayusculas():
    repo = RepoEnMemoria()
    svc  = ServicioMensajeria(repo)

    svc.publicar("hola devops")
    assert repo.obtener_todos() == ["HOLA DEVOPS"]
```

En el contexto de **pruebas unitarias** (como en el ejemplo), el DIP brilla especialmente porque facilita la **aislamiento de dependencias**. 

**Recapitulando el ejemplo proporcionado**

En el código:

- **Abstracción**: `IRepositorioMensajes` es un protocolo (o interfaz) que define métodos como `guardar` y `obtener_todos`, sin implementación concreta.
- **Implementación de producción**: `RepoSQLite` implementa esta abstracción usando SQLite (un detalle de infraestructura real).
- **Código de alto nivel**: `ServicioMensajeria` depende solo de la abstracción (`IRepositorioMensajes`), no de `RepoSQLite`. Recibe la dependencia via inyección en el constructor (`__init__`).
- **En pruebas**: Creamos un **fake** o **mock** en memoria (`RepoEnMemoria`), que también implementa la abstracción. Lo inyectamos en el servicio para probar `publicar` sin tocar una base de datos real.

Esto demuestra DIP: El servicio no "sabe" si el repositorio es SQLite, un servicio en la nube como DynamoDB, o un fake temporal. Solo interactúa con la interfaz.

En la prueba `test_publicar_mayusculas`:
- Inyectamos `RepoEnMemoria`.
- Ejecutamos `publicar("hola devops")`.
- Verificamos que el fake tenga `["HOLA DEVOPS"]`, confirmando que el servicio transforma el mensaje a mayúsculas sin efectos secundarios reales (como escribir en disco).

**Beneficios del DIP en Pruebas**

Aplicar DIP en pruebas no solo hace el código más modular, sino que resuelve problemas comunes en testing. Aquí detallo más:

- **Aislamiento de dependencias externas**:
  - Sin DIP, el servicio podría instanciar directamente `RepoSQLite` dentro de su constructor o métodos. Esto obligaría a las pruebas a usar una base de datos real, lo que introduce dependencias externas (por ejemplo, conexión a BD, archivos en disco). Resultado: Pruebas lentas, frágiles (si la BD falla, la prueba falla) y no unitarias (se convierten en integraciones).
  - Con DIP, inyectamos fakes: Las pruebas se enfocan solo en la lógica del servicio, ignorando el mundo real. En tu ejemplo, `RepoEnMemoria` es un "doble de prueba" (test double) que simula el comportamiento sin side-effects.

- **Velocidad y eficiencia**:
  - Fakes en memoria (como listas o diccionarios) son rápidos. Una prueba con SQLite podría tomar milisegundos por consulta; con un fake, es instantáneo. Ideal para TDD (Test-Driven Development) donde ejecutas pruebas frecuentemente.
  - Ejemplo extendido: Si tu repositorio involucra redes (por ejemplo, una API externa), un fake evita llamadas HTTP reales, reduciendo tiempo y costos (por ejemplo, no consumes cuotas de API en pruebas).

- **Control total sobre el comportamiento**:
  - Puedes simular escenarios edge-case fácilmente. Por ejemplo, en `RepoEnMemoria`, podrías agregar lógica para simular errores:
    ```python
    class RepoEnMemoria(IRepositorioMensajes):
        def __init__(self, simular_error=False):
            self._datos: list[str] = []
            self._simular_error = simular_error

        def guardar(self, mensaje: str) -> None:
            if self._simular_error:
                raise ValueError("Error simulado en almacenamiento")
            self._datos.append(mensaje)

        def obtener_todos(self):
            return self._datos
    ```
    En una prueba:
    ```python
    def test_publicar_con_error():
        repo = RepoEnMemoria(simular_error=True)
        svc = ServicioMensajeria(repo)
        with pytest.raises(ValueError):  # Asumiendo uso de pytest
            svc.publicar("test")
    ```
    Esto prueba manejo de errores sin configurar una BD real para fallar.

- **Facilita Mocks y Stubs**:
  - Usando bibliotecas como `unittest.mock` o `pytest-mock`, puedes crear mocks dinámicos basados en la interfaz:
    ```python
    from unittest.mock import MagicMock

    def test_publicar_con_mock():
        repo_mock = MagicMock(spec=IRepositorioMensajes)
        svc = ServicioMensajeria(repo_mock)
        svc.publicar("hola")
        repo_mock.guardar.assert_called_once_with("HOLA")
    ```
    Aquí, no implementas un fake completo; el mock verifica llamadas sin almacenar datos reales.

- **Mejora la cobertura y mantenibilidad**:
  - Pruebas unitarias puras aumentan la cobertura de código (por ejemplo, via herramientas como coverage.py).
  - Si cambias la implementación real (por ejemplo, de SQLite a MongoDB), las pruebas no se rompen porque dependen de la abstracción.

**Alternativas y extensiones**

- **Sin DIP**: Dependencia directa, por ejemplo, `self._repo = RepoSQLite()`. Pruebas requieren monkey-patching (sobrescribir clases en runtime), lo que es frágil y menos legible.
- **Inyección de dependencias (DI) avanzada**: Usa frameworks como `dependency_injector` o `inject` para automatizar la inyección. En pruebas, configuras un contenedor que inyecta fakes automáticamente.
- **Pruebas de integración**: DIP no elimina la necesidad de pruebas integradas (por ejemplo, con SQLite real). Usa DIP para unitarias rápidas, y pruebas integradas para validar la implementación concreta.
- **En Otros Lenguajes**: En Java, usarías interfaces y Spring para DI. En Go, interfaces implícitas. El principio es universal.

**Posibles pitfalls y mejores prácticas**

- **Sobreabstracción**: No abstraigas todo. Solo dependencias volátiles (por ejemplo, BD, APIs). Si el repositorio nunca cambia, podría ser overkill.
- **Leak de abstracciones**: Asegúrate que la interfaz no exponga detalles de implementación (por ejemplo, no agregues métodos específicos de SQLite como `ejecutar_query_sql`).
- **Testing de fakes**: Prueba los fakes si son complejos, pero manténlos simples.
- **Escalabilidad**: En apps grandes, usa capas (dominio, aplicación, infraestructura) como en Clean Architecture, donde DIP es central.

### 6  Métricas y disciplina DevOps (cobertura, *flakiness*, *benchmark*)

En un entorno DevOps, las métricas son esenciales para garantizar la calidad del software y la estabilidad del pipeline. Las herramientas como **pytest-cov** y **pytest-benchmark** no solo facilitan la medición, sino que también permiten establecer umbrales que actúan como *gates* automáticos en el pipeline CI/CD. A continuación, detallo cómo implementar y optimizar estas métricas, incluyendo estrategias para manejar *flakiness* y ejemplos prácticos.

#### Cobertura de código
La cobertura mide el porcentaje de código ejecutado durante las pruebas, pero debe usarse con cuidado para evitar falsos positivos (pruebas que pasan sin validar comportamiento). El ejemplo proporcionado en el `pyproject.toml` establece un umbral de **80 %**, pero se puede mejorar:

- **Cobertura por ramas**: Además de la cobertura de líneas, herramientas como **coverage.py** permiten medir la cobertura de ramas (`--cov-branch`), lo que asegura que se prueban todas las rutas lógicas (condiciones, bucles, etc.).
- **Exclusión selectiva**: Excluye código que no necesita pruebas (ejemplo: configuraciones, logging) para evitar inflar métricas. Ejemplo:
  ```ini
  [tool.coverage.run]
  omit = [
      "*/__init__.py",
      "*/config/*",
      "*/logging/*"
  ]
  ```
- **Integración con CI/CD**: En herramientas como GitHub Actions o GitLab CI, configura un paso que falle si la cobertura cae por debajo del umbral. Ejemplo para GitHub Actions:
  ```yaml
  name: CI Pipeline
  on: [push, pull_request]
  jobs:
    test:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v3
        - name: Install dependencies
          run: pip install pytest pytest-cov
        - name: Run tests with coverage
          run: pytest --cov=tienda --cov-report=xml --cov-report=term-missing
        - name: Check coverage threshold
          run: coverage report --fail-under=80
  ```

#### Flakiness (Pruebas inestables)
Las pruebas inestables (*flaky tests*) son un problema común que afecta la confianza en el pipeline. Una prueba es *flaky* si pasa o falla de forma no determinista. 

Algunas estrategias para mitigarlas son:

- **Aislamiento de pruebas**: Usa fixtures de pytest para garantizar que cada prueba tenga un entorno limpio. Ejemplo:
  ```python
  import pytest

  @pytest.fixture
  def clean_db(tmp_path):
      db = setup_database(tmp_path)
      yield db
      db.clear()  # Limpieza después de cada prueba
  ```
- **Reintentos controlados**: Usa `pytest-rerunfailures` para reintentar pruebas fallidas automáticamente, pero con un límite. Configuración en `pyproject.toml`:
  ```ini
  [tool.pytest.ini_options]
  addopts = "--reruns 2 --reruns-delay 1"
  ```
- **Detección de flakiness**: Herramientas como `pytest-flakefinder` ejecutan las pruebas múltiples veces para identificar inestabilidad. Ejemplo:
  ```bash
  pytest --flake-finder --flake-runs=10
  ```
- **Trazabilidad**: Registra logs detallados para identificar la causa de la inestabilidad (por ejemplo, problemas de red, concurrencia). Usa `logging` en lugar de `print` para facilitar el análisis.

#### Benchmarks de rendimiento
Los benchmarks miden el rendimiento de funciones críticas, como en el ejemplo de `test_algoritmo_benchmark`. Para hacerlo más robusto:

- **Umbrales de rendimiento**: Define un límite máximo de tiempo para la ejecución de funciones críticas. Ejemplo con `pytest-benchmark`:
  ```python
  def test_algoritmo_benchmark_with_threshold(benchmark):
      resultado = benchmark.pedantic(algoritmo_costoso, args=(10_000,), rounds=10, iterations=5)
      assert resultado > 0
      assert benchmark.stats.total < 0.5  # Falla si tarda más de 0.5 segundos
  ```
- **Comparación histórica**: Usa `--benchmark-save` para almacenar resultados de benchmarks y compararlos entre ejecuciones:
  ```bash
  pytest --benchmark-save=baseline --benchmark-compare=baseline
  ```
- **Pipeline de CI/CD**: Integra benchmarks en el pipeline para detectar degradaciones de rendimiento. Ejemplo en GitHub Actions:
  ```yaml
  - name: Run benchmarks
    run: pytest --benchmark-enable --benchmark-json=benchmark_results.json
  - name: Upload benchmark results
    uses: actions/upload-artifact@v3
    with:
      name: benchmark-results
      path: benchmark_results.json
  ```

####  Automatización en el pipeline

Para mantener la disciplina DevOps, el pipeline debe ser el guardián de la calidad. Configura *gates* automáticos para:
- **Cobertura**: Bloquea el merge si la cobertura cae por debajo del umbral.
- **Flakiness**: Falla el pipeline si una prueba es identificada como inestable tras múltiples ejecuciones.
- **Rendimiento**: Rechaza cambios si un benchmark muestra una degradación significativa (por ejemplo, >10 % más lento que el baseline).

Ejemplo avanzado de pipeline con todos estos elementos:

```yaml
name: Quality Gates
on: [pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: pip install pytest pytest-cov pytest-benchmark pytest-rerunfailures
      - name: Run tests with coverage and benchmarks
        run: pytest --cov=tienda --cov-report=xml --benchmark-enable --reruns 2
      - name: Check coverage
        run: coverage report --fail-under=80
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: |
            coverage.xml
            benchmark_results.json
```

#### Refactor progresivo de suites heredadas

Refactorizar una suite de pruebas heredada con 2000 pruebas acopladas y lentas es un desafío, pero la estrategia **Boy-Scout** (dejar el código mejor de lo que se encontró) permite modernizarla incrementalmente sin interrumpir el desarrollo. 

Los pasos de esta estrategia son:

#### 1. Identificar y mapear pruebas (Paso 1)
Cada vez que se modifica un módulo, identifica las pruebas asociadas. Usa herramientas como `pytest --collect-only` para listar las pruebas y grep para filtrarlas por módulo:
```bash
pytest --collect-only | grep "test_modulo_a"
```
Si las pruebas no están bien organizadas, usa `pytest --durations=10` para identificar las más lentas y priorizar su refactorización.

#### 2. Dividir en funciones independientes (SRP)

El principio de responsabilidad única implica que cada prueba debe validar un solo comportamiento. Ejemplo de refactorización:
```python
# Antes: Prueba monolítica
def test_procesar_pedido():
    pedido = crear_pedido()
    assert procesar_pedido(pedido) == "éxito"
    assert enviar_notificacion(pedido) == "enviado"
    assert actualizar_inventario(pedido) == "actualizado"

# Después: Pruebas independientes
def test_procesar_pedido_valida_estado():
    pedido = crear_pedido()
    assert procesar_pedido(pedido) == "éxito"

def test_enviar_notificacion_pedido():
    pedido = crear_pedido()
    assert enviar_notificacion(pedido) == "enviado"

def test_actualizar_inventario_pedido():
    pedido = crear_pedido()
    assert actualizar_inventario(pedido) == "actualizado"
```

#### 3 Parametrizar pruebas (OCP)
Parametriza las pruebas para cubrir múltiples casos sin duplicar código, haciendo el código extensible. Ejemplo con `pytest.mark.parametrize`:
```python
import pytest

@pytest.mark.parametrize("cantidad, esperado", [
    (1, "éxito"),
    (0, "error: cantidad inválida"),
    (-1, "error: cantidad negativa"),
])
def test_procesar_pedido_cantidades(cantidad, esperado):
    pedido = crear_pedido(cantidad=cantidad)
    assert procesar_pedido(pedido) == esperado
```

#### 4 Sustituir dobles con Autospec (LSP)
Usa `unittest.mock` con `autospec=True` para crear dobles que respeten la interfaz del objeto real, evitando errores por mocks mal configurados. Ejemplo:
```python
from unittest.mock import Mock, create_autospec
from tienda import ServicioNotificaciones

def test_procesar_pedido_con_notificacion():
    servicio = create_autospec(ServicioNotificaciones)
    pedido = crear_pedido()
    resultado = procesar_pedido_con_notificacion(pedido, servicio)
    assert resultado == "éxito"
    servicio.enviar.assert_called_once_with(pedido)
```

#### 5 Extraer fixtures granulares (ISP)
Crea fixtures específicas para cada necesidad, evitando dependencias innecesarias. Ejemplo:
```python
@pytest.fixture
def pedido_basico():
    return crear_pedido(cantidad=1)

@pytest.fixture
def servicio_notificaciones_mock():
    return create_autospec(ServicioNotificaciones)

def test_procesar_pedido_con_notificacion(pedido_basico, servicio_notificaciones_mock):
    resultado = procesar_pedido_con_notificacion(pedido_basico, servicio_notificaciones_mock)
    assert resultado == "éxito"
    servicio_notificaciones_mock.enviar.assert_called_once_with(pedido_basico)
```

#### 6. Inyectar dependencias con protocolos (DIP)

Usa protocolos (o interfaces en Python con `typing.Protocol`) para definir contratos claros y facilitar la inyección de dependencias. Ejemplo:
```python
from typing import Protocol

class Notificador(Protocol):
    def enviar(self, pedido) -> str:
        pass

def procesar_pedido_con_notificacion(pedido, notificador: Notificador) -> str:
    resultado = procesar_pedido(pedido)
    if resultado == "éxito":
        notificador.enviar(pedido)
    return resultado

# Prueba
def test_procesar_pedido_con_notificador(pedido_basico, servicio_notificaciones_mock):
    resultado = procesar_pedido_con_notificacion(pedido_basico, servicio_notificaciones_mock)
    assert resultado == "éxito"
    servicio_notificaciones_mock.enviar.assert_called_once_with(pedido_basico)
```

**Progreso incremental por Sprint**

- **Priorización**: Usa métricas como la duración de las pruebas (`pytest --durations=0`) o la cobertura para identificar los módulos más problemáticos.
- **Automatización de detección**: Integra herramientas como `flake8` o `pylint` para detectar código acoplado o complejo antes del refactor.
- **Documentación**: Mantén un registro de los módulos refactorizados en un archivo `REFACTOR.md` para rastrear el progreso.
- **Pruebas de regresión**: Ejecuta la suite completa tras cada refactor para garantizar que no se introducen errores.

Ejemplo de progreso por sprint:

1. **Sprint 1**: Refactoriza 10 % de las pruebas más lentas, dividiéndolas según SRP.
2. **Sprint 2**: Parametriza el 20 % de las pruebas unitarias.
3. **Sprint 3**: Sustituye mocks manuales por `autospec` en el 30 % de las pruebas de integración.
4. **Sprint 4**: Introduce fixtures granulares para el 50 % de los módulos críticos.


#### **Conexión entre métricas y refactorización**

Las métricas y la refactorización están intrínsecamente ligadas:

- **Cobertura**: Una suite refactorizada con pruebas granulares y parametrizadas mejora la cobertura sin inflar el número de pruebas.
- **Flakiness**: Al aislar pruebas y usar fixtures, se reduce la inestabilidad.
- **Benchmarks**: Las pruebas refactorizadas son más rápidas, lo que facilita la ejecución de benchmarks en el pipeline.

Ejemplo de cómo una prueba refactorizada mejora las métricas:
```python
# Antes: Prueba lenta y acoplada
def test_sistema_completo():
    db = setup_db()
    pedido = crear_pedido(db)
    assert procesar_pedido(pedido) == "éxito"
    assert db.get_inventario() == 99
    cleanup_db(db)

# Después: Prueba rápida, aislada y parametrizada
@pytest.fixture
def db_inventario(tmp_path):
    db = setup_db(tmp_path)
    yield db
    db.clear()

@pytest.mark.parametrize("cantidad, inventario_esperado", [(1, 99), (2, 98)])
def test_procesar_pedido_actualiza_inventario(db_inventario, cantidad, inventario_esperado):
    pedido = crear_pedido(cantidad=cantidad)
    assert procesar_pedido(pedido, db_inventario) == "éxito"
    assert db_inventario.get_inventario() == inventario_esperado
```
**Beneficios**:
- **Cobertura**: Cubre múltiples casos con una sola prueba.
- **Flakiness**: El fixture `db_inventario` garantiza un entorno limpio.
- **Rendimiento**: Menos setup/teardown, lo que reduce el tiempo de ejecución.


### 7 Inversión de dependencias (DIP)

La **Inversión de Dependencias (DIP)** es un pilar del diseño de software que invierte el flujo tradicional de dependencias, haciendo que las capas de alto nivel (como reglas de negocio y servicios de aplicación) dependan de abstracciones en lugar de implementaciones concretas. Esto se traslada a un punto de ensamblaje externo, como un contenedor de inyección de dependencias (DI). 

En ecosistemas DevOps y DevSecOps, donde las aplicaciones se reconstruyen en contenedores efímeros múltiples veces al día, DIP facilita el reemplazo de componentes críticos (bases de datos, servicios de mensajería, gateways externos) sin alterar las reglas de negocio ni los tests que las validan. Además, en un enfoque DevSecOps, DIP integra prácticas de seguridad desde el inicio, permitiendo pruebas automatizadas de vulnerabilidades, configuraciones seguras y detección temprana de riesgos.

**Beneficios avanzados de DIP en pruebas**

1. **Desacoplamiento para escalabilidad y resiliencia**  
   DIP permite que los tests sean independientes de la infraestructura real, facilitando la escalabilidad en entornos cloud-native. Por ejemplo, en un microservicio que depende de un servicio de autenticación externo, DIP inyecta una abstracción que puede ser un mock local en desarrollo o un servicio real en producción, reduciendo tiempos de ejecución y costos.

2. **Facilitación de pruebas no funcionales**  
   Más allá de las pruebas unitarias, DIP soporta pruebas de rendimiento, carga y estrés al inyectar dependencias configurables, como clientes HTTP con límites de tasa o simuladores de latencia.

3. **Reducción de riesgos en migraciones**  
   Durante migraciones (por ejemplo, de monolith a microservicios), DIP permite ejecutar tests en paralelo contra versiones antiguas y nuevas de dependencias, minimizando downtime y regresiones.

4. **Soporte para entornos híbridos**  
   En setups híbridos (on-premise + cloud), DIP abstrae diferencias, permitiendo que los mismos tests funcionen en ambos sin modificaciones.

**Fixtures como mecanismo de inyección de dependencias en Pytest**

Pytest implementa DI mediante fixtures, resolviendo dependencias automáticamente en tiempo de ejecución. Cada parámetro en la firma de un test se resuelve como una fixture, materializando DIP al enfocarse en *qué* se necesita, no en *cómo* obtenerlo.

* **Declaración explícita de necesidades**  
  El test especifica abstracciones (por ejemplo, `db_repository`), desconociendo detalles como conexiones o credenciales. Esto promueve código limpio y reutilizable.

* **Separación de setup y teardown**  
  La lógica de inicialización y limpieza reside en la fixture, centralizándola para revisiones de código y auditorías de seguridad.

* **Alineación con SRP (Single Responsibility Principle)**  
  Cada fixture maneja una responsabilidad única, como generar tokens JWT o configurar un proxy de red. La composición de fixtures construye entornos complejos sin violar SRP.

**Patrones avanzados de fixtures**

1. **Fixtures con hooks de seguridad**  
   En DevSecOps, fixtures pueden integrar chequeos de seguridad, como validación de certificados SSL o escaneo de vulnerabilidades en dependencias.

2. **Fixtures asíncronas**  
   Para aplicaciones async (por ejemplo, con asyncio), usa `@pytest_asyncio.fixture` para inyectar dependencias asíncronas, como clientes WebSocket.

3. **Fixtures con caching**  
   Para optimizar, fixtures pueden cachear resultados (por ejemplo, datasets sintéticos) usando `request.config.cache`.

**Variantes habituales de DI con fixtures**


| Variante             | Idea central                                                                       | Situación típica en pipelines DevOps/DevSecOps                                                                                                   |
| -------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Constructor-like** | Fixture como fábrica: crea y devuelve objetos configurados.                        | Construir instancias con feature flags; en DevSecOps, inyectar clientes con cifrado habilitado para entornos sensibles.                        |
| **Setter-like**      | Fixture aplica parches o hooks dinámicos.                                          | Redirigir llamadas a stubs en redes restringidas; en DevSecOps, aplicar monkey-patches para simular ataques como inyección SQL.               |
| **Interface-driven** | Fixture implementa interfaces mínimas del dominio.                                 | Cambiar backends (SQLite vs. Postgres) vía variables de entorno; en DevSecOps, asegurar que interfaces incluyan chequeos de autorización.     |
| **Proxy-like**       | Fixture envuelve dependencias con proxies para interceptar/modificar.               | Introducir fallos en pruebas de caos; en DevSecOps, proxies para monitorear y bloquear accesos no autorizados o detectar fugas de datos.      |
| **Factory-like**     | Fixture genera múltiples instancias dinámicamente.                                 | Pruebas paralelas con isolation; en DevSecOps, generar entornos sandboxed para pruebas de penetración sin exponer datos reales.                |

#### Integración en flujos DevOps

1. **Elasticidad de entornos efímeros**  
   En unit tests: fixtures con mocks embebidos. En integración: Docker Compose. En staging: servicios cloud via secret managers. Esto asegura reproducibilidad.

2. **Observabilidad y trazabilidad**  
   Fixtures inyectan clientes instrumentados (por ejemplo, con OpenTelemetry) para trazar spans en tests, correlacionando con métricas de producción.

3. **Gobernanza de datos**  
   Fixtures eligen datasets anonimizados o sintéticos, cumpliendo GDPR. En CI: datos ficticios; en pre-prod: sanitizados.

4. **Estrategias chaos-friendly**  
   Fixtures parametrizadas introducen fallos probabilísticos para validar resiliencia.

5. **Versionado progresivo**  
   Fixtures adaptadoras para migraciones v1 -> v2, ejecutando tests duales.

6. **Integración con herramientas CI/CD**  
   En GitHub Actions o Jenkins, fixtures se configuran via env vars para alinear con stages del pipeline.

#### Orientación a DevSecOps: Integrando seguridad en DIP y pruebas

DevSecOps extiende DevOps incorporando seguridad como responsabilidad compartida ("shift-left security"). DIP y fixtures en pytest son ideales para esto, ya que permiten inyectar prácticas de seguridad de manera desacoplada, automatizando chequeos y minimizando riesgos en pipelines.

#### Beneficios de DIP en DevSecOps

1. **Detección temprana de vulnerabilidades**  
   Fixtures pueden inyectar scanners de seguridad (por ejemplo, OWASP ZAP proxies) en tests de integración, simulando ataques como XSS o CSRF sin alterar el código de negocio.

2. **Configuraciones seguras por defecto**  
   Al centralizar DI en fixtures, se aplican principios como "least privilege": por ejemplo, inyectar conexiones DB con roles de solo lectura en tests, previniendo escaladas de privilegios.

3. **Pruebas de seguridad automatizadas**  
   Integra herramientas como SAST (Static Application Security Testing) o DAST (Dynamic) en fixtures. Por ejemplo, una fixture puede envolver un cliente API con un proxy que chequea por headers de seguridad (por ejemplo, CSP, HSTS).

#### Patrones DevSecOps con fixtures

1. **Fixtures para pruebas de penetración**  
   Usa fixtures para inyectar mocks vulnerables (por ejemplo, un repositorio con inyección SQL simulada) y validar que la lógica de negocio resiste ataques.

   Ejemplo en código:
   ```python
   @pytest.fixture
   def vulnerable_db_repository():
       from sql_injection_simulator import VulnerableRepo
       yield VulnerableRepo()
       # Teardown: log any detected injections

   def test_secure_query(vulnerable_db_repository):
       with pytest.raises(SecurityException):
           vulnerable_db_repository.query("SELECT * FROM users WHERE id = 1; DROP TABLE users;")
   ```

2. **Inyección de secretos seguros**  
   Fixtures integran con Vault o AWS Secrets Manager para inyectar credenciales efímeras, evitando hardcoding y reduciendo exposición.

   ```python
   @pytest.fixture
   def secure_api_client():
       import hvac  # HashiCorp Vault client
       client = hvac.Client(url='http://vault:8200')
       secret = client.secrets.kv.read_secret_version(path='my/secret')['data']['data']
       return APIClient(token=secret['token'])
   ```

3. **Pruebas de cumplimiento regulatorio**  
   Fixtures generan datasets compliant (por ejemplo, sin PII) y validan contra estándares como PCI-DSS o HIPAA en cada run del pipeline.

4. **Chaos engineering con foco en seguridad**  
   Extiende chaos-friendly: fixtures introducen fallos de seguridad (por ejemplo, certificados inválidos) para probar respuestas a brechas.

5. **Auditorías y logging de seguridad**  
   Fixtures adjuntan logs de seguridad a tests, integrándose con SIEM (Security Information and Event Management) como Splunk.

#### Integración en pipelines DevSecOps

- **Shift-left**: Incluye security gates en CI stages, usando fixtures para ejecutar scans antes de merges.
- **Automatización**: Herramientas como SonarQube o Trivy se inyectan via fixtures para escanear contenedores.
- **Respuesta a incidentes**: Fixtures permiten reproducir entornos de brechas para tests post-mortem.
- **Colaboración**: Desarrolladores, ops y security usan las mismas fixtures, fomentando "Sec" en DevOps.

#### Puntos de alineación con principios SOLID

* **DIP**: Tests dependen de contratos abstractos, no concretos; en DevSecOps, esto incluye contratos con chequeos de seguridad integrados.
* **SRP**: Fixtures focalizadas; añade responsabilidad de seguridad sin sobrecargar.
* **OCP (Open-Closed Principle)**: Extiende fixtures para nuevos scanners de seguridad sin modificar tests.
* **LSP (Liskov Substitution Principle)**: Mocks seguros sustituyen reales sin romper comportamiento.
* **ISP (Interface Segregation Principle)**: Interfaces mínimas, exponiendo solo métodos seguros.

### Variantes de DI

#### Constructor-like fixtures

**Descripción:**
Estos fixtures funcionan como fábricas preconfiguradas que devuelven instancias "listas para usar" de componentes pesados o complejos: clientes HTTP, conexiones a bases de datos, clientes de colas de mensajería o incluso objetos que envuelven autenticación y autorización completas.

**Características clave:**

* **Inicialización única:** la construcción del objeto (que puede implicar handshake, autenticación o carga de configuración) se realiza una única vez por sesión de test (scope `session` o `module`), reduciendo la sobrecarga en comparación con inicializaciones repetidas.
* **Reuse a nivel de suite:** al definirse con scope amplio, el fixture garantiza que todos los tests que lo requieran reciban la misma instancia o una instancia equivalente, evitando inicializaciones redundantes.
* **Configuración centralizada:** parámetros como URLs, credenciales o timeouts se parametrizan en un mismo lugar, facilitando modificaciones globales.

**Ejemplo (pytest):**

```python
import pytest
import requests

@pytest.fixture(scope="session")
def http_client():
    # Imagina un cliente configurado con autenticación y logging
    session = requests.Session()
    session.auth = ("user", "pass")
    session.headers.update({"X-Env": "test"})
    session.timeout = 5
    yield session
    session.close()

def test_api_status(http_client):
    resp = http_client.get("https://api.service.local/health")
    assert resp.status_code == 200
```

**Uso en DevOps:**

* En la fase de **Integration Tests**, `http_client` puede apuntar a un servicio mockeado localmente o a un contenedor Docker levantado por el pipeline.
* En **Acceptance/E2E**, configuramos `http_client` para que use la URL de staging, simplemente cambiando una variable de entorno (sin modificar el test).

#### Setter-like fixtures

**Descripción:**
En lugar de devolver instancias completas, estos fixtures exponen funciones u objetos de utilidad que permiten parchear o ajustar dinámicamente comportamientos, tanto del código bajo prueba como de dependencias globales o módulos.

**Características clave:**

* **Flexibilidad puntual:** el fixture ofrece un "setter" o un contexto que modifica el estado durante el test, ideal para simular fallos y escenarios de borde.
* **Monkepatch centralizado:** encapsula llamadas a `monkeypatch.setattr`, `monkeypatch.setenv` o substituciones de módulos completos, evitando código repetido en cada test.
* **Scope reducido:** normalmente scope `function`, pues cada test puede requerir parches distintos.

**Ejemplo (pytest con monkeypatch):**

```python
import pytest
from myapp import servicio_pago

@pytest.fixture
def patch_gateway(monkeypatch):
    # Provee una función para sobrescribir el cliente de pagos
    def _patch(success=True):
        class FakeGateway:
            def procesar(self, monto):
                if success:
                    return {"status": "ok"}
                else:
                    raise Exception("Falló conexión al gateway")
        monkeypatch.setattr(servicio_pago, "Gateway", FakeGateway)
    return _patch

def test_pago_exitosa(patch_gateway):
    patch_gateway(success=True)
    resultado = servicio_pago.realizar_pago(100)
    assert resultado["status"] == "ok"

def test_pago_fallido(patch_gateway):
    patch_gateway(success=False)
    with pytest.raises(Exception):
        servicio_pago.realizar_pago(100)
```

**Uso en DevOps:**

* Durante pruebas unitarias, `patch_gateway` simula comportamientos del gateway de pago sin necesidad de un entorno real ni de credenciales.
* En un pipeline paralelo, varios tests aplican diversos parches, permitiendo comprobar la lógica de recuperación ante errores en escenarios controlados.


#### Interface-driven fixtures

**Descripción:**
Estos fixtures proporcionan implementaciones mínimas (fakes o stubs) que satisfacen únicamente la interfaz pública esperada por la lógica de negocio. No cargan librerías pesadas ni conocen detalles internos, lo que acelera la ejecución y refuerza el principio de Liskov Substitution.

**Características clave:**

* **Ligereza extrema:** al limitarse a métodos stub con comportamiento controlado, consumen muy pocos recursos.
* **Aislamiento completo:** no requieren conexiones externas, bases de datos ni servicios.
* **Documentación implícita:** el stub deja claro qué métodos e interacciones son relevantes para el test.

**Ejemplo (pytest):**

```python
import pytest
from typing import Protocol

# Definición de la interfaz (en Python 3.8+ via Protocol)
class Repositorio(Protocol):
    def guardar(self, entidad): ...
    def buscar(self, id): ...

@pytest.fixture
def repo_fake():
    class RepositorioFake:
        def __init__(self):
            self.almacen = {}
        def guardar(self, entidad):
            self.almacen[entidad.id] = entidad
        def buscar(self, id):
            return self.almacen.get(id)
    return RepositorioFake()

def test_creacion_entidad(repo_fake):
    servicio = ServicioEntidades(repo=repo_fake)
    entidad = Entidad(id=1, valor="X")
    servicio.crear(entidad)
    assert repo_fake.buscar(1).valor == "X"
```

**Uso en DevOps:**

* En **Unit Tests**, `repo_fake` permite verificar toda la lógica de `ServicioEntidades` sin arrancar una base de datos real.
* Al promover el uso de Protocols o interfaces explícitas, se facilita la migración a un stub con un contenedor de Redis en una fase de integración, simplemente cambiando la fixture.

####  Integración de DI en pipelines

#### Etapa de pruebas unitarias: máxima velocidad

* **Fixtures empleadas:** Setter-like e Interface-driven
* **Objetivo:** aislar la lógica de negocio y validar cada unidad con stubs y mocks ultraligeros.
* **Estrategia DevOps:** ejecutar estos tests en cada commit, aprovechando runners efímeros con capas de caché para dependencias, asegurando feedback en segundos.

**Ejemplo de pipeline:**

```yaml
stages:
  - unit_test

unit_test:
  stage: unit_test
  script:
    - pytest tests/unit --maxfail=1 --disable-warnings -q
  tags:
    - fast
```

#### Etapa de pruebas de integración: realismo controlado

* **Fixtures empleadas:** Constructor-like (con containers) y Setter-like para ajustes puntuales.
* **Objetivo:** verificar interacciones entre componentes (DB, colas, servicios externos).
* **Estrategia DevOps:** emplear Docker Compose o Kubernetes ephemeral namespaces para levantar servicios; reutilizar fixtures con configuración alternativa.

**Ejemplo de pipeline:**

```yaml
stages:
  - integration_test

integration_test:
  stage: integration_test
  services:
    - postgres:13
    - rabbitmq:3
  variables:
    DB_HOST: postgres
    MQ_HOST: rabbitmq
  script:
    - pytest tests/integration --docker-compose docker-compose.test.yml
```

En este contexto, el fixture `db_tmp` (Constructor-like) detecta la variable `DB_HOST` y conecta al contenedor levantado por el pipeline, mientras `patch_gateway` (Setter-like) puede simular puntos débiles en el flujo de mensajes.

####  Reutilización de código de test

Gracias a la abstracción mediante fixtures, el **mismo conjunto de tests** , idénticas funciones y aserciones puede correr tanto en la etapa rápida de unit tests como en la más completa de integration tests. Solo cambia la configuración de los fixtures:

* **Mode local (unit):** los fixtures de integración devuelven stubs e interfaces, reduciendo latencia.
* **Mode CI (integration):** esos mismos fixtures detectan flags de entorno (`CI=true`) y devuelven instancias conectadas a contenedores Docker o servicios reales de staging.

```python
@pytest.fixture
def repo(request):
    if request.config.getoption("--mode") == "unit":
        return RepositorioFake()
    else:
        uri = f"postgresql://{os.getenv('DB_HOST')}/test"
        return RepositorioReal(uri)
```

En el pipeline:

* **Unit tests:** `pytest --mode unit`
* **Integration tests:** `pytest --mode integration`

####  Flexibilidad y mantenimiento

* **Escalabilidad de la suite:** añadir nuevas variantes de fixtures (por ejemplo, para un nuevo microservicio) no obliga a modificar tests anteriores.
* **Aislamiento de entornos:** las mismas pruebas pueden ejecutarse en local, en contenedores CI y en staging, sin duplicar código.
* **Visibilidad y control:** errores en unit tests señalan problemas de lógica pura; errores en integration tests advierten de incompatibilidades de infraestructura o configuración.


La combinación de **Constructor-like**, **Setter-like** e **Interface-driven fixtures**, unida a una orquestación inteligente en el pipeline de CI/CD, permite a los equipos DevOps alcanzar un equilibrio entre velocidad y realismo de las pruebas, garantizando un flujo de entrega continuo donde cada cambio sea validado de forma precisa, eficiente y reproducible.




